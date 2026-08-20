# Row-Level Security

Every application table has RLS enabled. The CI contract checker currently verifies all 28 mandatory tables plus the derived `take_views` table definition. Direct table grants are minimized; normal mutations pass through RPCs that validate `auth.uid()` and use `security definer set search_path = ''`.

Key controls:

- `user_private`, settings, device tokens, notifications, entitlements and deletion jobs are self-only; staff reads are explicit where required.
- Raw `takes` are self/staff readable. Feed access is only through `get_daily_feed`, which requires the caller’s valid daily participation and filters privacy/follows/blocks/status.
- Reactions/comments/follows/blocks/reports are written through RPCs; ownership, target status and block state are checked server-side.
- Moderation/admin RPCs require the role stored in immutable auth app metadata and write `admin_audit_log`.
- Storage buckets are private. Object names are scoped to the authenticated owner/attempt; feed playback uses short-lived signed URLs.
- `take_views` has no direct authenticated policy. Only `record_take_view` can record a non-self, non-blocked view of a published take.

`tool/verify_backend_contract.dart` is a static migration contract gate. It does not replace execution against a disposable Supabase/PostgreSQL instance; that live multi-user RLS test remains a CI/environment setup item.
