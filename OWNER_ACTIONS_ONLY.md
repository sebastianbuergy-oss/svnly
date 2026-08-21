# Owner Actions Only — Current Next Action

Only one owner action is current. Do not perform the later Apple or commercial setup until the Git remote and unsigned simulator workflow have completed.

## Complete the GitHub two-factor sign-in now

- Platform: the already open Codex in-app browser tab on `github.com/login`.
- Path: **GitHub → Sign in → account `sebastianbuergy-oss` → Password → Verify with your configured two-factor method**.
- Stop after the normal authenticated GitHub home page appears; do not create a repository manually.
- Why: the stored Git transport credential cannot call GitHub's repository API (HTTP 403), and Codemagic currently has no SVNLY application. After this one sign-in, Codex can create the private `svnly` repository, push all commits, register it through the existing Codemagic API token, run `svnly-ios-simulator`, collect the five screenshots and then continue to Apple signing.
- Verify: the browser no longer shows the GitHub sign-in form and the avatar menu is visible.

---

The sections below are later identity-bound release actions, retained for reference but they are not the current requested action.

These actions require Sebastian’s identity, private credentials, contracts/payment account or physical device. Technical implementation gaps remain separately listed in `FINAL_STATUS.md`.

## Later: Apple Developer identifiers and capabilities

- Platform: Apple Developer.
- Path: Certificates, Identifiers & Profiles → Identifiers → App IDs → Plus.
- Value: Description `SVNLY`; Bundle ID `ch.sebastianbuergy.svnly`; enable Sign in with Apple and Push Notifications.
- Why: Apple binds signing, Apple login and APNs to the owner’s developer team.
- Verify: The identifier page shows both capabilities and exactly that bundle ID.

## Later: Private Apple keys

- Sign in with Apple: Apple Developer → Certificates, Identifiers & Profiles → Keys → Plus → name `SVNLY Sign In` → enable Sign in with Apple → configure primary App ID → download the `.p8` once.
- APNs: same Keys screen → Plus → name `SVNLY APNs` → enable Apple Push Notifications service → download the `.p8` once.
- App Store Connect API: App Store Connect → Users and Access → Integrations → App Store Connect API → Plus → name `SVNLY Codemagic` → role App Manager → download `.p8`, record Issuer ID and Key ID.
- Why: Private keys prove Sebastian’s Apple identity and cannot be generated or accepted on his behalf.
- Verify: Each key is active, stored in the password manager/secret store and never committed.

## Later: App Store Connect app and purchases

- Path: App Store Connect → My Apps → Plus → New App.
- Values: iOS; Name `SVNLY`; Primary Language English (U.S.); Bundle ID `ch.sebastianbuergy.svnly`; SKU `SVNLY-IOS-001`.
- Then: Monetization → Subscriptions → group `SVNLY Plus`; products `svnly_plus_monthly` and `svnly_plus_yearly`; complete pricing, banking/tax agreements and review information.
- Why: Creating commercial records and accepting paid agreements requires the account holder.
- Verify: App Apple ID exists, both product IDs match `ios/Runner/SVNLY.storekit`, and agreements show Active.

## Later: Supabase and RevenueCat ownership

- Supabase: Dashboard → New project → name `SVNLY Production`; retain the project URL and publishable key; never expose the service-role key. Configure Auth → Providers → Apple with the Apple values, and URL Configuration redirect `svnly://auth-callback`.
- RevenueCat: Projects → New project `SVNLY` → Apps → App Store → bundle `ch.sebastianbuergy.svnly`; entitlement `plus`; offering `default`; attach both product IDs; upload the App Store In-App Purchase key under integrations.
- Why: Project ownership, provider credentials and commercial data require Sebastian’s accounts.
- Verify: A real Apple/email session can read the challenge; RevenueCat customer info returns entitlement `plus` after StoreKit sandbox purchase and restore.

## Later: Codemagic private integration

- Path: Codemagic → Team settings → Integrations → Developer Portal → Add key.
- Value: reference name exactly `svnly-app-store-connect`; upload the App Store Connect `.p8`, Issuer ID and Key ID.
- Path: Team settings → Global variables and secrets → group exactly `svnly_production`.
- Values: `APP_STORE_APPLE_ID`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `REVENUECAT_IOS_API_KEY`; mark values sensitive where offered.
- Why: Signing and uploading require owner-scoped secrets.
- Verify: `svnly-tests` passes, then `svnly-ios-release` produces a signed IPA and a processed TestFlight build.

## Later: Physical iPhone validation

- Platform: TestFlight on Sebastian’s iPhone running iOS 16 or later.
- Path: App Store Connect → TestFlight → Internal Testing → add Sebastian → install the latest SVNLY build.
- Test: front/rear camera, microphone, flash, exact duration, looks, background/kill/resume, offline upload, Apple login, APNs, purchase/restore, block/report and deletion.
- Why: Camera/audio/hardware interruptions and StoreKit/APNs behavior cannot be proven on this Windows host.
- Verify: Record the device/iOS/build and every pass/failure in `TEST_REPORT.md`; do not submit on any failure.

## Later: Legal/controller approval

- Provide the legal controller name/address, privacy/support contact and approved retention/legal wording to qualified counsel.
- Why: Identity disclosures, legal approval and publication authorization belong to the controller.
- Verify: Approved controller details match the already public privacy, terms, community, support and account-deletion pages and App Store Connect entries.
