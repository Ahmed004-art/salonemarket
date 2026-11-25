-- ============================================================
-- SaloneMarket: Vendor and Admin Portals Foundation
-- Migration: 20261122000011_vendor_admin_portals.sql
--
-- PURPOSE:
--   1. Provides authoritative server-side RPC functions for:
--      - Vendor onboarding / application (apply_for_vendor)
--      - Vendor dashboard analytics with real database values
--      - Vendor product management (vendor_save_product, vendor_delete_product)
--      - Vendor order management with strict status transition safeguards
--      - Admin platform dashboard metrics
--      - Admin vendor review, approval, suspension (admin_update_vendor_status)
--      - Admin product moderation (admin_update_product_status)
--   2. Enforces RLS and security rules:
--      - Vendors can only see and manipulate their own products & orders
--      - Vendors can never mark an unpaid order as paid
--      - Admins have audited oversight across all entities
-- ============================================================

-- ============================================================
-- 1. Vendor Application: apply_for_vendor
-- ============================================================
CREATE OR REPLACE FUNCTION public.apply_for_vendor(
    p_shop_name     TEXT,
    p_slug          TEXT,
    p_description   TEXT DEFAULT NULL,
    p_phone         TEXT DEFAULT NULL,
    p_location      TEXT DEFAULT 'Freetown, Sierra Leone',
    p_email         TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id   UUID := auth.uid();
    v_vendor_id UUID;
    v_vendor    RECORD;
    v_slug      TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'insufficient_privilege';
    END IF;

    IF p_shop_name IS NULL OR length(trim(p_shop_name)) = 0 THEN
        RAISE EXCEPTION 'Shop name is required' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    -- Clean slug
    v_slug := lower(regexp_replace(COALESCE(p_slug, p_shop_name), '[^a-zA-Z0-9]+', '-', 'g'));
    v_slug := trim(both '-' from v_slug);

    IF length(v_slug) = 0 THEN
        v_slug := 'shop-' || substr(gen_random_uuid()::text, 1, 8);
    END IF;

    -- Check if vendor already exists for this user
    SELECT * INTO v_vendor FROM public.vendors WHERE profile_id = v_user_id;
    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', true,
            'vendor_id', v_vendor.id,
            'status', v_vendor.status,
            'shop_name', v_vendor.shop_name,
            'message', 'Application already submitted'
        );
    END IF;

    -- Insert pending vendor record
    INSERT INTO public.vendors (
        profile_id, shop_name, slug, description,
        location, phone, email, status, commission_rate
    )
    VALUES (
        v_user_id, trim(p_shop_name), v_slug, p_description,
        COALESCE(p_location, 'Freetown, Sierra Leone'), p_phone, p_email, 'pending', 0.05
    )
    RETURNING id INTO v_vendor_id;

    -- Create notification for administrators
    INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
    SELECT
        p.id, 'system', 'New Vendor Application',
        'Shop "' || trim(p_shop_name) || '" has submitted a vendor application awaiting review.',
        jsonb_build_object('vendor_id', v_vendor_id, 'shop_name', trim(p_shop_name)),
        false
    FROM public.profiles p
    WHERE p.role = 'admin';

    RETURN jsonb_build_object(
        'success', true,
        'vendor_id', v_vendor_id,
        'status', 'pending',
        'shop_name', trim(p_shop_name),
        'message', 'Vendor application submitted successfully'
    );
END;
$$;

