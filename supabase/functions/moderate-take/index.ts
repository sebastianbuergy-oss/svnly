import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {corsHeaders, json} from '../_shared/cors.ts';
import {
  classifyModerationResults,
  isRetryableExtractionError,
} from '../_shared/moderation_policy.mjs';

const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const openAiKey = Deno.env.get('OPENAI_API_KEY');
const mediaWorkerUrl = Deno.env.get('MEDIA_WORKER_URL');
const mediaWorkerToken = Deno.env.get('MEDIA_WORKER_TOKEN');
const cronSecret = Deno.env.get('CRON_SECRET') ?? '';
const admin = createClient<any>(url, serviceKey, {auth: {persistSession: false}});

type ExtractedFrame = {
  name: string;
  timestampSeconds: number;
  sha256: string;
  base64: string;
};

type ExtractionProof = {
  takeId: string;
  extractorVersion: string;
  media: {duration: number; codec: string; width: number; height: number};
  frames: ExtractedFrame[];
};

function decodeBase64(value: string): Uint8Array {
  const binary = atob(value);
  const output = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) output[index] = binary.charCodeAt(index);
  return output;
}

async function sha256(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', Uint8Array.from(bytes).buffer);
  return [...new Uint8Array(digest)].map((part) => part.toString(16).padStart(2, '0')).join('');
}

async function matchesSecret(expected: string, supplied: string): Promise<boolean> {
  if (!expected || !supplied) return false;
  const hashes = await Promise.all([expected, supplied].map(async (value) =>
    new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)))));
  return hashes[0].every((byte, index) => byte === hashes[1][index]);
}

async function markForRetry(takeId: string, reason: string) {
  await admin.from('takes').update({
    status: 'processing', moderation_reason: `automation_retry:${reason}`,
  }).eq('id', takeId);
  await admin.from('moderation_queue').update({
    priority: 60,
    automation_last_error: reason,
    automation_last_attempt_at: new Date().toISOString(),
  }).eq('target_id', takeId).eq('status', 'open');
}

async function markForHumanReview(takeId: string, reason: string, scores: unknown) {
  await admin.from('takes').update({status: 'under_review', moderation_reason: reason}).eq('id', takeId);
  await admin.from('moderation_queue').update({
    priority: 80,
    automated_scores: {decision: 'review', results: scores},
    automation_last_error: null,
    automation_last_attempt_at: new Date().toISOString(),
  }).eq('target_id', takeId).eq('status', 'open');
}

