# Test Report

Date: 2026-08-21
Host: Windows 11, Flutter 3.47.0, Dart 3.13.0

## Executed

| Gate | Result | Evidence |
|---|---|---|
| Dart formatting | Pass | App, tool, integration and driver sources formatted |
| Flutter static analysis | Pass | Final run: `No issues found` |
| Flutter tests | Pass | 30/30 unit/widget tests |
| Challenge generator | Pass | Exactly 400 bilingual entries: 365 scheduled + 35 reserve |
| Backend static contract | Pass | 28 mandatory tables with RLS, nine critical RPCs, four private buckets |
| Website production build | Pass | Vinext 1.0.0-beta.2; six routes built |
| PostgreSQL RLS behavior | Pass | 12/12 cross-role policy tests on PostgreSQL-compatible PGlite |
| Release automation tests | Pass | 2/2 review-account configuration tests |
| Edge type checks | Pass | APNs, device registration, moderation and scheduled jobs |
| Website route matrix | Pass | 6/6 production server-render tests, including five public routes |
| Website deployment | Pass | Sites version 2 deployed publicly; four cookie-free HTTP 200 checks |

Covered automated behavior additionally includes authentication widgets, challenge states, notification/APNs preferences, privacy settings, rankings, trusted frame-extraction service behavior and true RLS allow/deny paths.

## Not executed or incomplete

- The Codemagic macOS simulator workflow is implemented but could not start because no SVNLY Git remote/application exists in Codemagic; a Git transport credential is present, but GitHub's API returned 403 for repository creation.
- No signed iOS build/archive: Apple signing and App Store Connect credentials are not present.
- No physical iPhone camera, microphone, flash, background, Apple login, APNs, StoreKit purchase/restore or interruption test.
- Production Supabase credentials are absent, so migrations, review-account provisioning, APNs delivery and scheduled jobs were not executed against the production project.
- The iOS integration journeys and five real simulator screenshot captures await the Codemagic run.
- Trusted frame extraction, APNs delivery and scheduler paths are implemented and type-/contract-tested, but external provider delivery awaits production secrets.
- No dependency CVE scanner was available locally; Codemagic records dependency inventory/outdated packages but should add OSV or equivalent before release.

This report deliberately distinguishes verified code from configuration- or hardware-dependent work.
