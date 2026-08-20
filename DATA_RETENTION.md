# Data Retention

- Pending local upload files are removed after confirmed finalization; failed uploads remain only until resumed, expired or manually cleared by app lifecycle policy.
- Users may select take auto-deletion at 30, 90 or 365 days, or no automatic deletion. A scheduled server job must enforce this value.
- Deleted comments are tombstoned for thread integrity; moderation/audit records retain the minimum needed for safety and legal defense.
- Account deletion immediately blocks use and queues deletion/anonymization of profile/private data, media, social rows, tokens, entitlements and analytics identifiers; Supabase Auth deletion completes the job.
- Backups follow the hosting provider’s backup expiry and are not restored selectively for active product use.

Exact statutory retention periods and the controller identity must be approved by qualified counsel before public launch. The public privacy page states contact and deletion mechanisms but is not a substitute for jurisdiction-specific legal review.
