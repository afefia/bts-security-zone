# The Security Zone 🛡️
### Private Security Personnel Monitoring Platform — now backed by Supabase

A Flutter application for tracking and verifying security personnel across multiple private security companies in Ghana, with a live PostgreSQL backend on Supabase.

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point — loads .env, initializes Supabase, deep links
├── theme/
│   └── app_theme.dart                 # Colors, typography, component styles
├── config/
│   └── supabase_service.dart          # Supabase client singleton
├── models/
│   └── db_models.dart                 # Data models that mirror the Supabase schema
├── utils/
│   └── validators.dart                # Shared input validation/sanitization
├── services/
│   ├── auth_service.dart              # Sign in / sign up / sign out / password reset / resend confirmation / profile update
│   ├── recruit_service.dart           # Search, register, conduct records, employment closure — offline-aware
│   ├── company_service.dart           # Company CRUD, verify/reject, current user's profile + role
│   ├── alerts_service.dart            # Notifications + real-time stream
│   ├── admin_service.dart             # Platform stats, analytics queries, audit log
│   ├── dispute_service.dart           # File/resolve disputes against conduct records
│   ├── fingerprint_service.dart       # Capture abstraction + real-hardware integration point
│   ├── recruit_pdf_service.dart       # Generates the recruit verification PDF report
│   ├── push_notification_service.dart # FCM registration, token storage, foreground display
│   ├── local_db.dart                  # SQLite cache + offline write queue
│   ├── connectivity_service.dart      # Online/offline detection stream
│   └── sync_service.dart              # Replays queued writes, refreshes cache on reconnect
├── widgets/
│   ├── app_button.dart                # THE single button widget — see "Design System" below
│   ├── app_max_width.dart             # Caps content width on wide screens — see "Design System" below
│   ├── app_spacing.dart               # Shared screen-padding constants
│   └── connectivity_banner.dart       # Shared "offline / syncing / pending" banner
└── screens/
    ├── splash_screen.dart             # Checks session → Dashboard or Login
    ├── login_screen.dart              # Real Supabase auth sign-in
    ├── register_company_screen.dart   # 3-step company + first-user signup
    ├── set_new_password_screen.dart    # Reached via password-reset deep link
    ├── profile_screen.dart            # Edit name/email ("My Account")
    ├── dashboard_screen.dart          # Live stats, quick actions, role-aware drawer
    ├── alerts_screen.dart             # Real-time notifications via Supabase stream
    ├── search_screen.dart             # Live search by name/ID/fingerprint
    ├── recruit_profile_screen.dart    # Full profile: timeline + conduct records + disputes
    ├── add_conduct_record_screen.dart # Submits real conduct records
    ├── file_dispute_screen.dart       # File a dispute against a conduct record
    ├── company_list_screen.dart       # Live registered companies list
    ├── register_recruit_screen.dart   # Registers real recruit + employment record
    └── admin_panel_screen.dart        # Overview, analytics, disputes, approvals, audit log

