-- ============================================================
-- SaloneMarket: Row Level Security Policies
-- Migration: 20261120000002_rls_policies.sql
-- ============================================================

-- ============================================================
-- Enable RLS on all 16 tables
-- ============================================================
ALTER TABLE public.profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendors           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_images    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carts             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_orders   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendor_orders     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_attempts  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wishlists         ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Helper: is_admin() inline check used in multiple policies
-- A stable function avoids repeating the subquery everywhere.
-- ============================================================
-- ============================================================
-- IMPORTANT: These MUST be LANGUAGE plpgsql (NOT sql) to prevent
-- PostgreSQL query planner from inlining them into RLS policies.
-- If inlined, is_admin() on the profiles table triggers the
-- profiles_select_own_or_admin policy which calls is_admin() again,
-- causing infinite recursion ERROR 42P17.
-- LANGUAGE plpgsql + SECURITY DEFINER bypasses RLS inside the function
-- and prevents inlining entirely.
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_role TEXT;
    v_uid  UUID := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RETURN false;
    END IF;
    -- Direct pk lookup bypasses RLS because SECURITY DEFINER
    SELECT role INTO v_role
    FROM public.profiles
    WHERE id = v_uid;
    RETURN COALESCE(v_role = 'admin', false);
END;
$$;

CREATE OR REPLACE FUNCTION public.is_vendor()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_role TEXT;
    v_uid  UUID := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RETURN false;
    END IF;
    SELECT role INTO v_role
    FROM public.profiles
    WHERE id = v_uid;
    RETURN COALESCE(v_role = 'vendor', false);
END;
$$;

-- ============================================================
-- 1. profiles
-- ============================================================
-- SELECT: own profile OR admin
CREATE POLICY "profiles_select_own_or_admin"
    ON public.profiles FOR SELECT
    USING (
        auth.uid() = id
        OR public.is_admin()
    );

-- UPDATE: own profile only (role escalation blocked by trigger)
CREATE POLICY "profiles_update_own"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- INSERT: handled by trigger only (service role) — no anon insert
-- DELETE: not allowed via RLS (cascade from auth.users)

-- ============================================================
-- 2. vendors
-- ============================================================
-- SELECT: active vendors (public), or own vendor profile, or admin
CREATE POLICY "vendors_select"
    ON public.vendors FOR SELECT
    USING (
        status = 'active'
        OR profile_id = auth.uid()
        OR public.is_admin()
    );

-- INSERT: only users with vendor role
CREATE POLICY "vendors_insert_vendor_role"
    ON public.vendors FOR INSERT
    WITH CHECK (
        profile_id = auth.uid()
        AND public.is_vendor()
    );

-- UPDATE own shop: vendor can update their own shop (status/commission_rate locked to admin)
CREATE POLICY "vendors_update_own_shop"
    ON public.vendors FOR UPDATE
    USING (
        profile_id = auth.uid()
        AND public.is_vendor()
    )
    WITH CHECK (
        profile_id = auth.uid()
        AND public.is_vendor()
    );

-- UPDATE admin: full control
CREATE POLICY "vendors_update_admin"
    ON public.vendors FOR UPDATE
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- DELETE admin only
CREATE POLICY "vendors_delete_admin"
    ON public.vendors FOR DELETE
    USING (public.is_admin());

-- ============================================================
-- 3. categories
-- ============================================================
-- SELECT: public
CREATE POLICY "categories_select_public"
    ON public.categories FOR SELECT
    USING (true);

-- INSERT/UPDATE/DELETE: admin only
CREATE POLICY "categories_insert_admin"
    ON public.categories FOR INSERT
    WITH CHECK (public.is_admin());

CREATE POLICY "categories_update_admin"
    ON public.categories FOR UPDATE
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

CREATE POLICY "categories_delete_admin"
    ON public.categories FOR DELETE
    USING (public.is_admin());

-- ============================================================
-- 4. products
-- ============================================================
-- SELECT: active products (public), vendor's own products, or admin
CREATE POLICY "products_select"
    ON public.products FOR SELECT
    USING (
        status = 'active'
        OR vendor_id IN (
            SELECT id FROM public.vendors WHERE profile_id = auth.uid()
        )
        OR public.is_admin()
    );

-- INSERT: vendor must own an active vendor shop
CREATE POLICY "products_insert_vendor"
    ON public.products FOR INSERT
    WITH CHECK (
        vendor_id IN (
            SELECT id FROM public.vendors
            WHERE profile_id = auth.uid() AND status = 'active'
        )
        AND public.is_vendor()
    );

-- UPDATE by vendor: own products only, cannot set status='active' (admin only for activation)
CREATE POLICY "products_update_vendor"
    ON public.products FOR UPDATE
    USING (
        vendor_id IN (
            SELECT id FROM public.vendors WHERE profile_id = auth.uid()
        )
        AND public.is_vendor()
    )
    WITH CHECK (
        vendor_id IN (
            SELECT id FROM public.vendors WHERE profile_id = auth.uid()
        )
        AND public.is_vendor()
        -- Vendors can only set status to draft or inactive (not active/flagged)
        AND status IN ('draft', 'inactive')
    );

