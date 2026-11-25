# Admin Panel Blank White Screen Fix Report (Updated & Comprehensive)

**Project:** SaloneMarket  
**Module:** Admin Operations Center (`/admin/dashboard`)  
**Date:** November 24, 2026  
**Status:** Root Causes Resolved & Verified via Suite Tests + Fresh APK Build  

---

## 1. Why the Previous Fix Failed & What the Real Causes Were

In the previous iteration, three issues were identified:
1. `AuthNotifier.refreshProfile()` in `initState` triggering router redirects.
2. Nested scrollable layouts collapsing on web.
3. Database `is_admin()` infinite RLS recursion.

However, the screen still flashed content and then blanked out because of **three critical cascading defects that were not fully addressed**:

### Critical Discovery 1: Shared Global State in `AdminNotifier` Causing Cascade Destruction
* In `AdminNotifier`, a single shared `_status` field (`AdminStatusState`) was used for everything: platform stats, vendor management, product moderation, order oversight, and transaction queries.
* When `loadDashboard()` fired, `_status` became `loading`. If the remote database RPC failed or timed out (due to unapplied RLS migration), `_status` became `AdminStatusState.error`.
* Every other screen or component that watched `AdminNotifier` (or checked `isLoading` / `status`) simultaneously switched to error or loading, breaking rendering across the entire admin module.
* **Fix Applied:** Separated domain states into dedicated independent statuses (`_dashboardStatus`, `_vendorsStatus`, `_productsStatus`, `_ordersStatus`, `_transactionsStatus`, `_usersStatus`) with per-domain loading getters (`isVendorsLoading`, `isProductsLoading`, etc.) and localized error states. A failure in platform statistics now **never** contaminates other screens or components.

### Critical Discovery 2: Premature Guard Redirection in `AppRouter`
* In `AppRouter._guard()`, the role check was:
  ```dart
  if (_adminRoutes.contains(location)) {
    if (!isLoggedIn) return Routes.login;
    if (notifier != null && notifier.isLoading && notifier.profile == null) {
      return null;
    }
    if (notifier != null && !notifier.isAdmin) {
      return Routes.home;
    }
  }
  ```
* When an admin navigates to `/admin/dashboard`, if any background auth event or profile reload occurred where `profile` was momentarily being refreshed, `profileReady` was false. But because `profile != null` (with an existing profile), the check `notifier.isLoading && notifier.profile == null` evaluated to `false`, causing the guard to execute `if (!notifier.isAdmin) return Routes.home;`.
* Furthermore, if `getUserProfile()` failed due to RLS recursion on the profiles table, `_loadProfile()` previously fell back to `existingRole ?? metaRole ?? Roles.customer`. If this happened on initial login, the admin was silently downgraded to `customer`, causing `_guard()` to redirect them to `/home` (causing the "flash of admin content, then gone").
* **Fix Applied:**
  1. Updated `_guard()` so that role-based redirection **never** evaluates while the profile is actively loading or resolving (`final profileReady = notifier != null && notifier.profile != null && !notifier.isLoading; if (!profileReady) return null;`).
  2. Updated `_loadProfile()` to strictly preserve the existing role, prioritize metadata roles, and log diagnostic warnings if profile fetching fails, preventing unexpected downgrades to `customer`.

### Critical Discovery 3: Database Migration Status & PostgreSQL Lock (`2BP01`)
* In the initial schema migration `20261120000002_rls_policies.sql`, `is_admin()` was defined as:
  ```sql
  CREATE OR REPLACE FUNCTION public.is_admin()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  ...
  ```