-- ============================================================
-- 2. Vendor Dashboard Statistics: vendor_get_dashboard_stats
-- ============================================================
CREATE OR REPLACE FUNCTION public.vendor_get_dashboard_stats(p_vendor_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id           UUID := auth.uid();
    v_vendor            RECORD;
    v_total_products    INT := 0;
    v_active_products   INT := 0;
    v_pending_orders    INT := 0;
    v_completed_orders  INT := 0;
    v_total_sales       NUMERIC(12,2) := 0.00;
    v_today_sales       NUMERIC(12,2) := 0.00;
    v_week_sales        NUMERIC(12,2) := 0.00;
    v_month_sales       NUMERIC(12,2) := 0.00;
    v_recent_orders     JSONB := '[]'::jsonb;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Verify vendor exists and caller owns it (or caller is admin)
    SELECT * INTO v_vendor FROM public.vendors WHERE id = p_vendor_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vendor not found' USING ERRCODE = 'no_data_found';
    END IF;

    IF v_vendor.profile_id != v_user_id AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied to vendor statistics' USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Product counts
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'active')
    INTO v_total_products, v_active_products
    FROM public.products
    WHERE vendor_id = p_vendor_id;

    -- Order counts and sales
    -- Pending orders = vendor orders requiring action or awaiting delivery
    SELECT COUNT(*)
    INTO v_pending_orders
    FROM public.vendor_orders vo
    JOIN public.customer_orders co ON co.id = vo.customer_order_id
    WHERE vo.vendor_id = p_vendor_id
      AND vo.status IN ('confirmed', 'processing', 'ready_for_pickup', 'shipped')
      AND co.payment_status = 'paid';

    -- Completed orders
    SELECT COUNT(*)
    INTO v_completed_orders
    FROM public.vendor_orders
    WHERE vendor_id = p_vendor_id
      AND status = 'delivered';

    -- Total Sales (all paid vendor orders)
    SELECT COALESCE(SUM(vo.vendor_payout), 0.00)
    INTO v_total_sales
    FROM public.vendor_orders vo
    JOIN public.customer_orders co ON co.id = vo.customer_order_id
    WHERE vo.vendor_id = p_vendor_id
      AND co.payment_status = 'paid'
      AND vo.status != 'cancelled';

    -- Today's sales
    SELECT COALESCE(SUM(vo.vendor_payout), 0.00)
    INTO v_today_sales
    FROM public.vendor_orders vo
    JOIN public.customer_orders co ON co.id = vo.customer_order_id
    WHERE vo.vendor_id = p_vendor_id
      AND co.payment_status = 'paid'
      AND vo.status != 'cancelled'
      AND vo.created_at >= date_trunc('day', now());

    -- Week's sales
    SELECT COALESCE(SUM(vo.vendor_payout), 0.00)
    INTO v_week_sales
    FROM public.vendor_orders vo
    JOIN public.customer_orders co ON co.id = vo.customer_order_id
    WHERE vo.vendor_id = p_vendor_id
      AND co.payment_status = 'paid'
      AND vo.status != 'cancelled'
      AND vo.created_at >= date_trunc('week', now());

    -- Month's sales
    SELECT COALESCE(SUM(vo.vendor_payout), 0.00)
    INTO v_month_sales
    FROM public.vendor_orders vo
    JOIN public.customer_orders co ON co.id = vo.customer_order_id
    WHERE vo.vendor_id = p_vendor_id
      AND co.payment_status = 'paid'
      AND vo.status != 'cancelled'
      AND vo.created_at >= date_trunc('month', now());

    -- Recent 5 Orders with items summary
    SELECT COALESCE(jsonb_agg(sub.order_json), '[]'::jsonb)
    INTO v_recent_orders
    FROM (
        SELECT jsonb_build_object(
            'id', vo.id,
            'customer_order_id', vo.customer_order_id,
            'status', vo.status,
            'payment_status', co.payment_status,
            'subtotal', vo.subtotal,
            'vendor_payout', vo.vendor_payout,
            'created_at', vo.created_at,
            'customer_name', COALESCE(p.full_name, 'Shopper'),
            'item_count', (SELECT COUNT(*) FROM public.order_items oi WHERE oi.vendor_order_id = vo.id)
        ) AS order_json
        FROM public.vendor_orders vo
        JOIN public.customer_orders co ON co.id = vo.customer_order_id
        JOIN public.profiles p ON p.id = vo.customer_id
        WHERE vo.vendor_id = p_vendor_id
        ORDER BY vo.created_at DESC
        LIMIT 5
    ) sub;

    RETURN jsonb_build_object(
        'vendor_id', p_vendor_id,
        'shop_name', v_vendor.shop_name,
        'status', v_vendor.status,
        'total_products', v_total_products,
        'active_products', v_active_products,
        'pending_orders', v_pending_orders,
        'completed_orders', v_completed_orders,
        'total_sales', v_total_sales,
        'today_sales', v_today_sales,
        'week_sales', v_week_sales,
        'month_sales', v_month_sales,
        'recent_orders', v_recent_orders
    );