async function extractTrustedFrames(
  take: {id: string; storage_path: string},
): Promise<ExtractionProof> {
  if (!mediaWorkerUrl || !mediaWorkerToken) throw new Error('media_worker_unconfigured');
  const {data: signed, error: signingError} = await admin.storage.from('takes')
    .createSignedUrl(take.storage_path, 90);
  if (signingError || !signed?.signedUrl) throw new Error('video_signing_failed');

  const response = await fetch(`${mediaWorkerUrl.replace(/\/$/, '')}/v1/extract`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${mediaWorkerToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({takeId: take.id, videoUrl: signed.signedUrl}),
    signal: AbortSignal.timeout(55_000),
  });
  if (!response.ok) {
    const payload = await response.json().catch(() => null) as {error?: string} | null;
    throw new Error(payload?.error ?? 'trusted_extraction_failed');
  }
  const proof = await response.json() as ExtractionProof;
  if (proof.takeId !== take.id || proof.frames?.length !== 3 ||
      proof.media.duration < 6.5 || proof.media.duration > 8.5) {
    throw new Error('invalid_extraction_proof');
  }

  for (const [index, frame] of proof.frames.entries()) {
    const expectedName = `frame-${String(index + 1).padStart(2, '0')}.jpg`;
    const bytes = decodeBase64(frame.base64);
    if (frame.name !== expectedName || bytes.length < 256 || bytes.length > 1024 * 1024 ||
        await sha256(bytes) !== frame.sha256) {
      throw new Error('frame_integrity_failed');
    }
    const {error} = await admin.storage.from('moderation-artifacts').upload(
      `${take.id}/frames/${expectedName}`,
      bytes,
      {contentType: 'image/jpeg', cacheControl: '0', upsert: true},
    );
    if (error) throw error;
  }
  const manifest = new TextEncoder().encode(JSON.stringify({
    takeId: proof.takeId,
    extractorVersion: proof.extractorVersion,
    media: proof.media,
    frames: proof.frames.map(({name, timestampSeconds, sha256}) => ({name, timestampSeconds, sha256})),
    extractedAt: new Date().toISOString(),
    sourceStoragePath: take.storage_path,
  }));
  const {error: manifestError} = await admin.storage.from('moderation-artifacts').upload(
    `${take.id}/manifest.txt`, manifest,
    {contentType: 'text/plain', cacheControl: '0', upsert: true},
  );
  if (manifestError) throw manifestError;
  return proof;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', {headers: corsHeaders});
  if (request.method !== 'POST') return json({error: 'method_not_allowed'}, 405);
  const authorization = request.headers.get('Authorization') ?? '';
  const suppliedCronSecret = request.headers.get('x-cron-secret') ?? '';
  const systemCall = await matchesSecret(cronSecret, suppliedCronSecret);
  const caller = createClient(url, anonKey, {global: {headers: {Authorization: authorization}}});
  const {data: {user}} = systemCall ? {data: {user: null}} : await caller.auth.getUser();
  if (!systemCall && !user) return json({error: 'invalid_session'}, 401);
  const {takeId} = await request.json();
  const {data: take} = await admin.from('takes')
    .select('id,user_id,status,storage_path').eq('id', takeId).single();
  if (!take || !take.storage_path ||
      (!systemCall && take.user_id !== user!.id && !['admin', 'moderator'].includes(user!.app_metadata?.role))) {
    return json({error: 'not_found'}, 404);
  }
  if (take.status !== 'processing') {
    return json({status: take.status});
  }

  try {
    await extractTrustedFrames(take);
  } catch (error) {
    const reason = error instanceof Error ? error.message : 'extraction_failed';
    if (isRetryableExtractionError(reason)) {
      await markForRetry(takeId, reason);
      return json({status: 'processing', retryable: true}, 503);
    }
    await admin.from('takes').update({
      status: 'rejected', moderation_reason: reason, published_at: null,
    }).eq('id', takeId);
    await admin.from('moderation_queue').update({
      status: 'resolved', resolved_at: new Date().toISOString(),
      automated_scores: {decision: 'reject', reason},
      automation_last_error: null,
      automation_last_attempt_at: new Date().toISOString(),
    }).eq('target_id', takeId).eq('status', 'open');
    return json({status: 'rejected'});
  }
  if (!openAiKey) {
    await markForRetry(takeId, 'automated_check_unavailable');
    return json({status: 'processing', retryable: true}, 503);
  }

  const imageInputs = [];
  for (const name of ['frame-01.jpg', 'frame-02.jpg', 'frame-03.jpg']) {
    const {data, error} = await admin.storage.from('moderation-artifacts')
      .createSignedUrl(`${takeId}/frames/${name}`, 60);
    if (error || !data?.signedUrl) {
      await markForRetry(takeId, 'frame_signing_failed');
      return json({status: 'processing', retryable: true}, 503);
    }
    imageInputs.push({type: 'image_url', image_url: {url: data.signedUrl}});
  }
  const response = await fetch('https://api.openai.com/v1/moderations', {
    method: 'POST',
    headers: {'Authorization': `Bearer ${openAiKey}`, 'Content-Type': 'application/json'},
    body: JSON.stringify({model: 'omni-moderation-latest', input: imageInputs}),
  });
  if (!response.ok) {
    await markForRetry(takeId, 'moderation_provider_error');
    return json({status: 'processing', retryable: true}, 503);
  }
  const result = await response.json();
  let decision: 'publish' | 'review' | 'reject';
  try {
    decision = classifyModerationResults(result.results);
  } catch {
    await markForRetry(takeId, 'invalid_moderation_response');
    return json({status: 'processing', retryable: true}, 503);
  }
  if (decision === 'review') {
    await markForHumanReview(takeId, 'automated_flag', result.results);
    return json({status: 'under_review'});
  }

  const status = decision === 'reject' ? 'rejected' : 'published';
  await admin.from('takes').update({
    status,
    published_at: decision === 'publish' ? new Date().toISOString() : null,
    moderation_reason: decision === 'reject' ? 'automated_reject' : null,
  }).eq('id', takeId);
  await admin.from('moderation_queue').update({
    status: 'resolved',
    automated_scores: {decision, results: result.results},
    resolved_at: new Date().toISOString(),
    automation_last_error: null,
    automation_last_attempt_at: new Date().toISOString(),
  }).eq('target_id', takeId).eq('status', 'open');
  return json({status});
});
