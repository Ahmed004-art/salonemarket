-- ============================================================
-- SaloneMarket: Seed Categories
-- Migration: 20261120000005_seed_categories.sql
--
-- Explicit UUIDs so child seeds / FK references are stable.
-- Parent categories inserted first; children follow with parent_id.
-- ============================================================

-- ============================================================
-- TOP-LEVEL CATEGORIES
-- ============================================================
INSERT INTO public.categories (id, name, slug, sort_order, is_active, created_at, updated_at)
VALUES
    -- 1. Electronics & Mobile
    ('a1000000-0000-0000-0000-000000000001',
     'Electronics & Mobile', 'electronics-mobile', 1, true, now(), now()),

    -- 2. Fashion & Clothing
    ('a2000000-0000-0000-0000-000000000001',
     'Fashion & Clothing', 'fashion-clothing', 2, true, now(), now()),

    -- 3. Food & Groceries
    ('a3000000-0000-0000-0000-000000000001',
     'Food & Groceries', 'food-groceries', 3, true, now(), now()),

    -- 4. Home & Living
    ('a4000000-0000-0000-0000-000000000001',
     'Home & Living', 'home-living', 4, true, now(), now()),

    -- 5. Health & Beauty
    ('a5000000-0000-0000-0000-000000000001',
     'Health & Beauty', 'health-beauty', 5, true, now(), now()),

    -- 6. Services
    ('a6000000-0000-0000-0000-000000000001',
     'Services', 'services', 6, true, now(), now())

ON CONFLICT (slug) DO UPDATE
    SET name       = EXCLUDED.name,
        sort_order = EXCLUDED.sort_order,
        is_active  = EXCLUDED.is_active,
        updated_at = now();

-- ============================================================
-- CHILDREN: Electronics & Mobile
-- ============================================================
INSERT INTO public.categories (id, name, slug, parent_id, sort_order, is_active, created_at, updated_at)
VALUES
    ('a1000000-0000-0000-0000-000000000011',
     'Phones & Accessories', 'phones-accessories',
     'a1000000-0000-0000-0000-000000000001', 1, true, now(), now()),

    ('a1000000-0000-0000-0000-000000000012',
     'Computers & Tablets', 'computers-tablets',
     'a1000000-0000-0000-0000-000000000001', 2, true, now(), now())

ON CONFLICT (slug) DO UPDATE
    SET name       = EXCLUDED.name,
        parent_id  = EXCLUDED.parent_id,
        sort_order = EXCLUDED.sort_order,
        is_active  = EXCLUDED.is_active,
        updated_at = now();

-- ============================================================
-- CHILDREN: Fashion & Clothing
-- ============================================================
INSERT INTO public.categories (id, name, slug, parent_id, sort_order, is_active, created_at, updated_at)
VALUES
    ('a2000000-0000-0000-0000-000000000011',
     'Men''s Wear', 'mens-wear',
     'a2000000-0000-0000-0000-000000000001', 1, true, now(), now()),

    ('a2000000-0000-0000-0000-000000000012',
     'Women''s Wear', 'womens-wear',
     'a2000000-0000-0000-0000-000000000001', 2, true, now(), now()),

    ('a2000000-0000-0000-0000-000000000013',
     'Children''s Clothing', 'childrens-clothing',
     'a2000000-0000-0000-0000-000000000001', 3, true, now(), now()),

    ('a2000000-0000-0000-0000-000000000014',
     'Shoes & Accessories', 'shoes-accessories',
     'a2000000-0000-0000-0000-000000000001', 4, true, now(), now())

ON CONFLICT (slug) DO UPDATE
    SET name       = EXCLUDED.name,
        parent_id  = EXCLUDED.parent_id,
        sort_order = EXCLUDED.sort_order,
        is_active  = EXCLUDED.is_active,
        updated_at = now();

