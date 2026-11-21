-- ============================================================
-- SaloneMarket: Storage Buckets & Strict Storage RLS Policies
-- Migration: 20261120000007_storage_policies.sql
--
-- Buckets:
--   1. 'product-images' — Public read; upload/update/delete restricted
--      strictly to authenticated and APPROVED vendors (status = 'active')
--      within their designated vendor folder (<vendor_id>/ or <profile_id>/).
--   2. 'avatars' — Public read; upload/update/delete restricted
--      strictly to the authenticated user owning the folder (<user_id>/).
-- ============================================================

-- Ensure storage schema extension exists
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── 1. Create or Update Storage Buckets ────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
    (
        'product-images',
        'product-images',
        true,
        10485760, -- 10MB limit per image
        ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
    ),
    (
        'avatars',
        'avatars',
        true,
        5242880,  -- 5MB limit per avatar
        ARRAY['image/jpeg', 'image/png', 'image/webp']
    )
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- storage.objects has RLS enabled by default in Supabase storage extension.
-- Explicit ALTER TABLE fails in migrations because postgres is not table owner (owned by supabase_storage_admin).
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- ── 2. Drop Any Pre-Existing SaloneMarket Storage Policies ────────────────────

DROP POLICY IF EXISTS "product_images_public_read" ON storage.objects;
DROP POLICY IF EXISTS "product_images_vendor_insert" ON storage.objects;
DROP POLICY IF EXISTS "product_images_vendor_update" ON storage.objects;
DROP POLICY IF EXISTS "product_images_vendor_delete" ON storage.objects;

DROP POLICY IF EXISTS "avatars_public_read" ON storage.objects;
DROP POLICY IF EXISTS "avatars_user_insert" ON storage.objects;
DROP POLICY IF EXISTS "avatars_user_update" ON storage.objects;
DROP POLICY IF EXISTS "avatars_user_delete" ON storage.objects;

-- Also drop generic names if previously defined
DROP POLICY IF EXISTS "Public Read Product Images" ON storage.objects;
DROP POLICY IF EXISTS "Vendor Upload Product Images" ON storage.objects;
DROP POLICY IF EXISTS "Public Read Avatars" ON storage.objects;
DROP POLICY IF EXISTS "User Upload Avatar" ON storage.objects;

-- ── 3. Policies: product-images ──────────────────────────────────────────────

-- A. Public Read: Any user (including unauthenticated guests) may view product images.
CREATE POLICY "product_images_public_read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'product-images');

-- B. Vendor Insert: Only authenticated and APPROVED vendors (status = 'active')
--    may upload images, and ONLY into their own designated folder (<vendor_id>/ or <profile_id>/).
--    Unapproved (status = 'pending') or suspended (status = 'suspended') vendors are rejected.
--    Root-level uploads are rejected because (storage.foldername(name))[1] evaluates to NULL.
CREATE POLICY "product_images_vendor_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'product-images'
    AND (
        EXISTS (
            SELECT 1 FROM public.vendors v
            WHERE (
                v.id::text = (storage.foldername(name))[1]
                OR v.profile_id::text = (storage.foldername(name))[1]
            )
            AND v.profile_id = auth.uid()
            AND v.status = 'active'
        )
        OR public.is_admin()
    )
);

-- C. Vendor Update: Only the owning active vendor (or admin) can update/replace an existing image.
--    Vendors cannot overwrite another vendor's image.
CREATE POLICY "product_images_vendor_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'product-images'
    AND (
        EXISTS (
            SELECT 1 FROM public.vendors v
            WHERE (
                v.id::text = (storage.foldername(name))[1]
                OR v.profile_id::text = (storage.foldername(name))[1]
            )
            AND v.profile_id = auth.uid()
            AND v.status = 'active'
        )
        OR public.is_admin()
    )
)
WITH CHECK (
    bucket_id = 'product-images'
    AND (
        EXISTS (
            SELECT 1 FROM public.vendors v
            WHERE (
                v.id::text = (storage.foldername(name))[1]
                OR v.profile_id::text = (storage.foldername(name))[1]
            )
            AND v.profile_id = auth.uid()
            AND v.status = 'active'
        )
        OR public.is_admin()
    )
);

-- D. Vendor Delete: Only the owning active vendor (or admin) can delete an image.
--    Vendors cannot delete another vendor's images.
CREATE POLICY "product_images_vendor_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'product-images'
    AND (
        EXISTS (
            SELECT 1 FROM public.vendors v
            WHERE (
                v.id::text = (storage.foldername(name))[1]
                OR v.profile_id::text = (storage.foldername(name))[1]
            )
            AND v.profile_id = auth.uid()
            AND v.status = 'active'
        )
        OR public.is_admin()
    )
);

-- ── 4. Policies: avatars ─────────────────────────────────────────────────────

-- A. Public Read: Any user may view user profile avatars.
CREATE POLICY "avatars_public_read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- B. User Insert: Users can only upload an avatar into their own designated folder (<user_id>/).
--    Users cannot upload into another user's folder or to the root of the bucket.
CREATE POLICY "avatars_user_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR public.is_admin()
    )
);

-- C. User Update: Users can only overwrite/update an avatar in their own designated folder.
CREATE POLICY "avatars_user_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR public.is_admin()
    )
)
WITH CHECK (
    bucket_id = 'avatars'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR public.is_admin()
    )
);

-- D. User Delete: Users can only delete their own avatar.
CREATE POLICY "avatars_user_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (
        (storage.foldername(name))[1] = auth.uid()::text
        OR public.is_admin()
    )
);
