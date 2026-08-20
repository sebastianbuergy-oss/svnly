# Security

## Threat model and controls

- A modified client cannot choose the global challenge, create extra attempts, unlock the feed or finalize another user’s upload because those decisions are server-side RPCs.
- Nonces, unique constraints and row locks make attempt operations replay-resistant and idempotent.
- Apple login uses a cryptographically random nonce and SHA-256 challenge.
- No gallery picker exists. Camera capture is automatic, seven seconds, and has no voluntary retake control.
- Private media is served by expiring signed URLs. Client logs receive mapped messages rather than backend details.
- Blocks delete both follow directions immediately and are included in feed, comments, rankings, reactions and view scoring.
- RevenueCat webhook authorization and moderation-provider keys are server-only.
- Account deletion immediately marks the profile `deletion_pending`, signs out the device, and delegates destructive cleanup to a privileged job.

## Secret handling

`.env.example` contains placeholders only. `.gitignore` excludes environment files and Apple key/profile formats. Codemagic performs a pattern-based secret scan. Before production, rotate any credential ever pasted into chat/logs and use Supabase/Codemagic secret stores.

## Known hardening work

The moderation function expects trusted extracted frames, but a production transcoding/frame-extraction worker is not included in this Windows-only build. Push delivery requires the APNs provider key and server scheduler. These are release blockers, not hidden fallbacks.
