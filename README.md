# SVNLY

**7 seconds. One take. Be real.**

SVNLY is an iPhone-first social video app built with Flutter and Supabase. Every user receives the same daily challenge, records exactly seven seconds in-app, and unlocks the day’s feed only after participating. There is no gallery import and no voluntary retake; a retry is issued only after a server-verified technical failure.

## Repository map

- `lib/` — Flutter app, Riverpod state, GoRouter navigation, auth, camera, feed, social, rankings, settings, Plus and admin UI.
- `ios/` — iPhone target, StoreKit configuration, entitlements, privacy manifest, icons and launch screen.
- `supabase/` — reproducible PostgreSQL migrations, RLS/storage policies, seed data and Edge Functions.
- `assets/data/challenges.json` — 400 validated bilingual challenges: 365 scheduled and 35 reserve.
- `site/` — official landing, legal, support and deletion pages; deployed through OpenAI Sites.
- `store_assets/` — App Store Connect copy, review notes and screenshot plans.
- `test/` — unit and widget tests.

## Local setup

1. Install Flutter stable and Xcode 16+ on macOS for iOS builds.
2. Copy `.env.example` to a private environment file and supply the public client values.
3. Start/apply Supabase migrations and seed data.
4. Run:

```sh
flutter pub get
dart run tool/generate_challenges.dart
dart format --set-exit-if-changed lib test tool
flutter analyze lib test tool
flutter test
flutter run --dart-define=APP_ENV=local \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY" \
  --dart-define=REVENUECAT_IOS_API_KEY="$REVENUECAT_IOS_API_KEY" \
  --dart-define=LEGAL_BASE_URL="$LEGAL_BASE_URL"
```

The app fails closed into a configuration screen when backend values are absent. Plus is automatically hidden when the RevenueCat key is absent. No service-role secret is ever compiled into the client.

## Release

`codemagic.yaml` defines a test workflow and a signed iOS/TestFlight workflow. Personal Apple, Supabase, RevenueCat and moderation credentials are intentionally absent; the exact owner-only setup is in `OWNER_ACTIONS_ONLY.md`. Quality evidence and known limitations are in `TEST_REPORT.md` and `FINAL_STATUS.md`.

## Public website

Public production deployment: <https://svnly.sebastian-buergy.chatgpt.site>

The repository records implemented and actually executed gates separately in `TEST_REPORT.md`; Apple signing, TestFlight and physical-device results are reported only after those runs complete.