-- UPDATE admin: full control over all products
CREATE POLICY "products_update_admin"
    ON public.products FOR UPDATE
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- DELETE: vendor owns AND status='draft', OR admin
CREATE POLICY "products_delete_vendor_draft"
    ON public.products FOR DELETE
    USING (
        (
            vendor_id IN (
                SELECT id FROM public.vendors WHERE profile_id = auth.uid()
            )
            AND status = 'draft'
        )
        OR public.is_admin()
    );

-- ============================================================
-- 5. product_images
-- ============================================================
-- SELECT: public
CREATE POLICY "product_images_select_public"
    ON public.product_images FOR SELECT
    USING (true);

-- INSERT: vendor owns the product, OR admin
CREATE POLICY "product_images_insert_vendor_or_admin"
    ON public.product_images FOR INSERT
    WITH CHECK (
        product_id IN (
            SELECT p.id FROM public.products p
            JOIN public.vendors v ON p.vendor_id = v.id
            WHERE v.profile_id = auth.uid()
        )
        OR public.is_admin()
    );

-- UPDATE: vendor owns the product, OR admin
CREATE POLICY "product_images_update_vendor_or_admin"
    ON public.product_images FOR UPDATE
    USING (
        product_id IN (
            SELECT p.id FROM public.products p
            JOIN public.vendors v ON p.vendor_id = v.id
            WHERE v.profile_id = auth.uid()
        )
        OR public.is_admin()
    )
    WITH CHECK (
        product_id IN (
            SELECT p.id FROM public.products p
            JOIN public.vendors v ON p.vendor_id = v.id
            WHERE v.profile_id = auth.uid()
        )
        OR public.is_admin()
    );

-- DELETE: vendor owns the product, OR admin
CREATE POLICY "product_images_delete_vendor_or_admin"
    ON public.product_images FOR DELETE
    USING (
        product_id IN (
            SELECT p.id FROM public.products p
            JOIN public.vendors v ON p.vendor_id = v.id
            WHERE v.profile_id = auth.uid()
        )
        OR public.is_admin()
    );

-- ============================================================
-- 6. addresses
-- ============================================================
-- SELECT: own addresses, admin reads all
CREATE POLICY "addresses_select_own_or_admin"
    ON public.addresses FOR SELECT
    USING (
        profile_id = auth.uid()
        OR public.is_admin()
    );

-- INSERT: own addresses
CREATE POLICY "addresses_insert_own"
    ON public.addresses FOR INSERT
    WITH CHECK (profile_id = auth.uid());

-- UPDATE: own addresses
CREATE POLICY "addresses_update_own"
    ON public.addresses FOR UPDATE
    USING (profile_id = auth.uid())
    WITH CHECK (profile_id = auth.uid());

-- DELETE: own addresses
CREATE POLICY "addresses_delete_own"
    ON public.addresses FOR DELETE
    USING (profile_id = auth.uid());

-- ============================================================
-- 7. carts
-- ============================================================
-- SELECT: own cart
CREATE POLICY "carts_select_own"
    ON public.carts FOR SELECT
    USING (customer_id = auth.uid());

-- INSERT: own cart
CREATE POLICY "carts_insert_own"
    ON public.carts FOR INSERT
    WITH CHECK (customer_id = auth.uid());

-- UPDATE: own cart
CREATE POLICY "carts_update_own"
    ON public.carts FOR UPDATE
    USING (customer_id = auth.uid())
    WITH CHECK (customer_id = auth.uid());

-- ============================================================
-- 8. cart_items
-- ============================================================
-- SELECT: items in own cart
CREATE POLICY "cart_items_select_own"
    ON public.cart_items FOR SELECT
    USING (
        cart_id IN (
            SELECT id FROM public.carts WHERE customer_id = auth.uid()
        )
    );

-- INSERT: items into own cart
CREATE POLICY "cart_items_insert_own"
    ON public.cart_items FOR INSERT
    WITH CHECK (
        cart_id IN (
            SELECT id FROM public.carts WHERE customer_id = auth.uid()
        )
    );

-- UPDATE: items in own cart
CREATE POLICY "cart_items_update_own"
    ON public.cart_items FOR UPDATE
    USING (
        cart_id IN (
            SELECT id FROM public.carts WHERE customer_id = auth.uid()
        )
    )
    WITH CHECK (
        cart_id IN (
            SELECT id FROM public.carts WHERE customer_id = auth.uid()
        )
    );

-- DELETE: items in own cart
CREATE POLICY "cart_items_delete_own"
    ON public.cart_items FOR DELETE
    USING (
        cart_id IN (
            SELECT id FROM public.carts WHERE customer_id = auth.uid()
        )
    );

-- ============================================================
-- 9. customer_orders
-- Service role (Edge Functions) handles all mutations.
-- ============================================================
-- SELECT: own orders, or admin
CREATE POLICY "customer_orders_select_own_or_admin"
    ON public.customer_orders FOR SELECT
    USING (
        customer_id = auth.uid()
        OR public.is_admin()
    );

