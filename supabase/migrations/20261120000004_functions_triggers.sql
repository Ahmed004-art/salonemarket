-- ============================================================
-- SaloneMarket: Functions & Triggers
-- Migration: 20261120000004_functions_triggers.sql
-- ============================================================

-- ============================================================
-- 1. handle_new_user()
-- Auto-creates a profiles row when a new auth.users row is inserted.
-- SECURITY DEFINER so it can write to profiles regardless of RLS.
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
        NEW.raw_user_meta_data ->> 'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

-- Ensure trigger exists (idempotent)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 2. update_updated_at()
-- Generic trigger function: sets updated_at = now() on any UPDATE.
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Apply update_updated_at to all relevant tables
DROP TRIGGER IF EXISTS trg_profiles_updated_at         ON public.profiles;
CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS trg_vendors_updated_at          ON public.vendors;
CREATE TRIGGER trg_vendors_updated_at
    BEFORE UPDATE ON public.vendors
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS trg_categories_updated_at       ON public.categories;
CREATE TRIGGER trg_categories_updated_at
    BEFORE UPDATE ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS trg_products_updated_at         ON public.products;
CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON public.products
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS trg_carts_updated_at            ON public.carts;
CREATE TRIGGER trg_carts_updated_at
    BEFORE UPDATE ON public.carts
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS trg_cart_items_updated_at       ON public.cart_items;
CREATE TRIGGER trg_cart_items_updated_at
    BEFORE UPDATE ON public.cart_items
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS trg_addresses_updated_at        ON public.addresses;
CREATE TRIGGER trg_addresses_updated_at
    BEFORE UPDATE ON public.addresses
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS trg_customer_orders_updated_at  ON public.customer_orders;
CREATE TRIGGER trg_customer_orders_updated_at
    BEFORE UPDATE ON public.customer_orders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS trg_vendor_orders_updated_at    ON public.vendor_orders;
CREATE TRIGGER trg_vendor_orders_updated_at
    BEFORE UPDATE ON public.vendor_orders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS trg_reviews_updated_at          ON public.reviews;
CREATE TRIGGER trg_reviews_updated_at
    BEFORE UPDATE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- 3. recalculate_product_rating()
-- AFTER INSERT/UPDATE/DELETE on reviews.
-- Recomputes products.rating_avg and rating_count.
-- ============================================================
CREATE OR REPLACE FUNCTION public.recalculate_product_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_product_id uuid;
BEGIN
    -- Determine which product_id to update
    IF TG_OP = 'DELETE' THEN
        v_product_id := OLD.product_id;
    ELSE
        v_product_id := NEW.product_id;
    END IF;

    UPDATE public.products
    SET
        rating_avg   = COALESCE((
            SELECT AVG(rating)::numeric(3,2)
            FROM public.reviews
            WHERE product_id = v_product_id
              AND is_visible = true
        ), 0.00),
        rating_count = (
            SELECT COUNT(*)
            FROM public.reviews
            WHERE product_id = v_product_id
              AND is_visible = true
        )
    WHERE id = v_product_id;

    RETURN NULL; -- AFTER trigger; return value is ignored
END;
$$;

DROP TRIGGER IF EXISTS trg_reviews_product_rating ON public.reviews;
CREATE TRIGGER trg_reviews_product_rating
    AFTER INSERT OR UPDATE OR DELETE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION public.recalculate_product_rating();

-- ============================================================
-- 4. recalculate_vendor_rating()
-- AFTER INSERT/UPDATE/DELETE on reviews.
-- Recomputes vendors.rating_avg and rating_count.
-- ============================================================
CREATE OR REPLACE FUNCTION public.recalculate_vendor_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_vendor_id uuid;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_vendor_id := OLD.vendor_id;
    ELSE
        v_vendor_id := NEW.vendor_id;
    END IF;

    UPDATE public.vendors
    SET
        rating_avg   = COALESCE((
            SELECT AVG(rating)::numeric(3,2)
            FROM public.reviews
            WHERE vendor_id = v_vendor_id
              AND is_visible = true
        ), 0.00),
        rating_count = (
            SELECT COUNT(*)
            FROM public.reviews
            WHERE vendor_id = v_vendor_id
              AND is_visible = true
        )
    WHERE id = v_vendor_id;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_reviews_vendor_rating ON public.reviews;
