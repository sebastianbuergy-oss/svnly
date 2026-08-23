-- Keep the production launch window covered until the generated annual schedule
-- starts on 2026-09-01. The current_challenge RPC treats scheduled rows whose
-- publish window is open as live, so this remains safe if the scheduler is late.
insert into public.challenges(
  challenge_date,
  title_en,
  title_de,
  description_en,
  description_de,
  category,
  safety_notes,
  status,
  publish_at,
  expires_at
)
select
  launch_day,
  'Show one small thing that made today better.',
  'Zeig eine kleine Sache, die deinen Tag besser gemacht hat.',
  'Keep it safe, show no private documents or exact location, and finish in one seven-second take.',
  'Bleib sicher, zeig keine privaten Dokumente oder genauen Orte und filme alles in einem sieben-sekündigen Take.',
  'mood',
  'No dangerous movement, private data, or exact location.',
  'scheduled'::public.challenge_status,
  launch_day::timestamptz,
  launch_day::timestamptz + interval '1 day'
from generate_series(date '2026-08-23', date '2026-08-31', interval '1 day') as days(launch_day)
on conflict (challenge_date) do nothing;