-- INSERT/UPDATE/DELETE: DENY to all authenticated users
-- (Edge Functions use service role key which bypasses RLS)

-- ============================================================
-- 10. vendor_orders
-- ============================================================
-- SELECT: vendor's own orders, customer's orders, admin
CREATE POLICY "vendor_orders_select"
    ON public.vendor_orders FOR SELECT
    USING (
        vendor_id IN (
            SELECT id FROM public.vendors WHERE profile_id = auth.uid()
        )
        OR customer_id = auth.uid()
        OR public.is_admin()
    );

-- UPDATE: vendor can update status of their own orders; admin full
CREATE POLICY "vendor_orders_update_vendor"
    ON public.vendor_orders FOR UPDATE
    USING (
        vendor_id IN (
            SELECT id FROM public.vendors WHERE profile_id = auth.uid()
        )
        OR public.is_admin()
    )
    WITH CHECK (
        vendor_id IN (
            SELECT id FROM public.vendors WHERE profile_id = auth.uid()
        )
        OR public.is_admin()
    );

-- INSERT/DELETE: DENY

-- ============================================================
-- 11. order_items
-- ============================================================
-- SELECT: customer sees items on their orders; vendor sees their items; admin
CREATE POLICY "order_items_select"
    ON public.order_items FOR SELECT
    USING (
        customer_order_id IN (
            SELECT id FROM public.customer_orders WHERE customer_id = auth.uid()
        )
        OR vendor_id IN (
            SELECT id FROM public.vendors WHERE profile_id = auth.uid()
        )
        OR public.is_admin()
    );

-- INSERT/UPDATE/DELETE: DENY

-- ============================================================
-- 12. payment_attempts
-- ============================================================
-- SELECT: own payment attempts, admin
CREATE POLICY "payment_attempts_select_own_or_admin"
    ON public.payment_attempts FOR SELECT
    USING (
        customer_id = auth.uid()
        OR public.is_admin()
    );

-- INSERT/UPDATE/DELETE: DENY

-- ============================================================
-- 13. transactions (append-only — no mutations via RLS)
-- ============================================================
-- SELECT: own transactions, admin
CREATE POLICY "transactions_select_own_or_admin"
    ON public.transactions FOR SELECT
    USING (
        customer_id = auth.uid()
        OR public.is_admin()
    );

-- INSERT/UPDATE/DELETE: DENY to ALL (service role only)
-- Note: prevent_transaction_mutation trigger in migration 4 provides
-- belt-and-suspenders immutability enforcement at DB layer.

-- ============================================================
-- 14. reviews
-- ============================================================
-- SELECT: visible reviews, own (even invisible), admin
CREATE POLICY "reviews_select"
    ON public.reviews FOR SELECT
    USING (
        is_visible = true
        OR customer_id = auth.uid()
        OR public.is_admin()
    );

-- INSERT: customer must be authenticated and have an order_item
CREATE POLICY "reviews_insert_customer_with_order"
    ON public.reviews FOR INSERT
    WITH CHECK (
        customer_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.order_items oi
            JOIN public.vendor_orders vo ON oi.vendor_order_id = vo.id
            WHERE oi.id = order_item_id
              AND vo.customer_id = auth.uid()
              AND vo.status = 'delivered'
        )
    );

-- UPDATE: own reviews only
CREATE POLICY "reviews_update_own"
    ON public.reviews FOR UPDATE
    USING (customer_id = auth.uid())
    WITH CHECK (customer_id = auth.uid());

-- DELETE: admin only
CREATE POLICY "reviews_delete_admin"
    ON public.reviews FOR DELETE
    USING (public.is_admin());

-- ============================================================
-- 15. notifications
-- ============================================================
-- SELECT: own notifications, admin
CREATE POLICY "notifications_select_own_or_admin"
    ON public.notifications FOR SELECT
    USING (
        user_id = auth.uid()
        OR public.is_admin()
    );

-- UPDATE: own notifications (is_read only — enforced by app layer)
CREATE POLICY "notifications_update_own"
    ON public.notifications FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- INSERT/DELETE: DENY (service role / Edge Functions only)

-- ============================================================
-- 16. wishlists
-- ============================================================
-- SELECT: own wishlist
CREATE POLICY "wishlists_select_own"
    ON public.wishlists FOR SELECT
    USING (customer_id = auth.uid());

-- INSERT: own wishlist
CREATE POLICY "wishlists_insert_own"
    ON public.wishlists FOR INSERT
    WITH CHECK (customer_id = auth.uid());

-- DELETE: own wishlist
CREATE POLICY "wishlists_delete_own"
    ON public.wishlists FOR DELETE
    USING (customer_id = auth.uid());

-- ============================================================
-- Role escalation prevention trigger
-- (Full function defined in migration 4; referenced here for clarity)
-- Applied to profiles in migration 4.
-- ============================================================
