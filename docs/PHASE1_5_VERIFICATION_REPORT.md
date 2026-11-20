# SaloneMarket — Phase 1.5 & 1.6 Technical Verification & Security Audit Report

**Date:** 2026-11-20  
**Auditor:** Senior Implementation Engineer  
**Scope:** Phase 1 foundation, Phase 1.5 verification, and Phase 1.6 security corrections  
**Repository:** https://github.com/Ahmed004-art/salonemarket  

> **This report constitutes the complete audit of the Phase 1 foundation and final security corrections. It does not contain Phase 2 screen implementation.**

---

## Rating Scale

| Rating | Meaning |
|--------|---------|
| ✅ PASS | Correct, complete, tested/verified, no action required |
| ⚠️ PARTIAL | Functionally present with documented operational boundaries |
| ❌ FAIL | Critical defect requiring immediate remediation |
| 🔲 BLOCKED | Requires external live infrastructure to execute |

---

## 1. GitHub Repository & Commit Integrity

| Check | Result | Evidence / Details |
|-------|:------:|-------------------|
| Remote HEAD Commit | ✅ PASS | HEAD is `767f37ff26470c115e18464f65fb18d3448e308d` on `main`. |
| Previous Fixes on Remote | ✅ PASS | Commit `cc95dcf` (Phase 1.5 defect fixes) confirmed on remote. |
| `.github/workflows/flutter_ci.yml` | ⚠️ READY | Valid syntax and commands locally; staged for push once PAT has `workflow` scope. |
| `.github/workflows/supabase_validate.yml` | ⚠️ READY | Fail-open removed; full local migration + lint sequence configured. Staged for push. |
| Secrets Exclusion | ✅ PASS | `.env`, `*.key`, `*.pem`, `*.jks`, `google-services.json` strictly ignored. Zero credentials in repo. |
| Branch State | ✅ PASS | Clean linear git history on `main`. |

---

## 2. Phase 1.6 Security & CI Corrections

Following review of Phase 1.5, two critical security and validation concerns were investigated and resolved:

### 2.1 GitHub Actions SQL Validation Hardening

* **What Was Wrong:**  
  `.github/workflows/supabase_validate.yml` previously executed `supabase db lint --local || true`. The `|| true` clause suppressed non-zero exit codes, masking syntax and schema errors and causing failing SQL checks to report as passing. Furthermore, local Supabase services were not started before linting.
* **What Was Changed:**  
  1. Removed `|| true` error suppression. Any validation or lint error now terminates the workflow with exit code 1 (fail-close).
  2. Added Docker daemon health check (`docker info`) to verify local container virtualization availability.
  3. Added `supabase start` step. When `supabase start` runs, it boots local PostgreSQL and applies all migrations in `supabase/migrations/` sequentially from oldest to newest (`01` through `07`). Any broken syntax, missing constraint, or migration ordering defect causes immediate build failure.
  4. Configured `supabase db lint --local` to run against the running schema, detecting RLS policy omissions and security definer view issues.
  5. Added clean shutdown step (`supabase stop --no-backup`) in `if: always()`.
  6. Added job timeout (`timeout-minutes: 15`).

### 2.2 Supabase Storage Security & Strict RLS Implementation

* **What Was Wrong:**  
  Storage buckets and RLS policies were previously documented as manual instructions rather than committed migrations. The documented draft policies did not check the vendor approval status (`v.status = 'active'`), lacked folder-level UPDATE and DELETE protections, and did not restrict uploads to intended MIME types.
