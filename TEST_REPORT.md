# Test Report

Date: 2026-08-20  
Host: Windows 11, Flutter 3.47.0, Dart 3.13.0

## Executed

| Gate | Result | Evidence |
|---|---|---|
| Dart formatting | Pass | 34 app/tool files plus six tests formatted |
| Flutter static analysis | Pass | Final `No issues found` run completed in 38.7 s |
| Flutter tests | Pass | 20/20 unit/widget tests |
| Challenge generator | Pass | Exactly 400 bilingual entries: 365 scheduled + 35 reserve |
| Backend static contract | Pass | 28 mandatory tables with RLS, nine critical RPCs, four private buckets |
| Website production build | Pass | Vinext 1.0.0-beta.2; six routes built |
| Website HTTP smoke test | Pass | Local production server returned HTTP 200 and SVNLY title |
| Website deployment | Pass | Sites version 1 deployed owner-only |

Covered automated behavior: UTC challenge timing, streaks, ranking normalization, technical retry, capture permissions, premium expiry, block visibility, username validity/reserved names, config fail-closed gates, challenge/attempt parsing, feed/comment defaults, localization, safe error mapping and onboarding rendering.

## Not executed or incomplete

- No signed iOS build/archive: Xcode and Apple signing are unavailable on Windows.
- No physical iPhone camera, microphone, flash, background, Apple login, APNs, StoreKit purchase/restore or interruption test.
- No live Supabase database migration/RLS execution with users A/B/C, moderator and admin. The current backend test is structural, not an authorization proof.
- The requested 30-path end-to-end suite and full widget matrix are not implemented; only the 14-test foundation above is green.
- No production moderation provider/frame extractor, APNs sender/scheduler or RevenueCat webhook was exercised.
- No dependency CVE scanner was available locally; Codemagic records dependency inventory/outdated packages but should add OSV or equivalent before release.

This report deliberately distinguishes verified code from configuration- or hardware-dependent work.
