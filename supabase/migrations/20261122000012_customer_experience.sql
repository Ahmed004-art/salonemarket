-- ============================================================
-- SaloneMarket: Customer Experience, Promotions & Reviews
-- Migration: 20261122000012_customer_experience.sql
-- ============================================================

-- 1. Promotions & Coupons
CREATE TABLE IF NOT EXISTS public.promotions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                TEXT NOT NULL UNIQUE,
    description         TEXT,
    discount_type       TEXT NOT NULL CHECK (discount_type IN ('percentage', 'fixed_amount')),
    discount_value      NUMERIC(12,2) NOT NULL CHECK (discount_value > 0),
    min_order_amount    NUMERIC(12,2) NOT NULL DEFAULT 0,
    max_discount_amount NUMERIC(12,2),
    starts_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at          TIMESTAMPTZ,
    is_active           BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_promotions_code_active ON public.promotions (code, is_active);

ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "promotions_read_public"
    ON public.promotions FOR SELECT
    TO authenticated
    USING (is_active = true);

CREATE POLICY "promotions_admin_all"
    ON public.promotions FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Seed initial promotions
INSERT INTO public.promotions (code, description, discount_type, discount_value, min_order_amount, is_active)
VALUES 
    ('WELCOME10', '10% discount on your first order', 'percentage', 10.00, 50.00, true),
    ('SALONE50', 'SLE 50 off orders above SLE 250', 'fixed_amount', 50.00, 250.00, true)
ON CONFLICT (code) DO NOTHING;

-- RPC: Validate and Apply Promotion
CREATE OR REPLACE FUNCTION public.apply_promo_code(
    p_code          TEXT,
    p_subtotal      NUMERIC(12,2)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_promo RECORD;
    v_discount NUMERIC(12,2) := 0.00;
BEGIN
    IF p_code IS NULL OR length(trim(p_code)) = 0 THEN
        RAISE EXCEPTION 'Promo code is required' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    SELECT * INTO v_promo
    FROM public.promotions
    WHERE upper(code) = upper(trim(p_code))
      AND is_active = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'valid', false,
            'message', 'Invalid or inactive promo code'
        );
    END IF;

    IF v_promo.expires_at IS NOT NULL AND v_promo.expires_at < now() THEN
        RETURN jsonb_build_object(
            'valid', false,
            'message', 'Promo code has expired'
        );
    END IF;

    IF p_subtotal < v_promo.min_order_amount THEN
        RETURN jsonb_build_object(
            'valid', false,
            'message', 'Minimum order amount of SLE ' || v_promo.min_order_amount || ' required'
        );
    END IF;

    IF v_promo.discount_type = 'percentage' THEN
        v_discount := round((p_subtotal * (v_promo.discount_value / 100.0)), 2);
        IF v_promo.max_discount_amount IS NOT NULL AND v_discount > v_promo.max_discount_amount THEN
            v_discount := v_promo.max_discount_amount;
        END IF;
    ELSE
        v_discount := v_promo.discount_value;
    END IF;

    IF v_discount > p_subtotal THEN
        v_discount := p_subtotal;
    END IF;

    RETURN jsonb_build_object(
        'valid', true,
        'code', v_promo.code,
        'discount_type', v_promo.discount_type,
        'discount_value', v_promo.discount_value,
        'discount_amount', v_discount,
        'new_subtotal', (p_subtotal - v_discount),
        'message', 'Promo code applied successfully'
    );
END;
$$;

-- 2. Customer Feedback & Support Tickets
CREATE TABLE IF NOT EXISTS public.customer_feedback (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    customer_order_id   UUID REFERENCES public.customer_orders(id) ON DELETE SET NULL,
    type                TEXT NOT NULL CHECK (type IN ('general_feedback', 'product_issue', 'delivery_complaint', 'refund_request')),
    subject             TEXT NOT NULL,
    message             TEXT NOT NULL,
    status              TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'under_review', 'resolved', 'closed')),
    admin_response      TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "feedback_select_own_or_admin"
    ON public.customer_feedback FOR SELECT
    TO authenticated
    USING (customer_id = auth.uid() OR public.is_admin());

CREATE POLICY "feedback_insert_own"
    ON public.customer_feedback FOR INSERT
    TO authenticated
    WITH CHECK (customer_id = auth.uid());