* **What Was Changed:**  
  Created formal migration: [20261120000007_storage_policies.sql](file:///c:/Users/MOK/Downloads/salonemarket/supabase/migrations/20261120000007_storage_policies.sql).

#### `product-images` Bucket Policies:
1. **Public Read:** Public access (`FOR SELECT`) allows any guest or customer to load product images.
2. **Approved Vendor Upload:** Upload (`FOR INSERT`) requires authentication AND verified active vendor status:
   ```sql
   EXISTS (
       SELECT 1 FROM public.vendors v
       WHERE (v.id::text = (storage.foldername(name))[1] OR v.profile_id::text = (storage.foldername(name))[1])
         AND v.profile_id = auth.uid()
         AND v.status = 'active'
   )
   ```
   - Unapproved (`status = 'pending'`) or suspended (`status = 'suspended'`) vendors are strictly blocked.
   - Root-level uploads fail because `(storage.foldername(name))[1]` evaluates to `NULL`.
3. **Cross-Vendor Overwrite & Delete Prevention:** `FOR UPDATE` and `FOR DELETE` enforce the exact same designated-folder ownership and active-status check. Vendors cannot modify or delete images owned by other vendors.
4. **MIME & Size Restrictions:** 10MB limit; restricted to `image/jpeg`, `image/png`, `image/webp`, `image/gif`.

#### `avatars` Bucket Policies:
1. **Public Read:** Public access (`FOR SELECT`) allows loading avatars across product reviews and user profiles.
2. **User Upload & Overwrite Lock:** `FOR INSERT`, `FOR UPDATE`, and `FOR DELETE` enforce that the folder matches the authenticated user:
   ```sql
   (storage.foldername(name))[1] = auth.uid()::text
   ```
   - Users cannot upload into another user's folder or delete another user's avatar.
3. **MIME & Size Restrictions:** 5MB limit; restricted to `image/jpeg`, `image/png`, `image/webp`.

---

## 3. Database Migration Sequence Audit

All 7 migrations are sequentially ordered:

1. `20261120000001_initial_schema.sql` (Creates 16 tables, constraints, enums)
2. `20261120000002_rls_policies.sql` (RLS enabled across all tables; core policies)
3. `20261120000003_indexes.sql` (FK indexes, partial indexes, GIN full-text search)
4. `20261120000004_functions_triggers.sql` (User triggers, timestamp syncing, role locks)
5. `20261120000005_seed_categories.sql` (26 hierarchical categories with stable UUIDs)
6. `20261120000006_vendor_status_protection.sql` (Trigger blocking vendor self-activation)
7. `20261120000007_storage_policies.sql` (Bucket definitions and strict Storage RLS)

---

## 4. Tests Performed & Results

Because Docker and live Supabase services are not hosted on the static audit machine, automated static validation was executed using an automated Python test harness (`scratch/validate_phase1_6.py`):

| Test | Method | Result | Details |
|---|:---:|:---:|---|
| **Workflow Syntax & Fail-Open Check** | Static AST / Regex | ✅ **PASS** | Verified zero `\|\| true` suppression; valid structure. |
| **Migration Sequence & DDL Integrity** | Static File Audit | ✅ **PASS** | All 7 migrations present, strictly ordered, with matching DDL. |
| **Storage Vendor Approval Check** | Static SQL Analysis | ✅ **PASS** | Confirmed `v.status = 'active'` and designated folder checks. |
| **Storage Cross-Tenant Protection** | Static SQL Analysis | ✅ **PASS** | Confirmed UPDATE and DELETE restrictions across both buckets. |
| **MIME & Size Constraints** | Static DDL Analysis | ✅ **PASS** | Verified image-only MIME arrays and size limits. |
| **Live Database Execution** | CI / Live CLI | 🔲 **PENDING** | Runs automatically in GitHub Actions on push or locally via `supabase db push`. |

---

## 5. Exact Deployment Instructions for Project Owner

### Step 1: Push GitHub Workflows (Requires PAT with `workflow` scope)
The workflow files `.github/workflows/flutter_ci.yml` and `.github/workflows/supabase_validate.yml` are ready locally:
```powershell
Set-Location "c:\Users\MOK\Downloads\salonemarket"
git add .github/workflows/
git commit -m "ci: add hardened GitHub Actions workflows"
git push origin main
```

### Step 2: Push Database Migrations (Including Storage RLS)
Once your Supabase project is created:
```powershell
supabase login
supabase link --project-ref <your-project-ref>
supabase db push
```
*(Note: Migration 7 automatically provisions the storage buckets and RLS policies; manual dashboard SQL creation is no longer required).*

### Step 3: Configure Auth & Deploy Functions
1. In Supabase Dashboard > **Authentication > Providers > Email**, ensure Email provider is ON.
2. Set service role key secret and deploy Edge Functions:
   ```powershell
   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
   supabase functions deploy initiate-checkout
   supabase functions deploy process-payment
   supabase functions deploy generate-receipt
   ```

---

## 6. Final Readiness Verdict

> **REPOSITORY FOUNDATION IS CLEAN, HARDENED, AND FULLY READY FOR PHASE 2 ONCE EXTERNAL PREREQUISITES ARE COMPLETED.**

All Phase 1.5 defects and Phase 1.6 security/CI corrections are resolved in code. No Phase 2 application screens or features have been implemented.

*Awaiting project-lead approval to proceed to Phase 2.*
