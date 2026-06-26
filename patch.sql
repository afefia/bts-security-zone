-- ============================================================
--  PATCH — Run this AFTER your working supabase_schema.sql
--  Adds GRANTs, stored procedures, roles, and storage.
--  Safe to re-run multiple times (all CREATE OR REPLACE).
-- ============================================================

-- 0. Add new user roles (if running schema that uses separate types)
DO $$ BEGIN
  ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'company_admin';
  ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'company_viewer';
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Also update the register_company function to set the first user
-- as company_admin instead of company_user
CREATE OR REPLACE FUNCTION register_company(
  p_company_name    TEXT,
  p_license_number  TEXT,
  p_region          TEXT,
  p_address         TEXT,
  p_email           TEXT,
  p_phone           TEXT,
  p_user_id         UUID,
  p_full_name       TEXT
)
RETURNS UUID
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_company_id UUID;
BEGIN
  INSERT INTO companies (name, license_number, region, address, email, phone, is_verified)
  VALUES (p_company_name, p_license_number, p_region, p_address, p_email, p_phone, FALSE)
  RETURNING id INTO v_company_id;

  INSERT INTO users (id, company_id, full_name, email, role)
  VALUES (p_user_id, v_company_id, p_full_name, p_email, 'company_admin');

  RETURN v_company_id;
END;
$$;

-- 0b. Create storage bucket for photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('photos', 'photos', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Allow public access to read photos
CREATE POLICY "photos_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'photos');

-- Allow authenticated users to upload photos
CREATE POLICY "photos_authenticated_insert" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'photos' AND auth.role() = 'authenticated');

-- 1. GRANT table permissions to anon role (needed for RLS to work)
GRANT USAGE    ON SCHEMA public TO anon;
GRANT SELECT   ON ALL TABLES IN SCHEMA public TO anon;
GRANT INSERT   ON ALL TABLES IN SCHEMA public TO anon;
GRANT UPDATE   ON ALL TABLES IN SCHEMA public TO anon;
GRANT DELETE   ON ALL TABLES IN SCHEMA public TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO authenticated;

-- 2. Registration stored procedure (called by the app after auth.signUp())
CREATE OR REPLACE FUNCTION register_company(
  p_company_name    TEXT,
  p_license_number  TEXT,
  p_region          TEXT,
  p_address         TEXT,
  p_email           TEXT,
  p_phone           TEXT,
  p_user_id         UUID,
  p_full_name       TEXT
)
RETURNS UUID
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_company_id UUID;
BEGIN
  INSERT INTO companies (name, license_number, region, address, email, phone, is_verified)
  VALUES (p_company_name, p_license_number, p_region, p_address, p_email, p_phone, FALSE)
  RETURNING id INTO v_company_id;

  INSERT INTO users (id, company_id, full_name, email, role)
  VALUES (p_user_id, v_company_id, p_full_name, p_email, 'company_user');

  RETURN v_company_id;
END;
$$;

-- 3. Admin stored procedures
CREATE OR REPLACE FUNCTION admin_get_all_companies()
RETURNS JSONB
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(c)::jsonb ORDER BY c.name)
  FROM (SELECT * FROM companies) c INTO v_result;
  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION admin_verify_company(p_company_id UUID)
RETURNS VOID
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE companies
  SET is_verified = TRUE, verified_at = NOW(), verified_by = auth.uid()
  WHERE id = p_company_id;
END;
$$;

CREATE OR REPLACE FUNCTION admin_reject_company(p_company_id UUID)
RETURNS VOID
SECURITY DEFINER SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM companies WHERE id = p_company_id;
END;
$$;
