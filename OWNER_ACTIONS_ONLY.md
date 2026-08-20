# Owner Actions Only

These actions require Sebastian’s identity, private credentials, contracts/payment account or physical device. Technical implementation gaps remain separately listed in `FINAL_STATUS.md`.

## 1. Apple Developer identifiers and capabilities

- Platform: Apple Developer.
- Path: Certificates, Identifiers & Profiles → Identifiers → App IDs → Plus.
- Value: Description `SVNLY`; Bundle ID `ch.sebastianbuergy.svnly`; enable Sign in with Apple and Push Notifications.
- Why: Apple binds signing, Apple login and APNs to the owner’s developer team.
- Verify: The identifier page shows both capabilities and exactly that bundle ID.

## 2. Private Apple keys

- Sign in with Apple: Apple Developer → Certificates, Identifiers & Profiles → Keys → Plus → name `SVNLY Sign In` → enable Sign in with Apple → configure primary App ID → download the `.p8` once.
- APNs: same Keys screen → Plus → name `SVNLY APNs` → enable Apple Push Notifications service → download the `.p8` once.
- App Store Connect API: App Store Connect → Users and Access → Integrations → App Store Connect API → Plus → name `SVNLY Codemagic` → role App Manager → download `.p8`, record Issuer ID and Key ID.
- Why: Private keys prove Sebastian’s Apple identity and cannot be generated or accepted on his behalf.
- Verify: Each key is active, stored in the password manager/secret store and never committed.

## 3. App Store Connect app and purchases

- Path: App Store Connect → My Apps → Plus → New App.
- Values: iOS; Name `SVNLY`; Primary Language English (U.S.); Bundle ID `ch.sebastianbuergy.svnly`; SKU `SVNLY-IOS-001`.
- Then: Monetization → Subscriptions → group `SVNLY Plus`; products `svnly_plus_monthly` and `svnly_plus_yearly`; complete pricing, banking/tax agreements and review information.
- Why: Creating commercial records and accepting paid agreements requires the account holder.
- Verify: App Apple ID exists, both product IDs match `ios/Runner/SVNLY.storekit`, and agreements show Active.

## 4. Supabase and RevenueCat ownership

- Supabase: Dashboard → New project → name `SVNLY Production`; retain the project URL and publishable key; never expose the service-role key. Configure Auth → Providers → Apple with the Apple values, and URL Configuration redirect `svnly://auth-callback`.
- RevenueCat: Projects → New project `SVNLY` → Apps → App Store → bundle `ch.sebastianbuergy.svnly`; entitlement `plus`; offering `default`; attach both product IDs; upload the App Store In-App Purchase key under integrations.
- Why: Project ownership, provider credentials and commercial data require Sebastian’s accounts.
- Verify: A real Apple/email session can read the challenge; RevenueCat customer info returns entitlement `plus` after StoreKit sandbox purchase and restore.

## 5. Codemagic private integration

- Path: Codemagic → Team settings → Integrations → Developer Portal → Add key.
- Value: reference name exactly `svnly-app-store-connect`; upload the App Store Connect `.p8`, Issuer ID and Key ID.
- Path: Team settings → Global variables and secrets → group exactly `svnly_production`.
- Values: `APP_STORE_APPLE_ID`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `REVENUECAT_IOS_API_KEY`; mark values sensitive where offered.
- Why: Signing and uploading require owner-scoped secrets.
- Verify: `svnly-tests` passes, then `svnly-ios-release` produces a signed IPA and a processed TestFlight build.

## 6. Physical iPhone validation

- Platform: TestFlight on Sebastian’s iPhone running iOS 16 or later.
- Path: App Store Connect → TestFlight → Internal Testing → add Sebastian → install the latest SVNLY build.
- Test: front/rear camera, microphone, flash, exact duration, looks, background/kill/resume, offline upload, Apple login, APNs, purchase/restore, block/report and deletion.
- Why: Camera/audio/hardware interruptions and StoreKit/APNs behavior cannot be proven on this Windows host.
- Verify: Record the device/iOS/build and every pass/failure in `TEST_REPORT.md`; do not submit on any failure.

## 7. Legal/controller approval and public website access

- Provide the legal controller name/address, privacy/support contact and approved retention/legal wording to qualified counsel.
- In Codex/Sites, change access for project `appgprj_6a873c0c072c8191a7992b9f75ab6d3e` from owner-only to Public only after approval.
- Why: Identity disclosures, legal approval and publication authorization belong to the controller.
- Verify: Privacy, terms, community, support and account-deletion URLs load without login and match App Store Connect entries.