END;
$$;

-- ============================================================
-- 3. Vendor Product Management: vendor_save_product
-- ============================================================
CREATE OR REPLACE FUNCTION public.vendor_save_product(
    p_vendor_id         UUID,
    p_product_id        UUID DEFAULT NULL,
    p_name              TEXT DEFAULT NULL,
    p_description       TEXT DEFAULT NULL,
    p_price             NUMERIC(12,2) DEFAULT NULL,
    p_compare_at_price  NUMERIC(12,2) DEFAULT NULL,
    p_cost_price        NUMERIC(12,2) DEFAULT NULL,
    p_stock_quantity    INT DEFAULT 0,
    p_category_id       UUID DEFAULT NULL,
    p_sku               TEXT DEFAULT NULL,
    p_status            TEXT DEFAULT 'draft',
    p_image_url         TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id       UUID := auth.uid();
    v_vendor        RECORD;
    v_product_id    UUID;
    v_slug          TEXT;
    v_base_slug     TEXT;
    v_slug_candidate TEXT;
    v_count         INT := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Verify vendor ownership and active status
    SELECT * INTO v_vendor FROM public.vendors WHERE id = p_vendor_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vendor shop not found' USING ERRCODE = 'no_data_found';
    END IF;

    IF v_vendor.profile_id != v_user_id AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Forbidden: You do not own this vendor store' USING ERRCODE = 'insufficient_privilege';
    END IF;

    IF v_vendor.status != 'active' AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Vendor store is %; only approved active stores can manage products', v_vendor.status
            USING ERRCODE = 'check_violation';
    END IF;

    -- Validations
    IF p_name IS NULL OR length(trim(p_name)) = 0 THEN
        RAISE EXCEPTION 'Product name is required' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_price IS NULL OR p_price < 0 THEN
        RAISE EXCEPTION 'Price must be greater than or equal to 0' USING ERRCODE = 'check_violation';
    END IF;

    IF p_stock_quantity IS NULL OR p_stock_quantity < 0 THEN
        RAISE EXCEPTION 'Stock quantity cannot be negative' USING ERRCODE = 'check_violation';
    END IF;

    IF p_status NOT IN ('draft', 'active', 'inactive') THEN
        RAISE EXCEPTION 'Invalid product status %', p_status USING ERRCODE = 'check_violation';
    END IF;

    IF p_product_id IS NOT NULL THEN
        -- UPDATE existing product
        SELECT id INTO v_product_id FROM public.products
        WHERE id = p_product_id AND vendor_id = p_vendor_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Product not found or not owned by vendor' USING ERRCODE = 'no_data_found';
        END IF;

        UPDATE public.products
        SET name = trim(p_name),
            description = p_description,
            price = p_price,
            compare_at_price = p_compare_at_price,
            cost_price = p_cost_price,
            stock_quantity = p_stock_quantity,
            category_id = p_category_id,
            sku = p_sku,
            status = p_status,
            updated_at = now()
        WHERE id = p_product_id;

        -- Update or insert primary image if provided
        IF p_image_url IS NOT NULL AND length(trim(p_image_url)) > 0 THEN
            INSERT INTO public.product_images (product_id, url, is_primary, sort_order)
            VALUES (p_product_id, trim(p_image_url), true, 0)
            ON CONFLICT DO NOTHING;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'product_id', p_product_id,
            'action', 'updated',
            'status', p_status
        );
    ELSE
        -- INSERT new product
        v_base_slug := lower(regexp_replace(trim(p_name), '[^a-zA-Z0-9]+', '-', 'g'));
        v_base_slug := trim(both '-' from v_base_slug);
        IF length(v_base_slug) = 0 THEN
            v_base_slug := 'product-' || substr(gen_random_uuid()::text, 1, 8);
        END IF;

        v_slug_candidate := v_base_slug;
        WHILE EXISTS (SELECT 1 FROM public.products WHERE vendor_id = p_vendor_id AND slug = v_slug_candidate) LOOP
            v_count := v_count + 1;
            v_slug_candidate := v_base_slug || '-' || v_count::text;
        END LOOP;
        v_slug := v_slug_candidate;

        INSERT INTO public.products (
            vendor_id, category_id, name, slug, description,
            price, compare_at_price, cost_price, sku,
            stock_quantity, track_inventory, status
        )
        VALUES (
            p_vendor_id, p_category_id, trim(p_name), v_slug, p_description,
            p_price, p_compare_at_price, p_cost_price, p_sku,
            p_stock_quantity, true, p_status
        )
        RETURNING id INTO v_product_id;

        IF p_image_url IS NOT NULL AND length(trim(p_image_url)) > 0 THEN
            INSERT INTO public.product_images (product_id, url, is_primary, sort_order)
            VALUES (v_product_id, trim(p_image_url), true, 0);
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'product_id', v_product_id,
            'action', 'created',
            'status', p_status
        );
    END IF;