* **PostgreSQL Technical Fact:** `LANGUAGE sql STABLE` functions are **inlined** by the query planner, even when marked `SECURITY DEFINER`. When inlined into the RLS policy `profiles_select_own_or_admin`, querying `public.profiles` evaluates `is_admin()`, which queries `public.profiles`, triggering infinite recursion `ERROR 42P17`.
* When attempting to drop this function, PostgreSQL aborts with `ERROR 2BP01: cannot drop function is_admin() because other objects depend on it`.
* **Database Status:** The remote Supabase database has **not yet** had the updated `CREATE OR REPLACE FUNCTION` script executed against it by the user. Because the previous attempt ran a `DROP FUNCTION` statement that failed with `ERROR 2BP01`, the remote database is still running the recursive `LANGUAGE sql STABLE` function.
* **Fix Applied:**
  1. Fixed migration `20261120000002_rls_policies.sql` to define `is_admin()` and `is_vendor()` as `LANGUAGE plpgsql STABLE SECURITY DEFINER` (which prevents inlining and bypasses RLS during internal execution).
  2. Provided idempotent SQL in `supabase/admin_permissions_fix.sql` using strictly `CREATE OR REPLACE` (no `DROP`).
  3. Made the Flutter UI completely immune: even if the database RPC fails or times out, `AdminDashboardScreen` displays a helpful error card explaining how to run the SQL fix, while the **Administrative Modules (Vendors, Products, Orders, Transactions, Payouts) remain 100% visible and interactive**.

---

## 2. Source Files Changed

1. **`app/lib/features/admin/presentation/screens/admin_dashboard_screen.dart`**
   - Re-architected to guarantee that the `Scaffold` and `SingleChildScrollView` body always render.
   - Removed all conditional returns that could replace the scaffold with an empty canvas or progress indicator.
   - Administrative modules (Vendor Management, Product Moderation, Order Oversight, Transactions & Ledger, Vendor Payouts) are static top-level elements that render immediately.
   - Financial (GMV) and Ecosystem metrics show polite placeholder cards while data is loading or if it fails.
   - Added `_StatsErrorBanner` that displays the exact error message with a retry button and diagnostic guidance without hiding modules.

2. **`app/lib/core/router/app_router.dart`**
   - Guard rewritten to require `profileReady` (`notifier.profile != null && !notifier.isLoading`) before making any role-based routing decision.
   - Live Supabase session checked via `Supabase.instance.client.auth.currentSession != null` to guarantee user is never treated as logged out during profile re-fetches.

3. **`app/lib/features/auth/presentation/controllers/auth_notifier.dart`**
   - In `_loadProfile()`, only sets `_status = AuthStatus.loading` if `_profile == null` (preventing transient unauthenticated states on existing sessions).
   - Defensive fallback preserves existing role and checks JWT `appMetadata['role']`.

4. **`app/lib/features/admin/presentation/controllers/admin_notifier.dart`**
   - Replaced shared `_status` with per-domain statuses: `_dashboardStatus`, `_vendorsStatus`, `_productsStatus`, `_ordersStatus`, `_transactionsStatus`, `_usersStatus`.
   - Added specific loading getters (`isVendorsLoading`, `isProductsLoading`, `isOrdersLoading`, etc.) and separate error getters.
   - Prevented failure of `loadDashboard()` from contaminating any other admin screen.

5. **`app/lib/features/admin/presentation/screens/admin_vendors_screen.dart`**
   - Updated to use `isVendorsLoading` and `vendorsError`.

6. **`app/lib/features/admin/presentation/screens/admin_products_screen.dart`**
   - Updated to use `isProductsLoading` and `productsError`.

7. **`app/lib/features/admin/presentation/screens/admin_orders_screen.dart`**
   - Updated to use `isOrdersLoading` and `ordersError`.

8. **`app/lib/features/admin/presentation/screens/admin_transactions_screen.dart`**
   - Updated to use `isTransactionsLoading` and `transactionsError`.

9. **`supabase/migrations/20261120000002_rls_policies.sql`**
   - Updated function definitions for `is_admin()` and `is_vendor()` to `LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp`.

10. **`app/test/unit/admin_dashboard_render_test.dart`**
    - Updated mock implementation and verified all 4 states (initial, loading, loaded, error).

---

## 3. Verification & Test Evidence

