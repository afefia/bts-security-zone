-- ============================================================
--  CLEAN SLATE — drops everything supabase_schema.sql creates
--  Run this FIRST, then run the (fixed) supabase_schema.sql fresh.
--
--  Safe to run even if some objects don't exist yet (every DROP uses
--  IF EXISTS) — so it's also fine to run this if your previous attempt
--  only partially completed, which is exactly the situation that led
--  here (a CREATE EXTENSION failure partway through stopped everything
--  after it, including the RLS policies).
--
--  WARNING: this deletes all data in these tables. Only run this if
--  you don't have real data you need to keep — which matches "just
--  testing registration so far."
-- ============================================================

-- ── Tables — children before parents (foreign key order) ──────
DROP TABLE IF EXISTS search_rate_limits CASCADE;
DROP TABLE IF EXISTS device_tokens CASCADE;
DROP TABLE IF EXISTS alerts CASCADE;
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS conduct_disputes CASCADE;
DROP TABLE IF EXISTS conduct_records CASCADE;
DROP TABLE IF EXISTS employment_history CASCADE;
DROP TABLE IF EXISTS recruits CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS companies CASCADE;

-- ── Functions ────────────────────────────────────────────────
-- CASCADE here drops any trigger still attached to a function (shouldn't
-- be any left since the tables above are already gone, but harmless).
DROP FUNCTION IF EXISTS check_search_rate_limit(UUID, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS cleanup_search_rate_limits() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at() CASCADE;
DROP FUNCTION IF EXISTS flag_recruit_on_conduct() CASCADE;
DROP FUNCTION IF EXISTS notify_push_on_alert() CASCADE;
DROP FUNCTION IF EXISTS my_company_id() CASCADE;
DROP FUNCTION IF EXISTS is_admin() CASCADE;
DROP FUNCTION IF EXISTS prevent_audit_log_mutation() CASCADE;

-- ── Types — only droppable once every table using them is gone ─
DROP TYPE IF EXISTS recruit_status CASCADE;
DROP TYPE IF EXISTS conduct_type CASCADE;
DROP TYPE IF EXISTS user_role CASCADE;
DROP TYPE IF EXISTS audit_action CASCADE;
DROP TYPE IF EXISTS dispute_status CASCADE;

-- ── Note on auth.users ──────────────────────────────────────
-- This intentionally does NOT touch auth.users (Supabase's built-in
-- auth table) — any test accounts you signed up with are still there.
-- If you want those gone too, delete them manually via
-- Dashboard → Authentication → Users, since deleting auth users via SQL
-- isn't recommended (it can leave Supabase's internal auth state
-- inconsistent). The `users` table above (your app's own profile table,
-- separate from auth.users) is already dropped by this script and will
-- be recreated empty when you re-run supabase_schema.sql.
