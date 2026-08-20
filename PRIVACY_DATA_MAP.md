# Privacy Data Map

| Data | Purpose | Location | Visibility |
|---|---|---|---|
| Auth email/provider ID | Account access | Supabase Auth | User/admin service |
| Birth date | Age gate | `user_private` | User/staff only |
| Username, display name, country, bio/avatar | Social identity/rankings | `profiles`, private avatar bucket | According to profile/privacy rules |
| Video, thumbnail | Daily participation/feed | private Storage + `takes` | Signed URL after feed/privacy checks |
| Camera/microphone | Capture seven-second take | On device during capture | Uploaded take only |
| Reactions/comments/follows/blocks/reports | Social and safety | PostgreSQL | Filtered by RPC/RLS |
| Device token/preferences | Push delivery | PostgreSQL | User/service only |
| Purchases/entitlement | Plus access | RevenueCat + `entitlements` | User/service only |
| Diagnostics/analytics | Reliability/product measurement | `analytics_events` | Staff; minimized payload |
| Support/deletion requests | User support/legal execution | PostgreSQL | User/staff/service |

No precise location, address book, tracking identifier or gallery access is required. Country is user-selected and rate-limited server-side. The iOS privacy manifest and App Store answers must be kept synchronized with production SDK behavior.
