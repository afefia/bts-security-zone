-- ============================================================
--  DIAGNOSTIC — run this in the Supabase SQL Editor and paste the
--  output back. Read-only, makes no changes.
-- ============================================================

-- 1. Does companies_select_own actually exist right now?
SELECT polname, polcmd, pg_get_expr(polqual, polrelid) AS using_clause
FROM pg_policy
WHERE polrelid = 'companies'::regclass;

-- 2. Every user row and their role — this tells us directly whether
--    everyone really is 'admin' in the database, or whether the app is
--    misreading a correct 'company_user' value.
SELECT id, company_id, full_name, email, role, created_at
FROM users
ORDER BY created_at;

-- 3. Every company row and its verification status — tells us whether
--    companies actually exist in the table at all (vs. being created
--    but invisible due to RLS).
SELECT id, name, is_verified, created_at
FROM companies
ORDER BY created_at;

-- 4. Confirm is_admin() and my_company_id() exist and are the expected
--    SECURITY DEFINER functions (a failed partial re-run could have left
--    an old, broken version of one of these in place).
SELECT proname, prosecdef AS is_security_definer, provolatile
FROM pg_proc
WHERE proname IN ('is_admin', 'my_company_id');

-- 5. Confirm RLS is actually enabled on both tables (it's possible for
--    a table to exist with policies defined but RLS itself toggled off,
--    which would make policies irrelevant either way).
SELECT relname, relrowsecurity AS rls_enabled
FROM pg_class
WHERE relname IN ('companies', 'users');
