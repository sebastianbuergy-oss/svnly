# SVNLY Architecture

## Runtime boundaries

The Flutter client is an untrusted presentation and capture layer. Riverpod owns dependencies/state, GoRouter owns navigation, and `AppRepository` is the only feature-facing backend boundary. `SupabaseRepository` uses the publishable client key and authenticated RPCs; it never receives the service-role key.

Supabase PostgreSQL is authoritative for challenge time, attempt consumption, retries, feed unlock, privacy, block filtering, rankings, streaks, entitlements and account state. Private Storage holds videos, thumbnails, avatars and moderation artifacts. Edge Functions handle privileged deletion, RevenueCat webhooks and moderation-provider calls.

```text
Flutter iPhone app
  -> Supabase Auth (Apple/email)
  -> security-definer RPCs (validated writes and filtered reads)
  -> private Storage (short-lived signed URLs)
  -> Edge Functions (server-only secrets)
  -> PostgreSQL + RLS

RevenueCat webhook -> Edge Function -> entitlements
Moderation provider -> Edge Function -> moderation queue/take status
OpenAI Sites -> public product/legal/support pages
```

## Capture lifecycle

`issued -> started -> upload_reserved -> finalized`. Recording begins only after `mark_attempt_started`, stops automatically after seven seconds and offers no voluntary discard/retake. A failed upload is persisted under app support and resumed after restart. `request_technical_retry` grants at most one retry only when the server sees no finalized storage path.

## Environments

`APP_ENV` supports `local`, `staging` and `production`. Supabase URL/publishable key, RevenueCat public iOS key and legal base URL are compile-time Dart defines. Provider secrets remain in Supabase/Codemagic secret stores.
