import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {corsHeaders, json} from '../_shared/cors.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const openAiKey = Deno.env.get('OPENAI_API_KEY');

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', {headers: corsHeaders});
  if (request.method !== 'POST') return json({error: 'method_not_allowed'}, 405);
  const authorization = request.headers.get('Authorization');
  if (!authorization) return json({error: 'authentication_required'}, 401);
  const caller = createClient(url, anonKey, {global: {headers: {Authorization: authorization}}});
  const {data: {user}} = await caller.auth.getUser();
  if (!user) return json({error: 'invalid_session'}, 401);
  const {takeId} = await request.json();
  const admin = createClient(url, serviceKey, {auth: {persistSession: false}});
  const {data: take} = await admin.from('takes').select('id,user_id,status').eq('id', takeId).single();
  if (!take || (take.user_id !== user.id && !['admin','moderator'].includes(user.app_metadata?.role))) {
    return json({error: 'not_found'}, 404);
  }
  const {data: frames} = await admin.storage.from('moderation-artifacts').list(`${takeId}/frames`, {limit: 3, sortBy: {column: 'name', order: 'asc'}});
  if (!openAiKey || !frames || frames.length < 3) {
    await admin.from('takes').update({status: 'under_review', moderation_reason: 'automated_check_unavailable'}).eq('id', takeId);
    await admin.from('moderation_queue').update({priority: 80}).eq('target_id', takeId).eq('status', 'open');
    return json({status: 'under_review'});
  }
  const imageInputs = [];
  for (const frame of frames.slice(0, 3)) {
    const {data} = await admin.storage.from('moderation-artifacts').createSignedUrl(`${takeId}/frames/${frame.name}`, 60);
    imageInputs.push({type: 'image_url', image_url: {url: data!.signedUrl}});
  }
  const response = await fetch('https://api.openai.com/v1/moderations', {
    method: 'POST',
    headers: {'Authorization': `Bearer ${openAiKey}`, 'Content-Type': 'application/json'},
    body: JSON.stringify({model: 'omni-moderation-latest', input: imageInputs}),
  });
  if (!response.ok) return json({error: 'moderation_provider_error'}, 502);
  const result = await response.json();
  const flagged = Boolean(result.results?.some((entry: {flagged?: boolean}) => entry.flagged));
  await admin.from('takes').update({
    status: flagged ? 'under_review' : 'published',
    published_at: flagged ? null : new Date().toISOString(),
    moderation_reason: flagged ? 'automated_flag' : null,
  }).eq('id', takeId);
  await admin.from('moderation_queue').update({
    status: flagged ? 'open' : 'resolved',
    automated_scores: result.results ?? {},
    resolved_at: flagged ? null : new Date().toISOString(),
  }).eq('target_id', takeId).eq('status', 'open');
  return json({status: flagged ? 'under_review' : 'published'});
});
