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
