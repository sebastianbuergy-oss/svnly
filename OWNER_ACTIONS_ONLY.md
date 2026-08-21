# Owner Actions Only — Current Handoff

## Run the prepared unsigned iOS simulator proof

- Platform: Codemagic, application `svnly` (`6a888dbb0daaee7ef954a2a7`).
- Path: **Applications → svnly → Start your first build**.
- Already selected: branch **`main`** and workflow **`SVNLY iOS simulator, native Live Looks and integration`**.
- Action: press **Start new build** once. Do not switch to the TestFlight workflow yet.
- Expected result: Flutter/widget/integration/RLS/Edge Function checks, the native AVFoundation Live Look test, an unsigned iOS Simulator app and five real simulator screenshot artifacts.

Codemagic is connected through the GitHub provider to the private repository `sebastianbuergy-oss/svnly`, and the root `codemagic.yaml` is active and visible in the application settings.

## Next identity-bound TestFlight action

After the simulator workflow succeeds, the one required owner step is:

**App Store Connect → Users and Access → Integrations → App Store Connect API → +** → create key `SVNLY Codemagic` with role **App Manager**, download the `.p8` once, and retain its **Issuer ID** and **Key ID**.

That private Apple credential cannot be created or transmitted by Codex. The repository already contains the signed `svnly-ios-release` workflow and TestFlight publishing configuration that will consume the Codemagic integration named `svnly-app-store-connect` once the key is installed.