-- ============================================================
-- CHILDREN: Food & Groceries
-- ============================================================
INSERT INTO public.categories (id, name, slug, parent_id, sort_order, is_active, created_at, updated_at)
VALUES
    ('a3000000-0000-0000-0000-000000000011',
     'Fresh Produce', 'fresh-produce',
     'a3000000-0000-0000-0000-000000000001', 1, true, now(), now()),

    ('a3000000-0000-0000-0000-000000000012',
     'Packaged Foods', 'packaged-foods',
     'a3000000-0000-0000-0000-000000000001', 2, true, now(), now()),

    ('a3000000-0000-0000-0000-000000000013',
     'Beverages', 'beverages',
     'a3000000-0000-0000-0000-000000000001', 3, true, now(), now())

ON CONFLICT (slug) DO UPDATE
    SET name       = EXCLUDED.name,
        parent_id  = EXCLUDED.parent_id,
        sort_order = EXCLUDED.sort_order,
        is_active  = EXCLUDED.is_active,
        updated_at = now();

-- ============================================================
-- CHILDREN: Home & Living
-- ============================================================
INSERT INTO public.categories (id, name, slug, parent_id, sort_order, is_active, created_at, updated_at)
VALUES
    ('a4000000-0000-0000-0000-000000000011',
     'Furniture', 'furniture',
     'a4000000-0000-0000-0000-000000000001', 1, true, now(), now()),

    ('a4000000-0000-0000-0000-000000000012',
     'Kitchen & Dining', 'kitchen-dining',
     'a4000000-0000-0000-0000-000000000001', 2, true, now(), now()),

    ('a4000000-0000-0000-0000-000000000013',
     'Bedding & Bath', 'bedding-bath',
     'a4000000-0000-0000-0000-000000000001', 3, true, now(), now())

ON CONFLICT (slug) DO UPDATE
    SET name       = EXCLUDED.name,
        parent_id  = EXCLUDED.parent_id,
        sort_order = EXCLUDED.sort_order,
        is_active  = EXCLUDED.is_active,
        updated_at = now();

-- ============================================================
-- CHILDREN: Health & Beauty
-- ============================================================
INSERT INTO public.categories (id, name, slug, parent_id, sort_order, is_active, created_at, updated_at)
VALUES
    ('a5000000-0000-0000-0000-000000000011',
     'Skincare', 'skincare',
     'a5000000-0000-0000-0000-000000000001', 1, true, now(), now()),

    ('a5000000-0000-0000-0000-000000000012',
     'Hair Care', 'hair-care',
     'a5000000-0000-0000-0000-000000000001', 2, true, now(), now()),

    ('a5000000-0000-0000-0000-000000000013',
     'Vitamins & Supplements', 'vitamins-supplements',
     'a5000000-0000-0000-0000-000000000001', 3, true, now(), now())

ON CONFLICT (slug) DO UPDATE
    SET name       = EXCLUDED.name,
        parent_id  = EXCLUDED.parent_id,
        sort_order = EXCLUDED.sort_order,
        is_active  = EXCLUDED.is_active,
        updated_at = now();

-- ============================================================
-- CHILDREN: Services
-- ============================================================
INSERT INTO public.categories (id, name, slug, parent_id, sort_order, is_active, created_at, updated_at)
VALUES
    ('a6000000-0000-0000-0000-000000000011',
     'Tailoring & Alterations', 'tailoring-alterations',
     'a6000000-0000-0000-0000-000000000001', 1, true, now(), now()),

    ('a6000000-0000-0000-0000-000000000012',
     'Repairs & Maintenance', 'repairs-maintenance',
     'a6000000-0000-0000-0000-000000000001', 2, true, now(), now()),

    ('a6000000-0000-0000-0000-000000000013',
     'Professional Services', 'professional-services',
     'a6000000-0000-0000-0000-000000000001', 3, true, now(), now())

ON CONFLICT (slug) DO UPDATE
    SET name       = EXCLUDED.name,
        parent_id  = EXCLUDED.parent_id,
        sort_order = EXCLUDED.sort_order,
        is_active  = EXCLUDED.is_active,
        updated_at = now();

-- ============================================================
-- Summary: 6 parent categories, 20 child categories = 26 total
-- UUID scheme: aX000000-0000-0000-0000-00000000000Y
--   X = parent index (1–6), Y = child index (1-based)
--   Parent UUIDs: aX000000-0000-0000-0000-000000000001
--   Child UUIDs:  aX000000-0000-0000-0000-00000000001Y
-- ============================================================
