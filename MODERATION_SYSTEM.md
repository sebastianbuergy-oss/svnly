# Moderation System

New takes finalize as `processing` and enter `moderation_queue`. They are never visible in the public feed until status is `published`.

The moderation Edge Function accepts an authenticated/internal request, validates the target, reads trusted moderation artifacts and sends only required frames/metadata to the configured provider. Provider scores can publish, reject or route to human review. Reports create priority-70 queue items. Staff decisions are restricted to auth app-metadata roles and create immutable audit entries.

Content states: `processing`, `published`, `under_review`, `rejected`, `removed`, `deleted`. User states: `active`, `restricted`, `suspended`, `banned`, `deletion_pending`, `deleted`.

Report reasons include nudity/sexual content, violence, harassment, hate, self-harm, dangerous activity, minor safety, spam/scam and other. Blocking is immediate and symmetric for visibility/follow relationships.

Production blocker: server-trusted extraction of at least three frames from the uploaded video must be deployed before automated moderation can be considered complete. Client-generated frames are not trusted.
