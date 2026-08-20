# Ranking System

Rankings are server-derived and never affected by Plus.

For a published take with at least five unique valid viewers:

```text
quality = 40 × min(unique reactions / impressions, 1)
        + 35 × min(unique commenters / impressions, 1)
        + 25 × completed views / impressions

confidence = min(1, ln(1 + impressions) / ln(51))
daily score = quality × confidence
all-time score = sum(daily score + 2 participation points)
```

The minimum sample and logarithmic confidence prevent one early interaction from winning. Rates rather than raw totals reduce follower-count advantage. Only unique, non-self interactions from active accounts count; blocked relationships and removed/unpublished takes score zero. A reaction is unique by `(user,take)`, views by `(viewer,take)`, and commenters are deduplicated.

World and country rankings are materialized after metric changes. Friends rankings filter the appropriate global table through accepted follows. Ties use `dense_rank`; daily ties are deterministically ordered by creation time only after equal scores. Moderation changes trigger recomputation and can remove points retroactively.
