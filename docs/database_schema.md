# SaloneMarket — Database Schema Reference

## Tables

---

### **profiles**

**Purpose:** Extends `auth.users` with application-level user data; created automatically by trigger on new auth user.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK, REFERENCES auth.users(id) ON DELETE CASCADE | Matches Supabase auth user id |
| full_name | text | | Display name |
| phone | text | UNIQUE | Sierra Leone phone number |
| avatar_url | text | | Supabase Storage URL |
| role | text | NOT NULL DEFAULT 'customer', CHECK IN ('customer','vendor','admin') | Application role |
| is_active | boolean | NOT NULL DEFAULT true | Account enabled flag |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| updated_at | timestamptz | NOT NULL DEFAULT now() | Auto-updated by trigger |

**Relationships:**
- One-to-one with `auth.users` (via `id`)
- One-to-one with `vendors` (via `vendors.profile_id`)
- One-to-many with `addresses`, `carts`, `customer_orders`, `notifications`

**RLS Policies:**

| Policy | Role | Operation | Condition |
|---|---|---|---|
| own_profile_read | authenticated | SELECT | `id = auth.uid()` |
| own_profile_update | authenticated | UPDATE | `id = auth.uid()` |
| admin_all | admin | ALL | `role = 'admin'` in JWT |

> `role` and `is_active` columns are protected by trigger `trg_protect_role`; non-admin UPDATE attempts on these fields are rejected.

**Indexes:** PK on `id`, UNIQUE on `phone`.

---

### **vendors**

**Purpose:** Represents a vendor's shop; linked 1:1 to a profile with `role='vendor'`.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| profile_id | uuid | NOT NULL UNIQUE REFERENCES profiles(id) | Owning user |
| shop_name | text | NOT NULL | Display name of shop |
| slug | text | NOT NULL UNIQUE | URL-safe identifier |
| description | text | | Shop bio |
| logo_url | text | | Supabase Storage URL |
| cover_image_url | text | | Supabase Storage URL |
| location | text | | Freetext location (e.g. "Lumley, Freetown") |
| phone | text | | Shop contact phone |
| email | text | | Shop contact email |
| status | text | NOT NULL DEFAULT 'pending', CHECK IN ('pending','active','suspended') | Approval state |
| rating_avg | numeric(3,2) | NOT NULL DEFAULT 0.00, CHECK BETWEEN 0 AND 5 | Computed average |
| rating_count | integer | NOT NULL DEFAULT 0, CHECK >= 0 | Total reviews |
| commission_rate | numeric(5,4) | NOT NULL DEFAULT 0.0500 | Platform commission (5% default) |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| updated_at | timestamptz | NOT NULL DEFAULT now() | |

**Relationships:** One-to-many with `products`, `vendor_orders`.

**RLS Policies:**

| Policy | Role | Operation | Condition |
|---|---|---|---|
| public_read_active | anon/authenticated | SELECT | `status = 'active'` |
| vendor_update_own | vendor | UPDATE | `profile_id = auth.uid()` |
| admin_all | admin | ALL | `role = 'admin'` in JWT |

**Indexes:** PK on `id`, UNIQUE on `profile_id`, UNIQUE on `slug`.

---

### **categories**

**Purpose:** Product taxonomy; supports one level of parent-child nesting.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| name | text | NOT NULL | Display name |
| slug | text | NOT NULL UNIQUE | URL slug |
| description | text | | |
| icon_url | text | | Icon for navigation |
| cover_image_url | text | | Hero image |
| parent_id | uuid | REFERENCES categories(id) ON DELETE SET NULL | Parent category |
| sort_order | integer | DEFAULT 0 | Display ordering |
| is_active | boolean | NOT NULL DEFAULT true | |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| updated_at | timestamptz | NOT NULL DEFAULT now() | |

**Relationships:** Self-referential via `parent_id`. One-to-many with `products`.

**RLS Policies:** Public read for active categories; admin full access.

**Indexes:** PK on `id`, UNIQUE on `slug`, INDEX on `parent_id`.

---

### **products**

