-- ============================================================
--  THE SECURITY ZONE — COMPLETE FIX
--  Run this in Supabase SQL Editor (Dashboard → SQL Editor)
--  Paste entire file, click RUN. Safe to re-run.
-- ============================================================

-- 0. Grant table-level permissions to anon role
--    RLS policies can only restrict access that was already granted.
--    Without these explicit GRANTs, RLS has nothing to enforce.
GRANT USAGE    ON SCHEMA public TO anon;
GRANT SELECT   ON ALL TABLES IN SCHEMA public TO anon;
GRANT INSERT   ON ALL TABLES IN SCHEMA public TO anon;
GRANT UPDATE   ON ALL TABLES IN SCHEMA public TO anon;
GRANT DELETE   ON ALL TABLES IN SCHEMA public TO anon;
-- Ensure future tables also get these grants
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO authenticated;

-- 1. Helper functions
CREATE OR REPLACE FUNCTION my_company_id()
RETURNS UUID AS $$
  SELECT company_id FROM users WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT role = 'admin' FROM users WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 2. Ensure RLS is enabled
ALTER TABLE IF EXISTS companies        ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS recruits         ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS employment_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS conduct_records  ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS conduct_disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS audit_logs       ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS alerts           ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS device_tokens    ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS search_rate_limits ENABLE ROW LEVEL SECURITY;

-- 3. Drop + recreate all policies
-- ── Companies ──
DROP POLICY IF EXISTS companies_insert_public ON companies;
CREATE POLICY "companies_insert_public" ON companies FOR INSERT WITH CHECK (TRUE);
DROP POLICY IF EXISTS companies_select_own ON companies;
CREATE POLICY "companies_select_own" ON companies FOR SELECT USING (id = my_company_id() OR is_admin());
DROP POLICY IF EXISTS companies_update_admin ON companies;
CREATE POLICY "companies_update_admin" ON companies FOR UPDATE USING (is_admin());

-- ── Users ──
DROP POLICY IF EXISTS users_select_own ON users;
CREATE POLICY "users_select_own" ON users FOR SELECT USING (id = auth.uid() OR is_admin());
DROP POLICY IF EXISTS users_insert_self ON users;
CREATE POLICY "users_insert_self" ON users FOR INSERT WITH CHECK (TRUE);

-- ── Employment History ──
DROP POLICY IF EXISTS employment_select ON employment_history;
CREATE POLICY "employment_select" ON employment_history FOR SELECT USING (EXISTS (SELECT 1 FROM companies WHERE id = my_company_id() AND is_verified = TRUE) OR is_admin());
DROP POLICY IF EXISTS employment_insert_own ON employment_history;
CREATE POLICY "employment_insert_own" ON employment_history FOR INSERT WITH CHECK (company_id = my_company_id());
DROP POLICY IF EXISTS employment_update_own ON employment_history;
CREATE POLICY "employment_update_own" ON employment_history FOR UPDATE USING (company_id = my_company_id() OR is_admin());

-- ── Conduct Records ──
DROP POLICY IF EXISTS conduct_select_verified ON conduct_records;
CREATE POLICY "conduct_select_verified" ON conduct_records FOR SELECT USING (EXISTS (SELECT 1 FROM companies WHERE id = my_company_id() AND is_verified = TRUE) OR is_admin());
DROP POLICY IF EXISTS conduct_insert_own ON conduct_records;
CREATE POLICY "conduct_insert_own" ON conduct_records FOR INSERT WITH CHECK (company_id = my_company_id());

-- ── Conduct Disputes ──
DROP POLICY IF EXISTS disputes_select_verified ON conduct_disputes;
CREATE POLICY "disputes_select_verified" ON conduct_disputes FOR SELECT USING (EXISTS (SELECT 1 FROM companies WHERE id = my_company_id() AND is_verified = TRUE) OR is_admin());
DROP POLICY IF EXISTS disputes_insert_verified ON conduct_disputes;
CREATE POLICY "disputes_insert_verified" ON conduct_disputes FOR INSERT WITH CHECK (disputed_by = my_company_id() AND EXISTS (SELECT 1 FROM companies WHERE id = my_company_id() AND is_verified = TRUE));
DROP POLICY IF EXISTS disputes_update ON conduct_disputes;
CREATE POLICY "disputes_update" ON conduct_disputes FOR UPDATE USING ((disputed_by = my_company_id() AND status = 'pending') OR is_admin());
DROP POLICY IF EXISTS disputes_delete_own_pending ON conduct_disputes;
CREATE POLICY "disputes_delete_own_pending" ON conduct_disputes FOR DELETE USING (disputed_by = my_company_id() AND status = 'pending');

-- ── Audit Logs ──
DROP POLICY IF EXISTS audit_select_own ON audit_logs;
CREATE POLICY "audit_select_own" ON audit_logs FOR SELECT USING (company_id = my_company_id() OR is_admin());
DROP POLICY IF EXISTS audit_insert ON audit_logs;
CREATE POLICY "audit_insert" ON audit_logs FOR INSERT WITH CHECK (company_id = my_company_id() OR (is_admin() AND company_id IS NULL));

-- ── Alerts ──
DROP POLICY IF EXISTS alerts_select_own ON alerts;
CREATE POLICY "alerts_select_own" ON alerts FOR SELECT USING (company_id = my_company_id());
DROP POLICY IF EXISTS alerts_update_own ON alerts;
CREATE POLICY "alerts_update_own" ON alerts FOR UPDATE USING (company_id = my_company_id());
DROP POLICY IF EXISTS alerts_insert ON alerts;
CREATE POLICY "alerts_insert" ON alerts FOR INSERT WITH CHECK (TRUE);

-- ── Device Tokens ──
DROP POLICY IF EXISTS device_tokens_insert_own ON device_tokens;
CREATE POLICY "device_tokens_insert_own" ON device_tokens FOR INSERT WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS device_tokens_select_own ON device_tokens;
CREATE POLICY "device_tokens_select_own" ON device_tokens FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS device_tokens_update_own ON device_tokens;
CREATE POLICY "device_tokens_update_own" ON device_tokens FOR UPDATE USING (user_id = auth.uid());
DROP POLICY IF EXISTS device_tokens_delete_own ON device_tokens;
CREATE POLICY "device_tokens_delete_own" ON device_tokens FOR DELETE USING (user_id = auth.uid());

-- ── Search Rate Limits ──
DROP POLICY IF EXISTS search_rate_limits_select_own ON search_rate_limits;
CREATE POLICY "search_rate_limits_select_own" ON search_rate_limits FOR SELECT USING (user_id = auth.uid());

-- ============================================================
--  4. REGISTRATION STORED PROCEDURE (backup — bypasses RLS)
-- ============================================================
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
SECURITY DEFINER
SET search_path = public
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