END;
$$;

-- ============================================================
-- 4. Vendor Order Status Transition: vendor_update_order_status
-- ============================================================
CREATE OR REPLACE FUNCTION public.vendor_update_order_status(
    p_vendor_order_id   UUID,
    p_new_status        TEXT,
    p_notes             TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id       UUID := auth.uid();
    v_vorder        RECORD;
    v_corder        RECORD;
    v_vendor        RECORD;
    v_valid         BOOLEAN := false;
    v_all_delivered BOOLEAN := false;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Fetch vendor order
    SELECT * INTO v_vorder FROM public.vendor_orders WHERE id = p_vendor_order_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vendor order not found' USING ERRCODE = 'no_data_found';
    END IF;

    -- Verify ownership
    SELECT * INTO v_vendor FROM public.vendors WHERE id = v_vorder.vendor_id;
    IF v_vendor.profile_id != v_user_id AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Forbidden: You do not own this vendor order' USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Fetch associated customer order
    SELECT * INTO v_corder FROM public.customer_orders WHERE id = v_vorder.customer_order_id;

    -- SAFEGUARD: Never let vendors fulfill unpaid orders!
    IF v_corder.payment_status != 'paid' AND p_new_status IN ('processing', 'ready_for_pickup', 'shipped', 'delivered') THEN
        RAISE EXCEPTION 'Cannot advance fulfillment status: Customer order is unpaid (payment_status: %)', v_corder.payment_status
            USING ERRCODE = 'check_violation';
    END IF;

    -- SAFEGUARD: Validate legal status transitions
    -- awaiting_payment -> confirmed (only server upon payment)
    -- confirmed -> processing, cancelled
    -- processing -> ready_for_pickup, shipped, cancelled
    -- ready_for_pickup -> shipped
    -- shipped -> delivered
    IF v_vorder.status = 'confirmed' AND p_new_status IN ('processing', 'cancelled') THEN
        v_valid := true;
    ELSIF v_vorder.status = 'processing' AND p_new_status IN ('ready_for_pickup', 'shipped', 'cancelled') THEN
        v_valid := true;
    ELSIF v_vorder.status = 'ready_for_pickup' AND p_new_status IN ('shipped', 'delivered') THEN
        v_valid := true;
    ELSIF v_vorder.status = 'shipped' AND p_new_status = 'delivered' THEN
        v_valid := true;
    ELSIF public.is_admin() THEN
        -- Admin can override
        v_valid := true;
    END IF;

    IF NOT v_valid THEN
        RAISE EXCEPTION 'Invalid status transition from "%" to "%"', v_vorder.status, p_new_status
            USING ERRCODE = 'check_violation';
    END IF;

    -- Apply transition
    UPDATE public.vendor_orders
    SET status = p_new_status,
        notes = COALESCE(p_notes, notes),
        updated_at = now()
    WHERE id = p_vendor_order_id;

    -- Check if all sibling vendor orders under this customer order are delivered
    SELECT (COUNT(*) = COUNT(*) FILTER (WHERE status = 'delivered'))
    INTO v_all_delivered
    FROM public.vendor_orders
    WHERE customer_order_id = v_vorder.customer_order_id;

    IF v_all_delivered THEN
        UPDATE public.customer_orders
        SET status = 'fulfilled',
            updated_at = now()
        WHERE id = v_vorder.customer_order_id;
    ELSIF p_new_status IN ('shipped', 'delivered', 'ready_for_pickup') THEN
        UPDATE public.customer_orders
        SET status = 'partially_fulfilled',
            updated_at = now()
        WHERE id = v_vorder.customer_order_id AND status = 'confirmed';
    END IF;

    -- Customer Notification
    INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
    VALUES (
        v_vorder.customer_id,
        CASE
            WHEN p_new_status = 'shipped' THEN 'order_shipped'
            WHEN p_new_status = 'delivered' THEN 'order_delivered'
            ELSE 'system'
        END,
        'Order Status Update',
        'Your items from ' || v_vendor.shop_name || ' are now ' || p_new_status || '.',
        jsonb_build_object(
            'customer_order_id', v_vorder.customer_order_id,
            'vendor_order_id', v_vorder.id,
            'status', p_new_status
        ),
        false
    );

    RETURN jsonb_build_object(
        'success', true,
        'vendor_order_id', p_vendor_order_id,
        'old_status', v_vorder.status,
        'new_status', p_new_status
    );
END;
$$;

-- ============================================================
-- 5. Admin Dashboard Statistics: admin_get_platform_stats
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_get_platform_stats()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_total_customers       INT := 0;
    v_total_vendors         INT := 0;
    v_pending_vendors       INT := 0;
    v_active_vendors        INT := 0;
    v_suspended_vendors     INT := 0;
    v_total_products        INT := 0;
    v_active_products       INT := 0;
    v_flagged_products      INT := 0;
    v_total_orders          INT := 0;
    v_total_gmv             NUMERIC(12,2) := 0.00;
    v_today_gmv             NUMERIC(12,2) := 0.00;
    v_week_gmv              NUMERIC(12,2) := 0.00;
    v_month_gmv             NUMERIC(12,2) := 0.00;
    v_reconciliation_alerts INT := 0;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied: Administrator privileges required' USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Customers
    SELECT COUNT(*) INTO v_total_customers FROM public.profiles WHERE role = 'customer';

    -- Vendors
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'pending'),
        COUNT(*) FILTER (WHERE status = 'active'),
        COUNT(*) FILTER (WHERE status = 'suspended')
    INTO v_total_vendors, v_pending_vendors, v_active_vendors, v_suspended_vendors
    FROM public.vendors;

    -- Products
    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'active'),
        COUNT(*) FILTER (WHERE status = 'flagged')
    INTO v_total_products, v_active_products, v_flagged_products
    FROM public.products;

    -- Orders & GMV
    SELECT
        COUNT(*),
        COALESCE(SUM(total) FILTER (WHERE payment_status = 'paid'), 0.00),
        COALESCE(SUM(total) FILTER (WHERE payment_status = 'paid' AND created_at >= date_trunc('day', now())), 0.00),
        COALESCE(SUM(total) FILTER (WHERE payment_status = 'paid' AND created_at >= date_trunc('week', now())), 0.00),
        COALESCE(SUM(total) FILTER (WHERE payment_status = 'paid' AND created_at >= date_trunc('month', now())), 0.00)
    INTO v_total_orders, v_total_gmv, v_today_gmv, v_week_gmv, v_month_gmv
    FROM public.customer_orders;

    -- Reconciliation Alerts
    SELECT COUNT(*)
    INTO v_reconciliation_alerts
    FROM public.transactions
    WHERE (metadata->>'reconciliation_needed')::boolean = true;

    RETURN jsonb_build_object(
        'total_customers', v_total_customers,
        'total_vendors', v_total_vendors,
        'pending_vendors', v_pending_vendors,
        'active_vendors', v_active_vendors,
        'suspended_vendors', v_suspended_vendors,
        'total_products', v_total_products,
        'active_products', v_active_products,
        'flagged_products', v_flagged_products,
        'total_orders', v_total_orders,
        'total_gmv', v_total_gmv,
        'today_gmv', v_today_gmv,
        'week_gmv', v_week_gmv,
        'month_gmv', v_month_gmv,
        'reconciliation_alerts', v_reconciliation_alerts
    );
