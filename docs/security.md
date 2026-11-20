# SaloneMarket — Security Model

> **Document status:** Foundation — Phase 1  
> Last updated: 2026-11-20

---

## 1. Authentication

SaloneMarket uses **Supabase Auth** for all user authentication.

### Mechanism
- Email + password authentication via `supabase.auth.signUp` / `signInWithPassword`
- JWT tokens issued by Supabase Auth on successful login
- Tokens stored and managed by the Supabase Flutter SDK — never manually persisted in `SharedPreferences` or plaintext storage
- Token expiry: 1 hour (Supabase default). The SDK auto-refreshes using the refresh token.
- Phone OTP can be enabled per Supabase project settings as an additional factor

### Session Management
- Session state is observed via `supabase.auth.onAuthStateChange` stream
- On sign-out, the session is invalidated both locally and server-side
- No session data is embedded in the Flutter app bundle

### Profile Creation
When a user signs up, a `SECURITY DEFINER` trigger (`handle_new_user`) automatically creates a row in `public.profiles` with `role = 'customer'`. The role is set by the trigger, not by the client.

---

## 2. Authorization

Authorization is enforced at two layers:

### Layer 1 — Supabase Row Level Security (RLS)

RLS is **enabled on all 16 application tables**. No table is exposed without policies.

Two helper functions are defined (`is_admin()`, `is_vendor()`, `is_vendor_for_product()`) with `SECURITY DEFINER` and `STABLE` to avoid repeated subqueries.

| Role | Access Summary |
|---|---|
| **Customer** | Reads own profile, own cart, own orders, own payment attempts, own transactions, own notifications, own wishlists. Reads active products/vendors publicly. Can write reviews for purchased items only. |
| **Vendor** | All customer access, plus: reads/writes own vendor shop, reads/writes own products, reads own vendor_orders, updates vendor_order status. Cannot read other vendors' cost_price or commission details. |
| **Admin** | Full read/write access to all tables via `is_admin()` policies. |
| **Service Role** | Bypasses RLS entirely. Used only in Edge Functions server-side. Never exposed to the client. |

### Layer 2 — Edge Function Server-Side Checks

All order and payment operations go through Edge Functions that:
1. Extract and verify the JWT from the `Authorization` header
2. Look up the caller's profile and role from the database
3. Validate ownership (e.g. customer owns the order being paid)
4. Verify amounts server-side (never trust client-submitted totals)
5. Write results using the service role client (bypassing RLS for trusted operations)

### Role Escalation Prevention

- `profiles.role` defaults to `'customer'` on signup (set by trigger, not client)
- A `BEFORE UPDATE` trigger (`prevent_role_escalation`) raises an exception if a non-service-role session attempts to set `role` to `'vendor'` or `'admin'`
- Vendors are promoted by an admin updating `profiles.role` via a trusted admin operation
- Vendor `status` starts as `'pending'` — only admin can set to `'active'`

---

## 3. Payment Security

### Simulated Payment Design

SaloneMarket uses a **fully simulated payment system**. No real financial transaction occurs.

| Control | Implementation |
|---|---|
| Server-side amount verification | Edge Function fetches `customer_orders.total` from DB and compares to expected amount. Client cannot submit a different amount. |
| Payment state controlled by server | `customer_orders.payment_status` and `payment_attempts.status` are updated only by the Edge Function (service role). RLS denies all client writes to these fields. |
| Idempotency | If a `processing` payment attempt exists for an order, the Edge Function returns the existing reference rather than creating a duplicate. |
| Immutable transaction ledger | `transactions` table has a `BEFORE UPDATE OR DELETE` trigger (`prevent_transaction_mutation`) that raises an exception unconditionally. Records are append-only. |
| Simulation clearly labelled | `is_simulated = true` is set on every `payment_attempt` and `transaction` row. All API responses include `is_simulated: true`. Receipt includes a prominent disclaimer. |
| No real gateway credentials | No Orange Money, Afrimoney, Stripe, or other payment provider credentials exist in the codebase. |

### What "Simulated" Means
- A random number determines success (90%) or failure (10%)
- No money moves. No SMS is sent. No external API is called.
- The disclaimer: *"This is a simulated transaction. No real payment has been processed. No money has been transferred."* appears on all receipts and payment confirmation screens.

### Production Payment Readiness
This architecture is designed to be **replaced** by a real payment provider:
1. The `process-payment` Edge Function is the single integration point
2. Replace the `Math.random()` simulation block with a real provider SDK call
3. Set `is_simulated = false` on resulting records
4. Add webhook handling for async payment confirmation
5. Obtain PCI DSS compliance assessment before going live

---

## 4. Secrets Management