CREATE POLICY "feedback_update_admin"
    ON public.customer_feedback FOR UPDATE
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- RPC: Check Review Eligibility
CREATE OR REPLACE FUNCTION public.check_review_eligibility(p_product_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_order_item RECORD;
    v_existing RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('eligible', false, 'reason', 'Authentication required');
    END IF;

    -- Check if user already reviewed this product
    SELECT id, rating, title, comment, created_at INTO v_existing
    FROM public.reviews
    WHERE product_id = p_product_id AND customer_id = v_user_id;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'eligible', false,
            'already_reviewed', true,
            'review_id', v_existing.id,
            'existing_rating', v_existing.rating,
            'reason', 'Product already reviewed'
        );
    END IF;

    -- Check if user has an order item for this product with delivered/confirmed status
    SELECT oi.id, oi.vendor_id INTO v_order_item
    FROM public.order_items oi
    JOIN public.customer_orders co ON co.id = oi.customer_order_id
    WHERE oi.product_id = p_product_id
      AND co.customer_id = v_user_id
      AND co.payment_status = 'paid'
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'eligible', false,
            'already_reviewed', false,
            'reason', 'Verified purchase required to write a review'
        );
    END IF;

    RETURN jsonb_build_object(
        'eligible', true,
        'order_item_id', v_order_item.id,
        'vendor_id', v_order_item.vendor_id,
        'reason', 'Eligible verified purchase'
    );
END;
$$;

-- RPC: Submit Product Review
CREATE OR REPLACE FUNCTION public.submit_product_review(
    p_product_id    UUID,
    p_rating        INT,
    p_title         TEXT DEFAULT NULL,
    p_comment       TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id       UUID := auth.uid();
    v_eligibility   JSONB;
    v_order_item_id UUID;
    v_vendor_id     UUID;
    v_review_id     UUID;
    v_avg_rating    NUMERIC(3,2);
    v_count_rating  INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'insufficient_privilege';
    END IF;

    IF p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Rating must be between 1 and 5' USING ERRCODE = 'check_violation';
    END IF;

    -- Verify eligibility
    v_eligibility := public.check_review_eligibility(p_product_id);
    IF (v_eligibility->>'eligible')::boolean != true THEN
        RAISE EXCEPTION '%', v_eligibility->>'reason' USING ERRCODE = 'check_violation';
    END IF;

    v_order_item_id := (v_eligibility->>'order_item_id')::uuid;
    v_vendor_id := (v_eligibility->>'vendor_id')::uuid;

    -- Insert Review
    INSERT INTO public.reviews (
        product_id, vendor_id, customer_id, order_item_id,
        rating, title, comment, is_visible
    )
    VALUES (
        p_product_id, v_vendor_id, v_user_id, v_order_item_id,
        p_rating, p_title, p_comment, true
    )
    RETURNING id INTO v_review_id;

    -- Recalculate Product average rating
    SELECT round(AVG(rating), 2), COUNT(*)
    INTO v_avg_rating, v_count_rating
    FROM public.reviews
    WHERE product_id = p_product_id AND is_visible = true;

    UPDATE public.products
    SET rating_avg = COALESCE(v_avg_rating, 0.00),
        rating_count = v_count_rating
    WHERE id = p_product_id;

    -- Recalculate Vendor average rating
    SELECT round(AVG(rating), 2), COUNT(*)
    INTO v_avg_rating, v_count_rating
    FROM public.reviews
    WHERE vendor_id = v_vendor_id AND is_visible = true;

    UPDATE public.vendors
    SET rating_avg = COALESCE(v_avg_rating, 0.00),
        rating_count = v_count_rating
    WHERE id = v_vendor_id;

    RETURN jsonb_build_object(
        'success', true,
        'review_id', v_review_id,
        'rating', p_rating,
        'message', 'Review submitted successfully'
    );
END;
$$;

-- RPC: Notifications bulk mark read
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    UPDATE public.notifications
    SET is_read = true
    WHERE user_id = auth.uid() AND is_read = false;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- Permissions
GRANT EXECUTE ON FUNCTION public.apply_promo_code(TEXT, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_review_eligibility(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_product_review(UUID, INT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated;