**Purpose:** A vendor's listed item with pricing, inventory, and status.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| vendor_id | uuid | NOT NULL REFERENCES vendors(id) ON DELETE CASCADE | Owning vendor |
| category_id | uuid | REFERENCES categories(id) ON DELETE SET NULL | |
| name | text | NOT NULL | |
| slug | text | NOT NULL, UNIQUE(vendor_id, slug) | Vendor-scoped URL slug |
| description | text | | |
| price | numeric(12,2) | NOT NULL CHECK >= 0 | Selling price in SLL |
| compare_at_price | numeric(12,2) | CHECK >= 0 | Original price if on sale |
| cost_price | numeric(12,2) | CHECK >= 0 | Private cost (vendor only) |
| sku | text | | Stock keeping unit |
| stock_quantity | integer | NOT NULL DEFAULT 0 CHECK >= 0 | Available units |
| track_inventory | boolean | NOT NULL DEFAULT true | Deduct stock on order |
| status | text | NOT NULL DEFAULT 'draft', CHECK IN ('draft','active','inactive','flagged') | |
| rating_avg | numeric(3,2) | NOT NULL DEFAULT 0.00 | |
| rating_count | integer | NOT NULL DEFAULT 0 | |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| updated_at | timestamptz | NOT NULL DEFAULT now() | |

**Relationships:** Many-to-one with `vendors`, `categories`. One-to-many with `product_images`, `order_items`, `cart_items`.

**RLS Policies:**

| Policy | Role | Operation | Condition |
|---|---|---|---|
| public_read_active | anon/authenticated | SELECT | `status = 'active'` AND vendor is active |
| vendor_manage_own | vendor | ALL | `vendor_id` = vendor's vendors.id |
| admin_all | admin | ALL | always |

**Indexes:** PK on `id`, UNIQUE on `(vendor_id, slug)`, INDEX on `category_id`, INDEX on `status`.

---

### **product_images**

**Purpose:** Ordered set of images for a product; one is flagged as primary.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| product_id | uuid | NOT NULL REFERENCES products(id) ON DELETE CASCADE | |
| url | text | NOT NULL | Supabase Storage URL |
| alt_text | text | | Accessibility description |
| sort_order | integer | DEFAULT 0 | Display order |
| is_primary | boolean | DEFAULT false | First image shown |
| created_at | timestamptz | NOT NULL DEFAULT now() | |

**Relationships:** Many-to-one with `products`.

**RLS Policies:** Public read; vendor manages own product images; admin full access.

**Indexes:** PK on `id`, INDEX on `product_id`.

---

### **addresses**

**Purpose:** Saved delivery addresses for customers.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| profile_id | uuid | NOT NULL REFERENCES profiles(id) ON DELETE CASCADE | |
| label | text | DEFAULT 'Home' | User-chosen label |
| full_name | text | | Recipient name |
| phone | text | | Recipient phone |
| address_line_1 | text | NOT NULL | Street address |
| address_line_2 | text | | Apt/flat/building |
| city | text | NOT NULL DEFAULT 'Freetown' | |
| district | text | | Sierra Leone district |
| is_default | boolean | DEFAULT false | Default delivery address |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| updated_at | timestamptz | NOT NULL DEFAULT now() | |

**Relationships:** Many-to-one with `profiles`. Referenced by `customer_orders`.

**RLS Policies:** Users read and manage own addresses only. Admin full access.

**Indexes:** PK on `id`, INDEX on `profile_id`.

---

### **carts**

**Purpose:** One active cart per customer. Created lazily on first add-to-cart.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| customer_id | uuid | NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE | |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| updated_at | timestamptz | NOT NULL DEFAULT now() | |

**Relationships:** One-to-one with `profiles`. One-to-many with `cart_items`.

**RLS Policies:** Customer reads and manages own cart only.

**Indexes:** PK on `id`, UNIQUE on `customer_id`.

---

### **cart_items**

**Purpose:** Line items within a customer's cart; price captured at add time (not at checkout — checkout re-validates).

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| cart_id | uuid | NOT NULL REFERENCES carts(id) ON DELETE CASCADE | |
| product_id | uuid | NOT NULL REFERENCES products(id) | |
| vendor_id | uuid | NOT NULL REFERENCES vendors(id) | Denormalised for grouping |
| quantity | integer | NOT NULL CHECK > 0 | |
| unit_price | numeric(12,2) | NOT NULL CHECK >= 0 | Price at time of adding to cart |
| UNIQUE | | (cart_id, product_id) | One line per product per cart |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| updated_at | timestamptz | NOT NULL DEFAULT now() | |