### Unit Tests
Ran all auth, vendor, and admin portal test suites via `flutter test`:
```
00:00 +0: AuthNotifier Tests initial status is unauthenticated when no session exists
00:00 +3: VendorOrder enforces legal sequential status transitions when paid
00:00 +4: AdminPlatformStats correctly parses real ecosystem figures
00:00 +5: Vendor application slug generation cleanses special characters
00:01 +6: AuthNotifier Tests signIn success transitions status and populates profile
00:02 +7: AuthNotifier Tests signIn failure transitions to error and sets message
00:02 +8: AuthNotifier Tests signUp success sets status to authenticated
00:02 +11: AuthNotifier Tests signOut resets state to unauthenticated
00:12 +13: AdminDashboardScreen renders all states safely without blanking
00:19 +14: All tests passed!
```
**Result: 14 of 14 unit tests passed (100%).**

### Debug APK Build
- Assembled via Gradle with Supabase configuration injected:
  `app/build/app/outputs/flutter-apk/app-debug.apk`

---

## 4. Action Required on Supabase Database

The database fix in `supabase/admin_permissions_fix.sql` **must be applied** by running it in the **Supabase Dashboard SQL Editor**:

```sql
-- Run in Supabase SQL Editor:
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

    SELECT role INTO v_role
    FROM public.profiles
    WHERE id = v_uid;

    RETURN COALESCE(v_role = 'admin', false);
END;
$$;

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

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_vendor() TO authenticated;
```

And verify your admin account role:
```sql
SELECT u.email, p.role 
FROM auth.users u 
JOIN public.profiles p ON p.id = u.id 
WHERE p.role = 'admin';
```

---

## 5. Follow-up Fix: Web Rendering, Missing Features & Freeze Prevention (November 25, 2026)

After user testing on Chrome reported missing admin features (vendor verification / user accounts) and occasional freezing:

### Additional Root Causes Found & Fixed
1. **Flutter Web `RefreshIndicator` + `SingleChildScrollView` Layout Collapse:**
   - On Chrome (`kIsWeb`), wrapping `SingleChildScrollView` or `ListView` inside `RefreshIndicator` can cause the scrollable area to collapse or behave erratically.
   - **Fix:** Updated `admin_dashboard_screen.dart` and all admin sub-screens to bypass `RefreshIndicator` when `kIsWeb` is true (using the AppBar refresh button instead) while keeping pull-to-refresh on mobile. Also wrapped dashboard metric cards in `_SafeSection` and `Flexible` to prevent overflow/build exceptions.
2. **Missing User Management Screen & Hidden Sub-screen Errors:**
   - `Routes.adminUsers` and `Routes.adminUserDetail` in `app_router.dart` were still pointing to `_PlaceholderScreen`.
   - Sub-screens (`admin_vendors_screen.dart`, `admin_products_screen.dart`, `admin_orders_screen.dart`, `admin_transactions_screen.dart`, `admin_payouts_screen.dart`) did not render their per-domain error states, making failed Supabase queries look like empty lists ("No vendors found").
   - `admin_products_screen.dart` also read `notifier.errorMessage` instead of `notifier.productsError`, and `admin_orders_screen.dart` / `admin_payouts_screen.dart` had unguarded `.substring()` calls.
   - **Fix:** Created `app/lib/features/admin/presentation/screens/admin_users_screen.dart` and `app/lib/features/admin/presentation/widgets/admin_error_state.dart`, wired `Routes.adminUsers` in `app_router.dart`, added the **User Accounts** module tile to `admin_dashboard_screen.dart`, and updated all admin sub-screens to display `AdminErrorState` with a Retry button on failure.
3. **Unbounded Supabase Queries Causing Freezes:**
   - Only `getPlatformStats()` had a timeout; all other methods in `AdminRepository` and `AdminPayoutRepository` had no timeout, and `AdminPayoutRepository.getPayoutRequests()` silently swallowed errors.
   - **Fix:** Added a 10-second `.timeout(const Duration(seconds: 10))` to every query and RPC in `AdminRepository` and `AdminPayoutRepository`, and propagated `getPayoutRequests()` errors to `AdminPayoutNotifier`.

