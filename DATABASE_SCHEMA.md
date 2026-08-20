# Database Schema

Migrations are ordered under `supabase/migrations/` and seed data is in `supabase/seed.sql`.

| Domain | Tables |
|---|---|
| Identity | `profiles`, `user_private`, `user_settings`, `terms_acceptances` |
| Daily participation | `challenges`, `take_attempts`, `takes`, `take_metrics`, `take_views` |
| Social graph | `reactions`, `comments`, `follows`, `blocks`, `reports` |
| Trust & safety | `moderation_queue`, `moderation_actions`, `admin_audit_log` |
| Progress | `badges`, `user_badges`, `daily_rankings`, `all_time_rankings` |
| Messaging | `device_tokens`, `notification_preferences`, `notifications` |
| Commerce/support | `entitlements`, `support_tickets`, `account_deletion_jobs` |
| Operations | `app_config`, `analytics_events` |

User-owned rows reference `auth.users` with explicit cascade/set-null behavior. Attempts are unique per user/challenge/retry slot. Takes have a unique attempt and user/challenge pair. Social relations use composite uniqueness. Ranking tables are derived, not client-writable.

Challenge dates and expiry are server timestamps. Production uses UTC as the global day boundary; device time cannot issue a challenge or advance a streak.