CREATE TRIGGER trg_reviews_vendor_rating
    AFTER INSERT OR UPDATE OR DELETE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION public.recalculate_vendor_rating();

-- ============================================================
-- 5. prevent_role_escalation()
-- BEFORE UPDATE on profiles.
-- Raises an exception if a non-service-role user attempts to
-- set role to 'vendor' or 'admin'.
-- Admins and the service role can change any role.
-- ============================================================
CREATE OR REPLACE FUNCTION public.prevent_role_escalation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Allow service_role and postgres (superuser) through unconditionally
    IF current_setting('request.jwt.claims', true)::jsonb ->> 'role' = 'service_role'
       OR current_user IN ('postgres', 'supabase_admin') THEN
        RETURN NEW;
    END IF;

    -- If role is not changing, nothing to enforce
    IF NEW.role = OLD.role THEN
        RETURN NEW;
    END IF;

    -- Check if the actor is an admin (read directly from table, bypass RLS)
    IF EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    ) THEN
        RETURN NEW;
    END IF;

    -- Non-admin is trying to escalate role — block it
    IF NEW.role IN ('vendor', 'admin') THEN
        RAISE EXCEPTION
            'Role escalation denied: only admins may assign vendor or admin roles.'
            USING ERRCODE = 'insufficient_privilege';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_prevent_role_escalation ON public.profiles;
CREATE TRIGGER trg_profiles_prevent_role_escalation
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.prevent_role_escalation();

-- ============================================================
-- 6. prevent_transaction_mutation()
-- BEFORE UPDATE OR DELETE on transactions.
-- Always raises an exception — the ledger is append-only.
-- Even the service role cannot UPDATE or DELETE transactions;
-- reversals must be recorded as new 'reversed' rows.
-- ============================================================
CREATE OR REPLACE FUNCTION public.prevent_transaction_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RAISE EXCEPTION
        'Transactions are immutable. The financial ledger is append-only. '
        'Record a reversal as a new transaction row with status=''reversed''.'
        USING ERRCODE = 'restrict_violation';
    -- RETURN NULL is unreachable but satisfies the trigger contract
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_transactions_no_update ON public.transactions;
CREATE TRIGGER trg_transactions_no_update
    BEFORE UPDATE ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.prevent_transaction_mutation();

DROP TRIGGER IF EXISTS trg_transactions_no_delete ON public.transactions;
CREATE TRIGGER trg_transactions_no_delete
    BEFORE DELETE ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.prevent_transaction_mutation();

-- ============================================================
-- SECURITY DEFINER function: insert_transaction()
-- The only authorised way for Edge Functions (via service role)
-- to write to the transactions ledger. Accepts all required
-- fields explicitly to prevent injection of arbitrary columns.
-- ============================================================
CREATE OR REPLACE FUNCTION public.insert_transaction(
    p_payment_attempt_id  uuid,
    p_customer_order_id   uuid,
    p_customer_id         uuid,
    p_reference           text,
    p_type                text,
    p_amount              numeric(12,2),
    p_currency            text,
    p_status              text,
    p_is_simulated        boolean,
    p_description         text DEFAULT NULL,
    p_metadata            jsonb DEFAULT '{}'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id uuid;
BEGIN
    INSERT INTO public.transactions (
        payment_attempt_id, customer_order_id, customer_id,
        reference, type, amount, currency, status,
        is_simulated, description, metadata
    )
    VALUES (
        p_payment_attempt_id, p_customer_order_id, p_customer_id,
        p_reference, p_type, p_amount, p_currency, p_status,
        p_is_simulated, p_description, p_metadata
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

-- Revoke direct EXECUTE from anon/authenticated; only service_role uses this
REVOKE EXECUTE ON FUNCTION public.insert_transaction FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.insert_transaction TO service_role;

-- ============================================================
-- 7. decrement_stock(p_product_id uuid, p_quantity integer)
-- Decrements stock_quantity for a product, ensuring it never goes below 0.
-- Used by edge functions when an order is placed.
-- ============================================================
CREATE OR REPLACE FUNCTION public.decrement_stock(p_product_id uuid, p_quantity integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.products
    SET stock_quantity = GREATEST(0, stock_quantity - p_quantity)
    WHERE id = p_product_id AND track_inventory = true;
END;
$$;

-- Allow service role to execute the stock decrement function
GRANT EXECUTE ON FUNCTION public.decrement_stock(uuid, integer) TO service_role;
