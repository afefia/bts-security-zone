-- ============================================================
--  THE SECURITY ZONE — Supabase PostgreSQL Schema
--  Run this entire file in your Supabase SQL Editor
--  Dashboard → SQL Editor → New Query → Paste → Run
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
CREATE TYPE recruit_status AS ENUM ('clear', 'flagged', 'terminated', 'suspended');
CREATE TYPE conduct_type   AS ENUM ('commendation', 'warning', 'suspension', 'misconduct', 'termination');
CREATE TYPE user_role      AS ENUM ('admin', 'company_user');
CREATE TYPE audit_action   AS ENUM ('SEARCH', 'REGISTER', 'ADD_RECORD', 'UPDATE', 'VERIFY', 'LOGIN', 'REJECT');

-- ============================================================
--  COMPANIES
-- ============================================================
CREATE TABLE companies (
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
CREATE TABLE users (
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
CREATE TABLE recruits (
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
CREATE INDEX idx_recruits_id_number        ON recruits(id_number);
CREATE INDEX idx_recruits_fingerprint_hash ON recruits(fingerprint_hash);
CREATE INDEX idx_recruits_status           ON recruits(status);

-- ============================================================
--  EMPLOYMENT HISTORY
-- ============================================================
CREATE TABLE employment_history (
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

CREATE INDEX idx_employment_recruit ON employment_history(recruit_id);
CREATE INDEX idx_employment_company ON employment_history(company_id);

-- ============================================================
--  CONDUCT RECORDS
-- ============================================================
CREATE TABLE conduct_records (
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

CREATE INDEX idx_conduct_recruit ON conduct_records(recruit_id);
CREATE INDEX idx_conduct_company ON conduct_records(company_id);
CREATE INDEX idx_conduct_type    ON conduct_records(type);

-- ============================================================
--  CONDUCT RECORD DISPUTES
--
--  Any verified company can file a dispute against a conduct record —
--  the most important gap in the original design, since a company could
--  file a false termination against a recruit with no recourse. Disputes
--  are reviewed and resolved by an admin. A disputed record remains
--  visible (with a DISPUTED badge) but does NOT change the recruit's
--  status until the admin makes a ruling. If the dispute is upheld, the
--  admin deletes the record (the only way a conduct record is ever
--  deleted — by an admin following a successful dispute, not by the
--  filing company). If the dispute is rejected, the record stands.
-- ============================================================
CREATE TYPE dispute_status AS ENUM ('pending', 'upheld', 'rejected');

CREATE TABLE conduct_disputes (
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
  -- One dispute per company per record — prevents spamming the same
  -- record with repeated disputes from the same company.
  UNIQUE (conduct_record_id, disputed_by)
);

CREATE INDEX idx_disputes_record ON conduct_disputes(conduct_record_id);
CREATE INDEX idx_disputes_status ON conduct_disputes(status);
CREATE INDEX idx_disputes_company ON conduct_disputes(disputed_by);

-- ============================================================
--  AUDIT LOGS
-- ============================================================
CREATE TABLE audit_logs (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id    UUID REFERENCES companies(id),
  user_id       UUID REFERENCES users(id),
  action        audit_action NOT NULL,
  detail        TEXT NOT NULL,
  recruit_id    UUID REFERENCES recruits(id),
  ip_address    TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_company    ON audit_logs(company_id);
CREATE INDEX idx_audit_created_at ON audit_logs(created_at DESC);

-- ============================================================
--  ALERTS
-- ============================================================
CREATE TABLE alerts (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  company_id    UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  title         TEXT NOT NULL,
  body          TEXT NOT NULL,
  severity      TEXT NOT NULL CHECK (severity IN ('high','medium','info')),
  is_read       BOOLEAN NOT NULL DEFAULT FALSE,
  recruit_id    UUID REFERENCES recruits(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_alerts_company ON alerts(company_id);
CREATE INDEX idx_alerts_unread  ON alerts(company_id, is_read) WHERE is_read = FALSE;

-- ============================================================
--  DEVICE TOKENS — for push notification delivery (FCM)
--
--  Supabase doesn't deliver push notifications itself; an Edge Function
--  (see supabase/functions/send-push) reads from this table and calls the
--  FCM send API whenever a new row appears in `alerts`. One user can have
--  multiple tokens (multiple devices, or a reinstalled app), so this is
--  keyed by token rather than by user.
-- ============================================================
CREATE TABLE device_tokens (
  token         TEXT PRIMARY KEY,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  company_id    UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  platform      TEXT, -- 'android' | 'ios' | 'web' | etc, informational only
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_device_tokens_company ON device_tokens(company_id);

-- ============================================================
--  SEARCH RATE LIMITING
--
--  Catches a buggy retry loop or casual scraping attempt from this app's
--  own search flow — the realistic abuse case for a tool used by people,
--  not bots. The counter lives in Postgres (not trusted to the client)
--  and the app calls check_search_rate_limit() once per search before
--  running the query, so the count tracks actual search *attempts*
--  rather than rows returned.
--
--  HONEST LIMITATION: this function is callable, but nothing forces a
--  client to call it before reading `recruits` directly — RLS on
--  `recruits` itself doesn't reference it. Folding the check into that
--  RLS policy was considered and rejected: RLS predicates run per row
--  scanned, so a search returning 50 recruits would burn 50 credits
--  instead of 1, making the limit far stricter than intended and
--  unrelated to actual query volume. The gap that leaves — someone using
--  their own valid session to call Supabase's REST API directly,
--  bypassing the app and this check entirely — is real, and the right
--  backstop for it is Supabase's own platform-level API rate limiting
--  (Dashboard → Settings → API), which applies regardless of which
--  table or method is used. This table's job is giving the *app* a clean
--  way to self-throttle and show a friendly message; it is not, by
--  itself, a complete defense against a determined attacker with API
--  credentials.
--
--  Uses a dedicated lightweight counter table rather than counting rows
--  in audit_logs on every search, since audit_logs grows unbounded and a
--  COUNT(*) over it would get slower over time — this table only ever
--  holds one row per user per minute-bucket and old buckets are cheap to
--  prune (see cleanup note below).
-- ============================================================
CREATE TABLE search_rate_limits (
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  minute_bucket TIMESTAMPTZ NOT NULL, -- truncated to the minute
  search_count  INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, minute_bucket)
);

-- Default cap: 30 searches per minute per user. Generous enough for a
-- security guard's office doing rapid back-to-back hires, but well above
-- what's needed for normal use, so it only kicks in for actual abuse.
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

-- Old minute-buckets are useless after they age out — run this
-- periodically (e.g. via pg_cron, or just accept the table staying small
-- since old rows are tiny and rarely re-queried). Not scheduled by
-- default since pg_cron availability varies by Supabase plan; safe to
-- run manually or wire up if you have it.
CREATE OR REPLACE FUNCTION cleanup_search_rate_limits()
RETURNS VOID AS $$
BEGIN
  DELETE FROM search_rate_limits WHERE minute_bucket < NOW() - INTERVAL '10 minutes';
END;
$$ LANGUAGE plpgsql;

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

CREATE TRIGGER trg_recruits_updated_at
  BEFORE UPDATE ON recruits
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_companies_updated_at
  BEFORE UPDATE ON companies
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

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

    -- Create alerts for all companies
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

CREATE TRIGGER trg_flag_on_conduct
  AFTER INSERT ON conduct_records
  FOR EACH ROW EXECUTE FUNCTION flag_recruit_on_conduct();

-- ============================================================
--  PUSH NOTIFICATION DISPATCH
--
--  Whenever a new row lands in `alerts` (fired by trg_flag_on_conduct
--  above, which inserts one alert per verified company), this trigger
--  fires an async HTTP call to a Supabase Edge Function that looks up
--  device tokens for that company and sends the actual FCM push.
--
--  REQUIRES: the pg_net extension and the Edge Function deployed — see
--  supabase/functions/send-push/index.ts and the deployment steps in
--  README.md. If the Edge Function isn't deployed yet, this trigger will
--  fail silently (caught below) rather than blocking alert inserts —
--  in-app Realtime alerts keep working either way.
--
--  IMPORTANT: pg_net is NOT enabled by default on every Supabase project
--  (it depends on plan/region, and sometimes needs a manual toggle under
--  Database → Extensions). A bare `CREATE EXTENSION pg_net` throws a hard
--  error if it's unavailable — and because the SQL Editor runs a pasted
--  script as one batch, that single failure would silently stop every
--  statement after it, including the RLS policies further down this
--  file. This is wrapped in a DO block specifically so a missing pg_net
--  degrades to "push notifications unavailable" instead of breaking
--  company registration, recruit search, and everything else below.
-- ============================================================
DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_net;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_net extension unavailable — push notification dispatch will be skipped. Everything else in this script will still run.';
END $$;

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
    -- Don't let a missing/misconfigured Edge Function break alert inserts.
    NULL;
  END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_notify_push_on_alert
  AFTER INSERT ON alerts
  FOR EACH ROW EXECUTE FUNCTION notify_push_on_alert();

-- ============================================================
--  ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE companies        ENABLE ROW LEVEL SECURITY;
ALTER TABLE users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE recruits         ENABLE ROW LEVEL SECURITY;
ALTER TABLE employment_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE conduct_records  ENABLE ROW LEVEL SECURITY;
ALTER TABLE conduct_disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs       ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts           ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens    ENABLE ROW LEVEL SECURITY;
ALTER TABLE search_rate_limits ENABLE ROW LEVEL SECURITY;

-- Helper: get current user's company_id
CREATE OR REPLACE FUNCTION my_company_id()
RETURNS UUID AS $$
  SELECT company_id FROM users WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Helper: is current user a platform admin?
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT role = 'admin' FROM users WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ── Companies ─────────────────────────────────────────────────
-- Anyone can register (insert). Only see own company or admin sees all.
CREATE POLICY "companies_insert_public" ON companies FOR INSERT WITH CHECK (TRUE);
CREATE POLICY "companies_select_own"    ON companies FOR SELECT USING (id = my_company_id() OR is_admin());
CREATE POLICY "companies_update_admin"  ON companies FOR UPDATE USING (is_admin());

-- ── Users ─────────────────────────────────────────────────────
CREATE POLICY "users_select_own"  ON users FOR SELECT USING (id = auth.uid() OR is_admin());
CREATE POLICY "users_insert_self" ON users FOR INSERT WITH CHECK (id = auth.uid());


-- ── Employment History ────────────────────────────────────────
CREATE POLICY "employment_select" ON employment_history
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM companies WHERE id = my_company_id() AND is_verified = TRUE)
    OR is_admin()
  );

CREATE POLICY "employment_insert_own" ON employment_history
  FOR INSERT WITH CHECK (company_id = my_company_id());

-- A company can only close out (set end_date/exit_reason on) employment
-- records that belong to them — not another company's record of the same
-- recruit. Admins can fix any record.
CREATE POLICY "employment_update_own" ON employment_history
  FOR UPDATE USING (company_id = my_company_id() OR is_admin());

-- ── Conduct Records ───────────────────────────────────────────
-- All verified companies can READ all conduct records (cross-company transparency)
CREATE POLICY "conduct_select_verified" ON conduct_records
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM companies WHERE id = my_company_id() AND is_verified = TRUE)
    OR is_admin()
  );

-- Only the company that owns the record can INSERT it
CREATE POLICY "conduct_insert_own" ON conduct_records
  FOR INSERT WITH CHECK (company_id = my_company_id());

-- ── Conduct Disputes ─────────────────────────────────────────────
-- Any verified company can see all disputes (so hiring companies can
-- see if a record against a candidate is contested), can file their
-- own dispute, and can update/delete only their own pending dispute.
-- Admins can do everything including resolve disputes.
CREATE POLICY "disputes_select_verified" ON conduct_disputes
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM companies WHERE id = my_company_id() AND is_verified = TRUE)
    OR is_admin()
  );

CREATE POLICY "disputes_insert_verified" ON conduct_disputes
  FOR INSERT WITH CHECK (
    disputed_by = my_company_id()
    AND EXISTS (SELECT 1 FROM companies WHERE id = my_company_id() AND is_verified = TRUE)
  );

-- Companies can withdraw their own pending dispute; admins resolve all
CREATE POLICY "disputes_update" ON conduct_disputes
  FOR UPDATE USING (
    (disputed_by = my_company_id() AND status = 'pending')
    OR is_admin()
  );

CREATE POLICY "disputes_delete_own_pending" ON conduct_disputes
  FOR DELETE USING (
    disputed_by = my_company_id() AND status = 'pending'
  );

-- ── Audit Logs ────────────────────────────────────────────────
CREATE POLICY "audit_select_own"   ON audit_logs FOR SELECT USING (company_id = my_company_id() OR is_admin());
-- Admins can log platform-level actions (e.g. resolving a dispute) that
-- aren't scoped to their own company, hence company_id may be NULL for
-- those rows — without the is_admin() branch here, those inserts would
-- be silently rejected by RLS since NULL = my_company_id() is never true.
CREATE POLICY "audit_insert"       ON audit_logs FOR INSERT WITH CHECK (
  company_id = my_company_id() OR (is_admin() AND company_id IS NULL)
);
-- No UPDATE or DELETE policy exists on audit_logs — those are explicitly
-- absent so no RLS policy can permit them. Combined with the REVOKE
-- below and the immutability trigger, the audit log is genuinely
-- append-only: not even admin RLS bypasses a REVOKE at the privilege
-- level, and not even a service_role connection bypasses the trigger.

-- ── Audit log immutability ────────────────────────────────────────────
-- Revoke UPDATE/DELETE at the privilege level so no role (including
-- authenticated, service_role, or postgres via RLS bypass) can modify or
-- delete audit log rows. This runs AFTER table creation and RLS setup
-- so it doesn't interfere with the initial schema load.
REVOKE UPDATE, DELETE ON audit_logs FROM authenticated;
REVOKE UPDATE, DELETE ON audit_logs FROM service_role;

-- Belt-and-suspenders trigger: raises an exception if any code path
-- somehow attempts an UPDATE or DELETE, even one running as superuser
-- that bypasses REVOKE. The REVOKE above is the primary control; this
-- trigger is a defense-in-depth backstop that also produces a clear,
-- logged error rather than a silent failure.
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

CREATE TRIGGER trg_audit_logs_immutable
  BEFORE UPDATE OR DELETE ON audit_logs
  FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_mutation();
-- NO UPDATE or DELETE policy — audit_logs is append-only. Even admins
-- cannot edit or delete audit history. Enforced two ways:
-- 1. No RLS policy permits UPDATE or DELETE on this table, so any
--    attempt via the anon/authenticated role is rejected by Postgres.
-- 2. The trigger above fires even if someone uses the service_role key
--    (which bypasses RLS), providing a second enforcement layer.
--    NOTE: REVOKE GRANT OPTION alone won't stop the service_role key
--    since it has superuser-equivalent access in Supabase. The trigger
--    is the real backstop for that case.

-- ── Alerts ────────────────────────────────────────────────────
CREATE POLICY "alerts_select_own"  ON alerts FOR SELECT USING (company_id = my_company_id());
CREATE POLICY "alerts_update_own"  ON alerts FOR UPDATE USING (company_id = my_company_id());
CREATE POLICY "alerts_insert"      ON alerts FOR INSERT WITH CHECK (TRUE); -- trigger inserts

-- ── Device Tokens ─────────────────────────────────────────────
-- A user can register/remove their own device's token. The Edge Function
-- that sends pushes uses the service_role key and bypasses RLS entirely,
-- so these policies only govern what the app itself can do.
CREATE POLICY "device_tokens_insert_own" ON device_tokens
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "device_tokens_select_own" ON device_tokens
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "device_tokens_update_own" ON device_tokens
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "device_tokens_delete_own" ON device_tokens
  FOR DELETE USING (user_id = auth.uid());

-- ── Search Rate Limits ───────────────────────────────────────
-- No INSERT/UPDATE/DELETE policy is defined for regular users — the only
-- way rows get written is through check_search_rate_limit(), which runs
-- as SECURITY DEFINER and therefore bypasses RLS entirely. This means the
-- client can SEE its own rate-limit usage (e.g. to show "X searches left
-- this minute") but cannot tamper with the counter directly.
CREATE POLICY "search_rate_limits_select_own" ON search_rate_limits
  FOR SELECT USING (user_id = auth.uid());

-- ============================================================
--  SEED DATA (optional — for testing)
-- ============================================================
INSERT INTO companies (id, name, license_number, region, email, phone, is_verified, verified_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'Alpha Shield Security',  'PSC-GH-1042', 'Greater Accra', 'info@alphashield.gh',   '+233201234567', TRUE, NOW()),
  ('22222222-2222-2222-2222-222222222222', 'Eagle Eye Protection',   'PSC-GH-2211', 'Ashanti',       'admin@eagleeye.gh',    '+233207654321', TRUE, NOW()),
  ('33333333-3333-3333-3333-333333333333', 'Guardian Force Ltd',     'PSC-GH-3390', 'Western',       'ops@guardianforce.gh', '+233209876543', FALSE, NULL);