**RLS Policies:** Customer reads and manages own cart items (via cart ownership). Admin full access.

**Indexes:** PK on `id`, UNIQUE on `(cart_id, product_id)`, INDEX on `vendor_id`.

---

### **customer_orders**

**Purpose:** The customer's unified view of an order placed across one or more vendors.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| customer_id | uuid | NOT NULL REFERENCES profiles(id) | |
| status | text | NOT NULL DEFAULT 'pending_payment', CHECK IN ('pending_payment','payment_failed','confirmed','partially_fulfilled','fulfilled','cancelled','refunded') | |
| subtotal | numeric(12,2) | NOT NULL | Sum of item totals |
| delivery_fee | numeric(12,2) | NOT NULL DEFAULT 0 | |
| platform_fee | numeric(12,2) | NOT NULL DEFAULT 0 | Platform commission |
| total | numeric(12,2) | NOT NULL | subtotal + delivery_fee |
| payment_method | text | CHECK IN ('simulated','mobile_money','cash_on_delivery') | |
| payment_status | text | NOT NULL DEFAULT 'pending', CHECK IN ('pending','processing','paid','failed','refunded') | |
| shipping_address_id | uuid | REFERENCES addresses(id) | |
| notes | text | | Customer delivery notes |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| updated_at | timestamptz | NOT NULL DEFAULT now() | |

**Relationships:** One-to-many with `vendor_orders`, `order_items`, `payment_attempts`.

**RLS Policies:** Customer reads own orders; vendors cannot read this table (they use `vendor_orders`); admin full access. No client UPDATE on `payment_status` or `status` — Edge Functions only.

**Indexes:** PK on `id`, INDEX on `customer_id`, INDEX on `status`.

---

### **vendor_orders**

**Purpose:** Each vendor's fulfilment slice of a customer order.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| customer_order_id | uuid | NOT NULL REFERENCES customer_orders(id) | |
| vendor_id | uuid | NOT NULL REFERENCES vendors(id) | |
| customer_id | uuid | NOT NULL REFERENCES profiles(id) | Denormalised for vendor queries |
| status | text | NOT NULL DEFAULT 'pending', CHECK IN ('pending','confirmed','processing','ready_for_pickup','shipped','delivered','cancelled') | Vendor-managed fulfilment status |
| subtotal | numeric(12,2) | NOT NULL | Vendor's portion |
| commission_amount | numeric(12,2) | NOT NULL DEFAULT 0 | Platform fee on this vendor slice |
| vendor_payout | numeric(12,2) | NOT NULL DEFAULT 0 | subtotal - commission_amount |
| fulfillment_notes | text | | Vendor's internal notes |
| shipped_at | timestamptz | | |
| delivered_at | timestamptz | | |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| updated_at | timestamptz | NOT NULL DEFAULT now() | |

**Relationships:** Many-to-one with `customer_orders`, `vendors`. One-to-many with `order_items`.

**RLS Policies:** Vendor reads and updates own vendor_orders (by `vendor_id`). Customer reads own (by `customer_id` via `customer_order_id`). Admin full access.

**Indexes:** PK on `id`, INDEX on `customer_order_id`, INDEX on `vendor_id`.

---

### **order_items**

**Purpose:** Immutable line-item snapshots captured at checkout. Source of truth for what was ordered and at what price.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| customer_order_id | uuid | NOT NULL REFERENCES customer_orders(id) | |
| vendor_order_id | uuid | NOT NULL REFERENCES vendor_orders(id) | |
| product_id | uuid | REFERENCES products(id) ON DELETE SET NULL | Reference only (not price source) |
| vendor_id | uuid | NOT NULL REFERENCES vendors(id) | |
| product_name | text | NOT NULL | Snapshot at order time |
| vendor_name | text | NOT NULL | Snapshot at order time |
| sku | text | | Snapshot at order time |
| unit_price | numeric(12,2) | NOT NULL | Snapshot at order time (SLL) |
| quantity | integer | NOT NULL CHECK > 0 | |
| subtotal | numeric(12,2) | NOT NULL | unit_price * quantity |
| created_at | timestamptz | NOT NULL DEFAULT now() | |

> **No `updated_at`** — these rows are never updated after insert. Any correction requires a refund workflow, not an UPDATE.