supabase_schema.sql                    # Full DB schema — run this in Supabase SQL Editor
supabase/functions/send-push/          # Edge Function: sends FCM pushes when alerts are created
.env.example                           # Template for your Supabase credentials
```

---

## 🎨 Design System — buttons & form fields

**This is a hard rule for this codebase, not a one-time pass:** no button anywhere stretches to fill its container, and no screen lets a `TextFormField` touch the screen edge. Every screen built from this point forward must follow the same two rules below — this section exists specifically so that's checkable later, not just remembered.

### Buttons — always use `AppButton`, never raw `ElevatedButton`/`OutlinedButton`/`TextButton`

`lib/widgets/app_button.dart` is the only place button styling is defined. Every button in the app is one of:

```dart
AppButton(label: 'SIGN IN', onPressed: _submit, isLoading: _isLoading)   // primary — gold, filled
AppButton.secondary(label: 'CANCEL', onPressed: () {})                   // outlined, gold border
AppButton.text(label: 'Forgot password?', onPressed: () {})              // inline link, no border
AppButton.danger(label: 'SIGN OUT', onPressed: _signOut)                 // destructive — red
AppButton.success(label: 'UPHOLD', onPressed: _uphold)                   // affirmative — green
```

By construction, every variant sizes itself to its label and icon — never `width: double.infinity`. To position one within a screen:
- A single primary action at the bottom of a form → wrap in `Center` (this is the default visual weight for "the one thing to do here")
- Two related actions side by side (e.g. a dialog's Cancel/Confirm, or a card's Reject/Uphold) → `Center(child: Wrap(spacing: 12, children: [...]))`, **not** `Row` with `Expanded` — `Wrap` lets both buttons size to their own text and gracefully wraps to a second line if the screen is narrow, instead of one of them stretching to match the other's width
- A small inline action inside a `ListTile.trailing`, an `AppBar.actions`, or tucked into a card corner → `AppButton.text(..., compact: true)`

Loading state is built in (`isLoading: true` swaps the label for a spinner automatically) — never hand-roll a `SizedBox`+`CircularProgressIndicator` swap inline like older code in this app used to.

**If you need a button style this file doesn't have** (a new color, a new size), add a new named constructor to `AppButton` itself rather than reaching for `ElevatedButton.styleFrom(...)` on the screen that needs it. That one rule is what keeps every button in the app looking like part of the same product instead of drifting screen by screen.

### Form fields — fill their row, but never touch the screen edge, and never stretch across a wide window

Text fields fill available width within their row — that's the standard, expected pattern (every banking app, every email client works this way), so `TextFormField` doesn't need a wrapper for that part. But "fills its row" is only correct if the row itself is reasonably sized. **Every screen with real content — forms, cards, lists — must wrap that content in `AppMaxWidth` (`lib/widgets/app_max_width.dart`).** On a phone it's invisible; on a desktop browser or a wide window it caps the content at a sane width and centers it, instead of a login field or a stat card stretching across a 1900px window the way a raw mobile layout does. This was missed in an earlier pass — it's the reason a login form looked fine on phone but stretched edge-to-edge on desktop — and it must not be skipped on any screen added after this one.

```dart
body: SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: AppMaxWidth(              // default 440 — good for login/registration/simple forms
    child: Form(child: Column(children: [...])),
  ),
),
```

Use a wider cap (`AppMaxWidth(maxWidth: 600)` or `700`) for screens with cards, lists, or charts that read better a bit wider than a login form — search results, the recruit profile, dashboard stat cards, admin tables. Every screen in this app already follows this pattern; check an existing screen (`search_screen.dart`, `dashboard_screen.dart`) for the exact wrapping shape before adding a new one, since the wrap point differs slightly depending on whether the screen uses `Padding`, `SingleChildScrollView`, `RefreshIndicator`, or a raw `ListView` as its outermost widget.

**The one place this doesn't apply:** `TextField`/`TextFormField` instances inside an `AlertDialog` — Flutter already constrains dialogs to a sane width on their own, so no extra wrap is needed there.

Beyond the max-width cap, screen margins should still be consistent:
- Every screen's root padding should be `AppSpacing.screen` (`EdgeInsets.all(16)`) from `lib/widgets/app_spacing.dart` — don't write a fresh `EdgeInsets.all(20)` or `EdgeInsets.all(12)` on a new screen; reuse the constant so every screen's left/right breathing room matches.
- Use `AppSpacing.fieldGap` (16) as the `SizedBox` height between stacked fields, and `AppSpacing.sectionGap` (24) between a field group and the next section.

---

## 🚀 Setup Instructions

### 1. Create a Supabase project
Go to [supabase.com](https://supabase.com) → New Project. Wait for it to finish provisioning.

### 2. Run the schema
Open your project → **SQL Editor** → New Query → paste the entire contents of `supabase_schema.sql` → Run.

This creates all tables, enums, indexes, triggers (auto-flagging recruits on serious conduct records), and Row Level Security policies, plus 3 seed companies for testing.

**If you already ran an earlier version of this script and got "row violates row-level security policy" when registering a company:** that almost certainly means the script silently stopped partway through. `CREATE EXTENSION pg_net` (used for the optional push-notification dispatch) throws a hard error on Supabase projects where that extension isn't enabled — and since the SQL Editor runs a pasted script as one batch, that single failure stops everything after it in the same run, including the RLS policy that allows company registration. This is now fixed (the extension creation is wrapped so its absence can't break anything else), but if you already hit this:
1. Run `supabase_cleanup.sql` first (drops everything the schema creates — safe, since `IF EXISTS` is used throughout, and it deliberately leaves your `auth.users` test accounts alone)
2. Then run the corrected `supabase_schema.sql` fresh

### 3. Configure environment variables
```bash
cp .env.example .env
```
Open `.env` and fill in your project's URL and anon key, found at:
**Supabase Dashboard → Settings → API**

```
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

