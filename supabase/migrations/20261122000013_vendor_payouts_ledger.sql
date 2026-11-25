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
