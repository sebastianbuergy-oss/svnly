# SVNLY Final Status

## Build identity

| Item | Value |
|---|---|
| App version | 1.0.0 |
| Build number | 1 locally; Codemagic increments from App Store Connect |
| Release source commit | `e19cfc804c37316db0d501eba4be77f37449b127` |
| Flutter | 3.47.0 stable, revision `4cf2416426` |
| Dart | 3.13.0 stable |
| iOS deployment target | 16.0 |
| Bundle ID | `ch.sebastianbuergy.svnly` |

## Verified results

- Flutter analysis: **PASS**, final local run reported no issues in 38.7 seconds.
- Flutter tests: **PASS**, 20/20.
- Static SQL/RLS contract: **PASS**, 28 mandatory tables with RLS, nine critical RPCs and four private buckets; derived `take_views` also has RLS.
- Challenge corpus: **PASS**, 400 bilingual prompts (365 scheduled + 35 reserve).
- Website: **PASS**, production build, HTTP smoke test and Sites version 1 deployment.
- Release iOS build/sign/archive: **NOT RUN** (Windows host/no Apple credentials).
- TestFlight: **NOT UPLOADED**.
- App Review: **NOT SUBMITTED**.

## Implemented

Flutter navigation/design, four-screen onboarding, Apple/email auth adapters, age/terms profile setup, server challenge/attempt/retry flow, exact timed camera UI, persisted uploads, locked/private feed, playback/view metrics, reactions/comments/follows/blocks/reports, rankings/streaks/badges backend, settings/support/deletion, RevenueCat adapter/StoreKit config, admin moderation UI, 400 challenge seed, database/RLS/storage migrations, Edge Functions, legal/marketing website and Codemagic workflows.

## Genuine release blockers and gaps

1. Live Looks are currently rendered as client preview color transforms and are not proven to be burned into the encoded video. Native Core Image/Metal output processing remains incomplete.
2. Automated moderation has no deployed trusted server-side frame extraction/transcoding worker. The Edge Function cannot safely rely on client-supplied frames.
3. APNs token registration UI/data exists, but the provider sender, daily/streak scheduler and delivery receipts are not implemented/tested.
4. Upload pipeline lacks production-grade codec/resolution/file-size validation, compression and trusted thumbnail generation.
5. The 30-path end-to-end suite, requested full widget matrix and live five-role RLS test suite are incomplete.
6. Migrations were not executed against a real Supabase/PostgreSQL instance in this environment; the SQL check is structural only.
7. No macOS iOS Release build, signing, archive, TestFlight upload or physical-device test occurred.
8. Actual-device App Store screenshots (DE/EN) and reviewer accounts do not yet exist.
9. Legal text and App Store privacy/age answers are product drafts and need controller/counsel approval against final production behavior.

Therefore this repository is a substantial release candidate, **not 100% App-Store-ready and not submitted**. The gaps above must not be reclassified as owner-only credential steps.

## Deployment

Owner-protected website: <https://svnly.sebastian-buergy.chatgpt.site>  
Sites project: `appgprj_6a873c0c072c8191a7992b9f75ab6d3e`, version 1.
