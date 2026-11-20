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