**RLS Policies:** Customer reads own (via customer_order_id). Vendor reads own (via vendor_order_id). No UPDATE or DELETE permitted by any client role. Admin read-only.

**Indexes:** PK on `id`, INDEX on `customer_order_id`, INDEX on `vendor_order_id`.

---

### **payment_attempts**

**Purpose:** Audit log of every payment attempt, including failures, for a customer order.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| customer_order_id | uuid | NOT NULL REFERENCES customer_orders(id) | |
| customer_id | uuid | NOT NULL REFERENCES profiles(id) | |
| payment_method | text | NOT NULL | 'simulated', 'mobile_money', etc. |
| amount | numeric(12,2) | NOT NULL | Amount attempted |
| status | text | NOT NULL DEFAULT 'pending', CHECK IN ('pending','processing','succeeded','failed','refunded') | |
| failure_reason | text | | Error message on failure |
| is_simulated | boolean | NOT NULL DEFAULT false | Flags non-real payment |
| gateway_reference | text | | External payment gateway ref |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| updated_at | timestamptz | NOT NULL DEFAULT now() | |

**Relationships:** Many-to-one with `customer_orders`. One-to-one with `transactions` on success.

**RLS Policies:** Customer reads own. No client INSERT — Edge Functions only. Admin full access.

**Indexes:** PK on `id`, INDEX on `customer_order_id`.

---

### **transactions**

**Purpose:** Append-only financial ledger. One row per confirmed money movement. Never updated or deleted.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| payment_attempt_id | uuid | REFERENCES payment_attempts(id) | Originating attempt |
| customer_order_id | uuid | NOT NULL REFERENCES customer_orders(id) | |
| customer_id | uuid | NOT NULL REFERENCES profiles(id) | |
| amount | numeric(12,2) | NOT NULL | Confirmed amount in SLL |
| type | text | NOT NULL CHECK IN ('payment','refund','payout','adjustment') | |
| is_simulated | boolean | NOT NULL DEFAULT false | |
| notes | text | | |
| created_at | timestamptz | NOT NULL DEFAULT now() | |

> **No `updated_at`** — intentional. No UPDATE or DELETE is permitted on this table by any role including admin. Corrections are made by inserting a compensating row (e.g., type='refund').

**RLS Policies:** No SELECT for customers or vendors (financial ledger is internal). Admin read-only. INSERT via Edge Function service role only.

**Indexes:** PK on `id`, INDEX on `customer_order_id`.

---

### **notifications**

**Purpose:** In-app notification feed for all roles.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| recipient_id | uuid | NOT NULL REFERENCES profiles(id) ON DELETE CASCADE | |
| type | text | NOT NULL | 'order_confirmed', 'order_shipped', 'new_order', etc. |
| title | text | NOT NULL | Short notification title |
| body | text | | Full message |
| data | jsonb | | Arbitrary payload (e.g. order_id) |
| is_read | boolean | NOT NULL DEFAULT false | |
| created_at | timestamptz | NOT NULL DEFAULT now() | |

**RLS Policies:** Recipients read and update `is_read` on own notifications. INSERT by Edge Functions only (service role). No client DELETE.

**Indexes:** PK on `id`, INDEX on `recipient_id`, INDEX on `is_read`.

---

### **reviews**

**Purpose:** Customer product reviews, with vendor_id for shop-level aggregation.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| product_id | uuid | NOT NULL REFERENCES products(id) ON DELETE CASCADE | |
| vendor_id | uuid | NOT NULL REFERENCES vendors(id) | Denormalised for shop queries |
| customer_id | uuid | NOT NULL REFERENCES profiles(id) | |
| order_item_id | uuid | REFERENCES order_items(id) | Proof of purchase |
| rating | integer | NOT NULL CHECK BETWEEN 1 AND 5 | |
| title | text | | |
| body | text | | |
| is_verified_purchase | boolean | NOT NULL DEFAULT false | Set by trigger if order_item_id present |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| updated_at | timestamptz | NOT NULL DEFAULT now() | |

**RLS Policies:** Public read. Customer inserts own review. Customer updates own review (within 24 hours — enforced by trigger). Admin full access.

**Indexes:** PK on `id`, INDEX on `product_id`, INDEX on `vendor_id`, INDEX on `customer_id`.

---

### **wishlists**