| Secret | Location | Who Uses It |
|---|---|---|
| `SUPABASE_URL` | `.env` (local), `--dart-define` (build), GitHub Actions secret | Flutter app (anon operations) |
| `SUPABASE_ANON_KEY` | `.env` (local), `--dart-define` (build), GitHub Actions secret | Flutter app (authenticated + public reads) |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Edge Function secrets panel only | Edge Functions only — **never in Dart code** |
| `SUPABASE_ACCESS_TOKEN` | GitHub Actions secret | CI/CD — `supabase db push` |
| `SUPABASE_DB_PASSWORD` | GitHub Actions secret | CI/CD — migrations |

### Rules
- `.env` is in `.gitignore` and must never be committed
- `.env.example` contains only placeholder values — safe to commit
- The service role key is set via `supabase secrets set` and accessed in Deno via `Deno.env.get()`
- GitHub secret scanning is enabled on this repository (confirmed at repo creation)
- If a secret is committed accidentally: rotate it immediately at the source (Supabase dashboard / GitHub settings), then remove it from git history with `git filter-repo`

---

## 5. Client Trust Model

### What the Flutter client CAN do (via anon key + RLS)
- Sign up and sign in
- Read own profile, update own profile (not role)
- Read active products, vendors, categories (public)
- Manage own cart and wishlist
- Read own orders, payment history, transactions, notifications
- Mark notifications as read
- Write a review for a purchased product
- Upload product images (via Supabase Storage, vendor only)

### What the Flutter client CANNOT do
- Set `payment_status` or `order_status` on any order (RLS denies all client writes)
- Create `payment_attempts` or `transactions` (RLS denies — service role only)
- Elevate own role to `vendor` or `admin` (trigger raises exception)
- Read another user's profile, cart, orders, or payment data (RLS restricts by `auth.uid()`)
- Read `vendors.commission_rate` or `products.cost_price` for other vendors (RLS restricts)
- Delete or modify `transactions` records (immutability trigger blocks all mutations)
- Activate their own vendor application (admin-only operation)
- Access admin-only data (admin policies check `is_admin()` function)

---

## 6. Edge Function Security

Every Edge Function:
1. Returns `200 OK` immediately for `OPTIONS` (CORS preflight)
2. Requires a valid Supabase JWT in the `Authorization: Bearer <token>` header
3. Creates an admin client using `SUPABASE_SERVICE_ROLE_KEY` from `Deno.env` (never from client input)
4. Verifies the caller's identity with `supabase.auth.getUser(jwt)`
5. Fetches the caller's profile to verify role and ownership
6. Returns `401` for unauthenticated requests, `403` for unauthorized role, `400` for validation errors, `500` for unexpected errors

CORS policy allows `*` origin — acceptable for a mobile app. For a web app deployment, restrict to specific origins.

---

## 7. Known Limitations

| Limitation | Risk | Mitigation Plan |
|---|---|---|
| Simulated payment only | No real revenue possible | Integrate real gateway before launch (see §3) |
| No rate limiting | Brute-force auth or API abuse possible | Add Supabase rate limiting or Cloudflare WAF before production |
| No fraud detection | Fake accounts, review manipulation | Add email verification, purchase-verified reviews (order_item_id link is in schema) |
| No MFA | Account takeover risk | Enable Supabase MFA (TOTP) for vendor and admin accounts |
| No audit log | Cannot trace who changed what | Add an `audit_log` table with triggers for sensitive operations |
| No input sanitisation beyond DB constraints | Potential for XSS in product descriptions if rendered as HTML | Sanitise all user-generated content before display; never use `innerHTML` |
| commission_rate not rate-limited | A bad deployment could set 0% | Add `CHECK (commission_rate BETWEEN 0 AND 0.5)` constraint (migration patch) |
| No vendor payout disbursement | vendor_payout column is calculated but no disbursement flow | Implement payout workflow when real payment gateway is integrated |

---

## 8. Pre-Production Security Checklist

Before deploying to production with real users and real money:

- [ ] Replace simulated payment with a real, certified payment gateway
- [ ] Enable email verification in Supabase Auth settings
- [ ] Enable MFA for admin and vendor accounts
- [ ] Restrict CORS origins to your specific domain
- [ ] Add rate limiting on auth endpoints and Edge Functions
- [ ] Conduct a full RLS policy audit with penetration testing
- [ ] Enable Supabase Vault for secret management (replace `Deno.env` with Vault references)
- [ ] Add `CHECK (commission_rate BETWEEN 0 AND 0.50)` constraint to vendors table
- [ ] Enable Supabase's built-in `pg_audit` extension for audit logging
- [ ] Review and restrict Supabase Storage bucket policies (product images should not allow arbitrary uploads)
- [ ] Enable Dependabot on the GitHub repository
- [ ] Remove all hardcoded fallback values from `AppConstants` (empty string defaults only)
- [ ] Obtain legal review of terms of service and privacy policy (data residency for Sierra Leone)
- [ ] Perform GDPR/data protection compliance review if any EU users are anticipated
- [ ] Run `flutter analyze` and `flutter test` with zero warnings before production build
- [ ] Conduct manual penetration test of all three role flows (customer, vendor, admin)
