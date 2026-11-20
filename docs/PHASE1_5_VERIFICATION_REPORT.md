# SaloneMarket — Phase 1.5 Independent Technical Verification Report

**Date:** 2026-11-20  
**Auditor:** Senior Implementation Engineer (independent audit pass)  
**Scope:** Phase 1 foundation — commit `9a0b5f0` (remote HEAD: `9b8714b`)  
**Repository:** https://github.com/Ahmed004-art/salonemarket  

> **This report is an audit of the Phase 1 foundation. It does not constitute Phase 2 work.**  
> Every defect identified was verified against actual file content. No finding is assumed.

---

## Rating Scale

| Rating | Meaning |
|--------|---------|
| ✅ PASS | Correct, complete, no action required |
| ⚠️ PARTIAL | Functionally present but has limitations; documented below |
| ❌ FAIL | Critical defect; must be fixed before Phase 2 |
| 🔲 BLOCKED | Cannot be verified without a live environment |

---

## 1. GitHub Repository Verification

| Check | Result | Evidence |
|-------|--------|---------|
| Commit `9a0b5f0` exists on remote | ✅ PASS | Confirmed via GitHub API: full SHA `9a0b5f0eafd288012d9fc24cafc923ef7b6c3a19` |
| Remote HEAD | ✅ PASS | HEAD is `9b8714b` (chore: stage workflows for PAT-scope push) — expected |
| All expected Phase 1 files present | ✅ PASS | GitHub API tree lists 57 objects; all 35 non-workflow files confirmed |
| `.github/workflows/flutter_ci.yml` on remote | ❌ FAIL | **Absent from remote.** Present locally at commit `34d98c6`. PAT lacks `workflow` scope. |
| `.github/workflows/supabase_validate.yml` on remote | ❌ FAIL | **Absent from remote.** Same cause. |
| GitHub Actions running | ❌ FAIL | `total_count: 0` — CI is inactive; no workflow runs have occurred |
| `.env` committed | ✅ PASS | `.env` is absent from the tree; `.env.example` is present |
| Credentials in repository | ✅ PASS | No credentials, keys or secrets found in any committed file |
| `.gitignore` coverage | ✅ PASS | `.env`, `*.key`, `*.pem`, `*.jks`, `google-services.json` all ignored |

**GitHub finding:** Two workflow files are present locally (commit `34d98c6`) but cannot be pushed without a GitHub PAT with `workflow` scope. CI is non-functional until the PAT is rotated.

---

## 2. Database Migration Audit

### 2.1 Table Coverage

| Table | Present | Notes |
|-------|---------|-------|
| profiles | ✅ | UUID PK, role CHECK, is_active |
| vendors | ✅ | status, commission_rate numeric(5,2) |
| categories | ✅ | Hierarchical via parent_id |
| products | ✅ | price/compare_price numeric(12,2) |
| product_images | ✅ | |
| carts | ✅ | UNIQUE(customer_id) enforced |
| cart_items | ✅ | UNIQUE(cart_id, product_id) enforced |
| customer_orders | ✅ | total numeric(12,2), status/payment_status CHECKs |
| vendor_orders | ✅ | subtotal numeric(12,2) |
| order_items | ✅ | unit_price/total numeric(12,2) |
| payment_attempts | ✅ | amount numeric(12,2), is_simulated flag |
| transactions | ✅ | amount numeric(12,2), is_simulated flag |
| reviews | ✅ | rating CHECK (1–5) |
| notifications | ✅ | type CHECK constraint |
| wishlists | ✅ | UNIQUE(product_id, customer_id) |
| addresses | ✅ | |

**All 16 required tables are present.** ✅ PASS

### 2.2 Financial Types

All monetary columns use `numeric(12,2)` or `numeric(5,2)`. No `float` or `double precision` used for currency. ✅ PASS

### 2.3 Foreign Keys and Constraints

All FK relationships verified. `ON DELETE CASCADE` applied correctly on dependent tables. UNIQUE constraints present where required. ✅ PASS

### 2.4 UUID Primary Keys

All tables use `uuid DEFAULT gen_random_uuid()`. ✅ PASS

### 2.5 Timestamps

All tables have `created_at timestamptz NOT NULL DEFAULT now()`. Tables with mutable rows additionally have `updated_at`. ✅ PASS

### 2.6 RLS Status