**Purpose:** Customer's saved products.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| customer_id | uuid | NOT NULL REFERENCES profiles(id) ON DELETE CASCADE | |
| product_id | uuid | NOT NULL REFERENCES products(id) ON DELETE CASCADE | |
| UNIQUE | | (customer_id, product_id) | One entry per product per user |
| created_at | timestamptz | NOT NULL DEFAULT now() | |

**RLS Policies:** Customer manages own wishlist only.

**Indexes:** PK on `id`, UNIQUE on `(customer_id, product_id)`.

---

### **vendor_applications**

**Purpose:** Tracks new vendor sign-up applications through admin review.

| Column | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK DEFAULT gen_random_uuid() | |
| profile_id | uuid | NOT NULL REFERENCES profiles(id) | Applicant |
| shop_name | text | NOT NULL | Proposed shop name |
| description | text | | |
| location | text | | |
| phone | text | | |
| status | text | NOT NULL DEFAULT 'pending', CHECK IN ('pending','approved','rejected') | |
| admin_notes | text | | Admin review notes |
| reviewed_by | uuid | REFERENCES profiles(id) | Admin who reviewed |
| reviewed_at | timestamptz | | |
| created_at | timestamptz | NOT NULL DEFAULT now() | |
| updated_at | timestamptz | NOT NULL DEFAULT now() | |

**RLS Policies:** Applicant reads own application. Admin full access. On approval, Edge Function creates `vendors` row and updates `profiles.role` to 'vendor'.

**Indexes:** PK on `id`, INDEX on `profile_id`, INDEX on `status`.

---

## Key Design Decisions

### Why `numeric(12,2)` not `float` for money

IEEE 754 floating-point arithmetic is inherently imprecise for base-10 decimals. `0.1 + 0.2` in a float column may not equal `0.3`. For a commerce platform, this causes incorrect totals, platform fee rounding errors, and audit discrepancies. `numeric(12,2)` stores exact decimal values up to 10 billion SLL with 2 decimal places — sufficient for Sierra Leonean commerce and precise for arithmetic.

### Why `order_items` are immutable snapshots

Storing `product_name`, `vendor_name`, and `unit_price` as plain columns (not FKs into live product data) ensures that:
1. Historical orders display the correct price even after the vendor changes pricing.
2. Financial records are tamper-proof.
3. Disputes can be resolved against a fixed record.

The `product_id` FK is retained for navigating to the current product page, but it is not the source of the displayed price.

### Why `vendor_orders` split

A single `customer_orders` row cannot expose vendor-specific data to multiple vendors without leaking cross-vendor information. Splitting into `vendor_orders` (one per vendor per order) allows:
- RLS: each vendor's SELECT policy filters by their own `vendor_id`.
- Independent fulfilment state: Vendor A can mark their items as shipped while Vendor B is still processing.
- Accurate platform fee calculation: `commission_amount` is computed per vendor at their `commission_rate`.

### Why `transactions` is append-only

The transactions table is a financial ledger. Allowing UPDATE or DELETE creates the possibility of altering the financial record — a serious integrity and compliance risk. All corrections (e.g., refunds) are recorded as new rows with `type='refund'` that offset the original. RLS enforces this: no UPDATE or DELETE policy exists on `transactions`.

### Why `payment_attempts` are separate from `transactions`

A payment attempt is an *event* (the user tried to pay). A transaction is a *confirmed financial fact* (money moved). These are different things:
- An attempt may fail and produce no transaction.
- Multiple attempts may occur before a successful transaction.
- Recording attempts separately provides a full audit trail of payment behaviour, useful for debugging and fraud analysis.

### Why `profiles.role` is enforced by trigger not just RLS

RLS policies are enforced at query time, but a sufficiently crafted UPDATE statement could attempt to set `role='admin'` on a customer's own row if the UPDATE RLS policy had a subtle flaw. A trigger (`trg_protect_role`) adds a second, independent layer: it fires `BEFORE UPDATE`, inspects `NEW.role` vs `OLD.role`, and raises an exception if the caller is not an admin. Defence in depth.

### Currency

All monetary amounts are stored in **SLL (Sierra Leonean Leone)** as integer-equivalent `numeric(12,2)` values. No denomination conversion is applied in the database. The application layer formats amounts for display (e.g., "Le 45,000"). This eliminates a class of bugs caused by storing amounts in different units and forgetting to convert.