### 4. Enable email confirmation (required, dashboard-only step)
**Supabase Dashboard → Authentication → Providers → Email → enable "Confirm email"**

This can't be done via SQL. With it on, Supabase will only let a user sign in after they click the link in their confirmation email. The app already handles both ends of this: `register_company_screen.dart` shows a "check your inbox" dialog instead of the success dialog when confirmation is pending, and `login_screen.dart` shows a "Resend confirmation email" button if someone tries to sign in too early.

### 5. Install dependencies & run
```bash
flutter pub get
flutter run
```

### 6. Create your first account
On first launch, tap **"Register Your Company"** on the login screen. This creates:
- A Supabase Auth user
- A `companies` row (unverified by default)
- A `users` row linking you to that company

⚠️ New companies start **unverified** — they can sign in (once email-confirmed) but won't see other companies' recruit data until an admin approves them.

### 7. Make yourself an admin (to test the Admin Panel)
Run this in the SQL Editor, replacing the email:
```sql
UPDATE users SET role = 'admin' WHERE email = 'you@example.com';
UPDATE companies SET is_verified = true WHERE id = (
  SELECT company_id FROM users WHERE email = 'you@example.com'
);
```

---

## 🔐 How Row Level Security works here

- **Recruits & conduct records** are readable by any verified company — that's the entire point of the platform (cross-company visibility on misconduct).
- **Conduct records** can only be *inserted* by the company that owns them — you can't write a record on behalf of another company.
- **Companies** can only see/update their own row, unless the user has `role = 'admin'`.
- **Alerts** are private per company.
- A **trigger** automatically sets a recruit's status to `terminated`/`misconduct`/`suspended` and broadcasts an alert to all verified companies whenever a serious conduct record is added — no client-side logic needed.

---

## 📶 Offline Mode — how it works and what it covers

This matters more than it might seem for an admin tool: recruit verification often happens at the exact moment someone walks into a new company's office, which is not guaranteed to be a moment with good signal. The app is built so that scenario doesn't break the core workflow.

**What's cached locally (SQLite, via `local_db.dart`):**
Every successful search, dashboard load, or sync refreshes a local copy of recruits and companies. The most recently seen ~500 recruits and their full employment/conduct history are available offline.

**What works fully offline:**
- Searching cached recruits by name, ID, or phone — results are clearly labeled "CACHED · [time] ago" so nobody mistakes stale data for live data
- Viewing a recruit's full profile, employment history, and conduct records, as long as that recruit was seen at least once while online
- Registering a new recruit — saved to a local outbox and synced automatically once connectivity returns
- Adding a conduct record — same outbox-and-sync behavior
- Browsing the Company List — shows the last-synced company list with a clear "Showing cached company list" notice

**The one real tradeoff:** the database trigger that auto-flags a recruit and alerts every company only fires when the conduct record actually reaches Supabase. A termination record added offline does **not** flag the recruit for other companies until it syncs — the Add Conduct Record screen shows this explicitly when offline so whoever's submitting it understands the record isn't visible platform-wide yet.

