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
