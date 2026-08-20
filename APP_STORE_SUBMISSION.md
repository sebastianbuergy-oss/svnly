# App Store Submission Runbook

1. Complete every item in `OWNER_ACTIONS_ONLY.md` and run the `svnly-tests` Codemagic workflow.
2. Apply all Supabase migrations in order, seed challenges, deploy Edge Functions and configure server-only secrets.
3. Run disposable-project RLS tests using user A, user B, private user C, moderator and admin. Confirm A cannot read/write B’s private rows/media.
4. Run `svnly-ios-release`. Download and inspect the `.xcarchive`/`.ipa`, then install the TestFlight build on a physical iPhone.
5. Validate the full capture, interruption, moderation, feed, social, block, deletion, push and StoreKit matrices. Capture real DE/EN screenshots only from the approved build.
6. In App Store Connect → My Apps → SVNLY, enter the copy from `store_assets/`, upload screenshots, configure the privacy/support URLs and complete privacy, age rating and export compliance forms.
7. Add the two normal-product review accounts described in `store_assets/APP_REVIEW_NOTES.md`; never add a hidden reviewer bypass.
8. Attach the Plus paywall screenshot and submit both IAP products with the app version if Plus is enabled. Otherwise disable the remote premium flag and omit unavailable purchase claims.
9. Select the processed TestFlight build, paste review notes, answer content-rights/advertising questions truthfully and submit for review.

Do not submit while moderation frame extraction, public legal URLs, actual-device tests, screenshots or multi-user RLS tests remain incomplete.
