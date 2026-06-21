$path = "supabase_schema.sql"
$content = Get-Content $path -Raw

# Add DROP POLICY IF EXISTS before every CREATE POLICY
$content = $content.Replace(
  'CREATE POLICY "companies_insert_public" ON companies FOR INSERT',
  'DROP POLICY IF EXISTS "companies_insert_public" ON companies;' + [Environment]::NewLine + 'CREATE POLICY "companies_insert_public" ON companies FOR INSERT'
)
$content = $content.Replace(
  'CREATE POLICY "companies_select_own"    ON companies FOR SELECT',
  'DROP POLICY IF EXISTS "companies_select_own" ON companies;' + [Environment]::NewLine + 'CREATE POLICY "companies_select_own"    ON companies FOR SELECT'
)
$content = $content.Replace(
  'CREATE POLICY "companies_update_admin"  ON companies FOR UPDATE',
  'DROP POLICY IF EXISTS "companies_update_admin" ON companies;' + [Environment]::NewLine + 'CREATE POLICY "companies_update_admin"  ON companies FOR UPDATE'
)
$content = $content.Replace(
  'CREATE POLICY "users_select_own"  ON users FOR SELECT',
  'DROP POLICY IF EXISTS "users_select_own" ON users;' + [Environment]::NewLine + 'CREATE POLICY "users_select_own"  ON users FOR SELECT'
)
$content = $content.Replace(
  'CREATE POLICY "users_insert_self" ON users FOR INSERT',
  'DROP POLICY IF EXISTS "users_insert_self" ON users;' + [Environment]::NewLine + 'CREATE POLICY "users_insert_self" ON users FOR INSERT'
)
$content = $content.Replace(
  'CREATE POLICY "employment_select" ON employment_history',
  'DROP POLICY IF EXISTS "employment_select" ON employment_history;' + [Environment]::NewLine + 'CREATE POLICY "employment_select" ON employment_history'
)
$content = $content.Replace(
  'CREATE POLICY "employment_insert_own" ON employment_history',
  'DROP POLICY IF EXISTS "employment_insert_own" ON employment_history;' + [Environment]::NewLine + 'CREATE POLICY "employment_insert_own" ON employment_history'
)
$content = $content.Replace(
  'CREATE POLICY "employment_update_own" ON employment_history',
  'DROP POLICY IF EXISTS "employment_update_own" ON employment_history;' + [Environment]::NewLine + 'CREATE POLICY "employment_update_own" ON employment_history'
)
$content = $content.Replace(
  'CREATE POLICY "conduct_select_verified" ON conduct_records',
  'DROP POLICY IF EXISTS "conduct_select_verified" ON conduct_records;' + [Environment]::NewLine + 'CREATE POLICY "conduct_select_verified" ON conduct_records'
)
$content = $content.Replace(
  'CREATE POLICY "conduct_insert_own" ON conduct_records',
  'DROP POLICY IF EXISTS "conduct_insert_own" ON conduct_records;' + [Environment]::NewLine + 'CREATE POLICY "conduct_insert_own" ON conduct_records'
)
$content = $content.Replace(
  'CREATE POLICY "disputes_select_verified" ON conduct_disputes',
  'DROP POLICY IF EXISTS "disputes_select_verified" ON conduct_disputes;' + [Environment]::NewLine + 'CREATE POLICY "disputes_select_verified" ON conduct_disputes'
)
$content = $content.Replace(
  'CREATE POLICY "disputes_insert_verified" ON conduct_disputes',
  'DROP POLICY IF EXISTS "disputes_insert_verified" ON conduct_disputes;' + [Environment]::NewLine + 'CREATE POLICY "disputes_insert_verified" ON conduct_disputes'
)
$content = $content.Replace(
  'CREATE POLICY "disputes_update" ON conduct_disputes',
  'DROP POLICY IF EXISTS "disputes_update" ON conduct_disputes;' + [Environment]::NewLine + 'CREATE POLICY "disputes_update" ON conduct_disputes'
)
$content = $content.Replace(
  'CREATE POLICY "disputes_delete_own_pending" ON conduct_disputes',
  'DROP POLICY IF EXISTS "disputes_delete_own_pending" ON conduct_disputes;' + [Environment]::NewLine + 'CREATE POLICY "disputes_delete_own_pending" ON conduct_disputes'
)
$content = $content.Replace(
  'CREATE POLICY "audit_select_own"   ON audit_logs FOR SELECT',
  'DROP POLICY IF EXISTS "audit_select_own" ON audit_logs;' + [Environment]::NewLine + 'CREATE POLICY "audit_select_own"   ON audit_logs FOR SELECT'
)
$content = $content.Replace(
  'CREATE POLICY "audit_insert"       ON audit_logs FOR INSERT',
  'DROP POLICY IF EXISTS "audit_insert" ON audit_logs;' + [Environment]::NewLine + 'CREATE POLICY "audit_insert"       ON audit_logs FOR INSERT'
)
$content = $content.Replace(
  'CREATE POLICY "alerts_select_own"  ON alerts FOR SELECT',
  'DROP POLICY IF EXISTS "alerts_select_own" ON alerts;' + [Environment]::NewLine + 'CREATE POLICY "alerts_select_own"  ON alerts FOR SELECT'
)
$content = $content.Replace(
  'CREATE POLICY "alerts_update_own"  ON alerts FOR UPDATE',
  'DROP POLICY IF EXISTS "alerts_update_own" ON alerts;' + [Environment]::NewLine + 'CREATE POLICY "alerts_update_own"  ON alerts FOR UPDATE'
)
$content = $content.Replace(
  'CREATE POLICY "alerts_insert"      ON alerts FOR INSERT',
  'DROP POLICY IF EXISTS "alerts_insert" ON alerts;' + [Environment]::NewLine + 'CREATE POLICY "alerts_insert"      ON alerts FOR INSERT'
)
$content = $content.Replace(
  'CREATE POLICY "device_tokens_insert_own" ON device_tokens',
  'DROP POLICY IF EXISTS "device_tokens_insert_own" ON device_tokens;' + [Environment]::NewLine + 'CREATE POLICY "device_tokens_insert_own" ON device_tokens'
)
$content = $content.Replace(
  'CREATE POLICY "device_tokens_select_own" ON device_tokens',
  'DROP POLICY IF EXISTS "device_tokens_select_own" ON device_tokens;' + [Environment]::NewLine + 'CREATE POLICY "device_tokens_select_own" ON device_tokens'
)
$content = $content.Replace(
  'CREATE POLICY "device_tokens_update_own" ON device_tokens',
  'DROP POLICY IF EXISTS "device_tokens_update_own" ON device_tokens;' + [Environment]::NewLine + 'CREATE POLICY "device_tokens_update_own" ON device_tokens'
)
$content = $content.Replace(
  'CREATE POLICY "device_tokens_delete_own" ON device_tokens',
  'DROP POLICY IF EXISTS "device_tokens_delete_own" ON device_tokens;' + [Environment]::NewLine + 'CREATE POLICY "device_tokens_delete_own" ON device_tokens'
)
$content = $content.Replace(
  'CREATE POLICY "search_rate_limits_select_own" ON search_rate_limits',
  'DROP POLICY IF EXISTS "search_rate_limits_select_own" ON search_rate_limits;' + [Environment]::NewLine + 'CREATE POLICY "search_rate_limits_select_own" ON search_rate_limits'
)

Set-Content $path $content
Write-Host "Done"
