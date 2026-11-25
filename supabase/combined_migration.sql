

-- ========================================================
-- MIGRATION: 20261120000001_initial_schema.sql
-- ========================================================

-- ============================================================
-- SaloneMarket: Initial Schema
-- Migration: 20261120000001_initial_schema.sql
-- ============================================================

-- Enable pgcrypto for gen_random_uuid() (Supabase has this by default, but just in case)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. profiles — extends auth.users
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id          uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name   text,
    phone       text        UNIQUE,
    avatar_url  text,
    role        text        NOT NULL DEFAULT 'customer'
                            CHECK (role IN ('customer', 'vendor', 'admin')),
    is_active   boolean     NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. vendors
-- ============================================================
CREATE TABLE IF NOT EXISTS public.vendors (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id        uuid        NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    shop_name         text        NOT NULL,
    slug              text        NOT NULL UNIQUE,
    description       text,
    logo_url          text,
    cover_image_url   text,
    location          text,
    phone             text,
    email             text,
    status            text        NOT NULL DEFAULT 'pending'
                                  CHECK (status IN ('pending', 'active', 'suspended')),
    rating_avg        numeric(3,2) NOT NULL DEFAULT 0.00
                                  CHECK (rating_avg BETWEEN 0 AND 5),
    rating_count      integer     NOT NULL DEFAULT 0
                                  CHECK (rating_count >= 0),
    commission_rate   numeric(5,4) NOT NULL DEFAULT 0.0500,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 3. categories (self-referencing for parent/child)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.categories (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    name              text        NOT NULL,
    slug              text        NOT NULL UNIQUE,
    description       text,
    icon_url          text,
    cover_image_url   text,
    parent_id         uuid        REFERENCES public.categories(id) ON DELETE SET NULL,
    sort_order        integer     DEFAULT 0,
    is_active         boolean     NOT NULL DEFAULT true,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 4. products
-- ============================================================
CREATE TABLE IF NOT EXISTS public.products (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id         uuid        NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
    category_id       uuid        REFERENCES public.categories(id) ON DELETE SET NULL,
    name              text        NOT NULL,
    slug              text        NOT NULL,
    description       text,
    price             numeric(12,2) NOT NULL CHECK (price >= 0),
    compare_at_price  numeric(12,2),
    cost_price        numeric(12,2),
    sku               text,
    stock_quantity    integer     NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    track_inventory   boolean     NOT NULL DEFAULT true,
    status            text        NOT NULL DEFAULT 'draft'
                                  CHECK (status IN ('draft', 'active', 'inactive', 'flagged')),
    rating_avg        numeric(3,2) NOT NULL DEFAULT 0.00
                                  CHECK (rating_avg BETWEEN 0 AND 5),
    rating_count      integer     NOT NULL DEFAULT 0
                                  CHECK (rating_count >= 0),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now(),
    UNIQUE (vendor_id, slug)
);

-- ============================================================
-- 5. product_images
-- ============================================================
CREATE TABLE IF NOT EXISTS public.product_images (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id  uuid        NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    url         text        NOT NULL,
    alt_text    text,
    sort_order  integer     DEFAULT 0,
    is_primary  boolean     DEFAULT false,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 6. addresses
-- ============================================================
CREATE TABLE IF NOT EXISTS public.addresses (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id      uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    label           text        DEFAULT 'Home',
    full_name       text,
    phone           text,
    address_line_1  text        NOT NULL,
    address_line_2  text,
    city            text        NOT NULL DEFAULT 'Freetown',
    district        text,
    is_default      boolean     DEFAULT false,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 7. carts
-- ============================================================
CREATE TABLE IF NOT EXISTS public.carts (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id uuid        NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 8. cart_items
-- ============================================================
CREATE TABLE IF NOT EXISTS public.cart_items (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id     uuid        NOT NULL REFERENCES public.carts(id) ON DELETE CASCADE,
    product_id  uuid        NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    vendor_id   uuid        NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
    quantity    integer     NOT NULL CHECK (quantity > 0),
    unit_price  numeric(12,2) NOT NULL CHECK (unit_price >= 0),
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (cart_id, product_id)
);

-- ============================================================
-- 9. customer_orders
-- ============================================================
CREATE TABLE IF NOT EXISTS public.customer_orders (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id         uuid        NOT NULL REFERENCES public.profiles(id),
    status              text        NOT NULL DEFAULT 'pending_payment'
                                    CHECK (status IN (
                                        'pending_payment', 'payment_failed', 'confirmed',
                                        'partially_fulfilled', 'fulfilled', 'cancelled', 'refunded'
                                    )),
    subtotal            numeric(12,2) NOT NULL,
    delivery_fee        numeric(12,2) NOT NULL DEFAULT 0,
    platform_fee        numeric(12,2) NOT NULL DEFAULT 0,
    total               numeric(12,2) NOT NULL,
    payment_method      text        CHECK (payment_method IN (
                                        'simulated', 'mobile_money', 'cash_on_delivery'
                                    )),
    payment_status      text        NOT NULL DEFAULT 'pending'
                                    CHECK (payment_status IN (
                                        'pending', 'processing', 'paid', 'failed', 'refunded'
                                    )),
    shipping_address_id uuid        REFERENCES public.addresses(id),
    notes               text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 10. vendor_orders
-- ============================================================
CREATE TABLE IF NOT EXISTS public.vendor_orders (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_order_id   uuid        NOT NULL REFERENCES public.customer_orders(id),
    vendor_id           uuid        NOT NULL REFERENCES public.vendors(id),
    customer_id         uuid        NOT NULL REFERENCES public.profiles(id),
    status              text        NOT NULL DEFAULT 'awaiting_payment'
                                    CHECK (status IN (
                                        'awaiting_payment', 'confirmed', 'processing',
                                        'ready_for_pickup', 'shipped', 'delivered', 'cancelled'
                                    )),
    subtotal            numeric(12,2) NOT NULL,
    delivery_fee        numeric(12,2) NOT NULL DEFAULT 0,
    commission_amount   numeric(12,2) NOT NULL DEFAULT 0,
    vendor_payout       numeric(12,2) NOT NULL,
    notes               text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 11. order_items (immutable snapshot)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.order_items (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_order_id     uuid        NOT NULL REFERENCES public.vendor_orders(id),
    customer_order_id   uuid        NOT NULL REFERENCES public.customer_orders(id),
    product_id          uuid        REFERENCES public.products(id) ON DELETE SET NULL,
    vendor_id           uuid        NOT NULL REFERENCES public.vendors(id),
    -- Snapshot columns (immutable at time of order)
    product_name        text        NOT NULL,
    product_image_url   text,
    sku                 text,
    quantity            integer     NOT NULL CHECK (quantity > 0),
    unit_price          numeric(12,2) NOT NULL,
    line_total          numeric(12,2) NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 12. payment_attempts
-- ============================================================
CREATE TABLE IF NOT EXISTS public.payment_attempts (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_order_id   uuid        NOT NULL REFERENCES public.customer_orders(id),
    customer_id         uuid        NOT NULL REFERENCES public.profiles(id),
    method              text        NOT NULL
                                    CHECK (method IN ('simulated', 'mobile_money', 'cash_on_delivery')),
    amount              numeric(12,2) NOT NULL CHECK (amount > 0),
    status              text        NOT NULL DEFAULT 'pending'
                                    CHECK (status IN ('pending', 'processing', 'succeeded', 'failed')),
    reference           text        NOT NULL UNIQUE,
    provider_reference  text,
    is_simulated        boolean     NOT NULL DEFAULT true,
    failure_reason      text,
    initiated_at        timestamptz DEFAULT now(),
    completed_at        timestamptz,
    metadata            jsonb       NOT NULL DEFAULT '{}'
);

-- ============================================================
-- 13. transactions (append-only financial ledger)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.transactions (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_attempt_id  uuid        REFERENCES public.payment_attempts(id),
    customer_order_id   uuid        REFERENCES public.customer_orders(id),
    customer_id         uuid        REFERENCES public.profiles(id),
    reference           text        NOT NULL UNIQUE,
    type                text        NOT NULL
                                    CHECK (type IN ('payment', 'refund', 'adjustment')),
    amount              numeric(12,2) NOT NULL,
    currency            text        NOT NULL DEFAULT 'SLL',
    status              text        NOT NULL
                                    CHECK (status IN ('succeeded', 'failed', 'reversed')),
    is_simulated        boolean     NOT NULL DEFAULT true,
    description         text,
    metadata            jsonb       NOT NULL DEFAULT '{}',
    created_at          timestamptz NOT NULL DEFAULT now()
    -- NO updated_at: append-only ledger
);

-- ============================================================
-- 14. reviews
-- ============================================================
CREATE TABLE IF NOT EXISTS public.reviews (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id      uuid        NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    vendor_id       uuid        NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
    customer_id     uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    order_item_id   uuid        REFERENCES public.order_items(id) ON DELETE SET NULL,
    rating          smallint    NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title           text,
    comment         text,
    is_visible      boolean     DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (product_id, customer_id)
);

-- ============================================================
-- 15. notifications
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    type        text        NOT NULL
                            CHECK (type IN (
                                'order_placed', 'order_confirmed', 'order_shipped',
                                'order_delivered', 'payment_received', 'payment_failed',
                                'review_received', 'vendor_approved', 'vendor_suspended', 'system'
                            )),
    title       text        NOT NULL,
    body        text,
    data        jsonb       NOT NULL DEFAULT '{}',
    is_read     boolean     NOT NULL DEFAULT false,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 16. wishlists
-- ============================================================
CREATE TABLE IF NOT EXISTS public.wishlists (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    product_id  uuid        NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (customer_id, product_id)
);

-- ============================================================
-- handle_new_user() trigger: auto-create profile on signup
-- (Defined here; full implementation in migration 4)
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
        NEW.raw_user_meta_data ->> 'full_name',
        NEW.raw_user_meta_data ->> 'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

-- Attach trigger to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ========================================================
-- MIGRATION: 20261120000002_rls_policies.sql
-- ========================================================

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
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
$$;

CREATE OR REPLACE FUNCTION public.is_vendor()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'vendor'
    );
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


-- ========================================================
-- MIGRATION: 20261120000003_indexes.sql
-- ========================================================

-- ============================================================
-- SaloneMarket: Performance Indexes
-- Migration: 20261120000003_indexes.sql
-- ============================================================

-- ============================================================
-- products
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_products_vendor_id
    ON public.products (vendor_id);

CREATE INDEX IF NOT EXISTS idx_products_category_id
    ON public.products (category_id);

CREATE INDEX IF NOT EXISTS idx_products_status
    ON public.products (status);

-- Full-text search index on name + description
CREATE INDEX IF NOT EXISTS idx_products_fts
    ON public.products
    USING GIN (to_tsvector('english', name || ' ' || COALESCE(description, '')));

-- ============================================================
-- product_images
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_product_images_product_id
    ON public.product_images (product_id);

-- ============================================================
-- cart_items
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_cart_items_cart_id
    ON public.cart_items (cart_id);

CREATE INDEX IF NOT EXISTS idx_cart_items_product_id
    ON public.cart_items (product_id);

-- ============================================================
-- customer_orders
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_customer_orders_customer_created
    ON public.customer_orders (customer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_customer_orders_payment_status
    ON public.customer_orders (payment_status);

-- ============================================================
-- vendor_orders
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_vendor_orders_customer_order_id
    ON public.vendor_orders (customer_order_id);

CREATE INDEX IF NOT EXISTS idx_vendor_orders_vendor_created
    ON public.vendor_orders (vendor_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_vendor_orders_status
    ON public.vendor_orders (status);

-- ============================================================
-- order_items
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_order_items_vendor_order_id
    ON public.order_items (vendor_order_id);

CREATE INDEX IF NOT EXISTS idx_order_items_customer_order_id
    ON public.order_items (customer_order_id);

CREATE INDEX IF NOT EXISTS idx_order_items_product_id
    ON public.order_items (product_id);

-- ============================================================
-- payment_attempts
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_payment_attempts_customer_order_id
    ON public.payment_attempts (customer_order_id);

CREATE INDEX IF NOT EXISTS idx_payment_attempts_reference
    ON public.payment_attempts (reference);

CREATE INDEX IF NOT EXISTS idx_payment_attempts_status
    ON public.payment_attempts (status);

-- ============================================================
-- transactions
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_transactions_customer_order_id
    ON public.transactions (customer_order_id);

CREATE INDEX IF NOT EXISTS idx_transactions_customer_created
    ON public.transactions (customer_id, created_at DESC);

-- ============================================================
-- reviews
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_reviews_product_id
    ON public.reviews (product_id);

CREATE INDEX IF NOT EXISTS idx_reviews_vendor_id
    ON public.reviews (vendor_id);

-- ============================================================
-- notifications
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_notifications_user_read_created
    ON public.notifications (user_id, is_read, created_at DESC);

-- ============================================================
-- wishlists
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_wishlists_customer_id
    ON public.wishlists (customer_id);

CREATE INDEX IF NOT EXISTS idx_wishlists_product_id
    ON public.wishlists (product_id);

-- ============================================================
-- vendors (bonus: slug lookup, status filter)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_vendors_slug
    ON public.vendors (slug);

CREATE INDEX IF NOT EXISTS idx_vendors_status
    ON public.vendors (status);

-- ============================================================
-- categories (bonus: parent traversal, slug lookup)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_categories_parent_id
    ON public.categories (parent_id);

CREATE INDEX IF NOT EXISTS idx_categories_slug
    ON public.categories (slug);


-- ========================================================
-- MIGRATION: 20261120000004_functions_triggers.sql
-- ========================================================

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


-- ========================================================
-- MIGRATION: 20261120000005_seed_categories.sql
-- ========================================================

-- ============================================================
-- SaloneMarket: Seed Categories
-- Migration: 20261120000005_seed_categories.sql
--
-- Explicit UUIDs so child seeds / FK references are stable.
-- Parent categories inserted first; children follow with parent_id.
-- ============================================================

-- ============================================================
-- TOP-LEVEL CATEGORIES
-- ============================================================
INSERT INTO public.categories (id, name, slug, sort_order, is_active, created_at, updated_at)
VALUES
    -- 1. Electronics & Mobile
    ('a1000000-0000-0000-0000-000000000001',
     'Electronics & Mobile', 'electronics-mobile', 1, true, now(), now()),

    -- 2. Fashion & Clothing
    ('a2000000-0000-0000-0000-000000000001',
     'Fashion & Clothing', 'fashion-clothing', 2, true, now(), now()),

    -- 3. Food & Groceries
    ('a3000000-0000-0000-0000-000000000001',
     'Food & Groceries', 'food-groceries', 3, true, now(), now()),

    -- 4. Home & Living
    ('a4000000-0000-0000-0000-000000000001',
     'Home & Living', 'home-living', 4, true, now(), now()),

    -- 5. Health & Beauty
    ('a5000000-0000-0000-0000-000000000001',
     'Health & Beauty', 'health-beauty', 5, true, now(), now()),

    -- 6. Services
    ('a6000000-0000-0000-0000-000000000001',
     'Services', 'services', 6, true, now(), now())

ON CONFLICT (slug) DO UPDATE
    SET name       = EXCLUDED.name,
        sort_order = EXCLUDED.sort_order,
        is_active  = EXCLUDED.is_active,
        updated_at = now();

-- ============================================================
-- CHILDREN: Electronics & Mobile
-- ============================================================
INSERT INTO public.categories (id, name, slug, parent_id, sort_order, is_active, created_at, updated_at)
VALUES
    ('a1000000-0000-0000-0000-000000000011',
     'Phones & Accessories', 'phones-accessories',
     'a1000000-0000-0000-0000-000000000001', 1, true, now(), now()),

    ('a1000000-0000-0000-0000-000000000012',
     'Computers & Tablets', 'computers-tablets',
     'a1000000-0000-0000-0000-000000000001', 2, true, now(), now())

ON CONFLICT (slug) DO UPDATE
    SET name       = EXCLUDED.name,
        parent_id  = EXCLUDED.parent_id,
        sort_order = EXCLUDED.sort_order,
        is_active  = EXCLUDED.is_active,
        updated_at = now();

-- ============================================================
-- CHILDREN: Fashion & Clothing
-- ============================================================
INSERT INTO public.categories (id, name, slug, parent_id, sort_order, is_active, created_at, updated_at)
VALUES
    ('a2000000-0000-0000-0000-000000000011',
     'Men''s Wear', 'mens-wear',
     'a2000000-0000-0000-0000-000000000001', 1, true, now(), now()),

    ('a2000000-0000-0000-0000-000000000012',
     'Women''s Wear', 'womens-wear',
     'a2000000-0000-0000-0000-000000000001', 2, true, now(), now()),

    ('a2000000-0000-0000-0000-000000000013',
     'Children''s Clothing', 'childrens-clothing',
     'a2000000-0000-0000-0000-000000000001', 3, true, now(), now()),

    ('a2000000-0000-0000-0000-000000000014',
     'Shoes & Accessories', 'shoes-accessories',
     'a2000000-0000-0000-0000-000000000001', 4, true, now(), now())

ON CONFLICT (slug) DO UPDATE
    SET name       = EXCLUDED.name,
        parent_id  = EXCLUDED.parent_id,
        sort_order = EXCLUDED.sort_order,
        is_active  = EXCLUDED.is_active,
        updated_at = now();

-- ============================================================
-- CHILDREN: Food & Groceries
-- ============================================================
INSERT INTO public.categories (id, name, slug, parent_id, sort_order, is_active, created_at, updated_at)
VALUES
    ('a3000000-0000-0000-0000-000000000011',
     'Fresh Produce', 'fresh-produce',
     'a3000000-0000-0000-0000-000000000001', 1, true, now(), now()),

    ('a3000000-0000-0000-0000-000000000012',
     'Packaged Foods', 'packaged-foods',
     'a3000000-0000-0000-0000-000000000001', 2, true, now(), now()),

    ('a3000000-0000-0000-0000-000000000013',
     'Beverages', 'beverages',
     'a3000000-0000-0000-0000-000000000001', 3, true, now(), now())

ON CONFLICT (slug) DO UPDATE
    SET name       = EXCLUDED.name,
        parent_id  = EXCLUDED.parent_id,
        sort_order = EXCLUDED.sort_order,
        is_active  = EXCLUDED.is_active,
        updated_at = now();

-- ============================================================
-- CHILDREN: Home & Living
-- ============================================================
INSERT INTO public.categories (id, name, slug, parent_id, sort_order, is_active, created_at, updated_at)
VALUES
    ('a4000000-0000-0000-0000-000000000011',
     'Furniture', 'furniture',
     'a4000000-0000-0000-0000-000000000001', 1, true, now(), now()),

    ('a4000000-0000-0000-0000-000000000012',
     'Kitchen & Dining', 'kitchen-dining',
     'a4000000-0000-0000-0000-000000000001', 2, true, now(), now()),

    ('a4000000-0000-0000-0000-000000000013',
     'Bedding & Bath', 'bedding-bath',
     'a4000000-0000-0000-0000-000000000001', 3, true, now(), now())

ON CONFLICT (slug) DO UPDATE
    SET name       = EXCLUDED.name,
        parent_id  = EXCLUDED.parent_id,
        sort_order = EXCLUDED.sort_order,
        is_active  = EXCLUDED.is_active,
        updated_at = now();

-- ============================================================
-- CHILDREN: Health & Beauty
-- ============================================================
INSERT INTO public.categories (id, name, slug, parent_id, sort_order, is_active, created_at, updated_at)
VALUES
    ('a5000000-0000-0000-0000-000000000011',
     'Skincare', 'skincare',
     'a5000000-0000-0000-0000-000000000001', 1, true, now(), now()),

    ('a5000000-0000-0000-0000-000000000012',
     'Hair Care', 'hair-care',
     'a5000000-0000-0000-0000-000000000001', 2, true, now(), now()),

    ('a5000000-0000-0000-0000-000000000013',
     'Vitamins & Supplements', 'vitamins-supplements',
     'a5000000-0000-0000-0000-000000000001', 3, true, now(), now())

ON CONFLICT (slug) DO UPDATE
    SET name       = EXCLUDED.name,
        parent_id  = EXCLUDED.parent_id,
        sort_order = EXCLUDED.sort_order,
        is_active  = EXCLUDED.is_active,
        updated_at = now();

-- ============================================================
-- CHILDREN: Services
-- ============================================================
INSERT INTO public.categories (id, name, slug, parent_id, sort_order, is_active, created_at, updated_at)
VALUES
    ('a6000000-0000-0000-0000-000000000011',
     'Tailoring & Alterations', 'tailoring-alterations',
     'a6000000-0000-0000-0000-000000000001', 1, true, now(), now()),

    ('a6000000-0000-0000-0000-000000000012',
     'Repairs & Maintenance', 'repairs-maintenance',
     'a6000000-0000-0000-0000-000000000001', 2, true, now(), now()),

    ('a6000000-0000-0000-0000-000000000013',
     'Professional Services', 'professional-services',
     'a6000000-0000-0000-0000-000000000001', 3, true, now(), now())

ON CONFLICT (slug) DO UPDATE
    SET name       = EXCLUDED.name,
        parent_id  = EXCLUDED.parent_id,
        sort_order = EXCLUDED.sort_order,
        is_active  = EXCLUDED.is_active,
        updated_at = now();

-- ============================================================
-- Summary: 6 parent categories, 20 child categories = 26 total
-- UUID scheme: aX000000-0000-0000-0000-00000000000Y
--   X = parent index (1–6), Y = child index (1-based)
--   Parent UUIDs: aX000000-0000-0000-0000-000000000001
--   Child UUIDs:  aX000000-0000-0000-0000-00000000001Y
-- ============================================================


-- ========================================================
-- MIGRATION: 20261120000006_vendor_status_protection.sql
-- ========================================================

-- ============================================================
-- SaloneMarket: Vendor Status & Commission Protection
-- Migration: 20261120000006_vendor_status_protection.sql
--
-- Prevents vendors from self-activating their shop or changing
-- their commission_rate through the client. Only service-role
-- operations (Edge Functions, admin actions) may change these.
-- ============================================================

-- ── Function ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.prevent_vendor_self_activation()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    jwt_role text;
BEGIN
    -- Allow service-role and postgres superuser to bypass this check.
    -- In Supabase, service-role JWTs carry role='service_role' in the claims.
    BEGIN
        jwt_role := current_setting('request.jwt.claims', true)::jsonb->>'role';
    EXCEPTION WHEN OTHERS THEN
        jwt_role := NULL;
    END;

    IF jwt_role = 'service_role' OR current_user IN ('postgres', 'supabase_admin') THEN
        RETURN NEW;
    END IF;

    -- Block authenticated users from changing status or commission_rate
    -- on their own vendor row (or any vendor row via RLS bypass attempts).
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        RAISE EXCEPTION 'Vendors cannot modify their own shop status. Contact an administrator.'
            USING ERRCODE = 'insufficient_privilege';
    END IF;

    IF NEW.commission_rate IS DISTINCT FROM OLD.commission_rate THEN
        RAISE EXCEPTION 'Vendors cannot modify commission rate. Contact an administrator.'
            USING ERRCODE = 'insufficient_privilege';
    END IF;

    RETURN NEW;
END;
$$;

-- ── Trigger ───────────────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS trg_vendors_prevent_self_activation ON public.vendors;

CREATE TRIGGER trg_vendors_prevent_self_activation
    BEFORE UPDATE ON public.vendors
    FOR EACH ROW
    EXECUTE FUNCTION public.prevent_vendor_self_activation();

-- ── Comment ───────────────────────────────────────────────────────────────────

COMMENT ON FUNCTION public.prevent_vendor_self_activation() IS
    'Blocks vendor users from self-activating or changing commission_rate. '
    'Service-role (Edge Functions, admin operations) is exempt.';


-- ========================================================
-- MIGRATION: 20261120000007_storage_policies.sql
-- ========================================================

-- ============================================================
-- SaloneMarket: Storage Buckets & Strict Storage RLS Policies
-- Migration: 20261120000007_storage_policies.sql
--
-- Buckets:
--   1. 'product-images' — Public read; upload/update/delete restricted
--      strictly to authenticated and APPROVED vendors (status = 'active')
--      within their designated vendor folder (<vendor_id>/ or <profile_id>/).
--   2. 'avatars' — Public read; upload/update/delete restricted
--      strictly to the authenticated user owning the folder (<user_id>/).
-- ============================================================

-- Ensure storage schema extension exists
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── 1. Create or Update Storage Buckets ────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
    (
        'product-images',
        'product-images',
        true,
        10485760, -- 10MB limit per image
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
    ),
    (
        'avatars',
        'avatars',
        true,
        5242880,  -- 5MB limit per avatar
        ARRAY['image/jpeg', 'image/png', 'image/webp']
    )
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- storage.objects has RLS enabled by default in Supabase storage extension.
-- Explicit ALTER TABLE fails in migrations because postgres is not table owner (owned by supabase_storage_admin).
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- ── 2. Drop Any Pre-Existing SaloneMarket Storage Policies ────────────────────

DROP POLICY IF EXISTS "product_images_public_read" ON storage.objects;
DROP POLICY IF EXISTS "product_images_vendor_insert" ON storage.objects;
DROP POLICY IF EXISTS "product_images_vendor_update" ON storage.objects;
DROP POLICY IF EXISTS "product_images_vendor_delete" ON storage.objects;

DROP POLICY IF EXISTS "avatars_public_read" ON storage.objects;
DROP POLICY IF EXISTS "avatars_user_insert" ON storage.objects;
DROP POLICY IF EXISTS "avatars_user_update" ON storage.objects;
DROP POLICY IF EXISTS "avatars_user_delete" ON storage.objects;

-- Also drop generic names if previously defined
DROP POLICY IF EXISTS "Public Read Product Images" ON storage.objects;
DROP POLICY IF EXISTS "Vendor Upload Product Images" ON storage.objects;
DROP POLICY IF EXISTS "Public Read Avatars" ON storage.objects;
DROP POLICY IF EXISTS "User Upload Avatar" ON storage.objects;

-- ── 3. Policies: product-images ──────────────────────────────────────────────

-- A. Public Read: Any user (including unauthenticated guests) may view product images.
CREATE POLICY "product_images_public_read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'product-images');

-- B. Vendor Insert: Only authenticated and APPROVED vendors (status = 'active')
--    may upload images, and ONLY into their own designated folder (<vendor_id>/ or <profile_id>/).
--    Unapproved (status = 'pending') or suspended (status = 'suspended') vendors are rejected.
--    Root-level uploads are rejected because (storage.foldername(name))[1] evaluates to NULL.
CREATE POLICY "product_images_vendor_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'product-images'
    AND (
        EXISTS (
            SELECT 1 FROM public.vendors v
            WHERE (
                v.id::text = (storage.foldername(name))[1]
                OR v.profile_id::text = (storage.foldername(name))[1]
            )
            AND v.profile_id = auth.uid()
            AND v.status = 'active'
        )
        OR public.is_admin()
    )
);

-- C. Vendor Update: Only the owning active vendor (or admin) can update/replace an existing image.
--    Vendors cannot overwrite another vendor's image.
CREATE POLICY "product_images_vendor_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'product-images'
    AND (
        EXISTS (
            SELECT 1 FROM public.vendors v
            WHERE (
                v.id::text = (storage.foldername(name))[1]
                OR v.profile_id::text = (storage.foldername(name))[1]
            )
            AND v.profile_id = auth.uid()
            AND v.status = 'active'
        )
        OR public.is_admin()
    )
)
WITH CHECK (
    bucket_id = 'product-images'
    AND (
        EXISTS (
            SELECT 1 FROM public.vendors v
            WHERE (
                v.id::text = (storage.foldername(name))[1]
                OR v.profile_id::text = (storage.foldername(name))[1]
            )
            AND v.profile_id = auth.uid()
            AND v.status = 'active'
        )
        OR public.is_admin()
    )
);

-- D. Vendor Delete: Only the owning active vendor (or admin) can delete an image.
--    Vendors cannot delete another vendor's images.
CREATE POLICY "product_images_vendor_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'product-images'
    AND (
        EXISTS (
            SELECT 1 FROM public.vendors v
            WHERE (
                v.id::text = (storage.foldername(name))[1]
                OR v.profile_id::text = (storage.foldername(name))[1]
            )
            AND v.profile_id = auth.uid()
            AND v.status = 'active'
        )
        OR public.is_admin()
    )
);

-- ── 4. Policies: avatars ─────────────────────────────────────────────────────

-- A. Public Read: Any user may view user profile avatars.
CREATE POLICY "avatars_public_read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- B. User Insert: Users can only upload an avatar into their own designated folder (<user_id>/).
--    Users cannot upload into another user's folder or to the root of the bucket.
CREATE POLICY "avatars_user_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR public.is_admin()
    )
);

-- C. User Update: Users can only overwrite/update an avatar in their own designated folder.
CREATE POLICY "avatars_user_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR public.is_admin()
    )
)
WITH CHECK (
    bucket_id = 'avatars'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR public.is_admin()
    )
);

-- D. User Delete: Users can only delete their own avatar.
CREATE POLICY "avatars_user_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR public.is_admin()
    )
);


