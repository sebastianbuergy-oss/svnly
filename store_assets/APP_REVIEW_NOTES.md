# App Review Notes

SVNLY gives every user the same UTC-based daily video prompt. The camera records automatically for seven seconds after a 3–2–1 countdown. There is no gallery import, stop button or voluntary retake. A technical retry is available only when the server verifies that no valid upload was finalized.

The feed is intentionally locked until the user submits today’s take. This is the normal product for every user, not a reviewer-only restriction.

## Review path

1. Sign in with review account B to test profile/challenge/camera. Tap the primary camera action, grant camera/microphone permission and complete the countdown. The recording stops automatically.
2. After upload/moderation, open Discover and switch Friends/Country/World.
3. Long-press or use the overflow actions on a take/profile to report or block. Blocking removes both follow directions and immediately hides interaction.
4. Account deletion: Settings → Privacy & Account → Delete Account → confirm. The profile is disabled immediately and the deletion job starts.
5. Community Guidelines: Settings → Legal → Community Guidelines, or the public `/community` URL.
6. Plus: Settings → SVNLY Plus. Test monthly/yearly StoreKit sandbox purchase and Restore Purchases. Plus never changes ranking or attempt count.

## Review accounts

- Account A is a confirmed public profile (`review.primary`) with a completed production onboarding state.
- Account B is a confirmed private profile (`review.secondary`) with a completed production onboarding state.
- The accounts follow each other with an accepted relationship, so Friends and private-profile behavior can be reviewed immediately.
- Their email/password values come from the encrypted Codemagic variables `APP_REVIEW_PRIMARY_*` and `APP_REVIEW_SECONDARY_*`; credentials are entered in App Store Connect review notes and are never committed.
- `node tool/provision_review_accounts.mjs` creates or repairs both accounts idempotently and verifies both production profiles. The TestFlight workflow runs this before signing.

Neither account receives a hidden challenge or moderation bypass. Both begin each UTC day without a take; the reviewer records normally. If automated moderation delays publication, the take displays its normal processing/review state.