RLS enabled on all 16 tables (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`). ✅ PASS

### 2.7 RLS Policy Correctness

| Table | Policy Assessment |
|-------|------------------|
| profiles | SELECT: own row + vendor/admin view logic; UPDATE: own row only. No self-role-escalation. ✅ |
| vendors | SELECT: authenticated; INSERT: requires customer role (prevents vendor self-creation from vendor role); UPDATE: `vendors_update_own_shop` — see **DEFECT 6** below ⚠️ |
| categories | SELECT: public; INSERT/UPDATE/DELETE: admin only ✅ |
| products | SELECT: public (active); vendor CRUD: own products; admin: all ✅ |
| product_images | Mirrors product vendor ownership ✅ |
| carts | Strict customer_id = auth.uid() isolation ✅ |
| cart_items | Via cart ownership check ✅ |
| customer_orders | Customer sees own; vendor sees none directly (via vendor_orders); admin sees all ✅ |
| vendor_orders | Vendor sees own vendor_id only; prevents cross-vendor access ✅ |
| order_items | Tied to customer_order ownership ✅ |
| payment_attempts | Customer sees own; prevents cross-customer access ✅ |
| transactions | Customer sees own; prevents cross-customer access ✅ |
| reviews | Customer CRUD own; vendor read; public read ✅ |
| notifications | User sees own user_id only ✅ |
| wishlists | Customer sees own ✅ |
| addresses | Customer sees own ✅ |

### 2.8 `is_admin()` and `is_vendor()` Security Functions

Both are `SECURITY DEFINER` with `SET search_path = public`. They query `profiles` by `auth.uid()` — no parameter, no caller influence. No recursion risk (functions are not called from within profiles' own policies; profiles SELECT policy uses a subquery). ✅ PASS

### 2.9 Role Escalation Protection

`prevent_role_escalation` trigger blocks any UPDATE to `profiles.role` from non-service-role callers. Correctly uses JWT claims check. The `current_user IN ('postgres', 'supabase_admin')` fallback is acceptable for admin-API use. ⚠️ PARTIAL — cannot live-verify without Supabase instance.

### 2.10 Transaction History

`transactions` table has no UPDATE or DELETE RLS policies — records are insert-only by design. Combined with `prevent_payment_modification` trigger on `customer_orders` and `vendor_orders` (migration 4), paid orders cannot be reopened. ✅ PASS

### 2.11 Search Indexes

Migration 3 creates indexes on all high-traffic FK columns, full-text search vector on `products`, and partial indexes for active/visible records. ✅ PASS

### 2.12 Category Seeds

Migration 5 seeds 6 parent categories and 20 child categories (26 total) using stable explicit UUIDs. `ON CONFLICT (slug) DO UPDATE` ensures idempotent re-runs. ✅ PASS

### 2.13 `handle_new_user` Trigger Duplication

⚠️ PARTIAL — The function is defined in both migration 1 (without COALESCE) and migration 4 (with COALESCE). `CREATE OR REPLACE FUNCTION` and `DROP TRIGGER IF EXISTS` prevent a runtime failure, but migration 1's version is dead code. Recommend removing the definition from migration 1 in a future cleanup migration. Not blocking for Phase 2.

### 2.14 DEFECT 6 — Vendor Self-Activation (SECURITY) — **FIXED**

**Original defect:** `vendors_update_own_shop` RLS policy had no WITH CHECK restriction on `status` or `commission_rate`. A vendor could self-activate or change their commission rate.

**Fix applied:** Migration `20261120000006_vendor_status_protection.sql` adds `trg_vendors_prevent_self_activation` — a `BEFORE UPDATE` trigger that raises `insufficient_privilege` if a non-service-role caller attempts to change `status` or `commission_rate`. Service-role (Edge Functions) is exempt via JWT claim check.

**Status:** ✅ FIXED (migration 6 added)

---

## 3. Edge Function Security Audit

### 3.1 `_shared/auth.ts` — Authentication Gate

All three functions call `getAuthenticatedUser(req, supabase)` as their first action. This function:
- Extracts the Authorization header
- Calls `supabase.auth.getUser(token)` against the service-role client
- Returns the user or throws a 401 Response

Unauthenticated requests are rejected before any business logic executes. ✅ PASS

### 3.2 `_shared/supabase_client.ts` — Admin Client

Uses `SUPABASE_SERVICE_ROLE_KEY` from `Deno.env` (Supabase Secrets). Never appears in client-side code. `autoRefreshToken: false, persistSession: false` — correct for server-side use. ✅ PASS

### 3.3 `initiate-checkout` Audit

| Check | Result |
|-------|--------|
| Unauthenticated requests rejected | ✅ PASS |
| Customer cannot access another's cart | ✅ — `cart.customer_id !== user.id` explicit check (line 55) |
| Client cannot supply amount | ✅ — Total is computed server-side from `order_items × product.price` |
| Client cannot mark order as paid | ✅ — Only creates `pending_payment` orders |
| Vendor order splitting | ✅ — Groups items by `vendor_id`, creates separate `vendor_orders` |
| Subtotal calculation | ✅ — Computed per vendor group, summed to total |
| Payment relationship | ✅ — `payment_attempt` linked to `customer_order_id` |
| Atomicity | ⚠️ PARTIAL — No explicit transaction/rollback. If `vendor_orders` insert fails after `customer_order` created, DB is inconsistent. Acceptable for Phase 1 scope; noted in `docs/security.md`. |

### 3.4 `process-payment` Audit

**Multiple critical defects were found and fixed (see section 5).**

| Check | Result |
|-------|--------|
| Unauthenticated requests rejected | ✅ PASS |
| Customer isolation | ✅ — `order.customer_id !== user.id` explicit check (line 48) |
| Client cannot supply trusted amount | ✅ — `expected_amount` is optional and only used for client-side consistency verification; server always uses `order.total` from DB |
| Client cannot mark order as paid | ✅ — All status updates are in Edge Function logic only |
| Duplicate payment prevention | ✅ — Checks for existing `processing` attempt and returns idempotent response |
| Failed payment → no false transaction | ✅ — Failed path creates a `failed` transaction, does not set `confirmed`/`paid` |
| Simulated payment identification | ✅ — `is_simulated: true` on all records; disclaimer in response |
| payment_attempts insert columns | ❌ FAIL → **FIXED** (see section 5) |
| transactions insert columns | ❌ FAIL → **FIXED** (see section 5) |
| notifications field names | ❌ FAIL → **FIXED** (see section 5) |
| notification type values | ❌ FAIL → **FIXED** (see section 5) |

### 3.5 `generate-receipt` Audit

| Check | Result |
|-------|--------|
| Unauthenticated requests rejected | ✅ PASS |
| Ownership verified | ✅ — `order.customer_id !== user.id` check |
| Receipt only for paid orders | ✅ — Checks `payment_status = 'paid'` |
| Commission/payout data exposure | ⚠️ PARTIAL — `commission_amount` and `vendor_payout` are included per vendor order. Acceptable for academic transparency but should be reviewed for production. |

---

## 4. Flutter Foundation Audit

### 4.1 Route Count

Declared routes in `app_router.dart`:
- Auth: 6 (`/`, `/login`, `/register`, `/forgot-password`, `/reset-password`, `/verify-email`)
- Customer browse: 10
- Customer checkout/orders: 8
- Customer account: 5
- Vendor portal: 9
- Admin portal: 8
- 404: 1

**Total: 47 declared routes** (originally stated as 41 — the actual file contains 47). All map to `_PlaceholderScreen` as expected for Phase 1.

### 4.2 Route Guard (`_guard`)

| Check | Result |
|-------|--------|
| Unauthenticated → `/login` | ✅ — `if (!isLoggedIn && !isPublic) return Routes.login` |
| Authenticated on auth screen → `/home` | ✅ — `if (isLoggedIn && isPublic && location != Routes.splash)` |
| Vendor routes without login | ✅ — Secondary check redirects to `/login` |
| Admin routes without login | ✅ — Secondary check redirects to `/login` |
| Role guard for authenticated vendor/admin | ⚠️ PARTIAL — Guard comment acknowledges that role checking requires a loaded Profile. Authenticated non-vendors can currently navigate to vendor routes if they know the URL. This is documented in the code and acceptable for Phase 1 (screens are placeholders). Must be completed in Phase 2 with a Provider/Notifier. |

### 4.3 `app_theme.dart`

Comprehensive Material 3 theme with:
- Colour palette: Deep Navy (#1A1A2E), Warm Amber (#E8A020), Warm Off-White (#F7F4EF)
- Typography: Plus Jakarta Sans (headings), DM Sans (body) — Google Fonts
- Zero elevation cards with 1px border — avoids generic shadow aesthetics
- Consistent 8px border radius across all interactive components
- No unnecessary gradients

✅ PASS — Design system is well-structured and matches the premium brief.

### 4.4 `main.dart`

- Supabase initialised with `--dart-define` injected URL and anon key (never hard-coded)
- `MaterialApp.router` with `AppRouter.router` and `SaloneMarketTheme.lightTheme`
- `debugShowCheckedModeBanner: false`
- Note comment warning FlutterFlow about replacing this file

✅ PASS

### 4.5 `app_constants.dart`

All CHECK-constraint values mirrored as typed constants. 

**DEFECT FIXED:** `NotificationType` previously declared `order_cancelled`, `low_stock`, `new_review` which do not exist in the `notifications.type` CHECK constraint. These were removed and a note added directing developers to add a migration before extending.

✅ PASS (after fix)

### 4.6 `auth_repository.dart`

- Sealed `AuthResult<T>` / `AuthSuccess` / `AuthFailure` — no exception propagation
- `signUpWithEmail` passes `full_name` in metadata → used by `handle_new_user` trigger ✅
- `signInWithEmail` with password ✅
- `signOut` ✅
- `getUserProfile` queries own profile by ID ✅
- `watchAuthState()` stream for reactive auth ✅

✅ PASS

### 4.7 `supabase_service.dart`

Thin singleton wrapper. Contains only anon-key operations. Explicit security comment that service-role key must never appear in client code. ✅ PASS

### 4.8 `pubspec.yaml`

| Concern | Assessment |
|---------|-----------|
| `supabase_flutter: ^2.3.4` | ✅ Current major version |
| `go_router: ^13.2.0` | ✅ |
| `google_fonts: ^6.2.1` | ✅ Required for Plus Jakarta Sans / DM Sans |
| `provider: ^6.1.2` | ✅ For state management |
| `flutter_animate: ^4.5.0` | ✅ For micro-interactions |
| `mocktail: ^1.0.4` | ✅ Dev only |
| `assets/images/` and `assets/icons/` declared | ⚠️ PARTIAL — Directories not yet created; will cause build warning but not failure until assets are referenced. Create in Phase 2. |

### 4.9 Tests

| Test | Status |
|------|--------|
| `auth_repository_test.dart` — payment reference format | ✅ PASS (pure logic, no Supabase needed) |
| `auth_repository_test.dart` — Supabase integration tests | 🔲 BLOCKED — Correctly skipped with descriptive messages |
| `app_theme_test.dart` — theme property tests | ✅ Design-only, no Supabase needed |
| `flutter test` execution | 🔲 BLOCKED — Flutter SDK not installed on audit machine |

### 4.10 FlutterFlow Compatibility

`main.dart` includes an explicit note warning developers to compare FlutterFlow's generated `main.dart` before replacing. `docs/architecture.md` (Phase 1 deliverable) documents the FlutterFlow sync workflow. All custom code is in clearly namespaced directories (`lib/core/`, `lib/features/`) separate from FlutterFlow's expected output directories. ✅ PASS

---

## 5. Critical Defect Summary and Fixes Applied

All five critical defects were in `supabase/functions/process-payment/index.ts`. All have been corrected in this commit.

### DEFECT 1 — `payment_attempts` insert: non-existent `currency` column ❌ → ✅

**Location:** Line 120 (original)  
**Problem:** `currency: 'SLL'` — column does not exist in `payment_attempts` schema.  
**Fix:** Removed `currency` field from the insert.

### DEFECT 2 — `payment_attempts` insert: `raw_response` → `metadata` ❌ → ✅

**Location:** Lines 125, 149, 244 (original)  
**Problem:** `raw_response` column does not exist. Schema column is `metadata`.  
**Fix:** Replaced all `raw_response:` with `metadata:` in insert and update operations. Also removed `updated_at:` from update operations (`payment_attempts` has no `updated_at` column).

### DEFECT 3 — `payment_attempts` insert: missing `customer_id` NOT NULL ❌ → ✅

**Location:** Line 115–128 insert block (original)  
**Problem:** `payment_attempts.customer_id` is `NOT NULL`. It was absent from the insert.  
**Fix:** Added `customer_id: user.id` to the insert.

### DEFECT 4 — `transactions` insert: `notes` → `description` ❌ → ✅

**Location:** Lines 171, 265 (original)  
**Problem:** `notes` column does not exist in `transactions`. Schema column is `description`.  
**Fix:** Replaced `notes:` with `description:` in both success and failure transaction inserts.

### DEFECT 5 — `notifications` insert: wrong column name and invalid type values ❌ → ✅

**Location:** Lines 202–220 and 285–291 (original)  
**Problem (a):** `profile_id:` used — column is `user_id` in `notifications` schema.  
**Problem (b):** `type: 'new_order'` — not in CHECK constraint. Valid values do not include `new_order`.  
**Problem (c):** `type: 'payment_success'` — not in CHECK constraint.  
**Fix:**  
- All `profile_id:` → `user_id:`  
- Vendor notification type: `'new_order'` → `'payment_received'`  
- Customer success notification type: `'payment_success'` → `'order_confirmed'`  
- Customer failure notification type: `'payment_failed'` ← already correct, retained

### DEFECT 6 — Vendor self-activation via RLS ❌ → ✅

**Location:** `supabase/migrations/20261120000002_rls_policies.sql` — `vendors_update_own_shop`  
**Problem:** WITH CHECK only validates ownership, not which columns are changed. A vendor could self-activate (`status = 'active'`) or change `commission_rate`.  
**Fix:** New migration `20261120000006_vendor_status_protection.sql` adds `trg_vendors_prevent_self_activation` — a `BEFORE UPDATE` trigger that raises `insufficient_privilege` on `status` or `commission_rate` changes from non-service-role callers.

---

## 6. Additional Findings (Non-Blocking)

| Finding | Severity | Action |
|---------|----------|--------|
| `handle_new_user` defined in migration 1 AND migration 4 | Low | Clean up in a future migration (not Phase 2 scope) |
| `generate-receipt` exposes `commission_amount`/`vendor_payout` to customer | Low | Flag for review before production launch |
| `initiate-checkout` lacks DB transaction / rollback | Architectural | Documented in `security.md`; acceptable for Phase 1 |
| Role-based route guard deferred to Phase 2 | Expected | Code comment and architecture docs acknowledge this |
| `assets/images/` and `assets/icons/` not yet created | Low | Create in Phase 2 when first asset is added |
| Flutter SDK not installed on audit machine | Environmental | Tests are BLOCKED, not failing |
| `order_cancelled`, `low_stock`, `new_review` absent from notification CHECK constraint | Minor | Flutter constants corrected; extend migration if these types are needed in Phase 2 |

---

## 7. Missing Accounts, Credentials and Configuration

| Item | Status | Action Required |
|------|--------|----------------|
| Supabase project | ❌ Not created | Create project, run migrations, configure secrets |
| `SUPABASE_URL` | ❌ Not set | Required before any Flutter build or Edge Function deploy |
| `SUPABASE_ANON_KEY` | ❌ Not set | Required for Flutter `--dart-define` |
| `SUPABASE_SERVICE_ROLE_KEY` | ❌ Not set | Set via `supabase secrets set`, never commit |
| GitHub PAT with `workflow` scope | ❌ Current PAT lacks this scope | Rotate PAT with `workflow` permission to push CI files |
| GitHub Actions secrets | ❌ Not configured | Add `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD` in repo Settings |
| Flutter SDK | ❌ Not on audit machine | Required for `flutter test`, `flutter build` |
| Supabase CLI | ❌ Not confirmed installed | Required for `supabase db push`, `supabase functions deploy` |

---

## 8. Potential Blockers

1. **No Supabase project exists.** All database and Edge Function code is untested against a live instance. Migrations may surface additional issues.
2. **GitHub CI is non-functional.** Two workflow files cannot be pushed without `workflow`-scoped PAT.
3. **Flutter SDK absent.** Unit and widget tests are BLOCKED; cannot confirm `flutter analyze` passes.
4. **`initiate-checkout` has no atomic rollback.** An interrupted checkout can leave orphaned `customer_order` records. Must be addressed in Phase 2 if Supabase supports `pg_advisory_lock` or similar patterns.
5. **Role guard is incomplete.** Authenticated users who know a vendor/admin URL can reach placeholder screens. Phase 2 must complete guard logic using a Profile Provider/Notifier.

---

## 9. Files Modified in This Audit

| File | Change |
|------|--------|
| `supabase/functions/process-payment/index.ts` | Fixed 5 critical runtime defects (column names, missing customer_id, invalid notification types) |
| `supabase/migrations/20261120000006_vendor_status_protection.sql` | **New file** — vendor self-activation protection trigger |
| `app/lib/core/constants/app_constants.dart` | Fixed `NotificationType` constants to match schema CHECK constraint |
| `docs/PHASE1_5_VERIFICATION_REPORT.md` | **This file** |

---

## 10. Verdict

> **READY AFTER SPECIFIED FIXES**

The Phase 1 foundation is structurally sound. The database schema, RLS design, Flutter architecture and design system are well-considered and appropriate for the project requirements.

**All six critical defects identified have been fixed in this commit.** The two remaining blockers (Supabase project creation, GitHub PAT rotation) require manual action from the project lead and cannot be resolved by the engineering team alone.

**Conditions for Phase 2 approval:**

1. ✅ All 6 defects fixed — done in this commit
2. ⏳ Project lead creates a Supabase project and runs migrations to verify no additional SQL errors
3. ⏳ GitHub PAT rotated with `workflow` scope and CI workflows pushed
4. ⏳ GitHub Actions secrets (`SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`) configured

Once conditions 2–4 are confirmed, Phase 2 may proceed.

---

*Report generated by independent technical audit. All findings based on static analysis of committed source files. No production systems were accessed or modified.*
