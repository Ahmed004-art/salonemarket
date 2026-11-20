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