### Latest Verification
- `flutter analyze lib/features/admin lib/core/router/app_router.dart`: **0 errors** (only pre-existing `info`/`warning` lints).
- `flutter test test/unit/admin_dashboard_render_test.dart test/unit/auth_notifier_test.dart test/unit/vendor_admin_portals_test.dart`: **15 of 15 tests passed** (including `SaloneMarketTheme.lightTheme` rendering of `AdminDashboardScreen` with pending alerts and `AdminVendorsScreen` with pending/active/suspended action buttons).
- **Command to run in Chrome:** `cd app; flutter run -d chrome --dart-define-from-file=../supabase.dev.json`

---

## 6. Confirmed Root Cause of "Flash -> Disappear -> Freeze" (November 25, 2026)

### Exact Runtime / Layout Error Reproduced
Testing `AdminDashboardScreen` and `AdminVendorsScreen` with the real `SaloneMarketTheme.lightTheme` reproduced the exact crash responsible for the "glimpse of all features, then disappear & freeze" behavior:

```text
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during performLayout():
BoxConstraints forces an infinite width.
These invalid constraints were provided to RenderPhysicalShape's layout() function by the following
function, which probably computed the invalid constraints in question:
  RenderConstrainedBox.performLayout (package:flutter/src/rendering/proxy_box.dart:310:14)
The offending constraints were:
  BoxConstraints(w=Infinity, 52.0<=h<=Infinity)

The relevant error-causing widget was:
  ElevatedButton
  ElevatedButton:file:///C:/Users/MOK/Downloads/salonemarket/app/lib/features/admin/presentation/screens/admin_dashboard_screen.dart:677:11
```

### Why It Happened
1. `SaloneMarketTheme.lightTheme` (`app/lib/core/theme/app_theme.dart`) sets `minimumSize: const Size(double.infinity, 52)` globally on both `ElevatedButtonThemeData` and `OutlinedButtonThemeData`.
2. On `AdminDashboardScreen`, `_AlertBanner` is only inserted **after** `loadDashboard()` completes with `pendingVendors > 0` or `reconciliationAlerts > 0`. That explains why all modules briefly appeared before `loadDashboard()` finished, and then crashed the `RenderFlex` / `SingleChildScrollView` layout as soon as the alert banner's `Row` tried to lay out an `ElevatedButton` requesting `w=Infinity`.
3. On `AdminVendorsScreen` and `AdminPayoutsScreen`, the action buttons (`Approve Store`, `Suspend`, `Reactivate Store`, `Reject`, `Disburse Funds`) were also placed inside `Row`s without overriding `minimumSize`, causing the exact same `BoxConstraints forces an infinite width` crash as soon as vendor/payout data loaded.
4. The earlier `admin_dashboard_render_test.dart` passed without catching this because it pumped `MaterialApp` without `theme: SaloneMarketTheme.lightTheme`.

### Fix Implemented
- Overrode `minimumSize: const Size(0, 40)` (and `Size(0, 44)` in `AdminErrorState`) on all `ElevatedButton` and `OutlinedButton` widgets inside `Row`s and dialogs across:
  - `app/lib/features/admin/presentation/screens/admin_dashboard_screen.dart`
  - `app/lib/features/admin/presentation/screens/admin_vendors_screen.dart`
  - `app/lib/features/admin/presentation/screens/admin_payouts_screen.dart`
  - `app/lib/features/admin/presentation/screens/admin_products_screen.dart`
  - `app/lib/features/admin/presentation/widgets/admin_error_state.dart`
- Updated `app/test/unit/admin_dashboard_render_test.dart` to pump `MaterialApp(theme: SaloneMarketTheme.lightTheme, ...)` and verify both `AdminDashboardScreen` (with `pendingVendors > 0` and `reconciliationAlerts > 0`) and `AdminVendorsScreen` (with pending, active, and suspended vendors).