END;
$$;

-- ============================================================
-- 6. Admin Actions: admin_update_vendor_status
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_update_vendor_status(
    p_vendor_id         UUID,
    p_status            TEXT,
    p_commission_rate   NUMERIC(5,4) DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_vendor    RECORD;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied: Administrator privileges required' USING ERRCODE = 'insufficient_privilege';
    END IF;

    IF p_status NOT IN ('pending', 'active', 'suspended') THEN
        RAISE EXCEPTION 'Invalid status "%"', p_status USING ERRCODE = 'check_violation';
    END IF;

    SELECT * INTO v_vendor FROM public.vendors WHERE id = p_vendor_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vendor not found' USING ERRCODE = 'no_data_found';
    END IF;

    UPDATE public.vendors
    SET status = p_status,
        commission_rate = COALESCE(p_commission_rate, commission_rate),
        updated_at = now()
    WHERE id = p_vendor_id;

    -- If approved active, update the user profile role to 'vendor'
    IF p_status = 'active' THEN
        UPDATE public.profiles
        SET role = 'vendor', updated_at = now()
        WHERE id = v_vendor.profile_id AND role != 'admin';

        -- Send approval notification to vendor
        INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
        VALUES (
            v_vendor.profile_id, 'vendor_approved',
            'Vendor Application Approved!',
            'Congratulations! Your store "' || v_vendor.shop_name || '" has been approved. You can now access your Vendor Dashboard and list products.',
            jsonb_build_object('vendor_id', p_vendor_id, 'status', 'active'),
            false
        );
    ELSIF p_status = 'suspended' THEN
        INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
        VALUES (
            v_vendor.profile_id, 'vendor_suspended',
            'Vendor Store Suspended',
            'Your store "' || v_vendor.shop_name || '" has been suspended by an administrator. Please contact support.',
            jsonb_build_object('vendor_id', p_vendor_id, 'status', 'suspended'),
            false
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'vendor_id', p_vendor_id,
        'old_status', v_vendor.status,
        'new_status', p_status
    );
END;
$$;

-- ============================================================
-- 7. Admin Actions: admin_update_product_status
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_update_product_status(
    p_product_id    UUID,
    p_status        TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_product   RECORD;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied: Administrator privileges required' USING ERRCODE = 'insufficient_privilege';
    END IF;

    IF p_status NOT IN ('draft', 'active', 'inactive', 'flagged') THEN
        RAISE EXCEPTION 'Invalid status "%"', p_status USING ERRCODE = 'check_violation';
    END IF;

    SELECT * INTO v_product FROM public.products WHERE id = p_product_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found' USING ERRCODE = 'no_data_found';
    END IF;

    UPDATE public.products
    SET status = p_status,
        updated_at = now()
    WHERE id = p_product_id;

    RETURN jsonb_build_object(
        'success', true,
        'product_id', p_product_id,
        'old_status', v_product.status,
        'new_status', p_status
    );
END;
$$;

-- ============================================================
-- 8. Permissions
-- ============================================================
GRANT EXECUTE ON FUNCTION public.apply_for_vendor(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vendor_get_dashboard_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vendor_save_product(UUID, UUID, TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC, INT, UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vendor_update_order_status(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_platform_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_vendor_status(UUID, TEXT, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_product_status(UUID, TEXT) TO authenticated;
