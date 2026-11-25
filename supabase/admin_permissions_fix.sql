-- ============================================================
-- SaloneMarket: Permanent Admin Permissions & Dashboard Fix
-- Run this ENTIRE script in the Supabase Dashboard SQL Editor.
-- ============================================================

-- ── STEP 1: Redefine is_admin() as PLPGSQL SECURITY DEFINER ─────────────
-- NOTE: We use CREATE OR REPLACE (NOT DROP) because RLS policies depend on
-- this function. Replacing in-place preserves all policy dependencies.
-- This prevents PostgreSQL query inlining and eliminates the infinite
-- RLS recursion loop that happens when is_admin() is called from an
-- RLS policy on the profiles table (which calls is_admin() again).
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE plpgsql
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

    -- Use a direct pk lookup (bypasses RLS on profiles because SECURITY DEFINER)
    SELECT role INTO v_role
    FROM public.profiles
    WHERE id = v_uid;

    RETURN COALESCE(v_role = 'admin', false);
END;
$$;

-- ── STEP 3: Redefine is_vendor() with same safe pattern ──────────────────
CREATE OR REPLACE FUNCTION public.is_vendor()
RETURNS boolean
LANGUAGE plpgsql
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

-- ── STEP 4: Robust admin_get_platform_stats() ────────────────────────────
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
        RAISE EXCEPTION 'Access denied: Administrator privileges required'
              USING ERRCODE = 'insufficient_privilege';
    END IF;

    -- Customers
    BEGIN
        SELECT COALESCE(COUNT(*), 0) INTO v_total_customers
        FROM public.profiles WHERE role = 'customer';
    EXCEPTION WHEN OTHERS THEN v_total_customers := 0; END;

    -- Vendors
    BEGIN
        SELECT
            COALESCE(COUNT(*), 0),
            COALESCE(COUNT(*) FILTER (WHERE status = 'pending'), 0),
            COALESCE(COUNT(*) FILTER (WHERE status = 'active'), 0),
            COALESCE(COUNT(*) FILTER (WHERE status = 'suspended'), 0)
        INTO v_total_vendors, v_pending_vendors, v_active_vendors, v_suspended_vendors
        FROM public.vendors;
    EXCEPTION WHEN OTHERS THEN END;

    -- Products
    BEGIN
        SELECT
            COALESCE(COUNT(*), 0),
            COALESCE(COUNT(*) FILTER (WHERE status = 'active'), 0),
            COALESCE(COUNT(*) FILTER (WHERE status = 'flagged'), 0)
        INTO v_total_products, v_active_products, v_flagged_products
        FROM public.products;
    EXCEPTION WHEN OTHERS THEN END;

    -- Orders & GMV
    BEGIN
        SELECT
            COALESCE(COUNT(*), 0),
            COALESCE(SUM(total) FILTER (WHERE payment_status = 'paid'), 0.00),
            COALESCE(SUM(total) FILTER (WHERE payment_status = 'paid' AND created_at >= date_trunc('day', now())), 0.00),
            COALESCE(SUM(total) FILTER (WHERE payment_status = 'paid' AND created_at >= date_trunc('week', now())), 0.00),
            COALESCE(SUM(total) FILTER (WHERE payment_status = 'paid' AND created_at >= date_trunc('month', now())), 0.00)
        INTO v_total_orders, v_total_gmv, v_today_gmv, v_week_gmv, v_month_gmv
        FROM public.customer_orders;
    EXCEPTION WHEN OTHERS THEN END;

    -- Reconciliation Alerts (safe even if table is empty or metadata is null)
    BEGIN
        SELECT COALESCE(COUNT(*), 0) INTO v_reconciliation_alerts
        FROM public.transactions
        WHERE (metadata->>'reconciliation_needed')::boolean = true;
    EXCEPTION WHEN OTHERS THEN
        v_reconciliation_alerts := 0;
    END;

    RETURN jsonb_build_object(
        'total_customers',      v_total_customers,
        'total_vendors',        v_total_vendors,
        'pending_vendors',      v_pending_vendors,
        'active_vendors',       v_active_vendors,
        'suspended_vendors',    v_suspended_vendors,
        'total_products',       v_total_products,
        'active_products',      v_active_products,
        'flagged_products',     v_flagged_products,
        'total_orders',         v_total_orders,
        'total_gmv',            v_total_gmv,
        'today_gmv',            v_today_gmv,
        'week_gmv',             v_week_gmv,
        'month_gmv',            v_month_gmv,
        'reconciliation_alerts', v_reconciliation_alerts
    );
END;
$$;

-- ── STEP 5: Explicit execution grants ────────────────────────────────────
GRANT EXECUTE ON FUNCTION public.is_admin()                TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_vendor()               TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_platform_stats() TO authenticated;

-- ── STEP 6: Confirm your admin role is set ───────────────────────────────
-- Run this SELECT to verify who has admin access:
-- SELECT u.email, p.role FROM auth.users u JOIN public.profiles p ON p.id = u.id WHERE p.role = 'admin';

-- If the row is missing, run this (replace the email with yours):
-- UPDATE public.profiles SET role = 'admin'
-- WHERE id = (SELECT id FROM auth.users WHERE email = 'YOUR_ADMIN_EMAIL@gmail.com');