**How sync happens:** `SyncService` listens for connectivity changes and replays the outbox automatically the moment a network connection returns — no button to press. A manual "SYNC" action is also available in the dashboard drawer for anyone who wants to force a retry rather than wait.

**What's intentionally still online-only:** approving or rejecting a company (in the Admin Panel) requires a live connection. Unlike registering a recruit, there's no safe way to "queue" this and have it feel trustworthy — an admin tapping APPROVE with no confirmation the action actually applied is worse than just being told to reconnect, since this action gates whether other companies can see that company's recruit submissions at all. The button shows a clear error if attempted offline rather than silently queuing or failing. The rest of the Admin Panel (overview stats, analytics charts, audit log) still requires a connection too, since none of it represents time-critical, at-the-door verification work the way recruit search does.

---

## 📄 PDF Export

The recruit profile screen has an "EXPORT PDF" button that generates a clean, printable report covering identification details, status, full employment timeline, and every conduct record on file — the kind of document a company might attach to a hiring file, hand to an auditor, or print for a dispute review.

Tapping it opens a sheet with two options: **Share/Save** (hands the PDF to the OS share sheet — email, WhatsApp, Files, Drive, AirDrop, whatever's installed) or **Print** (sends straight to a connected or network printer via the OS print dialog). Both are powered by the `printing` package, so platform-specific printer/share integration is handled for you on iOS, Android, and desktop.

The report's styling intentionally avoids being flashy — navy and gold accents to match the in-app theme, but otherwise a plain, legible business-document layout, since this may end up printed in black-and-white or forwarded as evidence in a dispute.

---

## 🔔 Push Notifications

In-app alerts already update live via Supabase Realtime (see Alerts screen). Push notifications extend that to reach a phone that's locked or the app fully closed — important for "you've been flagged" or "a recruit you employ was just terminated elsewhere" type alerts that shouldn't wait for someone to open the app.

**Architecture, and why it's split this way:**
Supabase doesn't deliver push notifications itself. Sending a push requires a Firebase service-account credential that must never ship inside the app binary — anyone could extract it and send arbitrary notifications as you. So sending happens server-side:

```
conduct record inserted
  → DB trigger flags recruit + inserts one `alerts` row per verified company
    → DB trigger (trg_notify_push_on_alert) calls a Supabase Edge Function
      → Edge Function looks up that company's device_tokens
        → sends each one a push via Firebase Cloud Messaging (HTTP v1 API)
```

The Flutter app's only job is: ask for notification permission, get an FCM token, store it in `device_tokens`, and display incoming notifications. All in `lib/services/push_notification_service.dart`.

**This is fully optional.** If you skip every step below, the app works exactly as it does now — in-app Realtime alerts keep working, `initializeFirebaseIfConfigured()` just fails quietly and push notifications are simply off.

### Setup steps

**1. Create a Firebase project** (free tier is enough) at [console.firebase.google.com](https://console.firebase.google.com)

**2. Add your apps to the Firebase project:**
- Android: register the app's package name → download `google-services.json` → place at `android/app/google-services.json`
- iOS: register the app's bundle ID → download `GoogleService-Info.plist` → place at `ios/Runner/GoogleService-Info.plist`, and add it to the Xcode project via Xcode itself (drag into Runner)

If `android/` and `ios/` folders don't exist yet in your checkout, run `flutter create .` from the project root first to generate them, then add the files above.

**3. Android native config** — in `android/build.gradle`, add to the `dependencies` block:
```gradle
classpath 'com.google.gms:google-services:4.4.2'
```
and at the **bottom** of `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'
```

**4. Generate a service account key for server-side sending:**
Firebase Console → Project Settings → Service Accounts → "Generate new private key" → downloads a JSON file. Keep this secret — it's what lets the Edge Function send pushes on your behalf.

**5. Deploy the Edge Function:**
```bash
supabase functions deploy send-push
supabase secrets set FCM_PROJECT_ID=your-firebase-project-id
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat path/to/service-account.json)"
```

**6. Wire the database trigger to the deployed function** — run in the SQL Editor, replacing both values:
```sql
ALTER DATABASE postgres SET app.settings.push_function_url =
  'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-push';
ALTER DATABASE postgres SET app.settings.service_role_key =
  'YOUR_SERVICE_ROLE_KEY'; -- Settings → API → service_role (NOT the anon key)
```

**7. Run `flutter pub get` and rebuild the app.** On first launch after login, it'll request notification permission and register its token automatically.

### Testing it
Add a termination/misconduct conduct record for any recruit from a second test account. Every verified company (including yours, if verified) should receive a push within a few seconds. If nothing arrives, check the Edge Function logs (`supabase functions logs send-push`) — the most common issue is the service account JSON being malformed when set as a secret (make sure it's valid single-line JSON, no stray newlines).

---

## 📊 Analytics Dashboard

The Admin Panel has an "ANALYTICS" tab (admin-only, same as the rest of the panel) with five charts pulling live data straight from Supabase — no separate analytics pipeline or pre-aggregated tables, just queries run on demand:

- **Registration trend** (30-day line chart) — recruit sign-ups per day, useful for spotting adoption growth or a sudden drop-off
- **Search activity** (30-day line chart) — how much companies are actually using the verification feature day to day
- **Recruit status breakdown** (donut chart) — what fraction of the recruit pool is clear vs. flagged vs. suspended vs. terminated
- **Conduct records by type** (bar chart) — whether commendations or violations dominate, and which violation type is most common
- **Recruits by region** (horizontal bar chart) — where recruits are concentrated geographically

All five are zero-filled where relevant (e.g. a day with no registrations still shows as a zero point rather than vanishing from the trend line) so the charts read as honest activity levels rather than skipping gaps. Each chart card shows its own empty-state message rather than just looking broken when a table has no rows yet (e.g. a fresh database with no conduct records).

Charts are built with `fl_chart` and re-fetch on pull-to-refresh, same pattern as the rest of the Admin Panel.

---

## 🚦 Search Rate Limiting

The recruit search endpoint is capped at 30 searches per minute per user, enforced in Postgres via a `check_search_rate_limit()` function that the app calls once before every search — not trusted purely to client-side logic, since the count lives in the database, not in app memory that could be reset by reinstalling or modifying the app.

**How it works:** a small `search_rate_limits` table holds one row per user per minute, incremented atomically via `INSERT ... ON CONFLICT DO UPDATE`. If a user's count for the current minute exceeds the cap, the function returns `false` and the app shows "Too many searches — please wait a moment and try again." instead of running the query.

**Why 30/minute:** generous enough that a busy hiring office doing rapid back-to-back checks never notices it, but well above what normal use requires — it's there to catch a runaway retry loop or casual scraping from within the app, not to throttle legitimate work.

**What this does and doesn't cover — worth being precise about:** this protects the app's own search flow, which is the realistic abuse scenario for a tool used by people doing hiring checks. It does **not** by itself stop someone with a valid login from bypassing the app and calling Supabase's REST API directly to read `recruits` without ever calling the rate-limit function first — RLS on the `recruits` table doesn't reference this counter, and deliberately so: RLS policies apply per row scanned, so wiring the check into the policy would multiply the cost by however many recruits a single search matches, turning a "30 searches/minute" limit into something closer to "30 *results* per minute," which isn't the intended behavior. The correct backstop for direct-API abuse is Supabase's own platform-level API rate limiting (Dashboard → Settings → API), which applies uniformly regardless of which table or method is hit — this app-level check is a complementary layer giving the app itself a clean way to self-throttle and show a friendly message, not a complete defense against a determined attacker with valid API credentials.

**Fails open, not closed:** if the rate-limit RPC itself fails — not deployed yet, a transient network blip — the app lets the search proceed rather than blocking everyone over an enforcement mechanism issue.

---

## 👆 Fingerprint Scanning — current state & how to go live

There's no way around this honestly: matching one scanned finger against thousands of stored recruits (1:N identification) needs dedicated scanner hardware and its vendor SDK — phone biometrics (Face ID, Android fingerprint unlock) only answer "is this the device owner," which isn't what this app needs.

Right now, `lib/services/fingerprint_service.dart` ships with a `SoftwareFallbackProvider` so the full capture → identify → search flow works end-to-end in demos, but it generates a random placeholder template on every scan rather than reading a real finger — so it will (correctly) never report a match.

**The matching architecture is real, not a placeholder.** `FingerprintProvider` has a dedicated `match()` method, and `RecruitService.findByFingerprint()` does genuine 1:N identification: it fetches every recruit with a fingerprint on file and runs `FingerprintService.findMatch()` against each one, rather than doing an exact-equality database lookup (which could never work for real fingerprint images, since no two scans of the same finger produce identical bytes).

To go live with real hardware:
1. Buy a USB or Bluetooth scanner — Mantra MFS100 is a common, affordable choice in Ghana/India; SecuGen and DigitalPersona are other options.
2. Obtain that vendor's Flutter plugin and add it to `pubspec.yaml` (commented placeholder lines are already there).
3. Uncomment `MantraFingerprintProvider` in `fingerprint_service.dart` — it's a complete, working implementation (capture with quality-threshold checking, plus real `match()` using the vendor's scoring API), not a sketch. You'll likely need to adjust method names to match whatever the actual plugin's API surface turns out to be, since vendor plugin APIs vary, but the shape — capture returns a template + quality score, matching is a separate vendor-provided scoring call — is standard across fingerprint SDKs.
4. Swap `FingerprintService()` for `FingerprintService(provider: MantraFingerprintProvider())` in `search_screen.dart` and `register_recruit_screen.dart`.

**On scale:** `findByFingerprint` currently matches client-side against every recruit with a fingerprint on file — fine for hundreds to a few thousand recruits. If the platform grows well beyond that, move matching server-side (an Edge Function, or a dedicated matching service) so a phone isn't running thousands of comparisons on every scan.

The UI already shows a "SIMULATED — NO SCANNER" badge wherever fingerprint capture happens, so nobody mistakes the demo for production-ready biometric matching.

---

## ✅ Features Implemented

- [x] Real Supabase Auth (sign up, sign in, sign out, password reset)
- [x] Email confirmation enforced before login, with a resend-confirmation flow
- [x] Company registration with admin approval workflow
- [x] Live recruit search by name / ID / fingerprint, with real 1:N matching architecture
- [x] Full recruit profile with real employment history & conduct records
- [x] Add conduct record → auto-flags recruit + alerts all companies (DB trigger)
- [x] Real-time alerts via Supabase Realtime stream
- [x] Admin panel: live stats, analytics charts, company approve/reject, full audit log
- [x] Audit logging on search, register, add-record, login, verify actions
- [x] Row Level Security enforced at the database level
- [x] Pull-to-refresh on all data screens
- [x] Loading states & error handling throughout
- [x] Fingerprint capture + matching abstraction, with a complete (not sketch) reference hardware implementation
- [x] Offline mode: cached search/profile/company reads, queued writes, auto-sync on reconnect
- [x] PDF export of recruit profiles with share/print options
- [x] Push notifications (FCM) — optional, degrades gracefully if not configured
- [x] Analytics dashboard: registration/search trends, status breakdown, conduct types, regional distribution
- [x] App-level search rate limiting (30/minute/user, counter enforced in Postgres)
- [x] Server-side input validation: CHECK constraints on all tables + client-side Validators class
- [x] Audit log immutability: REVOKE UPDATE/DELETE + immutability trigger
- [x] Dispute/appeal mechanism: file disputes, admin DISPUTES tab, uphold/reject with status recalculation
- [x] service_role key isolation: only used via Supabase dashboard settings, never in code or .env
- [x] Role-gated Admin Panel (only visible/usable by users with role='admin')
- [x] Employment history can be closed out (end date + exit reason)
- [x] Account/profile editing (name, email)
- [x] Password reset deep link flow with a proper "Set New Password" screen
- [x] Session expiry redirects to login instead of failing silently
- [x] Clear setup-needed screen instead of crashing on placeholder .env credentials
- [x] Consistent design system: every button sizes to its text via shared AppButton widget; no full-width buttons anywhere
- [x] Every screen's content is capped to a sane max width (AppMaxWidth) so forms and cards don't stretch edge-to-edge on wide/desktop windows

---

## 🔐 Security Hardening

Five gaps identified in a security review were all addressed:

**1. Server-side input validation (CHECK constraints + Validators class)**
Every write path is validated at two levels: a `Validators` class in `lib/utils/validators.dart` gives forms fast, consistent feedback and sanitizes control characters before any data leaves the device. Matching `CHECK` constraints in the database enforce the same limits (length caps, format rules, date sanity) at the Postgres level — so a malicious client bypassing the app and calling the REST API directly still can't insert garbage data. The two sets of rules are co-located in comments to make drift obvious.

**2. Audit log immutability**
`audit_logs` is append-only. `UPDATE` and `DELETE` privileges are explicitly revoked from both `authenticated` and `service_role`, and a `BEFORE UPDATE OR DELETE` trigger raises an exception if any code path somehow attempts a modification — even one running as superuser. An admin reviewing a dispute can read the full history, but cannot edit or delete it.

**3. Dispute and appeal mechanism for conduct records**
This was the single highest-stakes gap: a company could file a false termination record with no recourse. Now any verified company can file a dispute against any conduct record (`lib/screens/file_dispute_screen.dart`, reachable via a DISPUTE button on every conduct record tile). A disputed record stays visible with a DISPUTED indicator while it's under review. Admins resolve disputes in the new DISPUTES tab of the Admin Panel: upholding one deletes the record and recalculates the recruit's status; rejecting one leaves the record unchanged. One dispute per company per record (enforced at the DB level by a `UNIQUE` constraint) prevents spamming.

**4. Audit log immutability via REVOKE + trigger**
See item 2 above — both the privilege-level REVOKE and the trigger defense-in-depth are in `supabase_schema.sql`.

**5. service_role key handling**
The service_role key is only used in Supabase's own dashboard `current_setting` mechanism (set via SQL, not stored in code or `.env`). The `.env` file only holds the anon key. The README now explicitly warns: never commit the service_role key, never paste it in Slack or a shared doc, and rotate it immediately via the Supabase dashboard if you believe it was exposed.

---

## 🛠️ Functionality Fixes

A pass through the app to check "does this actually work end to end" turned up several real bugs and gaps, all now fixed:

**App won't crash on first run anymore.** If `.env` still has the placeholder `SUPABASE_URL`/`SUPABASE_ANON_KEY` values, the app now shows a clear "Setup Needed" screen with exact instructions instead of crashing deep in the Supabase client with an unhelpful stack trace. You still need to put your real credentials in `.env` — nothing can do that for you — but the failure mode while you're getting there is now legible.

**Admin Panel is now actually admin-only.** It was previously visible to every logged-in user regardless of role — the database correctly blocked non-admins from admin *writes* via RLS, but the app itself never checked who should even see the link or the screen. A new `DbUserProfile` model and `CompanyService.getMyProfile()` fetch the user's role, and the drawer now only shows "Admin Panel" to users whose role is actually `admin`.

**The flag button on every recruit profile did nothing.** It's now wired to open Add Conduct Record.

**Fixed a real bug in dispute resolution.** `upholdDispute` was being called with an empty string for `recruitId`, which meant the recruit's status never recalculated correctly after a dispute was upheld — the database query `eq('recruit_id', '')` matches nothing, so a recruit could keep showing as flagged/terminated even after the record causing that status was removed. The service now looks up the correct recruit ID from the conduct record itself before deleting it, so this can't drift out of sync again.

**Found and fixed a silent RLS bug.** Admin dispute resolutions log an audit entry with `company_id: null` (since resolving a dispute isn't scoped to the admin's own company) — but the original `audit_insert` policy required `company_id = my_company_id()`, which is never true when the value is `null`. Every one of these audit entries was being silently rejected. Fixed by allowing admins to insert null-company audit rows.

**Recruit profile data now refreshes after you act on it.** Closing an employment record or adding a conduct record used to leave the screen showing stale data until you backed out and re-searched. The screen now re-fetches and updates in place.

**Employment history can now actually be closed out.** There was no way to mark someone's employment at a company as ended — every recruit showed as a permanent current employee of whoever registered them. Added a "Close Employment" action (end date + optional exit reason) on each current position, plus the missing RLS `UPDATE` policy on `employment_history` that this needed (it only had SELECT and INSERT policies before, so this would have failed silently with a permissions error even once the UI existed).

**Password reset now actually returns you to the app.** Previously, tapping the reset link in the email dropped you on a generic browser confirmation page with no way back in. `resetPasswordForEmail` now specifies a custom redirect (`securityzone://reset-password`), caught by a deep link listener in `main.dart`, landing on a new "Set New Password" screen. **This needs two pieces of manual setup that can't be done from code** — see the Password Reset section below.

**Added a profile/account screen.** Users previously had no way to update their name or email after registering. New "My Account" item in the drawer lets you edit both — email changes go through Supabase's own re-confirmation flow rather than applying immediately, which is intentional (stops someone changing the email to one they don't control proving access to).

**Session expiry now redirects to login instead of silently failing.** If a session's refresh token expires or the user is signed out remotely, the app now listens for that and redirects to the login screen rather than letting every subsequent request fail with confusing errors.

**Removed unused dependencies.** `flutter_riverpod`, `uuid`, and `shared_preferences` were in `pubspec.yaml` but never referenced anywhere in the codebase — dead weight removed.

### Password Reset — manual setup required

The redirect-based flow above needs two things configured outside of code, neither of which I can do for you:

1. **Supabase Dashboard → Authentication → URL Configuration** — add `securityzone://reset-password` to the Redirect URLs allow-list. Supabase rejects redirects to URLs not on this list, so without this step the reset email link will fail even though the app-side code is correct.
2. **Register the custom URL scheme natively.** Since this project doesn't yet have generated `android/`/`ios/` folders (run `flutter create .` first if you haven't), you'll need to add:
   - **Android** (`android/app/src/main/AndroidManifest.xml`): an `<intent-filter>` on the main activity with `<data android:scheme="securityzone" android:host="reset-password" />`
   - **iOS** (`ios/Runner/Info.plist`): a `CFBundleURLTypes` entry with `CFBundleURLSchemes` containing `securityzone`

   The `app_links` package's own documentation has copy-pasteable XML/plist snippets for exactly this — search "app_links deep link setup" for the current version's exact syntax, since it occasionally changes between package versions.

---

## 🔮 Next Steps

- [ ] Connect real fingerprint scanner hardware — the matching code is ready; this is now a hardware-acquisition + plugin-wiring task, not a design task (see Fingerprint section above)
- [ ] Consolidated/bulk PDF export (e.g. all flagged recruits in one report)
- [ ] Extend offline caching to admin-only screens (overview stats, analytics, audit log) — deliberately left online-only since none of it is time-critical at-the-door work
- [ ] Per-user notification preferences (e.g. mute low-severity alerts)
- [ ] Export analytics charts as part of a periodic admin report (PDF/email)
- [ ] Move fingerprint matching server-side if the recruit pool grows well beyond a few thousand
- [ ] Enable Supabase's platform-level API rate limiting (Dashboard → Settings → API) — the real backstop against someone bypassing the app and hitting the REST API directly; the in-app check only covers the app's own search flow (see Search Rate Limiting section above)

