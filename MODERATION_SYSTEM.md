# Moderation System

New takes finalize as `processing` and enter `moderation_queue`. They are never visible in the public feed until status is `published`.

The signed iOS app extracts three fixed-time JPEG frames from the final encoded MP4 (0.70 s, 3.50 s and 6.30 s). It uploads them once to the private `moderation-artifacts` bucket before finalization. Storage RLS permits only the owner of the still-reserved take to insert the three exact paths; updates are denied. The moderation Edge Function downloads the immutable frames with its service role, verifies JPEG integrity and SHA-256 hashes, writes the audit manifest, and sends only the three short-lived private image URLs to OpenAI's free Moderation endpoint. No separate video worker, GPU or paid moderation service is required for V1.

Provider scores can publish, reject or route to human review. Reports create priority-70 queue items. Staff decisions are restricted to auth app-metadata roles and create immutable audit entries. Moderator self-approval is denied. Participation/feed unlock remains independent of the later moderation result.

Content states: `processing`, `published`, `under_review`, `rejected`, `removed`, `deleted`. User states: `active`, `restricted`, `suspended`, `banned`, `deletion_pending`, `deleted`.

Report reasons include nudity/sexual content, violence, harassment, hate, self-harm, dangerous activity, minor safety, spam/scam and other. Blocking is immediate and symmetric for visibility/follow relationships.

The client-frame path is deliberately a V1 cost tradeoff: it validates the same final MP4 used for upload and makes the artifacts immutable, but a compromised client could still substitute frames. Reports, blocking, human escalation and immutable audit history remain the defense-in-depth path. A server-side extractor can replace this path later without changing the take state machine.
