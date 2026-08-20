# Release Checklist

## Source gates

- [x] iPhone-only Flutter target and bundle ID `ch.sebastianbuergy.svnly`
- [x] App icon, launch screen, privacy manifest, camera/microphone strings
- [x] No gallery picker and no voluntary retake UI
- [x] Private Storage/RLS migrations and security-definer RPC boundary
- [x] 400 deterministic bilingual challenges
- [x] Local formatter, analyzer and 14 tests green at recorded checkpoint
- [x] Legal/support/deletion website deployed owner-only
- [ ] Run final formatter/analyzer/tests on committed source in Codemagic
- [ ] Execute migrations and multi-role RLS tests on disposable Supabase
- [ ] Deploy trusted transcoding/frame extraction and moderation provider
- [ ] Deploy APNs sender/scheduler and validate token lifecycle
- [ ] Complete 30-path integration suite and requested widget coverage

## iOS/TestFlight

- [ ] Apple Developer membership active
- [ ] Explicit App ID/capabilities provisioned
- [ ] Sign in with Apple and APNs keys stored securely
- [ ] App Store Connect app record and IAP products created
- [ ] Codemagic integration/secret group configured
- [ ] Signed Release IPA/archive produced
- [ ] StoreKit purchase and restore validated
- [ ] Physical iPhone matrix passed
- [ ] TestFlight upload/install/smoke test passed

## Store submission

- [x] DE/EN metadata drafts, privacy/age/export answers and review notes
- [x] Privacy, terms, guidelines, support and deletion routes
- [ ] Replace owner-only website access with public access before submission
- [ ] Generate and inspect actual-device DE/EN screenshots in accepted sizes
- [ ] Create reviewer accounts A and B in production
- [ ] Confirm privacy answers against final SDK/network capture
- [ ] Upload screenshots/metadata and attach IAP review screenshot
- [ ] Submit only when every applicable checkbox above is green
