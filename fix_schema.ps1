$path = "supabase_schema.sql"
$content = Get-Content $path -Raw
$content = $content.Replace("CREATE INDEX idx_recruits_id_number", "CREATE INDEX IF NOT EXISTS idx_recruits_id_number")
$content = $content.Replace("CREATE INDEX idx_recruits_fingerprint_hash", "CREATE INDEX IF NOT EXISTS idx_recruits_fingerprint_hash")
$content = $content.Replace("CREATE INDEX idx_recruits_status", "CREATE INDEX IF NOT EXISTS idx_recruits_status")
$content = $content.Replace("CREATE INDEX idx_employment_recruit", "CREATE INDEX IF NOT EXISTS idx_employment_recruit")
$content = $content.Replace("CREATE INDEX idx_employment_company", "CREATE INDEX IF NOT EXISTS idx_employment_company")
$content = $content.Replace("CREATE INDEX idx_conduct_recruit", "CREATE INDEX IF NOT EXISTS idx_conduct_recruit")
$content = $content.Replace("CREATE INDEX idx_conduct_company", "CREATE INDEX IF NOT EXISTS idx_conduct_company")
$content = $content.Replace("CREATE INDEX idx_conduct_type", "CREATE INDEX IF NOT EXISTS idx_conduct_type")
$content = $content.Replace("CREATE INDEX idx_disputes_record", "CREATE INDEX IF NOT EXISTS idx_disputes_record")
$content = $content.Replace("CREATE INDEX idx_disputes_status", "CREATE INDEX IF NOT EXISTS idx_disputes_status")
$content = $content.Replace("CREATE INDEX idx_disputes_company", "CREATE INDEX IF NOT EXISTS idx_disputes_company")
$content = $content.Replace("CREATE INDEX idx_audit_company", "CREATE INDEX IF NOT EXISTS idx_audit_company")
$content = $content.Replace("CREATE INDEX idx_audit_created_at", "CREATE INDEX IF NOT EXISTS idx_audit_created_at")
$content = $content.Replace("CREATE INDEX idx_alerts_company", "CREATE INDEX IF NOT EXISTS idx_alerts_company")
$content = $content.Replace("CREATE INDEX idx_alerts_unread", "CREATE INDEX IF NOT EXISTS idx_alerts_unread")
$content = $content.Replace("CREATE INDEX idx_device_tokens_company", "CREATE INDEX IF NOT EXISTS idx_device_tokens_company")
Set-Content $path $content
Write-Host "Done."
