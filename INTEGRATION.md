# Integration Guide — Scholarship Application + Review Flow

Drop-in addition to the existing **Scholar Wallet v2.0.0+3** codebase
(Firebase Auth + Supabase, Flutter). Nothing in the existing allowance /
QR-claim / expense flow is changed.

## Files in this package

| File | Copy to | Purpose |
|---|---|---|
| `supabase_application_flow.sql` | Supabase SQL editor (run once) | 3 new tables + 2 RPCs + storage bucket |
| `lib/models/scholarship_models.dart` | same path | `ScholarshipProgram`, `ScholarshipApplication`, `ApplicationReview`, `ApplicationStatus` |
| `lib/services/scholarship_service.dart` | same path | all Supabase reads/writes; decisions go through RPC only |
| `lib/screens/application_screen.dart` | same path | SCHOLAR: application process + status tracking |
| `lib/screens/admin/application_review_screen.dart` | same path | ADMIN: review process with full audit trail |

## Step 1 — Run the SQL

Open the Supabase SQL editor and run `supabase_application_flow.sql`.
It is **additive-only** (`create table if not exists`, `create or replace
function`) and does not touch `profiles`, `allowance_claims`, etc.

**RLS note:** the whole build authenticates through **Firebase** and talks to
Supabase with the anon/publishable key — there is no Supabase JWT, so
`auth.uid()` policies would block every query (that is why every existing
table runs with RLS disabled). The new tables follow the same posture, and the
SQL file ends with a commented, ready-to-run policy block for the future
Firebase→Supabase JWT migration.

## Step 2 — Wire the screens

### Scholar side — `lib/screens/home_screen.dart`

Add one QuickAction next to the existing three:

```dart
QuickAction(
  icon: Icons.school_rounded,
  label: 'My\nApplication',
  onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ApplicationScreen())),
),
```

…with `import 'application_screen.dart';` at the top.

### Admin side — `lib/screens/admin/admin_dashboard_screen.dart`

```dart
import 'application_review_screen.dart'; // add to imports

// In the ADMINISTRATIVE CONTROLS grid, add:
_control(Icons.school_outlined, 'Application\nReview', () async {
  await Navigator.push(context,
      MaterialPageRoute(builder: (_) => const ApplicationReviewScreen()));
  _load();
}),
```

No `AppState` changes are required — both screens instantiate
`ScholarshipService` directly, matching how `ClaimsScreen` uses
`context.read<AppState>().wallet`.

## Step 3 — (Optional) seed a first scholarship

```sql
insert into scholarship_programs (title, description, requirements)
values ('Scholar Wallet Scholarship',
        'Scholarship for active scholars.',
        'Enrolled full-time; GPA 85%+; motivation statement.');
```

## How it fits the existing architecture

- **Auth:** Firebase UID == `profiles.id`, exactly like every existing table.
- **State changes server-side only:** submission = RPC `submit_application`
  (enforces one-live-application + admin notification); decisions = RPC
  `record_application_review` (enforces admin role, appends the audit row,
  notifies the scholar, activates approved scholars). The Dart code never
  writes `status` directly — same pattern as `claim_allowance`.
- **Notifications:** reuses the existing `notifications` table + Supabase
  Realtime feed. New `type` values your `NotificationsScreen` may want to
  style: `application_submitted`, `application_under_review`,
  `application_needs_info`, `application_approved`, `application_rejected`.
- **Payout link:** an approved scholar's profile flips `is_active = true`, so
  they immediately appear in Manage Scholars and can be included in payout
  batches (`is_active` is already required by the payout flow). No change to
  the QR claim logic.
- **Terminology:** single vocabulary everywhere — *Application* (request),
  *Review* (admin decision), *Payout* (money movement). The word
  "withdrawal" appears nowhere in the new code (v2 removed that flow).

## Notes for the Scholar Wallet documentation

- The `application_reviews` table is the **audit trail** of the review
  process — every decision row records reviewer, decision, notes, timestamp.
- The application stores a **snapshot** of the applicant's profile
  (student number, university, course, year level) at submission time, so
  later profile edits can never rewrite what was reviewed.
- `flutter analyze` could not be run in this environment (no Flutter SDK
  installed) — run it once the files are copied into the project.
