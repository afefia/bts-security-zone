-- ============================================================
--  THE SECURITY ZONE — Supabase PostgreSQL Schema
--  Run this entire file in your Supabase SQL Editor
--  Dashboard → SQL Editor → New Query → Paste → Run
--
--  FULLY IDEMPOTENT — safe to re-run as many times as needed.
--  Every CREATE uses IF NOT EXISTS or is wrapped in a DO block
--  that silently skips if the object already exists.
--
--  ALSO REQUIRED (cannot be done via SQL):
--  Dashboard → Authentication → Providers → Email
--  → Enable "Confirm email" so users must verify their address
--    before they can sign in. The Flutter app's AuthService
--    already handles the "needs confirmation" state on both
--    sign-up and sign-in — this toggle is what makes Supabase
--    actually enforce it server-side.
--
--  FOR PUSH NOTIFICATIONS (optional, app works without it):
--  1. Deploy the Edge Function in supabase/functions/send-push/
--  2. Run, with your own values:
--       ALTER DATABASE postgres SET app.settings.push_function_url =
--         'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-push';
--       ALTER DATABASE postgres SET app.settings.service_role_key =
--         'YOUR_SERVICE_ROLE_KEY'; -- Settings -> API -> service_role
--  See README.md "Push Notifications" section for full steps.
--
--  FOR PRODUCTION: enable API rate limiting (protects the REST endpoint
--  from direct abuse that bypasses the app's own rate-limit check):
--  Dashboard → Settings → API → Rate Limiting → Enable
--  Recommended starting values: 100 req/min per IP for anon key,
--  300 req/min per IP for authenticated users.
-- ============================================================

-- ── Extensions ───────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── Enums ────────────────────────────────────────────────────
DO $$ BEGIN CREATE TYPE recruit_status AS ENUM ('clear', 'flagged', 'terminated', 'suspended'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE conduct_type   AS ENUM ('commendation', 'warning', 'suspension', 'misconduct', 'termination'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE user_role      AS ENUM ('admin', 'company_user'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE audit_action   AS ENUM ('SEARCH', 'REGISTER', 'ADD_RECORD', 'UPDATE', 'VERIFY', 'LOGIN', 'REJECT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
--  COMPANIES
-- ============================================================
CREATE TABLE IF NOT EXISTS companies (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name            TEXT NOT NULL CHECK (char_length(trim(name)) BETWEEN 2 AND 150),
  license_number  TEXT NOT NULL UNIQUE CHECK (char_length(license_number) BETWEEN 1 AND 40),
  region          TEXT NOT NULL CHECK (char_length(region) BETWEEN 1 AND 60),
  address         TEXT CHECK (address IS NULL OR char_length(address) <= 300),
  email           TEXT NOT NULL UNIQUE CHECK (email ~* '^[^\s@]+@[^\s@]+\.[^\s@]+$' AND char_length(email) <= 254),
  phone           TEXT CHECK (phone IS NULL OR char_length(phone) <= 20),
  is_verified     BOOLEAN NOT NULL DEFAULT FALSE,
  verified_at     TIMESTAMPTZ,
  verified_by     UUID,                  -- references users(id)
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
--  USERS  (one or more users per company)
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  company_id    UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  full_name     TEXT NOT NULL CHECK (char_length(trim(full_name)) BETWEEN 2 AND 120),
  email         TEXT NOT NULL UNIQUE CHECK (email ~* '^[^\s@]+@[^\s@]+\.[^\s@]+$' AND char_length(email) <= 254),
  role          user_role NOT NULL DEFAULT 'company_user',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
--  RECRUITS
-- ============================================================
CREATE TABLE IF NOT EXISTS recruits (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name         TEXT NOT NULL CHECK (char_length(trim(full_name)) BETWEEN 2 AND 120),
  id_number         TEXT NOT NULL UNIQUE CHECK (char_length(id_number) BETWEEN 1 AND 40),       -- National ID
  fingerprint_hash  TEXT,                        -- hashed biometric token
  phone             TEXT CHECK (phone IS NULL OR char_length(phone) <= 20),
  region            TEXT NOT NULL CHECK (char_length(region) BETWEEN 1 AND 60),
  photo_url         TEXT,
  status            recruit_status NOT NULL DEFAULT 'clear',
  registered_by     UUID REFERENCES users(id),
  registered_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast lookup
CREATE INDEX IF NOT EXISTS idx_recruits_id_number        ON recruits(id_number);
CREATE INDEX IF NOT EXISTS idx_recruits_fingerprint_hash ON recruits(fingerprint_hash);
CREATE INDEX IF NOT EXISTS idx_recruits_status           ON recruits(status);

-- ============================================================
--  EMPLOYMENT HISTORY
-- ============================================================
CREATE TABLE IF NOT EXISTS employment_history (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recruit_id    UUID NOT NULL REFERENCES recruits(id) ON DELETE CASCADE,
  company_id    UUID NOT NULL REFERENCES companies(id),
  role          TEXT NOT NULL CHECK (char_length(role) BETWEEN 1 AND 60),
  start_date    DATE NOT NULL,
  end_date      DATE,
  exit_reason   TEXT CHECK (exit_reason IS NULL OR char_length(exit_reason) <= 500),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_employment_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_employment_recruit ON employment_history(recruit_id);
CREATE INDEX IF NOT EXISTS idx_employment_company ON employment_history(company_id);

-- ============================================================
--  CONDUCT RECORDS
-- ============================================================
CREATE TABLE IF NOT EXISTS conduct_records (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recruit_id    UUID NOT NULL REFERENCES recruits(id) ON DELETE CASCADE,
  company_id    UUID NOT NULL REFERENCES companies(id),
  type          conduct_type NOT NULL,
  description   TEXT NOT NULL CHECK (char_length(trim(description)) BETWEEN 10 AND 2000),
  reported_by   TEXT NOT NULL CHECK (char_length(reported_by) BETWEEN 1 AND 120),           -- name/title of reporter
  submitted_by  UUID REFERENCES users(id),
  incident_date DATE NOT NULL CHECK (incident_date <= CURRENT_DATE),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conduct_recruit ON conduct_records(recruit_id);
CREATE INDEX IF NOT EXISTS idx_conduct_company ON conduct_records(company_id);
CREATE INDEX IF NOT EXISTS idx_conduct_type    ON conduct_records(type);

-- ============================================================
--  CONDUCT RECORD DISPUTES
-- ============================================================
DO $$ BEGIN CREATE TYPE dispute_status AS ENUM ('pending', 'upheld', 'rejected'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS conduct_disputes (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conduct_record_id UUID NOT NULL REFERENCES conduct_records(id) ON DELETE CASCADE,
  disputed_by       UUID NOT NULL REFERENCES companies(id),
  submitted_by_user UUID NOT NULL REFERENCES users(id),
  reason            TEXT NOT NULL CHECK (char_length(trim(reason)) BETWEEN 20 AND 2000),
  status            dispute_status NOT NULL DEFAULT 'pending',
  admin_notes       TEXT CHECK (admin_notes IS NULL OR char_length(admin_notes) <= 1000),
  resolved_by       UUID REFERENCES users(id),
  resolved_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (conduct_record_id, disputed_by)
);

CREATE INDEX IF NOT EXISTS idx_disputes_record ON conduct_disputes(conduct_record_id);
CREATE INDEX IF NOT EXISTS idx_disputes_status ON conduct_disputes(status);
CREATE INDEX IF NOT EXISTS idx_disputes_company ON conduct_disputes(disputed_by);

-- ============================================================
--  AUDIT LOGS
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_logs (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id    UUID REFERENCES companies(id),
  user_id       UUID REFERENCES users(id),
  action        audit_action NOT NULL,
  detail        TEXT NOT NULL,
  recruit_id    UUID REFERENCES recruits(id),
  ip_address    TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_company    ON audit_logs(company_id);
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON audit_logs(created_at DESC);

-- ============================================================
--  ALERTS
-- ============================================================
CREATE TABLE IF NOT EXISTS alerts (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id    UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  body          TEXT NOT NULL,
  severity      TEXT NOT NULL CHECK (severity IN ('high','medium','info')),
  is_read       BOOLEAN NOT NULL DEFAULT FALSE,
  recruit_id    UUID REFERENCES recruits(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_alerts_company ON alerts(company_id);
CREATE INDEX IF NOT EXISTS idx_alerts_unread  ON alerts(company_id, is_read) WHERE is_read = FALSE;

-- ============================================================
--  DEVICE TOKENS
-- ============================================================
CREATE TABLE IF NOT EXISTS device_tokens (
  token         TEXT PRIMARY KEY,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  company_id    UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  platform      TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_company ON device_tokens(company_id);

-- ============================================================
--  SEARCH RATE LIMITING
-- ============================================================
CREATE TABLE IF NOT EXISTS search_rate_limits (
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  minute_bucket TIMESTAMPTZ NOT NULL,
  search_count  INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, minute_bucket)
);

CREATE OR REPLACE FUNCTION check_search_rate_limit(p_user_id UUID, p_limit INTEGER DEFAULT 30)
RETURNS BOOLEAN AS $$
DECLARE
  v_bucket TIMESTAMPTZ := date_trunc('minute', NOW());
  v_count INTEGER;
BEGIN
  INSERT INTO search_rate_limits (user_id, minute_bucket, search_count)
  VALUES (p_user_id, v_bucket, 1)
  ON CONFLICT (user_id, minute_bucket)
  DO UPDATE SET search_count = search_rate_limits.search_count + 1
  RETURNING search_count INTO v_count;

  RETURN v_count <= p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION cleanup_search_rate_limits()
RETURNS VOID AS $$
BEGIN
  DELETE FROM search_rate_limits WHERE minute_bucket < NOW() - INTERVAL '10 minutes';
END;
$$ LANGUAGE plpgsql;

-- ============================================================
--  REGISTRATION STORED PROCEDURE (bypasses RLS via SECURITY DEFINER)
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
SECURITY DEFINER  -- runs as owner, bypasses RLS
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_company_id UUID;
BEGIN
  -- Insert the company
  INSERT INTO companies (name, license_number, region, address, email, phone, is_verified)
  VALUES (p_company_name, p_license_number, p_region, p_address, p_email, p_phone, FALSE)
  RETURNING id INTO v_company_id;

  -- Insert the user record
  INSERT INTO users (id, company_id, full_name, email, role)
  VALUES (p_user_id, v_company_id, p_full_name, p_email, 'company_user');

  RETURN v_company_id;
END;
$$;

-- ============================================================
--  AUTO-UPDATE updated_at TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN DROP TRIGGER IF EXISTS trg_recruits_updated_at ON recruits; CREATE TRIGGER trg_recruits_updated_at BEFORE UPDATE ON recruits FOR EACH ROW EXECUTE FUNCTION update_updated_at(); EXCEPTION WHEN undefined_table THEN NULL; END $$;
DO $$ BEGIN DROP TRIGGER IF EXISTS trg_companies_updated_at ON companies; CREATE TRIGGER trg_companies_updated_at BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION update_updated_at(); EXCEPTION WHEN undefined_table THEN NULL; END $$;

-- ============================================================
--  AUTO-FLAG RECRUIT on serious conduct record
-- ============================================================
CREATE OR REPLACE FUNCTION flag_recruit_on_conduct()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.type IN ('termination', 'misconduct') THEN
    UPDATE recruits
    SET status = NEW.type::TEXT::recruit_status,
        updated_at = NOW()
    WHERE id = NEW.recruit_id;

    INSERT INTO alerts (company_id, title, body, severity, recruit_id)
    SELECT c.id,
           'Recruit Status Updated',
           (SELECT full_name FROM recruits WHERE id = NEW.recruit_id)
             || ' has been flagged with a ' || NEW.type || ' record.',
           'high',
           NEW.recruit_id
    FROM companies c
    WHERE c.is_verified = TRUE;
  END IF;

  IF NEW.type = 'suspension' THEN
    UPDATE recruits SET status = 'suspended', updated_at = NOW()
    WHERE id = NEW.recruit_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN DROP TRIGGER IF EXISTS trg_flag_on_conduct ON conduct_records; CREATE TRIGGER trg_flag_on_conduct AFTER INSERT ON conduct_records FOR EACH ROW EXECUTE FUNCTION flag_recruit_on_conduct(); EXCEPTION WHEN undefined_table THEN NULL; END $$;

-- ============================================================
--  PUSH NOTIFICATION DISPATCH (optional — see header comment)
-- ============================================================
DO $$ BEGIN CREATE EXTENSION IF NOT EXISTS pg_net; EXCEPTION WHEN OTHERS THEN NULL; END $$;

CREATE OR REPLACE FUNCTION notify_push_on_alert()
RETURNS TRIGGER AS $$
BEGIN
  BEGIN
    PERFORM net.http_post(
      url := current_setting('app.settings.push_function_url', true),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization',
        'Bearer ' || current_setting('app.settings.service_role_key', true)
      ),
      body := jsonb_build_object('alert_id', NEW.id)
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN DROP TRIGGER IF EXISTS trg_notify_push_on_alert ON alerts; CREATE TRIGGER trg_notify_push_on_alert AFTER INSERT ON alerts FOR EACH ROW EXECUTE FUNCTION notify_push_on_alert(); EXCEPTION WHEN undefined_table THEN NULL; END $$;

-- ============================================================
--  ROLE PERMISSIONS (needed for RLS to function)
-- ============================================================
GRANT USAGE    ON SCHEMA public TO anon;
GRANT SELECT   ON ALL TABLES IN SCHEMA public TO anon;
GRANT INSERT   ON ALL TABLES IN SCHEMA public TO anon;
GRANT UPDATE   ON ALL TABLES IN SCHEMA public TO anon;
GRANT DELETE   ON ALL TABLES IN SCHEMA public TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO authenticated;

-- ============================================================
--  ROW LEVEL SECURITY (RLS)
-- ============================================================
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

-- Helper functions
CREATE OR REPLACE FUNCTION my_company_id()
RETURNS UUID AS $$
  SELECT company_id FROM users WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT role = 'admin' FROM users WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ── Companies ─────────────────────────────────────────────────
DROP POLICY IF EXISTS companies_insert_public ON companies;
CREATE POLICY "companies_insert_public" ON companies FOR INSERT WITH CHECK (TRUE);
DROP POLICY IF EXISTS companies_select_own ON companies;
CREATE POLICY "companies_select_own" ON companies FOR SELECT USING (id = my_company_id() OR is_admin());
DROP POLICY IF EXISTS companies_update_admin ON companies;
CREATE POLICY "companies_update_admin" ON companies FOR UPDATE USING (is_admin());

-- ── Users ─────────────────────────────────────────────────────
-- INSERT policy allows any insert because the FOREIGN KEY
-- constraint (id -> auth.users(id)) already prevents creating
-- fake user records — you can't insert a user row without a
-- matching auth user. This is critical during registration
-- when email confirmation is required and auth.uid() is null.
DROP POLICY IF EXISTS users_select_own ON users;
CREATE POLICY "users_select_own" ON users FOR SELECT USING (id = auth.uid() OR is_admin());
DROP POLICY IF EXISTS users_insert_self ON users;
CREATE POLICY "users_insert_self" ON users FOR INSERT WITH CHECK (TRUE);

-- ── Employment History ────────────────────────────────────────
DROP POLICY IF EXISTS employment_select ON employment_history;
CREATE POLICY "employment_select" ON employment_history FOR SELECT USING (EXISTS (SELECT 1 FROM companies WHERE id = my_company_id() AND is_verified = TRUE) OR is_admin());
DROP POLICY IF EXISTS employment_insert_own ON employment_history;
CREATE POLICY "employment_insert_own" ON employment_history FOR INSERT WITH CHECK (company_id = my_company_id());
DROP POLICY IF EXISTS employment_update_own ON employment_history;
CREATE POLICY "employment_update_own" ON employment_history FOR UPDATE USING (company_id = my_company_id() OR is_admin());

-- ── Conduct Records ───────────────────────────────────────────
DROP POLICY IF EXISTS conduct_select_verified ON conduct_records;
CREATE POLICY "conduct_select_verified" ON conduct_records FOR SELECT USING (EXISTS (SELECT 1 FROM companies WHERE id = my_company_id() AND is_verified = TRUE) OR is_admin());
DROP POLICY IF EXISTS conduct_insert_own ON conduct_records;
CREATE POLICY "conduct_insert_own" ON conduct_records FOR INSERT WITH CHECK (company_id = my_company_id());

-- ── Conduct Disputes ─────────────────────────────────────────────
DROP POLICY IF EXISTS disputes_select_verified ON conduct_disputes;
CREATE POLICY "disputes_select_verified" ON conduct_disputes FOR SELECT USING (EXISTS (SELECT 1 FROM companies WHERE id = my_company_id() AND is_verified = TRUE) OR is_admin());
DROP POLICY IF EXISTS disputes_insert_verified ON conduct_disputes;
CREATE POLICY "disputes_insert_verified" ON conduct_disputes FOR INSERT WITH CHECK (disputed_by = my_company_id() AND EXISTS (SELECT 1 FROM companies WHERE id = my_company_id() AND is_verified = TRUE));
DROP POLICY IF EXISTS disputes_update ON conduct_disputes;
CREATE POLICY "disputes_update" ON conduct_disputes FOR UPDATE USING ((disputed_by = my_company_id() AND status = 'pending') OR is_admin());
DROP POLICY IF EXISTS disputes_delete_own_pending ON conduct_disputes;
CREATE POLICY "disputes_delete_own_pending" ON conduct_disputes FOR DELETE USING (disputed_by = my_company_id() AND status = 'pending');

-- ── Audit Logs ────────────────────────────────────────────────
DROP POLICY IF EXISTS audit_select_own ON audit_logs;
CREATE POLICY "audit_select_own" ON audit_logs FOR SELECT USING (company_id = my_company_id() OR is_admin());
DROP POLICY IF EXISTS audit_insert ON audit_logs;
CREATE POLICY "audit_insert" ON audit_logs FOR INSERT WITH CHECK (company_id = my_company_id() OR (is_admin() AND company_id IS NULL));

-- ── Audit log immutability ────────────────────────────────────
REVOKE UPDATE, DELETE ON audit_logs FROM authenticated;
REVOKE UPDATE, DELETE ON audit_logs FROM service_role;

CREATE OR REPLACE FUNCTION prevent_audit_log_mutation()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION
    'audit_logs is append-only. Modification attempt by user % blocked.',
    current_user
    USING ERRCODE = 'insufficient_privilege';
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_audit_logs_immutable ON audit_logs;
CREATE TRIGGER trg_audit_logs_immutable BEFORE UPDATE OR DELETE ON audit_logs FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_mutation();

-- ── Alerts ────────────────────────────────────────────────────
DROP POLICY IF EXISTS alerts_select_own ON alerts;
CREATE POLICY "alerts_select_own" ON alerts FOR SELECT USING (company_id = my_company_id());
DROP POLICY IF EXISTS alerts_update_own ON alerts;
CREATE POLICY "alerts_update_own" ON alerts FOR UPDATE USING (company_id = my_company_id());
DROP POLICY IF EXISTS alerts_insert ON alerts;
CREATE POLICY "alerts_insert" ON alerts FOR INSERT WITH CHECK (TRUE);

-- ── Device Tokens ─────────────────────────────────────────────
DROP POLICY IF EXISTS device_tokens_insert_own ON device_tokens;
CREATE POLICY "device_tokens_insert_own" ON device_tokens FOR INSERT WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS device_tokens_select_own ON device_tokens;
CREATE POLICY "device_tokens_select_own" ON device_tokens FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS device_tokens_update_own ON device_tokens;
CREATE POLICY "device_tokens_update_own" ON device_tokens FOR UPDATE USING (user_id = auth.uid());
DROP POLICY IF EXISTS device_tokens_delete_own ON device_tokens;
CREATE POLICY "device_tokens_delete_own" ON device_tokens FOR DELETE USING (user_id = auth.uid());

-- ── Search Rate Limits ───────────────────────────────────────
DROP POLICY IF EXISTS search_rate_limits_select_own ON search_rate_limits;
CREATE POLICY "search_rate_limits_select_own" ON search_rate_limits FOR SELECT USING (user_id = auth.uid());

-- ============================================================
--  SEED DATA (optional — skip with ON CONFLICT DO NOTHING)
-- ============================================================
INSERT INTO companies (id, name, license_number, region, email, phone, is_verified, verified_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'Alpha Shield Security',  'PSC-GH-1042', 'Greater Accra', 'info@alphashield.gh',   '+233201234567', TRUE, NOW()),
  ('22222222-2222-2222-2222-222222222222', 'Eagle Eye Protection',   'PSC-GH-2211', 'Ashanti',       'admin@eagleeye.gh',    '+233207654321', TRUE, NOW()),
  ('33333333-3333-3333-3333-333333333333', 'Guardian Force Ltd',     'PSC-GH-3390', 'Western',       'ops@guardianforce.gh', '+233209876543', FALSE, NULL)
ON CONFLICT (id) DO NOTHING;