-- ========================================================
-- MIGRATION: 20261120000008_atomic_checkout.sql
-- ========================================================

-- ============================================================
-- SaloneMarket: Atomic Checkout RPC
-- Migration: 20261120000008_atomic_checkout.sql
--
-- PURPOSE
--   Replaces the sequential, non-atomic order-creation loop in the
--   initiate-checkout Edge Function (Milestone 3 Finding 2).
--
--   All writes — customer_orders, vendor_orders, order_items, stock
--   decrements, and cart clearing — now execute inside a single
--   PostgreSQL transaction.  Any failure causes a full rollback; no
--   orphaned rows, no partial stock decrements.
--
-- CONCURRENCY / OVERSELLING PREVENTION
--   FOR UPDATE is used when reading stock_quantity so that concurrent
--   checkouts for the same product are serialised at the row level.
--   The function re-reads live stock inside the transaction after the
--   lock is acquired, defeating any TOCTOU race between the
--   application-layer validation and the actual decrement.
--
-- IDEMPOTENCY
--   The Edge Function already prevents duplicate submissions by
--   returning the result of the same function call to the same HTTP
--   request (Supabase Functions are single-request handlers).  At the
--   database layer we do not add a separate idempotency key table in
--   this migration because the Flutter client does not currently send
--   one; the note below documents how to extend this.
--
-- NOTE: Do NOT edit already-applied historical migrations.
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_checkout_order(
    p_customer_id       uuid,
    p_cart_id           uuid,
    p_shipping_address_id uuid,   -- may be NULL
    p_notes             text,     -- may be NULL
    p_items             jsonb     -- array of cart-item objects (see below)
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
/*
  p_items element shape (validated by Edge Function before this call):
  {
    "product_id":      "<uuid>",
    "vendor_id":       "<uuid>",
    "product_name":    "<text>",
    "quantity":        <integer>,
    "unit_price":      <numeric>,   -- server-authoritative live price
    "commission_rate": <numeric>,   -- e.g. 0.05
    "track_inventory": <boolean>
  }
*/
DECLARE
    v_item              jsonb;
    v_product_id        uuid;
    v_vendor_id         uuid;
    v_quantity          integer;
    v_unit_price        numeric(12,2);
    v_commission_rate   numeric(5,4);
    v_track_inventory   boolean;

    -- Stock validation (locked read)
    v_live_stock        integer;

    -- Totals
    v_order_subtotal    numeric(12,2) := 0;
    v_delivery_fee      numeric(12,2) := 0;
    v_platform_fee      numeric(12,2) := 0;
    v_order_total       numeric(12,2);

    -- Vendor grouping: vendor_id -> subtotal, commission, payout, items
    -- We use a temporary table to accumulate per-vendor data cleanly.
    v_customer_order_id uuid;
    v_vendor_order_id   uuid;
    v_vendor_order_ids  uuid[] := ARRAY[]::uuid[];

    -- Result payload
    v_result            jsonb;
BEGIN
    -- ------------------------------------------------------------------
    -- 0. Guard: must have items
    -- ------------------------------------------------------------------
    IF jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Cart is empty' USING ERRCODE = 'check_violation';
    END IF;

    -- ------------------------------------------------------------------
    -- 1. Lock product rows FOR UPDATE to prevent concurrent overselling,
    --    then validate stock inside the transaction.
    -- ------------------------------------------------------------------
    FOR v_item IN SELECT jsonb_array_elements(p_items)
    LOOP
        v_product_id      := (v_item->>'product_id')::uuid;
        v_quantity        := (v_item->>'quantity')::integer;
        v_track_inventory := (v_item->>'track_inventory')::boolean;

        IF v_track_inventory THEN
            -- Advisory row-level lock: blocks concurrent checkout for same product
            SELECT stock_quantity
              INTO v_live_stock
              FROM public.products
             WHERE id = v_product_id
               AND status = 'active'
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Product "%" is no longer available',
                    v_item->>'product_name'
                    USING ERRCODE = 'check_violation';
            END IF;

            IF v_live_stock < v_quantity THEN
                RAISE EXCEPTION 'Insufficient stock for "%": % available, % requested',
                    v_item->>'product_name', v_live_stock, v_quantity
                    USING ERRCODE = 'check_violation';
            END IF;
        END IF;
    END LOOP;

    -- ------------------------------------------------------------------
    -- 2. Compute order totals
    -- ------------------------------------------------------------------
    FOR v_item IN SELECT jsonb_array_elements(p_items)
    LOOP
        v_unit_price  := (v_item->>'unit_price')::numeric(12,2);
        v_quantity    := (v_item->>'quantity')::integer;
        v_order_subtotal := v_order_subtotal + ROUND(v_unit_price * v_quantity, 2);
    END LOOP;

    v_order_total := ROUND(v_order_subtotal + v_delivery_fee + v_platform_fee, 2);

    -- ------------------------------------------------------------------
    -- 3. Insert customer_order
    -- ------------------------------------------------------------------
    INSERT INTO public.customer_orders (
        customer_id, status, subtotal, delivery_fee, platform_fee,
        total, payment_method, payment_status, shipping_address_id, notes
    )
    VALUES (
        p_customer_id, 'pending_payment', v_order_subtotal,
        v_delivery_fee, v_platform_fee, v_order_total,
        'simulated', 'pending', p_shipping_address_id, p_notes
    )
    RETURNING id INTO v_customer_order_id;

    -- ------------------------------------------------------------------
    -- 4. For each distinct vendor: create vendor_order + order_items
    -- ------------------------------------------------------------------
    FOR v_vendor_id IN
        SELECT DISTINCT (elem->>'vendor_id')::uuid
          FROM jsonb_array_elements(p_items) AS elem
    LOOP
        DECLARE
            v_vendor_subtotal   numeric(12,2) := 0;
            v_vendor_commission numeric(12,2);
            v_vendor_payout     numeric(12,2);
            v_vendor_comm_rate  numeric(5,4);
        BEGIN
            -- Calculate vendor subtotal + commission
            SELECT
                COALESCE(SUM(ROUND((elem->>'unit_price')::numeric * (elem->>'quantity')::integer, 2)), 0),
                MAX((elem->>'commission_rate')::numeric)
            INTO v_vendor_subtotal, v_vendor_comm_rate
            FROM jsonb_array_elements(p_items) AS elem
            WHERE (elem->>'vendor_id')::uuid = v_vendor_id;

            v_vendor_commission := ROUND(v_vendor_subtotal * v_vendor_comm_rate, 2);
            v_vendor_payout     := ROUND(v_vendor_subtotal - v_vendor_commission, 2);

            -- Insert vendor_order
            INSERT INTO public.vendor_orders (
                customer_order_id, vendor_id, customer_id, status,
                subtotal, delivery_fee, commission_amount, vendor_payout
            )
            VALUES (
                v_customer_order_id, v_vendor_id, p_customer_id,
                'awaiting_payment', v_vendor_subtotal, 0,
                v_vendor_commission, v_vendor_payout
            )
            RETURNING id INTO v_vendor_order_id;

            v_vendor_order_ids := array_append(v_vendor_order_ids, v_vendor_order_id);

            -- Insert order_items (snapshot) for this vendor
            INSERT INTO public.order_items (
                vendor_order_id, customer_order_id, product_id, vendor_id,
                product_name, product_image_url, sku,
                quantity, unit_price, line_total
            )
            SELECT
                v_vendor_order_id,
                v_customer_order_id,
                (elem->>'product_id')::uuid,
                v_vendor_id,
                elem->>'product_name',
                NULL,  -- product_image_url: not snapshotted in this version
                NULL,  -- sku: not snapshotted in this version
                (elem->>'quantity')::integer,
                (elem->>'unit_price')::numeric(12,2),
                ROUND((elem->>'unit_price')::numeric * (elem->>'quantity')::integer, 2)
            FROM jsonb_array_elements(p_items) AS elem
            WHERE (elem->>'vendor_id')::uuid = v_vendor_id;
        END;
    END LOOP;

    -- ------------------------------------------------------------------
    -- 5. Decrement stock atomically (GREATEST ensures floor of 0)
    -- ------------------------------------------------------------------
    FOR v_item IN SELECT jsonb_array_elements(p_items)
    LOOP
        IF (v_item->>'track_inventory')::boolean THEN
            UPDATE public.products
               SET stock_quantity = GREATEST(0, stock_quantity - (v_item->>'quantity')::integer)
             WHERE id = (v_item->>'product_id')::uuid
               AND track_inventory = true;
        END IF;
    END LOOP;

    -- ------------------------------------------------------------------
    -- 6. Clear cart items
    -- ------------------------------------------------------------------
    DELETE FROM public.cart_items WHERE cart_id = p_cart_id;

    -- ------------------------------------------------------------------
    -- 7. Return result payload (mirrors previous Edge Function response)
    -- ------------------------------------------------------------------
    v_result := jsonb_build_object(
        'customer_order_id', v_customer_order_id,
        'vendor_order_ids',  to_jsonb(v_vendor_order_ids),
        'total',             v_order_total
    );

    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        -- Re-raise so the Edge Function can inspect and return an appropriate HTTP error.
        RAISE;
END;
$$;

-- Grant execution to service_role only (Edge Functions run as service_role)
REVOKE EXECUTE ON FUNCTION public.create_checkout_order(uuid, uuid, uuid, text, jsonb) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.create_checkout_order(uuid, uuid, uuid, text, jsonb) TO service_role;

-- ============================================================
-- Keep the old decrement_stock function in place (used by
-- existing tests and potentially other Edge Functions).
-- The new RPC owns its own inline UPDATE instead.
-- ============================================================


-- ========================================================
-- MIGRATION: 20261120000009_checkout_idempotency.sql
-- ========================================================

-- ============================================================
-- SaloneMarket: Checkout Idempotency
-- Migration: 20261120000009_checkout_idempotency.sql
-- CI: Supabase CLI v2.stable, timeout 20m, --ignore-health-check
--
-- PURPOSE
--   Prevents duplicate orders when a client retries a checkout
--   request after a network failure or timeout.
--
--   The client generates a UUID before initiating checkout and
--   sends it as `idempotency_key`.  The Edge Function passes
--   it to the RPC.  On the first call the order is created and
--   the key is recorded.  On any subsequent call with the same
--   key the existing result is returned immediately — no new
--   order, no new stock decrement, no new cart clear.
--
-- DESIGN NOTES
--   • The table key is TEXT (not UUID) so callers can use any
--     stable string (UUID, hash, etc.).  The Edge Function
--     generates a UUID v4 per request and the Flutter client
--     sends it in the body.
--   • TTL / cleanup: idempotency keys older than 24 hours are
--     considered expired.  The check is enforced at query time
--     (WHERE created_at > now() - interval '24 hours'); expired
--     rows are ignored and a fresh order is created.  A
--     scheduled job can purge expired rows in production.
--   • The table is not directly accessible to the anon or
--     authenticated roles — all access is through the
--     SECURITY DEFINER RPC.
-- ============================================================

-- ============================================================
-- 1. Idempotency log table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.checkout_idempotency_log (
    key              TEXT        NOT NULL,
    customer_id      UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    customer_order_id UUID       NOT NULL REFERENCES public.customer_orders(id) ON DELETE CASCADE,
    vendor_order_ids  UUID[]     NOT NULL DEFAULT '{}',
    total            NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT checkout_idempotency_log_pkey PRIMARY KEY (key)
);

-- Index for fast expiry-aware lookups
CREATE INDEX IF NOT EXISTS idx_idempotency_log_created_at
    ON public.checkout_idempotency_log (created_at);

-- RLS: no direct client access (service_role only via SECURITY DEFINER function)
ALTER TABLE public.checkout_idempotency_log ENABLE ROW LEVEL SECURITY;
-- Deny all roles except service_role (which bypasses RLS)
-- No policies created = deny-by-default for anon / authenticated.

-- ============================================================
-- 2. Replace create_checkout_order with idempotency support
--    (CREATE OR REPLACE preserves existing grants on signature)
-- ============================================================
CREATE OR REPLACE FUNCTION public.create_checkout_order(
    p_customer_id         uuid,
    p_cart_id             uuid,
    p_shipping_address_id uuid,     -- may be NULL
    p_notes               text,     -- may be NULL
    p_items               jsonb,    -- array of cart-item objects
    p_idempotency_key     text      -- client-supplied UUID; NULL = no idempotency
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
/*
  p_items element shape (validated by Edge Function before this call):
  {
    "product_id":      "<uuid>",
    "vendor_id":       "<uuid>",
    "product_name":    "<text>",
    "quantity":        <integer>,
    "unit_price":      <numeric>,   -- server-authoritative live price
    "commission_rate": <numeric>,   -- e.g. 0.05
    "track_inventory": <boolean>
  }

  Idempotency behaviour:
  - If p_idempotency_key is not null and a non-expired record exists for
    that key, return the stored result without touching any other table.
  - TTL: 24 hours.  After expiry the key is treated as absent and a new
    order is created normally.
*/
DECLARE
    v_item              jsonb;
    v_product_id        uuid;
    v_vendor_id         uuid;
    v_quantity          integer;
    v_unit_price        numeric(12,2);
    v_commission_rate   numeric(5,4);
    v_track_inventory   boolean;

    -- Stock validation (locked read)
    v_live_stock        integer;

    -- Totals
    v_order_subtotal    numeric(12,2) := 0;
    v_delivery_fee      numeric(12,2) := 0;
    v_platform_fee      numeric(12,2) := 0;
    v_order_total       numeric(12,2);

    v_customer_order_id uuid;
    v_vendor_order_id   uuid;
    v_vendor_order_ids  uuid[] := ARRAY[]::uuid[];

    -- Idempotency
    v_existing          RECORD;

    -- Result payload
    v_result            jsonb;
BEGIN
    -- ------------------------------------------------------------------
    -- 0a. Idempotency check: return existing result if key already used
    -- ------------------------------------------------------------------
    IF p_idempotency_key IS NOT NULL THEN
        SELECT customer_order_id, vendor_order_ids, total
          INTO v_existing
          FROM public.checkout_idempotency_log
         WHERE key = p_idempotency_key
           AND created_at > now() - INTERVAL '24 hours';

        IF FOUND THEN
            -- Key exists and is not expired: return stored result
            RETURN jsonb_build_object(
                'customer_order_id', v_existing.customer_order_id,
                'vendor_order_ids',  to_jsonb(v_existing.vendor_order_ids),
                'total',             v_existing.total,
                'idempotent_replay', true
            );
        END IF;
    END IF;

    -- ------------------------------------------------------------------
    -- 0b. Guard: must have items
    -- ------------------------------------------------------------------
    IF jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Cart is empty' USING ERRCODE = 'check_violation';
    END IF;

    -- ------------------------------------------------------------------
    -- 1. Lock product rows FOR UPDATE to prevent concurrent overselling,
    --    then validate stock inside the transaction.
    -- ------------------------------------------------------------------
    FOR v_item IN SELECT jsonb_array_elements(p_items)
    LOOP
        v_product_id      := (v_item->>'product_id')::uuid;
        v_quantity        := (v_item->>'quantity')::integer;
        v_track_inventory := (v_item->>'track_inventory')::boolean;

        IF v_track_inventory THEN
            -- Row-level lock: blocks concurrent checkout for same product
            SELECT stock_quantity
              INTO v_live_stock
              FROM public.products
             WHERE id = v_product_id
               AND status = 'active'
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Product "%" is no longer available',
                    v_item->>'product_name'
                    USING ERRCODE = 'check_violation';
            END IF;

            IF v_live_stock < v_quantity THEN
                RAISE EXCEPTION 'Insufficient stock for "%": % available, % requested',
                    v_item->>'product_name', v_live_stock, v_quantity
                    USING ERRCODE = 'check_violation';
            END IF;
        END IF;
    END LOOP;

    -- ------------------------------------------------------------------
    -- 2. Compute order totals
    -- ------------------------------------------------------------------
    FOR v_item IN SELECT jsonb_array_elements(p_items)
    LOOP
        v_unit_price  := (v_item->>'unit_price')::numeric(12,2);
        v_quantity    := (v_item->>'quantity')::integer;
        v_order_subtotal := v_order_subtotal + ROUND(v_unit_price * v_quantity, 2);
    END LOOP;

    v_order_total := ROUND(v_order_subtotal + v_delivery_fee + v_platform_fee, 2);

    -- ------------------------------------------------------------------
    -- 3. Insert customer_order
    -- ------------------------------------------------------------------
    INSERT INTO public.customer_orders (
        customer_id, status, subtotal, delivery_fee, platform_fee,
        total, payment_method, payment_status, shipping_address_id, notes
    )
    VALUES (
        p_customer_id, 'pending_payment', v_order_subtotal,
        v_delivery_fee, v_platform_fee, v_order_total,
        'simulated', 'pending', p_shipping_address_id, p_notes
    )
    RETURNING id INTO v_customer_order_id;

    -- ------------------------------------------------------------------
    -- 4. For each distinct vendor: create vendor_order + order_items
    -- ------------------------------------------------------------------
    FOR v_vendor_id IN
        SELECT DISTINCT (elem->>'vendor_id')::uuid
          FROM jsonb_array_elements(p_items) AS elem
    LOOP
        DECLARE
            v_vendor_subtotal   numeric(12,2) := 0;
            v_vendor_commission numeric(12,2);
            v_vendor_payout     numeric(12,2);
            v_vendor_comm_rate  numeric(5,4);
        BEGIN
            -- Calculate vendor subtotal + commission
            SELECT
                COALESCE(SUM(ROUND((elem->>'unit_price')::numeric * (elem->>'quantity')::integer, 2)), 0),
                MAX((elem->>'commission_rate')::numeric)
            INTO v_vendor_subtotal, v_vendor_comm_rate
            FROM jsonb_array_elements(p_items) AS elem
            WHERE (elem->>'vendor_id')::uuid = v_vendor_id;

            v_vendor_commission := ROUND(v_vendor_subtotal * v_vendor_comm_rate, 2);
            v_vendor_payout     := ROUND(v_vendor_subtotal - v_vendor_commission, 2);

            -- Insert vendor_order
            INSERT INTO public.vendor_orders (
                customer_order_id, vendor_id, customer_id, status,
                subtotal, delivery_fee, commission_amount, vendor_payout
            )
            VALUES (
                v_customer_order_id, v_vendor_id, p_customer_id,
                'awaiting_payment', v_vendor_subtotal, 0,
                v_vendor_commission, v_vendor_payout
            )
            RETURNING id INTO v_vendor_order_id;

            v_vendor_order_ids := array_append(v_vendor_order_ids, v_vendor_order_id);

            -- Insert order_items (snapshot) for this vendor
            INSERT INTO public.order_items (
                vendor_order_id, customer_order_id, product_id, vendor_id,
                product_name, product_image_url, sku,
                quantity, unit_price, line_total
            )
            SELECT
                v_vendor_order_id,
                v_customer_order_id,
                (elem->>'product_id')::uuid,
                v_vendor_id,
                elem->>'product_name',
                NULL,  -- product_image_url: not snapshotted in this version
                NULL,  -- sku: not snapshotted in this version
                (elem->>'quantity')::integer,
                (elem->>'unit_price')::numeric(12,2),
                ROUND((elem->>'unit_price')::numeric * (elem->>'quantity')::integer, 2)
            FROM jsonb_array_elements(p_items) AS elem
            WHERE (elem->>'vendor_id')::uuid = v_vendor_id;
        END;
    END LOOP;

    -- ------------------------------------------------------------------
    -- 5. Decrement stock atomically (GREATEST ensures floor of 0)
    -- ------------------------------------------------------------------
    FOR v_item IN SELECT jsonb_array_elements(p_items)
    LOOP
        IF (v_item->>'track_inventory')::boolean THEN
            UPDATE public.products
               SET stock_quantity = GREATEST(0, stock_quantity - (v_item->>'quantity')::integer)
             WHERE id = (v_item->>'product_id')::uuid
               AND track_inventory = true;
        END IF;
    END LOOP;

    -- ------------------------------------------------------------------
    -- 6. Clear cart items
    -- ------------------------------------------------------------------
    DELETE FROM public.cart_items WHERE cart_id = p_cart_id;

    -- ------------------------------------------------------------------
    -- 7. Record idempotency key (after successful commit of all writes)
    -- ------------------------------------------------------------------
    IF p_idempotency_key IS NOT NULL THEN
        INSERT INTO public.checkout_idempotency_log (
            key, customer_id, customer_order_id, vendor_order_ids, total
        )
        VALUES (
            p_idempotency_key, p_customer_id,
            v_customer_order_id, v_vendor_order_ids, v_order_total
        )
        ON CONFLICT (key) DO NOTHING;  -- race: another concurrent insert won, ignore
    END IF;

    -- ------------------------------------------------------------------
    -- 8. Return result payload
    -- ------------------------------------------------------------------
    v_result := jsonb_build_object(
        'customer_order_id', v_customer_order_id,
        'vendor_order_ids',  to_jsonb(v_vendor_order_ids),
        'total',             v_order_total
    );

    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        -- Re-raise so the Edge Function can inspect and return an appropriate HTTP error.
        RAISE;
END;
$$;

-- ============================================================
-- Grants: revoke from PUBLIC, grant to service_role only.
-- The new 6-argument overload is a distinct function from the
-- old 5-argument version; both need explicit grants.
-- ============================================================
REVOKE EXECUTE ON FUNCTION public.create_checkout_order(uuid, uuid, uuid, text, jsonb, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.create_checkout_order(uuid, uuid, uuid, text, jsonb, text) TO service_role;

-- Keep old 5-argument signature callable by service_role in case
-- any existing code references it (it has no idempotency support).
-- New code MUST call the 6-argument version.
-- (The old grant from migration 8 still covers the 5-arg version.)

-- ============================================================
-- END OF MIGRATION
-- ============================================================


-- ========================================================
-- MIGRATION: 20261120000010_payment_foundation.sql
-- ========================================================

-- ============================================================
-- SaloneMarket: Payment Foundation & Atomic Settlement
-- Migration: 20261120000010_payment_foundation.sql
--
-- PURPOSE:
--   1. Expands payment_attempts schema to support multi-provider
--      metadata, explicit idempotency keys, canonical currency ('SLE'),
--      and full lifecycle states ('cancelled', 'expired').
--   2. Enforces unique idempotency keys per customer for payment
--      attempts and unique provider references.
--   3. Provides atomic, single-transaction RPC routines:
--      - create_or_get_payment_attempt(...)
--      - settle_order_payment(...)
--      - expire_unpaid_order(...)
--   4. Guarantees append-only immutable transactions ledger,
--      authoritative server-side validations, currency consistency,
--      inventory restoration exactly once upon expiration, failed
--      settlement idempotency, and administrator reconciliation alerts.
--   5. Restricts execution to service_role (SECURITY DEFINER with
--      safe search_path = public, pg_temp).
-- ============================================================

-- ============================================================
-- 1. Schema Enhancements: payment_attempts
-- ============================================================

-- Add provider discriminator, idempotency_key, and canonical currency ('SLE') columns.
-- Note: Existing monetary amounts are already in current Leone units (SLE); no numeric rescaling.
ALTER TABLE public.payment_attempts
    ADD COLUMN IF NOT EXISTS provider TEXT NOT NULL DEFAULT 'simulated',
    ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
    ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'SLE';

-- Update payment_attempts status check constraint to support full lifecycle
ALTER TABLE public.payment_attempts
    DROP CONSTRAINT IF EXISTS payment_attempts_status_check;

ALTER TABLE public.payment_attempts
    ADD CONSTRAINT payment_attempts_status_check
    CHECK (status IN ('pending', 'processing', 'succeeded', 'failed', 'cancelled', 'expired'));

-- Database-enforced idempotency: a customer cannot create duplicate payment attempts
-- with the same idempotency key
CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_attempts_customer_idempotency
    ON public.payment_attempts (customer_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- Protect provider references against duplicate use where provided
CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_attempts_provider_ref
    ON public.payment_attempts (provider, provider_reference)
    WHERE provider_reference IS NOT NULL;

-- Index for payment attempt lookups by customer_order and status
CREATE INDEX IF NOT EXISTS idx_payment_attempts_order_status
    ON public.payment_attempts (customer_order_id, status);

-- Index for fast transactions lookup by customer order and status
CREATE INDEX IF NOT EXISTS idx_transactions_order_status
    ON public.transactions (customer_order_id, status);

-- Index for transactions lookup by payment_attempt_id
CREATE INDEX IF NOT EXISTS idx_transactions_payment_attempt_id
    ON public.transactions (payment_attempt_id);

-- Update notifications type constraint to support order_cancelled notifications
ALTER TABLE public.notifications
    DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_type_check
    CHECK (type IN (
        'order_placed', 'order_confirmed', 'order_shipped',
        'order_delivered', 'payment_received', 'payment_failed',
        'review_received', 'vendor_approved', 'vendor_suspended',
        'system', 'order_cancelled'
    ));

-- ============================================================
-- 1b. Schema Enhancements: payment_webhook_events
--     Durable database idempotency log for payment provider webhooks.
--     Enforces a unique constraint on (provider, event_id) to prevent
--     concurrent race conditions and double settlements.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.payment_webhook_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider TEXT NOT NULL,
    event_id TEXT NOT NULL,
    event_name TEXT NOT NULL,
    customer_order_id UUID REFERENCES public.customer_orders(id) ON DELETE SET NULL,
    payment_attempt_id UUID REFERENCES public.payment_attempts(id) ON DELETE SET NULL,
    status TEXT NOT NULL CHECK (status IN ('processing', 'completed', 'failed', 'ignored')),
    processing_expires_at TIMESTAMPTZ,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_payment_webhook_events_provider_event UNIQUE (provider, event_id)
);

CREATE INDEX IF NOT EXISTS idx_payment_webhook_events_provider_event
    ON public.payment_webhook_events (provider, event_id);

CREATE INDEX IF NOT EXISTS idx_payment_webhook_events_order_id
    ON public.payment_webhook_events (customer_order_id);

CREATE INDEX IF NOT EXISTS idx_payment_webhook_events_lease
    ON public.payment_webhook_events (status, processing_expires_at);

ALTER TABLE public.payment_webhook_events ENABLE ROW LEVEL SECURITY;

-- Admins can view webhook logs for auditing and debugging
CREATE POLICY "Admins can view payment webhook events"
    ON public.payment_webhook_events
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
        )
    );

-- service_role has full access for webhook processing
CREATE POLICY "Service role has full access to payment webhook events"
    ON public.payment_webhook_events
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- ============================================================
-- 1c. RPC: claim_payment_webhook_event
--     Atomically claims or reclaims a processing lease for an event.
--     Guarantees that:
--     - Completed events are never re-processed (returns status: 'completed').
--     - In-flight active leases reject concurrent handlers (returns acquired: false, in_flight).
--     - Abandoned/crashed processing events are safely reclaimed once lease expires.
--     - Failed events can be retried safely.
--     - Concurrent reclaimers are serialized via row-level locks (FOR UPDATE).
-- ============================================================

CREATE OR REPLACE FUNCTION public.claim_payment_webhook_event(
    p_provider          TEXT,
    p_event_id          TEXT,
    p_event_name        TEXT,
    p_payload           JSONB DEFAULT '{}'::jsonb,
    p_lease_seconds     INT DEFAULT 60
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_event         RECORD;
    v_now           TIMESTAMPTZ := now();
    v_lease_until   TIMESTAMPTZ := v_now + (p_lease_seconds || ' seconds')::interval;
BEGIN
    IF p_provider IS NULL OR p_event_id IS NULL OR p_event_name IS NULL THEN
        RAISE EXCEPTION 'provider, event_id, and event_name are required' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    -- 1. Try initial atomic insert
    INSERT INTO public.payment_webhook_events (
        provider, event_id, event_name, status, payload, processing_expires_at, created_at, updated_at
    )
    VALUES (
        p_provider, p_event_id, p_event_name, 'processing', p_payload, v_lease_until, v_now, v_now
    )
    ON CONFLICT (provider, event_id) DO NOTHING
    RETURNING id, status, processing_expires_at
    INTO v_event;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'acquired', true,
            'reason', 'new_event',
            'event_db_id', v_event.id,
            'status', 'processing',
            'expires_at', v_event.processing_expires_at
        );
    END IF;

    -- 2. Conflict hit: row exists. Lock row FOR UPDATE to serialize concurrent handlers
    SELECT id, status, processing_expires_at, customer_order_id, payment_attempt_id, error_message
      INTO v_event
      FROM public.payment_webhook_events
     WHERE provider = p_provider
       AND event_id = p_event_id
    FOR UPDATE;

    -- Case A: Completed (terminal state)
    IF v_event.status = 'completed' THEN
        RETURN jsonb_build_object(
            'acquired', false,
            'status', 'completed',
            'reason', 'already_completed',
            'event_db_id', v_event.id,
            'customer_order_id', v_event.customer_order_id,
            'payment_attempt_id', v_event.payment_attempt_id
        );
    END IF;

    -- Case B: Actively in-flight within valid lease window
    IF v_event.status = 'processing' AND v_event.processing_expires_at > v_now THEN
        RETURN jsonb_build_object(
            'acquired', false,
            'status', 'processing',
            'reason', 'in_flight_active_lease',
            'event_db_id', v_event.id,
            'expires_at', v_event.processing_expires_at,
            'retry_after_seconds', GREATEST(1, EXTRACT(EPOCH FROM (v_event.processing_expires_at - v_now))::int)
        );
    END IF;

    -- Case C: Abandoned processing lease expired (crash recovery) OR failed event retry
    UPDATE public.payment_webhook_events
       SET status = 'processing',
           processing_expires_at = v_lease_until,
           updated_at = v_now,
           error_message = NULL
     WHERE id = v_event.id;

    RETURN jsonb_build_object(
        'acquired', true,
        'reason', CASE WHEN v_event.status = 'processing' THEN 'reclaimed_expired_lease' ELSE 'retry_failed_event' END,
        'event_db_id', v_event.id,
        'status', 'processing',
        'expires_at', v_lease_until
    );
END;
$$;

-- ============================================================
-- 2. RPC: create_or_get_payment_attempt
--    Atomically initiates a payment attempt with database-enforced
--    idempotency and order validation.
-- ============================================================

CREATE OR REPLACE FUNCTION public.create_or_get_payment_attempt(
    p_customer_order_id  UUID,
    p_customer_id        UUID,
    p_amount             NUMERIC(12,2),
    p_currency           TEXT DEFAULT 'SLE',
    p_method             TEXT DEFAULT 'simulated',
    p_provider           TEXT DEFAULT 'simulated',
    p_idempotency_key    TEXT DEFAULT NULL,
    p_metadata           JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order             RECORD;
    v_existing_attempt  RECORD;
    v_attempt_id        UUID;
    v_reference         TEXT;
BEGIN
    -- 1. Input validations
    IF p_customer_order_id IS NULL THEN
        RAISE EXCEPTION 'customer_order_id is required' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_customer_id IS NULL THEN
        RAISE EXCEPTION 'customer_id is required' USING ERRCODE = 'invalid_parameter_value';
    END IF;
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'amount must be greater than zero' USING ERRCODE = 'check_violation';
    END IF;
    IF p_currency NOT IN ('SLL', 'SLE') THEN
        RAISE EXCEPTION 'Unsupported currency "%"', p_currency USING ERRCODE = 'check_violation';
    END IF;
    IF p_method NOT IN ('simulated', 'mobile_money', 'cash_on_delivery') THEN
        RAISE EXCEPTION 'Invalid payment method "%"', p_method USING ERRCODE = 'check_violation';
    END IF;

    -- 2. Idempotency check: return existing attempt if key already used by this customer
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id, customer_order_id, customer_id, amount, currency,
               status, reference, provider, provider_reference
          INTO v_existing_attempt
          FROM public.payment_attempts
         WHERE customer_id = p_customer_id
           AND idempotency_key = p_idempotency_key;

        IF FOUND THEN
            -- Validate that the key was not reused for a different order
            IF v_existing_attempt.customer_order_id != p_customer_order_id THEN
                RAISE EXCEPTION 'Idempotency key "%" is already bound to a different order %',
                    p_idempotency_key, v_existing_attempt.customer_order_id
                    USING ERRCODE = 'unique_violation';
            END IF;

            -- Validate that the amount matches the original intent
            IF ABS(v_existing_attempt.amount - p_amount) > 0.01 THEN
                RAISE EXCEPTION 'Idempotency key "%" reused with different amount (% vs %)',
                    p_idempotency_key, p_amount, v_existing_attempt.amount
                    USING ERRCODE = 'check_violation';
            END IF;

            -- Validate that currency matches the original intent
            IF v_existing_attempt.currency != p_currency THEN
                RAISE EXCEPTION 'Idempotency key "%" reused with different currency (% vs %)',
                    p_idempotency_key, p_currency, v_existing_attempt.currency
                    USING ERRCODE = 'check_violation';
            END IF;

            RETURN jsonb_build_object(
                'success', true,
                'idempotent_replay', true,
                'payment_attempt_id', v_existing_attempt.id,
                'reference', v_existing_attempt.reference,
                'status', v_existing_attempt.status,
                'amount', v_existing_attempt.amount,
                'currency', v_existing_attempt.currency,
                'provider', v_existing_attempt.provider,
                'provider_reference', v_existing_attempt.provider_reference
            );
        END IF;
    END IF;

    -- 3. Lock customer order FOR UPDATE to prevent concurrent payment initiation or expiry
    SELECT id, customer_id, status, payment_status, total
      INTO v_order
      FROM public.customer_orders
     WHERE id = p_customer_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_customer_order_id USING ERRCODE = 'no_data_found';
    END IF;

    -- Verify order ownership
    IF v_order.customer_id != p_customer_id THEN
        RAISE EXCEPTION 'Forbidden: customer % does not own order %',
            p_customer_id, p_customer_order_id
            USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Verify order status allows payment
    IF v_order.status != 'pending_payment' THEN
        RAISE EXCEPTION 'Order % is not in pending_payment state (current: %)',
            p_customer_order_id, v_order.status
            USING ERRCODE = 'check_violation';
    END IF;

    IF v_order.payment_status NOT IN ('pending', 'failed') THEN
        RAISE EXCEPTION 'Order % payment cannot be initiated (current payment_status: %)',
            p_customer_order_id, v_order.payment_status
            USING ERRCODE = 'check_violation';
    END IF;

    -- Verify amount integrity against server-authoritative order total
    IF ABS(v_order.total - p_amount) > 0.01 THEN
        RAISE EXCEPTION 'Amount mismatch: expected order total %, client sent %',
            v_order.total, p_amount
            USING ERRCODE = 'check_violation';
    END IF;

    -- 4. Generate payment attempt reference
    v_reference := 'PA-' || upper(substr(gen_random_uuid()::text, 1, 8)) || '-' || to_char(now(), 'YYYYMMDD');

    -- 5. Insert payment_attempt record in 'processing' status
    INSERT INTO public.payment_attempts (
        customer_order_id, customer_id, method, provider,
        amount, currency, status, reference, is_simulated,
        idempotency_key, metadata, initiated_at
    )
    VALUES (
        p_customer_order_id, p_customer_id, p_method, p_provider,
        p_amount, p_currency, 'processing', v_reference,
        (p_provider = 'simulated' OR p_method = 'simulated'),
        p_idempotency_key, p_metadata, now()
    )
    RETURNING id INTO v_attempt_id;

    -- 6. Update customer_orders payment_status to 'processing'
    UPDATE public.customer_orders
       SET payment_status = 'processing',
           payment_method = p_method,
           updated_at = now()
     WHERE id = p_customer_order_id;

    RETURN jsonb_build_object(
        'success', true,
        'idempotent_replay', false,
        'payment_attempt_id', v_attempt_id,
        'reference', v_reference,
        'status', 'processing',
        'amount', p_amount,
        'currency', p_currency,
        'provider', p_provider
    );
END;
$$;

-- ============================================================
-- 3. RPC: settle_order_payment
--    Atomically settles payment for an order inside a single
--    PostgreSQL transaction with row-level locks.
-- ============================================================

CREATE OR REPLACE FUNCTION public.settle_order_payment(
    p_customer_order_id    UUID,
    p_payment_attempt_id   UUID,
    p_customer_id          UUID,
    p_payment_status       TEXT,          -- 'succeeded', 'failed', 'cancelled', 'expired'
    p_amount               NUMERIC(12,2),
    p_currency             TEXT DEFAULT 'SLE',
    p_provider_reference   TEXT DEFAULT NULL,
    p_failure_reason       TEXT DEFAULT NULL,
    p_metadata             JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order             RECORD;
    v_attempt           RECORD;
    v_existing_tx       RECORD;
    v_tx_id             UUID;
    v_tx_reference      TEXT;
    v_vendor_order      RECORD;
BEGIN
    -- 1. Input validations
    IF p_payment_status NOT IN ('succeeded', 'failed', 'cancelled', 'expired') THEN
        RAISE EXCEPTION 'Invalid payment settlement status "%"', p_payment_status
            USING ERRCODE = 'check_violation';
    END IF;
    IF p_currency NOT IN ('SLL', 'SLE') THEN
        RAISE EXCEPTION 'Unsupported currency "%"', p_currency
            USING ERRCODE = 'check_violation';
    END IF;

    -- 2. Lock customer_orders row FOR UPDATE
    SELECT id, customer_id, status, payment_status, total
      INTO v_order
      FROM public.customer_orders
     WHERE id = p_customer_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_customer_order_id USING ERRCODE = 'no_data_found';
    END IF;

    -- Validate order ownership
    IF v_order.customer_id != p_customer_id THEN
        RAISE EXCEPTION 'Forbidden: order % does not belong to customer %',
            p_customer_order_id, p_customer_id
            USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Validate amount against order total
    IF ABS(v_order.total - p_amount) > 0.01 THEN
        RAISE EXCEPTION 'Amount mismatch: order total is %, settlement amount is %',
            v_order.total, p_amount
            USING ERRCODE = 'check_violation';
    END IF;

    -- 3. Lock payment_attempts row FOR UPDATE
    SELECT id, customer_order_id, customer_id, status, amount, currency,
           reference, failure_reason, is_simulated, provider, provider_reference
      INTO v_attempt
      FROM public.payment_attempts
     WHERE id = p_payment_attempt_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payment attempt % not found', p_payment_attempt_id USING ERRCODE = 'no_data_found';
    END IF;

    -- Validate attempt belongs to specified order and customer
    IF v_attempt.customer_order_id != p_customer_order_id THEN
        RAISE EXCEPTION 'Payment attempt % does not belong to order %',
            p_payment_attempt_id, p_customer_order_id
            USING ERRCODE = 'check_violation';
    END IF;

    IF v_attempt.customer_id != p_customer_id THEN
        RAISE EXCEPTION 'Payment attempt % does not belong to customer %',
            p_payment_attempt_id, p_customer_id
            USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Validate attempt amount matches settlement amount
    IF ABS(v_attempt.amount - p_amount) > 0.01 THEN
        RAISE EXCEPTION 'Amount mismatch: payment attempt amount is %, settlement amount is %',
            v_attempt.amount, p_amount
            USING ERRCODE = 'check_violation';
    END IF;

    -- Validate attempt currency matches settlement currency
    IF v_attempt.currency != p_currency THEN
        RAISE EXCEPTION 'Currency mismatch: payment attempt was initiated in %, requested settlement is %',
            v_attempt.currency, p_currency
            USING ERRCODE = 'check_violation';
    END IF;

    -- Provider reference reuse protection
    IF p_provider_reference IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.payment_attempts
             WHERE provider = v_attempt.provider
               AND provider_reference = p_provider_reference
               AND id != p_payment_attempt_id
        ) THEN
            RAISE EXCEPTION 'Provider reference "%" is already used by another payment attempt',
                p_provider_reference
                USING ERRCODE = 'unique_violation';
        END IF;
    END IF;

    -- =========================================================================
    -- CASE A: Order is ALREADY 'confirmed' and 'paid'
    -- =========================================================================
    IF v_order.status = 'confirmed' AND v_order.payment_status = 'paid' THEN
        -- If attempting to record success on already paid order:
        IF p_payment_status = 'succeeded' THEN
            -- Check if this attempt is the one that settled the order
            SELECT id, reference, amount, payment_attempt_id
              INTO v_existing_tx
              FROM public.transactions
             WHERE customer_order_id = p_customer_order_id
               AND status = 'succeeded'
             ORDER BY created_at ASC
             LIMIT 1;

            IF v_existing_tx.payment_attempt_id = p_payment_attempt_id THEN
                -- Idempotent replay: find existing successful transaction
                RETURN jsonb_build_object(
                    'success', true,
                    'idempotent_replay', true,
                    'customer_order_id', p_customer_order_id,
                    'payment_attempt_id', p_payment_attempt_id,
                    'order_status', 'confirmed',
                    'payment_status', 'paid',
                    'transaction_id', v_existing_tx.id,
                    'transaction_reference', v_existing_tx.reference
                );
            ELSE
                -- DUPLICATE PAYMENT RECONCILIATION:
                -- A different attempt was already used to pay this order, and now this attempt also confirmed success.
                -- Record the transaction with reconciliation_needed = true and alert admins for refund.
                v_tx_reference := 'TX-' || upper(substr(gen_random_uuid()::text, 1, 8)) || '-' || to_char(now(), 'YYYYMMDD');

                INSERT INTO public.transactions (
                    payment_attempt_id, customer_order_id, customer_id,
                    reference, type, amount, currency, status,
                    is_simulated, description, metadata
                ) VALUES (
                    p_payment_attempt_id, p_customer_order_id, p_customer_id,
                    v_tx_reference, 'payment', p_amount, p_currency, 'succeeded',
                    v_attempt.is_simulated,
                    'Duplicate payment received for already paid order - Reconciliation required',
                    jsonb_build_object(
                        'reconciliation_needed', true,
                        'reason', 'Duplicate payment received: order was already paid by transaction ' || v_existing_tx.reference,
                        'provider', v_attempt.provider,
                        'provider_reference', p_provider_reference
                    ) || p_metadata
                ) RETURNING id INTO v_tx_id;

                UPDATE public.payment_attempts
                   SET status = 'succeeded',
                       provider_reference = COALESCE(p_provider_reference, provider_reference),
                       completed_at = now(),
                       metadata = metadata || jsonb_build_object('reconciliation_needed', true, 'duplicate_payment', true)
                 WHERE id = p_payment_attempt_id;

                -- Customer alert
                INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
                VALUES (
                    p_customer_id, 'system',
                    'Duplicate Payment Received',
                    'A duplicate payment of ' || p_currency || ' ' || p_amount::text || ' was received for order #' || upper(substr(p_customer_order_id::text, 1, 8)) || '. Our support team has flagged this for a refund.',
                    jsonb_build_object('customer_order_id', p_customer_order_id, 'transaction_id', v_tx_id, 'duplicate_payment', true),
                    false
                );

                -- Admin alert
                INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
                SELECT p.id, 'system', 'Duplicate Payment Alert',
                    'Order #' || upper(substr(p_customer_order_id::text, 1, 8)) || ' received a duplicate payment (Attempt #' || upper(substr(p_payment_attempt_id::text, 1, 8)) || '). Refund required.',
                    jsonb_build_object('customer_order_id', p_customer_order_id, 'payment_attempt_id', p_payment_attempt_id, 'transaction_id', v_tx_id, 'reconciliation_needed', true),
                    false
                FROM public.profiles p WHERE p.role = 'admin';

                RETURN jsonb_build_object(
                    'success', false,
                    'reconciliation_needed', true,
                    'duplicate_payment', true,
                    'error', 'Order has already been paid by a previous payment attempt. Duplicate charge flagged for administrator refund.',
                    'customer_order_id', p_customer_order_id,
                    'payment_attempt_id', p_payment_attempt_id,
                    'transaction_id', v_tx_id,
                    'transaction_reference', v_tx_reference
                );
            END IF;
        ELSE
            -- Never allow a failed or expired attempt to overwrite an already successful payment!
            RETURN jsonb_build_object(
                'success', false,
                'idempotent_replay', true,
                'error', 'Order is already confirmed and paid; cannot overwrite with failure or expiration',
                'customer_order_id', p_customer_order_id,
                'order_status', 'confirmed',
                'payment_status', 'paid'
            );
        END IF;
    END IF;

    -- =========================================================================
    -- CASE B: Order is 'cancelled' (e.g. expired reservation window)
    -- =========================================================================
    IF v_order.status = 'cancelled' THEN
        IF p_payment_status = 'succeeded' THEN
            -- LATE SUCCESS RECONCILIATION:
            -- Customer was charged by provider, but platform order was already cancelled.
            -- Record immutable ledger entry with reconciliation flag.
            v_tx_reference := 'TX-' || upper(substr(gen_random_uuid()::text, 1, 8)) || '-' || to_char(now(), 'YYYYMMDD');

            INSERT INTO public.transactions (
                payment_attempt_id, customer_order_id, customer_id,
                reference, type, amount, currency, status,
                is_simulated, description, metadata
            )
            VALUES (
                p_payment_attempt_id, p_customer_order_id, p_customer_id,
                v_tx_reference, 'payment', p_amount, p_currency, 'succeeded',
                v_attempt.is_simulated,
                'Late payment received after order cancellation - Reconciliation required',
                jsonb_build_object(
                    'reconciliation_needed', true,
                    'reason', 'Payment received after order cancellation',
                    'provider', v_attempt.provider,
                    'provider_reference', p_provider_reference
                ) || p_metadata
            )
            RETURNING id INTO v_tx_id;

            UPDATE public.payment_attempts
               SET status = 'succeeded',
                   provider_reference = COALESCE(p_provider_reference, provider_reference),
                   completed_at = now(),
                   metadata = metadata || jsonb_build_object('reconciliation_needed', true)
             WHERE id = p_payment_attempt_id;

            -- 1. Notify customer of payment hold / reconciliation
            INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
            VALUES (
                p_customer_id, 'system',
                'Payment Received for Cancelled Order',
                'A payment was received for order #' || upper(substr(p_customer_order_id::text, 1, 8)) || ' after it was cancelled. Our support team has flagged this for immediate review or refund.',
                jsonb_build_object('customer_order_id', p_customer_order_id, 'transaction_id', v_tx_id),
                false
            );

            -- 2. Notify all administrators of reconciliation requirement
            INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
            SELECT
                p.id,
                'system',
                'Payment Reconciliation Needed: Cancelled Order Paid',
                'A payment of ' || p_currency || ' ' || p_amount::text || ' was confirmed for cancelled order #' || upper(substr(p_customer_order_id::text, 1, 8)) || '. Immediate review or refund required.',
                jsonb_build_object(
                    'customer_order_id', p_customer_order_id,
                    'payment_attempt_id', p_payment_attempt_id,
                    'transaction_id', v_tx_id,
                    'reconciliation_needed', true
                ),
                false
            FROM public.profiles p
            WHERE p.role = 'admin';

            RETURN jsonb_build_object(
                'success', false,
                'reconciliation_needed', true,
                'error', 'Payment received after order was cancelled. Flagged for admin reconciliation or refund.',
                'customer_order_id', p_customer_order_id,
                'order_status', 'cancelled',
                'payment_status', 'failed',
                'transaction_id', v_tx_id,
                'transaction_reference', v_tx_reference
            );
        ELSE
            -- Idempotent handling for repeated failure on cancelled order
            IF v_attempt.status = p_payment_status THEN
                SELECT id, reference
                  INTO v_existing_tx
                  FROM public.transactions
                 WHERE payment_attempt_id = p_payment_attempt_id
                   AND status = 'failed'
                 LIMIT 1;

                RETURN jsonb_build_object(
                    'success', false,
                    'idempotent_replay', true,
                    'order_status', 'cancelled',
                    'payment_status', 'failed',
                    'attempt_status', v_attempt.status,
                    'customer_order_id', p_customer_order_id,
                    'payment_attempt_id', p_payment_attempt_id,
                    'transaction_id', v_existing_tx.id,
                    'transaction_reference', v_existing_tx.reference
                );
            END IF;

            -- Non-success settlement on cancelled order: update attempt and return
            UPDATE public.payment_attempts
               SET status = p_payment_status,
                   failure_reason = p_failure_reason,
                   provider_reference = COALESCE(p_provider_reference, provider_reference),
                   completed_at = now()
             WHERE id = p_payment_attempt_id;

            RETURN jsonb_build_object(
                'success', true,
                'order_status', 'cancelled',
                'payment_status', 'failed',
                'attempt_status', p_payment_status
            );
        END IF;
    END IF;

    -- =========================================================================
    -- CASE C: Normal Settlement (Order is 'pending_payment' / 'payment_failed')
    -- =========================================================================
    v_tx_reference := 'TX-' || upper(substr(gen_random_uuid()::text, 1, 8)) || '-' || to_char(now(), 'YYYYMMDD');

    IF p_payment_status = 'succeeded' THEN
        -- Prevent multiple successful attempts for the same order without reconciliation
        IF EXISTS (
            SELECT 1 FROM public.payment_attempts
             WHERE customer_order_id = p_customer_order_id
               AND status = 'succeeded'
               AND id != p_payment_attempt_id
        ) THEN
            -- DUPLICATE PAYMENT RECONCILIATION:
            -- Another attempt already marked succeeded for this order.
            v_tx_reference := 'TX-' || upper(substr(gen_random_uuid()::text, 1, 8)) || '-' || to_char(now(), 'YYYYMMDD');

            INSERT INTO public.transactions (
                payment_attempt_id, customer_order_id, customer_id,
                reference, type, amount, currency, status,
                is_simulated, description, metadata
            ) VALUES (
                p_payment_attempt_id, p_customer_order_id, p_customer_id,
                v_tx_reference, 'payment', p_amount, p_currency, 'succeeded',
                v_attempt.is_simulated,
                'Duplicate payment received for order - Reconciliation required',
                jsonb_build_object(
                    'reconciliation_needed', true,
                    'reason', 'Duplicate payment: another attempt already succeeded for this order',
                    'provider', v_attempt.provider,
                    'provider_reference', p_provider_reference
                ) || p_metadata
            ) RETURNING id INTO v_tx_id;

            UPDATE public.payment_attempts
               SET status = 'succeeded',
                   provider_reference = COALESCE(p_provider_reference, provider_reference),
                   completed_at = now(),
                   metadata = metadata || jsonb_build_object('reconciliation_needed', true, 'duplicate_payment', true)
             WHERE id = p_payment_attempt_id;

            -- Admin alert
            INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
            SELECT p.id, 'system', 'Duplicate Payment Alert',
                'Order #' || upper(substr(p_customer_order_id::text, 1, 8)) || ' received duplicate payment success. Reconciliation required.',
                jsonb_build_object('customer_order_id', p_customer_order_id, 'payment_attempt_id', p_payment_attempt_id, 'transaction_id', v_tx_id, 'reconciliation_needed', true),
                false
            FROM public.profiles p WHERE p.role = 'admin';

            RETURN jsonb_build_object(
                'success', false,
                'reconciliation_needed', true,
                'duplicate_payment', true,
                'error', 'Another payment attempt has already succeeded for this order. Flagged for administrator reconciliation.',
                'customer_order_id', p_customer_order_id,
                'payment_attempt_id', p_payment_attempt_id,
                'transaction_id', v_tx_id,
                'transaction_reference', v_tx_reference
            );
        END IF;

        -- 1. Update payment_attempts to 'succeeded'
        UPDATE public.payment_attempts
           SET status = 'succeeded',
               provider_reference = COALESCE(p_provider_reference, provider_reference),
               completed_at = now(),
               metadata = metadata || p_metadata
         WHERE id = p_payment_attempt_id;

        -- 2. Insert into immutable transactions ledger
        INSERT INTO public.transactions (
            payment_attempt_id, customer_order_id, customer_id,
            reference, type, amount, currency, status,
            is_simulated, description, metadata
        )
        VALUES (
            p_payment_attempt_id, p_customer_order_id, p_customer_id,
            v_tx_reference, 'payment', p_amount, p_currency, 'succeeded',
            v_attempt.is_simulated,
            'Order payment settlement for #' || upper(substr(p_customer_order_id::text, 1, 8)),
            jsonb_build_object(
                'provider', v_attempt.provider,
                'provider_reference', p_provider_reference,
                'settled_at', now()
            ) || p_metadata
        )
        RETURNING id INTO v_tx_id;

        -- 3. Update customer_orders to 'confirmed' and 'paid'
        UPDATE public.customer_orders
           SET status = 'confirmed',
               payment_status = 'paid',
               payment_method = v_attempt.method,
               updated_at = now()
         WHERE id = p_customer_order_id;

        -- 4. Update child vendor_orders to 'confirmed'
        UPDATE public.vendor_orders
           SET status = 'confirmed',
               updated_at = now()
         WHERE customer_order_id = p_customer_order_id
           AND status = 'awaiting_payment';

        -- 5. Insert customer notification
        INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
        VALUES (
            p_customer_id, 'payment_received',
            'Payment Successful',
            'Your payment of ' || p_currency || ' ' || p_amount::text || ' was successful. Order confirmed!',
            jsonb_build_object(
                'customer_order_id', p_customer_order_id,
                'transaction_id', v_tx_id,
                'transaction_reference', v_tx_reference
            ),
            false
        );

        -- 6. Insert vendor notifications
        FOR v_vendor_order IN
            SELECT id, vendor_id
              FROM public.vendor_orders
             WHERE customer_order_id = p_customer_order_id
        LOOP
            INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
            VALUES (
                v_vendor_order.vendor_id, 'payment_received',
                'New Order Confirmed',
                'Order #' || upper(substr(p_customer_order_id::text, 1, 8)) || ' payment has been confirmed.',
                jsonb_build_object(
                    'customer_order_id', p_customer_order_id,
                    'vendor_order_id', v_vendor_order.id
                ),
                false
            );
        END LOOP;

        RETURN jsonb_build_object(
            'success', true,
            'idempotent_replay', false,
            'customer_order_id', p_customer_order_id,
            'payment_attempt_id', p_payment_attempt_id,
            'order_status', 'confirmed',
            'payment_status', 'paid',
            'transaction_id', v_tx_id,
            'transaction_reference', v_tx_reference
        );

    ELSE
        -- IDEMPOTENCY CHECK FOR FAILED / CANCELLED / EXPIRED SETTLEMENT
        -- If this attempt was already settled with this failure status, return existing result without duplicate ledger entries
        IF v_attempt.status = p_payment_status THEN
            SELECT id, reference
              INTO v_existing_tx
              FROM public.transactions
             WHERE payment_attempt_id = p_payment_attempt_id
               AND status = 'failed'
             LIMIT 1;

            RETURN jsonb_build_object(
                'success', false,
                'idempotent_replay', true,
                'order_status', v_order.status,
                'payment_status', v_order.payment_status,
                'attempt_status', v_attempt.status,
                'customer_order_id', p_customer_order_id,
                'payment_attempt_id', p_payment_attempt_id,
                'transaction_id', v_existing_tx.id,
                'transaction_reference', v_existing_tx.reference,
                'failure_reason', v_attempt.failure_reason
            );
        END IF;

        -- 1. Update payment_attempts to failed/cancelled/expired
        UPDATE public.payment_attempts
           SET status = p_payment_status,
               failure_reason = p_failure_reason,
               provider_reference = COALESCE(p_provider_reference, provider_reference),
               completed_at = now(),
               metadata = metadata || p_metadata
         WHERE id = p_payment_attempt_id;

        -- 2. Insert ledger record for failed payment
        INSERT INTO public.transactions (
            payment_attempt_id, customer_order_id, customer_id,
            reference, type, amount, currency, status,
            is_simulated, description, metadata
        )
        VALUES (
            p_payment_attempt_id, p_customer_order_id, p_customer_id,
            v_tx_reference, 'payment', p_amount, p_currency, 'failed',
            v_attempt.is_simulated,
            'Payment ' || p_payment_status || ': ' || COALESCE(p_failure_reason, 'No reason provided'),
            jsonb_build_object(
                'failure_reason', p_failure_reason,
                'attempt_status', p_payment_status,
                'provider', v_attempt.provider
            ) || p_metadata
        )
        RETURNING id INTO v_tx_id;

        -- 3. Update customer_orders payment_status to 'failed'
        -- NOTE: order status remains 'pending_payment' so customer can retry within the 15-minute window!
        -- Inventory is NOT restored here; stock is restored ONLY on explicit order expiration.
        UPDATE public.customer_orders
           SET payment_status = 'failed',
               updated_at = now()
         WHERE id = p_customer_order_id;

        -- 4. Insert customer notification for failed payment
        INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
        VALUES (
            p_customer_id, 'payment_failed',
            'Payment ' || initcap(p_payment_status),
            'Your payment of ' || p_currency || ' ' || p_amount::text || ' was not completed: ' || COALESCE(p_failure_reason, 'Payment unsuccessful'),
            jsonb_build_object(
                'customer_order_id', p_customer_order_id,
                'payment_attempt_id', p_payment_attempt_id
            ),
            false
        );

        RETURN jsonb_build_object(
            'success', false,
            'order_status', 'pending_payment',
            'payment_status', 'failed',
            'attempt_status', p_payment_status,
            'customer_order_id', p_customer_order_id,
            'payment_attempt_id', p_payment_attempt_id,
            'transaction_id', v_tx_id,
            'transaction_reference', v_tx_reference,
            'failure_reason', p_failure_reason
        );
    END IF;
END;
$$;

-- ============================================================
-- 4. RPC: expire_unpaid_order
--    Explicit, atomic expiration of an unpaid order.
--    Guarantees stock is restored exactly once within the same transaction.
--    Refuses to release stock while an active payment attempt is processing
--    unless p_force is explicitly granted with administrator audit logging.
-- ============================================================

CREATE OR REPLACE FUNCTION public.expire_unpaid_order(
    p_customer_order_id  UUID,
    p_reason             TEXT DEFAULT 'Payment reservation window expired (15 minutes)',
    p_force              BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order             RECORD;
    v_active_attempt    RECORD;
    v_item              RECORD;
BEGIN
    IF p_customer_order_id IS NULL THEN
        RAISE EXCEPTION 'customer_order_id is required' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    -- 1. Lock customer order FOR UPDATE
    SELECT id, customer_id, status, payment_status, created_at
      INTO v_order
      FROM public.customer_orders
     WHERE id = p_customer_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % not found', p_customer_order_id USING ERRCODE = 'no_data_found';
    END IF;

    -- Idempotent handling: already cancelled
    IF v_order.status = 'cancelled' THEN
        RETURN jsonb_build_object(
            'success', true,
            'already_cancelled', true,
            'customer_order_id', p_customer_order_id,
            'status', 'cancelled'
        );
    END IF;

    -- Protection: never expire confirmed or paid orders
    IF v_order.status = 'confirmed' OR v_order.payment_status = 'paid' THEN
        RAISE EXCEPTION 'Cannot expire order %: order is confirmed and paid', p_customer_order_id
            USING ERRCODE = 'check_violation';
    END IF;

    IF v_order.status != 'pending_payment' THEN
        RAISE EXCEPTION 'Cannot expire order %: current status is %', p_customer_order_id, v_order.status
            USING ERRCODE = 'check_violation';
    END IF;

    -- 2. Check for active processing attempts
    -- An unresolved processing attempt CANNOT automatically cause inventory to be released
    -- merely because time has elapsed. The outcome must be finalized by the provider first.
    SELECT id, initiated_at
      INTO v_active_attempt
      FROM public.payment_attempts
     WHERE customer_order_id = p_customer_order_id
       AND status = 'processing'
     LIMIT 1;

    IF FOUND THEN
        IF NOT p_force THEN
            RETURN jsonb_build_object(
                'success', false,
                'deferred', true,
                'error', 'Order has an unresolved payment attempt in processing state. Expiry blocked until payment outcome is finalized or explicitly forced with reconciliation.',
                'customer_order_id', p_customer_order_id,
                'payment_attempt_id', v_active_attempt.id
            );
        ELSE
            -- p_force is explicitly requested by service_role:
            -- Mark the unresolved attempt as expired with forced reconciliation metadata
            UPDATE public.payment_attempts
               SET status = 'expired',
                   failure_reason = 'Forced order expiration while attempt was processing: ' || p_reason,
                   completed_at = now(),
                   metadata = metadata || jsonb_build_object('forced_expiration', true, 'reconciliation_pending', true)
             WHERE id = v_active_attempt.id;

            -- Notify administrators of forced expiration with unresolved attempt
            INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
            SELECT
                p.id,
                'system',
                'Order Forcibly Expired With Processing Payment',
                'Order #' || upper(substr(p_customer_order_id::text, 1, 8)) || ' was forcibly expired while payment attempt #' || upper(substr(v_active_attempt.id::text, 1, 8)) || ' was still in processing state. Monitor for late webhook confirmations.',
                jsonb_build_object(
                    'customer_order_id', p_customer_order_id,
                    'payment_attempt_id', v_active_attempt.id,
                    'forced_expiration', true
                ),
                false
            FROM public.profiles p
            WHERE p.role = 'admin';
        END IF;
    END IF;

    -- 3. Restore product stock exactly once within this atomic transaction
    FOR v_item IN
        SELECT product_id, quantity
          FROM public.order_items
         WHERE customer_order_id = p_customer_order_id
           AND product_id IS NOT NULL
    LOOP
        UPDATE public.products
           SET stock_quantity = stock_quantity + v_item.quantity
         WHERE id = v_item.product_id
           AND track_inventory = true;
    END LOOP;

    -- 4. Update customer_orders to cancelled
    UPDATE public.customer_orders
       SET status = 'cancelled',
           payment_status = 'failed',
           notes = COALESCE(notes || E'\n', '') || '[EXPIRED] ' || p_reason,
           updated_at = now()
     WHERE id = p_customer_order_id;

    -- 5. Cancel child vendor_orders
    UPDATE public.vendor_orders
       SET status = 'cancelled',
           updated_at = now()
     WHERE customer_order_id = p_customer_order_id
       AND status = 'awaiting_payment';

    -- 6. Expire lingering pending payment attempts
    UPDATE public.payment_attempts
       SET status = 'expired',
           failure_reason = p_reason,
           completed_at = now()
     WHERE customer_order_id = p_customer_order_id
       AND status IN ('pending', 'processing');

    -- 7. Insert customer notification
    INSERT INTO public.notifications (user_id, type, title, body, data, is_read)
    VALUES (
        v_order.customer_id, 'order_cancelled',
        'Order Reservation Expired',
        'Your order #' || upper(substr(p_customer_order_id::text, 1, 8)) || ' has expired because payment was not completed within the reservation window. Reserved items have been released.',
        jsonb_build_object('customer_order_id', p_customer_order_id),
        false
    );

    RETURN jsonb_build_object(
        'success', true,
        'customer_order_id', p_customer_order_id,
        'status', 'cancelled',
        'stock_restored', true,
        'reason', p_reason
    );
END;
$$;

-- ============================================================
-- 5. Permissions: Strict Service-Role Access Control
-- ============================================================

-- Revoke all execute permissions from public, anon, and authenticated roles
REVOKE EXECUTE ON FUNCTION public.claim_payment_webhook_event(TEXT, TEXT, TEXT, JSONB, INT) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.create_or_get_payment_attempt(UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.settle_order_payment(UUID, UUID, UUID, TEXT, NUMERIC, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.expire_unpaid_order(UUID, TEXT, BOOLEAN) FROM PUBLIC, anon, authenticated;

-- Grant execution strictly to service_role (Edge Functions / backend administrative tasks)
GRANT EXECUTE ON FUNCTION public.claim_payment_webhook_event(TEXT, TEXT, TEXT, JSONB, INT) TO service_role;
GRANT EXECUTE ON FUNCTION public.create_or_get_payment_attempt(UUID, UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION public.settle_order_payment(UUID, UUID, UUID, TEXT, NUMERIC, TEXT, TEXT, TEXT, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION public.expire_unpaid_order(UUID, TEXT, BOOLEAN) TO service_role;

-- End of migration


-- ========================================================
-- MIGRATION: 20261122000011_vendor_admin_portals.sql
-- ========================================================

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


-- ========================================================
-- MIGRATION: 20261122000012_customer_experience.sql
-- ========================================================

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


-- ========================================================
-- MIGRATION: 20261122000013_vendor_payouts_ledger.sql
-- ========================================================

-- ============================================================
-- SaloneMarket: Vendor Earnings Ledger & Payout Settlement
-- Migration: 20261122000013_vendor_payouts_ledger.sql
-- ============================================================

-- 1. Vendor Payout Destinations (Mobile Money & Bank Accounts)
CREATE TABLE IF NOT EXISTS public.vendor_payout_destinations (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id           UUID NOT NULL REFERENCES public.vendors(id) ON DELETE CASCADE,
    type                TEXT NOT NULL CHECK (type IN ('mobile_money', 'bank_account')),
    provider            TEXT NOT NULL, -- 'orange_money', 'afrimoney', 'slcb', 'rokel', 'gtbank'
    account_number      TEXT NOT NULL,
    account_name        TEXT NOT NULL,
    is_default          BOOLEAN NOT NULL DEFAULT true,
    is_verified         BOOLEAN NOT NULL DEFAULT false,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payout_destinations_vendor 
    ON public.vendor_payout_destinations (vendor_id);

ALTER TABLE public.vendor_payout_destinations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "payout_destinations_vendor_select"
    ON public.vendor_payout_destinations FOR SELECT
    TO authenticated
    USING (
        vendor_id IN (SELECT id FROM public.vendors WHERE profile_id = auth.uid())
        OR public.is_admin()
    );

CREATE POLICY "payout_destinations_vendor_insert"
    ON public.vendor_payout_destinations FOR INSERT
    TO authenticated
    WITH CHECK (
        vendor_id IN (SELECT id FROM public.vendors WHERE profile_id = auth.uid())
    );

CREATE POLICY "payout_destinations_vendor_update"
    ON public.vendor_payout_destinations FOR UPDATE
    TO authenticated
    USING (
        vendor_id IN (SELECT id FROM public.vendors WHERE profile_id = auth.uid())
    )
    WITH CHECK (
        vendor_id IN (SELECT id FROM public.vendors WHERE profile_id = auth.uid())
    );

CREATE POLICY "payout_destinations_vendor_delete"
    ON public.vendor_payout_destinations FOR DELETE
    TO authenticated
    USING (
        vendor_id IN (SELECT id FROM public.vendors WHERE profile_id = auth.uid())
    );


-- 2. Vendor Payout Requests & Disbursements
CREATE TABLE IF NOT EXISTS public.vendor_payouts (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payout_reference            TEXT NOT NULL UNIQUE,
    vendor_id                   UUID NOT NULL REFERENCES public.vendors(id) ON DELETE RESTRICT,
    amount                      NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    currency                    TEXT NOT NULL DEFAULT 'SLE',
    fee                         NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    status                      TEXT NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending', 'approved', 'processing', 'completed', 'rejected', 'failed', 'cancelled')),
    destination_type            TEXT NOT NULL CHECK (destination_type IN ('mobile_money', 'bank_account')),
    destination_provider        TEXT NOT NULL,
    destination_account_number  TEXT NOT NULL,
    destination_account_name    TEXT NOT NULL,
    requested_by                UUID NOT NULL REFERENCES public.profiles(id),
    authorized_by               UUID REFERENCES public.profiles(id),
    authorized_at               TIMESTAMPTZ,
    disbursement_method         TEXT NOT NULL DEFAULT 'manual'
                                CHECK (disbursement_method IN ('monime_payout', 'manual')),
    provider_payout_id          TEXT,
    provider_reference          TEXT,
    admin_notes                 TEXT,
    failure_reason              TEXT,
    completed_at                TIMESTAMPTZ,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vendor_payouts_vendor_status 
    ON public.vendor_payouts (vendor_id, status);

CREATE INDEX IF NOT EXISTS idx_vendor_payouts_created 
    ON public.vendor_payouts (created_at DESC);

ALTER TABLE public.vendor_payouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "vendor_payouts_vendor_select"
    ON public.vendor_payouts FOR SELECT
    TO authenticated
    USING (
        vendor_id IN (SELECT id FROM public.vendors WHERE profile_id = auth.uid())
        OR public.is_admin()
    );

CREATE POLICY "vendor_payouts_admin_all"
    ON public.vendor_payouts FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());


-- 3. Immutable Vendor Earnings Ledger (Double-Entry Financial Traceability)
CREATE TABLE IF NOT EXISTS public.vendor_earnings_ledger (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vendor_id           UUID NOT NULL REFERENCES public.vendors(id) ON DELETE RESTRICT,
    vendor_order_id     UUID REFERENCES public.vendor_orders(id) ON DELETE SET NULL,
    customer_order_id   UUID REFERENCES public.customer_orders(id) ON DELETE SET NULL,
    payout_id           UUID REFERENCES public.vendor_payouts(id) ON DELETE SET NULL,
    type                TEXT NOT NULL CHECK (type IN (
                            'order_credit',         -- Net earnings credited from paid order
                            'commission_deduction', -- 5% platform commission record
                            'payout_debit',         -- Balance deducted when payout completed
                            'payout_refund',        -- Balance restored if payout failed/rejected
                            'order_refund',         -- Earnings debit reversal if order cancelled/refunded
                            'adjustment'            -- Admin manual audit adjustment
                        )),
    gross_amount        NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    commission_rate     NUMERIC(5,4) NOT NULL DEFAULT 0.0500,
    commission_amount   NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    net_amount          NUMERIC(12,2) NOT NULL, -- positive credits balance, negative debits balance
    currency            TEXT NOT NULL DEFAULT 'SLE',
    reference           TEXT NOT NULL UNIQUE,
    description         TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
    -- NO updated_at: strictly append-only financial ledger
);

CREATE INDEX IF NOT EXISTS idx_vendor_ledger_vendor 
    ON public.vendor_earnings_ledger (vendor_id, created_at DESC);

ALTER TABLE public.vendor_earnings_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "vendor_ledger_vendor_select"
    ON public.vendor_earnings_ledger FOR SELECT
    TO authenticated
    USING (
        vendor_id IN (SELECT id FROM public.vendors WHERE profile_id = auth.uid())
        OR public.is_admin()
    );

CREATE POLICY "vendor_ledger_admin_select"
    ON public.vendor_earnings_ledger FOR SELECT
    TO authenticated
    USING (public.is_admin());


-- ============================================================
-- 4. RPC: Vendor Payout Summary (Authoritative Calculations)
-- ============================================================
CREATE OR REPLACE FUNCTION public.vendor_get_payout_summary(p_vendor_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id         UUID := auth.uid();
    v_vendor_owner_id   UUID;
    v_total_earned      NUMERIC(12,2) := 0.00;
    v_total_paid_out    NUMERIC(12,2) := 0.00;
    v_pending_payout    NUMERIC(12,2) := 0.00;
    v_available_balance NUMERIC(12,2) := 0.00;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Verify vendor ownership or admin privilege
    SELECT profile_id INTO v_vendor_owner_id FROM public.vendors WHERE id = p_vendor_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vendor not found' USING ERRCODE = 'no_data_found';
    END IF;

    IF v_vendor_owner_id != v_caller_id AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied to vendor payout records' USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- 1. Total net earnings from paid, valid orders (subtotal - 5% commission)
    SELECT COALESCE(SUM(vo.vendor_payout), 0.00)
    INTO v_total_earned
    FROM public.vendor_orders vo
    JOIN public.customer_orders co ON co.id = vo.customer_order_id
    WHERE vo.vendor_id = p_vendor_id
      AND co.payment_status = 'paid'
      AND co.status NOT IN ('cancelled', 'refunded');

    -- 2. Total already paid out via completed payouts
    SELECT COALESCE(SUM(amount), 0.00)
    INTO v_total_paid_out
    FROM public.vendor_payouts
    WHERE vendor_id = p_vendor_id
      AND status = 'completed';

    -- 3. Currently in-flight / pending payout requests
    SELECT COALESCE(SUM(amount), 0.00)
    INTO v_pending_payout
    FROM public.vendor_payouts
    WHERE vendor_id = p_vendor_id
      AND status IN ('pending', 'approved', 'processing');

    -- 4. Authoritative available balance
    v_available_balance := v_total_earned - v_total_paid_out - v_pending_payout;
    IF v_available_balance < 0 THEN
        v_available_balance := 0.00;
    END IF;

    RETURN jsonb_build_object(
        'vendor_id', p_vendor_id,
        'currency', 'SLE',
        'total_earned', v_total_earned,
        'total_paid_out', v_total_paid_out,
        'pending_payout', v_pending_payout,
        'available_balance', v_available_balance
    );
END;
$$;


-- ============================================================
-- 5. RPC: Reconcile Vendor Order Earnings (Idempotent Ledger Settlement)
-- ============================================================
CREATE OR REPLACE FUNCTION public.reconcile_vendor_order_earnings(p_customer_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order         RECORD;
    v_vendor_order  RECORD;
    v_count         INT := 0;
    v_ledger_ref    TEXT;
    v_comm_rate     NUMERIC(5,4);
    v_comm_amount   NUMERIC(12,2);
    v_net_earnings  NUMERIC(12,2);
BEGIN
    SELECT * INTO v_order
    FROM public.customer_orders
    WHERE id = p_customer_order_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'reason', 'Order not found');
    END IF;

    -- Only orders with verified paid status can be credited to vendor ledgers
    IF v_order.payment_status != 'paid' THEN
        RETURN jsonb_build_object('success', false, 'reason', 'Order is not paid');
    END IF;

    FOR v_vendor_order IN
        SELECT vo.*, v.commission_rate as vendor_commission_rate
        FROM public.vendor_orders vo
        JOIN public.vendors v ON v.id = vo.vendor_id
        WHERE vo.customer_order_id = p_customer_order_id
    LOOP
        v_ledger_ref := 'EARN-' || v_vendor_order.id;
        v_comm_rate := COALESCE(v_vendor_order.vendor_commission_rate, 0.0500);
        v_comm_amount := ROUND(v_vendor_order.subtotal * v_comm_rate, 2);
        v_net_earnings := v_vendor_order.subtotal - v_comm_amount;

        -- Idempotently insert ledger credit (skip if already credited)
        INSERT INTO public.vendor_earnings_ledger (
            vendor_id,
            vendor_order_id,
            customer_order_id,
            type,
            gross_amount,
            commission_rate,
            commission_amount,
            net_amount,
            currency,
            reference,
            description
        )
        VALUES (
            v_vendor_order.vendor_id,
            v_vendor_order.id,
            p_customer_order_id,
            'order_credit',
            v_vendor_order.subtotal,
            v_comm_rate,
            v_comm_amount,
            v_net_earnings,
            'SLE',
            v_ledger_ref,
            'Earnings for order #' || substr(p_customer_order_id::text, 1, 8) || ' (5% commission retained)'
        )
        ON CONFLICT (reference) DO NOTHING;

        IF FOUND THEN
            v_count := v_count + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'reconciled_vendor_orders', v_count);
END;
$$;


-- ============================================================
-- 5b. RPC: Reconcile Vendor Order Refund / Cancellation (Ledger Debit Reversal)
-- ============================================================
CREATE OR REPLACE FUNCTION public.reconcile_vendor_order_refund(p_customer_order_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order         RECORD;
    v_vendor_order  RECORD;
    v_count         INT := 0;
    v_ledger_ref    TEXT;
    v_comm_rate     NUMERIC(5,4);
    v_comm_amount   NUMERIC(12,2);
    v_net_earnings  NUMERIC(12,2);
BEGIN
    SELECT * INTO v_order
    FROM public.customer_orders
    WHERE id = p_customer_order_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'reason', 'Order not found');
    END IF;

    -- Only process if order has been cancelled or refunded
    IF v_order.status NOT IN ('cancelled', 'refunded') THEN
        RETURN jsonb_build_object('success', false, 'reason', 'Order is not cancelled or refunded');
    END IF;

    FOR v_vendor_order IN
        SELECT vo.*, v.commission_rate as vendor_commission_rate
        FROM public.vendor_orders vo
        JOIN public.vendors v ON v.id = vo.vendor_id
        WHERE vo.customer_order_id = p_customer_order_id
    LOOP
        v_ledger_ref := 'REFUND-' || v_vendor_order.id;
        v_comm_rate := COALESCE(v_vendor_order.vendor_commission_rate, 0.0500);
        v_comm_amount := ROUND(v_vendor_order.subtotal * v_comm_rate, 2);
        v_net_earnings := v_vendor_order.subtotal - v_comm_amount;

        -- Check if earnings were originally credited for this vendor order
        IF EXISTS (
            SELECT 1 FROM public.vendor_earnings_ledger 
            WHERE vendor_order_id = v_vendor_order.id AND type = 'order_credit'
        ) THEN
            -- Idempotently insert ledger debit reversal (negative net_amount)
            INSERT INTO public.vendor_earnings_ledger (
                vendor_id,
                vendor_order_id,
                customer_order_id,
                type,
                gross_amount,
                commission_rate,
                commission_amount,
                net_amount,
                currency,
                reference,
                description
            )
            VALUES (
                v_vendor_order.vendor_id,
                v_vendor_order.id,
                p_customer_order_id,
                'order_refund',
                v_vendor_order.subtotal,
                v_comm_rate,
                v_comm_amount,
                -v_net_earnings, -- negative net amount reverses the previous credit
                'SLE',
                v_ledger_ref,
                'Earnings reversal for cancelled/refunded order #' || substr(p_customer_order_id::text, 1, 8)
            )
            ON CONFLICT (reference) DO NOTHING;

            IF FOUND THEN
                v_count := v_count + 1;
            END IF;
        END IF;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'refunded_vendor_orders', v_count);
END;
$$;


-- ============================================================
-- 5c. Automated Trigger: Customer Orders Payment & Cancellation Reconciliation
-- ============================================================
CREATE OR REPLACE FUNCTION public.trigger_reconcile_customer_order_earnings()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- 1. When payment transitions to 'paid', credit vendor earnings
    IF NEW.payment_status = 'paid' AND (OLD.payment_status IS DISTINCT FROM 'paid') THEN
        PERFORM public.reconcile_vendor_order_earnings(NEW.id);
    END IF;

    -- 2. When paid order transitions to 'cancelled' or 'refunded', reverse vendor earnings
    IF NEW.status IN ('cancelled', 'refunded')
       AND (OLD.status NOT IN ('cancelled', 'refunded'))
       AND NEW.payment_status = 'paid' THEN
        PERFORM public.reconcile_vendor_order_refund(NEW.id);
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_customer_orders_earnings_reconcile ON public.customer_orders;
CREATE TRIGGER trg_customer_orders_earnings_reconcile
    AFTER UPDATE OF payment_status, status ON public.customer_orders
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_reconcile_customer_order_earnings();


-- ============================================================
-- 6. RPC: Vendor Request Payout
-- ============================================================
CREATE OR REPLACE FUNCTION public.vendor_request_payout(
    p_amount            NUMERIC(12,2),
    p_destination_id    UUID,
    p_notes             TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id         UUID := auth.uid();
    v_vendor            RECORD;
    v_dest              RECORD;
    v_summary           JSONB;
    v_available         NUMERIC(12,2);
    v_payout_id         UUID;
    v_payout_ref        TEXT;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'insufficient_privilege';
    END IF;

    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Payout amount must be greater than zero' USING ERRCODE = 'check_violation';
    END IF;

    IF p_amount < 50.00 THEN
        RAISE EXCEPTION 'Minimum payout amount is SLE 50.00' USING ERRCODE = 'check_violation';
    END IF;

    -- Lookup vendor owned by caller with row locking
    SELECT * INTO v_vendor
    FROM public.vendors
    WHERE profile_id = v_caller_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Only registered vendors can request payouts' USING ERRCODE = 'insufficient_privilege';
    END IF;

    IF v_vendor.status NOT IN ('active', 'approved') THEN
        RAISE EXCEPTION 'Only active vendors can request payouts' USING ERRCODE = 'check_violation';
    END IF;

    -- Verify destination belongs to this vendor
    SELECT * INTO v_dest
    FROM public.vendor_payout_destinations
    WHERE id = p_destination_id AND vendor_id = v_vendor.id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid payout destination selected' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    -- Check available balance authoritatively
    v_summary := public.vendor_get_payout_summary(v_vendor.id);
    v_available := (v_summary->>'available_balance')::numeric;

    IF p_amount > v_available THEN
        RAISE EXCEPTION 'Requested amount (SLE %) exceeds available balance (SLE %)',
            p_amount, v_available USING ERRCODE = 'check_violation';
    END IF;

    v_payout_ref := 'PO-' || to_char(now(), 'YYYYMMDD') || '-' || upper(substr(gen_random_uuid()::text, 1, 8));

    -- Create payout record in pending state
    INSERT INTO public.vendor_payouts (
        payout_reference,
        vendor_id,
        amount,
        currency,
        status,
        destination_type,
        destination_provider,
        destination_account_number,
        destination_account_name,
        requested_by,
        admin_notes
    )
    VALUES (
        v_payout_ref,
        v_vendor.id,
        p_amount,
        'SLE',
        'pending',
        v_dest.type,
        v_dest.provider,
        v_dest.account_number,
        v_dest.account_name,
        v_caller_id,
        p_notes
    )
    RETURNING id INTO v_payout_id;

    -- Dispatch notification to admins
    INSERT INTO public.notifications (user_id, type, title, body, data)
    SELECT p.id, 'system', 'New Vendor Payout Request',
           v_vendor.shop_name || ' requested payout of SLE ' || p_amount,
           jsonb_build_object('payout_id', v_payout_id, 'payout_reference', v_payout_ref)
    FROM public.profiles p
    WHERE p.role = 'admin';

    RETURN jsonb_build_object(
        'success', true,
        'payout_id', v_payout_id,
        'payout_reference', v_payout_ref,
        'amount', p_amount,
        'status', 'pending',
        'message', 'Payout request submitted successfully and queued for admin authorization'
    );
END;
$$;


-- ============================================================
-- 7. RPC: Admin Approve and Disburse Payout
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_approve_and_disburse_payout(
    p_payout_id             UUID,
    p_disbursement_method   TEXT, -- 'monime_payout' or 'manual'
    p_provider_ref          TEXT DEFAULT NULL,
    p_admin_notes           TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id     UUID := auth.uid();
    v_payout        RECORD;
    v_vendor        RECORD;
    v_ledger_ref    TEXT;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Administrator permission required' USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Lock payout row to prevent concurrent processing
    SELECT * INTO v_payout
    FROM public.vendor_payouts
    WHERE id = p_payout_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payout request not found' USING ERRCODE = 'no_data_found';
    END IF;

    IF v_payout.status NOT IN ('pending', 'approved', 'processing') THEN
        RAISE EXCEPTION 'Payout cannot be processed because status is %', v_payout.status
            USING ERRCODE = 'check_violation';
    END IF;

    SELECT * INTO v_vendor FROM public.vendors WHERE id = v_payout.vendor_id;

    -- Update payout to completed
    UPDATE public.vendor_payouts
    SET status = 'completed',
        disbursement_method = p_disbursement_method,
        provider_reference = COALESCE(p_provider_ref, v_payout.payout_reference),
        authorized_by = v_caller_id,
        authorized_at = COALESCE(authorized_at, now()),
        completed_at = now(),
        admin_notes = COALESCE(p_admin_notes, admin_notes),
        updated_at = now()
    WHERE id = p_payout_id;

    -- Append debit entry to immutable vendor ledger
    v_ledger_ref := 'PAYOUT-' || v_payout.payout_reference;

    INSERT INTO public.vendor_earnings_ledger (
        vendor_id,
        payout_id,
        type,
        gross_amount,
        commission_rate,
        commission_amount,
        net_amount,
        currency,
        reference,
        description
    )
    VALUES (
        v_payout.vendor_id,
        v_payout.id,
        'payout_debit',
        v_payout.amount,
        0.0000,
        0.00,
        -v_payout.amount, -- negative net amount debits the balance
        'SLE',
        v_ledger_ref,
        'Payout disbursed (' || p_disbursement_method || ') via ' || v_payout.destination_provider || ' to ' || v_payout.destination_account_number
    )
    ON CONFLICT (reference) DO NOTHING;

    -- Notify vendor of payout disbursement
    IF v_vendor.profile_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (
            v_vendor.profile_id,
            'payment_received',
            'Payout Disbursed',
            'Your payout of SLE ' || v_payout.amount || ' has been successfully disbursed via ' || v_payout.destination_provider,
            jsonb_build_object(
                'payout_id', p_payout_id,
                'payout_reference', v_payout.payout_reference,
                'amount', v_payout.amount,
                'provider_reference', p_provider_ref
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'payout_id', p_payout_id,
        'status', 'completed',
        'disbursement_method', p_disbursement_method,
        'amount', v_payout.amount,
        'provider_reference', p_provider_ref,
        'message', 'Payout successfully authorized and recorded as completed'
    );
END;
$$;


-- ============================================================
-- 7b. RPC: Finalize Completed Payout (Webhook / Terminal Settlement Only)
-- Strictly finalizes an existing processing payout. Validates Monime payout ID,
-- amount match, and currency consistency. Records ledger debit exactly once.
-- NEVER initiates outbound transfers.
-- ============================================================
CREATE OR REPLACE FUNCTION public.finalize_completed_payout(
    p_payout_id             UUID,
    p_provider_payout_id    TEXT,
    p_amount                NUMERIC(12,2),
    p_currency              TEXT DEFAULT 'SLE',
    p_metadata              JSONB DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_payout        RECORD;
    v_vendor        RECORD;
    v_ledger_ref    TEXT;
BEGIN
    IF p_payout_id IS NULL THEN
        RAISE EXCEPTION 'payout_id is required' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    IF p_provider_payout_id IS NULL OR length(trim(p_provider_payout_id)) = 0 THEN
        RAISE EXCEPTION 'provider_payout_id is required' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    -- Lock payout row to prevent concurrent processing
    SELECT * INTO v_payout
    FROM public.vendor_payouts
    WHERE id = p_payout_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payout request not found');
    END IF;

    -- Idempotent check: if already completed, acknowledge safely without re-debiting
    IF v_payout.status = 'completed' THEN
        RETURN jsonb_build_object(
            'success', true,
            'payout_id', p_payout_id,
            'status', 'completed',
            'already_completed', true,
            'message', 'Payout was already finalized as completed'
        );
    END IF;

    -- Payout MUST be in an active in-flight status ('processing' or 'approved' or 'pending')
    IF v_payout.status NOT IN ('processing', 'approved', 'pending') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Cannot finalize payout with status ' || v_payout.status
        );
    END IF;

    -- Validate currency
    IF v_payout.currency != COALESCE(p_currency, 'SLE') THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Currency mismatch: payout expected ' || v_payout.currency || ', received ' || p_currency
        );
    END IF;

    -- Validate exact amount match (within 0.01 tolerance)
    IF p_amount IS NOT NULL AND ABS(v_payout.amount - p_amount) > 0.01 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Amount mismatch: payout expected ' || v_payout.amount || ', received ' || p_amount
        );
    END IF;

    -- Validate provider payout ID if one was previously recorded
    IF v_payout.provider_payout_id IS NOT NULL 
       AND v_payout.provider_payout_id != p_provider_payout_id THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Provider payout ID mismatch'
        );
    END IF;

    SELECT * INTO v_vendor FROM public.vendors WHERE id = v_payout.vendor_id;

    -- Update payout to completed
    UPDATE public.vendor_payouts
    SET status = 'completed',
        disbursement_method = 'monime_payout',
        provider_payout_id = p_provider_payout_id,
        provider_reference = COALESCE(provider_reference, p_provider_payout_id),
        completed_at = now(),
        updated_at = now()
    WHERE id = p_payout_id;

    -- Append debit entry to immutable vendor ledger exactly once
    v_ledger_ref := 'PAYOUT-' || v_payout.payout_reference;

    INSERT INTO public.vendor_earnings_ledger (
        vendor_id,
        payout_id,
        type,
        gross_amount,
        commission_rate,
        commission_amount,
        net_amount,
        currency,
        reference,
        description
    )
    VALUES (
        v_payout.vendor_id,
        v_payout.id,
        'payout_debit',
        v_payout.amount,
        0.0000,
        0.00,
        -v_payout.amount, -- negative net amount debits the balance
        v_payout.currency,
        v_ledger_ref,
        'Payout finalized via Monime (' || p_provider_payout_id || ') to ' || v_payout.destination_provider
    )
    ON CONFLICT (reference) DO NOTHING;

    -- Dispatch notification to vendor
    IF v_vendor.profile_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (
            v_vendor.profile_id,
            'payment_received',
            'Payout Completed',
            'Your payout of SLE ' || v_payout.amount || ' has been successfully transferred to your ' || v_payout.destination_provider || ' account.',
            jsonb_build_object(
                'payout_id', p_payout_id,
                'payout_reference', v_payout.payout_reference,
                'provider_payout_id', p_provider_payout_id,
                'amount', v_payout.amount
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'payout_id', p_payout_id,
        'status', 'completed',
        'provider_payout_id', p_provider_payout_id,
        'amount', v_payout.amount,
        'currency', v_payout.currency,
        'message', 'Payout successfully finalized and debited from ledger'
    );
END;
$$;


-- ============================================================
-- 8. RPC: Admin Reject Payout
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_reject_payout(
    p_payout_id     UUID,
    p_reason        TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id     UUID := auth.uid();
    v_payout        RECORD;
    v_vendor        RECORD;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Administrator permission required' USING ERRCODE = 'insufficient_privilege';
    END IF;

    IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
        RAISE EXCEPTION 'Rejection reason is required' USING ERRCODE = 'invalid_parameter_value';
    END IF;

    SELECT * INTO v_payout
    FROM public.vendor_payouts
    WHERE id = p_payout_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payout request not found' USING ERRCODE = 'no_data_found';
    END IF;

    IF v_payout.status NOT IN ('pending', 'approved') THEN
        RAISE EXCEPTION 'Cannot reject payout in % status', v_payout.status
            USING ERRCODE = 'check_violation';
    END IF;

    SELECT * INTO v_vendor FROM public.vendors WHERE id = v_payout.vendor_id;

    -- Mark payout as rejected (which restores pending balance to available)
    UPDATE public.vendor_payouts
    SET status = 'rejected',
        failure_reason = p_reason,
        authorized_by = v_caller_id,
        updated_at = now()
    WHERE id = p_payout_id;

    -- Notify vendor
    IF v_vendor.profile_id IS NOT NULL THEN
        INSERT INTO public.notifications (user_id, type, title, body, data)
        VALUES (
            v_vendor.profile_id,
            'payment_failed',
            'Payout Request Rejected',
            'Your payout request for SLE ' || v_payout.amount || ' was rejected: ' || p_reason,
            jsonb_build_object(
                'payout_id', p_payout_id,
                'payout_reference', v_payout.payout_reference,
                'reason', p_reason
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'payout_id', p_payout_id,
        'status', 'rejected',
        'message', 'Payout request rejected and balance restored'
    );
END;
$$;


-- ============================================================
-- 9. RPC: Admin Get Payout Requests
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_get_payout_requests(p_status TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_res JSONB;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Administrator permission required' USING ERRCODE = 'insufficient_privilege';
    END IF;

    SELECT jsonb_agg(
        jsonb_build_object(
            'id', po.id,
            'payout_reference', po.payout_reference,
            'vendor_id', po.vendor_id,
            'vendor_name', v.shop_name,
            'amount', po.amount,
            'currency', po.currency,
            'fee', po.fee,
            'status', po.status,
            'destination_type', po.destination_type,
            'destination_provider', po.destination_provider,
            'destination_account_number', po.destination_account_number,
            'destination_account_name', po.destination_account_name,
            'disbursement_method', po.disbursement_method,
            'provider_reference', po.provider_reference,
            'failure_reason', po.failure_reason,
            'admin_notes', po.admin_notes,
            'created_at', po.created_at,
            'completed_at', po.completed_at
        ) ORDER BY po.created_at DESC
    ) INTO v_res
    FROM public.vendor_payouts po
    JOIN public.vendors v ON v.id = po.vendor_id
    WHERE (p_status IS NULL OR p_status = 'all' OR po.status = p_status);

    RETURN COALESCE(v_res, '[]'::jsonb);
END;
$$;


-- Permissions
GRANT EXECUTE ON FUNCTION public.vendor_get_payout_summary(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reconcile_vendor_order_earnings(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reconcile_vendor_order_refund(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vendor_request_payout(NUMERIC, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_approve_and_disburse_payout(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_completed_payout(UUID, TEXT, NUMERIC, TEXT, JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_reject_payout(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_payout_requests(TEXT) TO authenticated;
