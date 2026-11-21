-- ============================================================
-- SaloneMarket: Checkout Idempotency
-- Migration: 20261120000009_checkout_idempotency.sql
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
