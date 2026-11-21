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
