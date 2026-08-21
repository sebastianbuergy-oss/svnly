import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {corsHeaders, json} from '../_shared/cors.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const openAiKey = Deno.env.get('OPENAI_API_KEY');
const mediaWorkerUrl = Deno.env.get('MEDIA_WORKER_URL');
const mediaWorkerToken = Deno.env.get('MEDIA_WORKER_TOKEN');

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
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((part) => part.toString(16).padStart(2, '0')).join('');
}

async function markForHumanReview(admin: ReturnType<typeof createClient>, takeId: string, reason: string) {
  await admin.from('takes').update({status: 'under_review', moderation_reason: reason}).eq('id', takeId);
  await admin.from('moderation_queue').update({priority: 80}).eq('target_id', takeId).eq('status', 'open');
}

async function extractTrustedFrames(
  admin: ReturnType<typeof createClient>,
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
  if (!response.ok) throw new Error('trusted_extraction_failed');
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
  const authorization = request.headers.get('Authorization');
  if (!authorization) return json({error: 'authentication_required'}, 401);
  const caller = createClient(url, anonKey, {global: {headers: {Authorization: authorization}}});
  const {data: {user}} = await caller.auth.getUser();
  if (!user) return json({error: 'invalid_session'}, 401);
  const {takeId} = await request.json();
  const admin = createClient(url, serviceKey, {auth: {persistSession: false}});
  const {data: take} = await admin.from('takes')
    .select('id,user_id,status,storage_path').eq('id', takeId).single();
  if (!take || !take.storage_path ||
      (take.user_id !== user.id && !['admin', 'moderator'].includes(user.app_metadata?.role))) {
    return json({error: 'not_found'}, 404);
  }
  if (!['processing', 'under_review'].includes(take.status)) {
    return json({status: take.status});
  }

  try {
    await extractTrustedFrames(admin, take);
  } catch (error) {
    await markForHumanReview(admin, takeId, error instanceof Error ? error.message : 'extraction_failed');
    return json({status: 'under_review'});
  }
  if (!openAiKey) {
    await markForHumanReview(admin, takeId, 'automated_check_unavailable');
    return json({status: 'under_review'});
  }

  const imageInputs = [];
  for (const name of ['frame-01.jpg', 'frame-02.jpg', 'frame-03.jpg']) {
    const {data, error} = await admin.storage.from('moderation-artifacts')
      .createSignedUrl(`${takeId}/frames/${name}`, 60);
    if (error || !data?.signedUrl) {
      await markForHumanReview(admin, takeId, 'frame_signing_failed');
      return json({status: 'under_review'});
    }
    imageInputs.push({type: 'image_url', image_url: {url: data.signedUrl}});
  }
  const response = await fetch('https://api.openai.com/v1/moderations', {
    method: 'POST',
    headers: {'Authorization': `Bearer ${openAiKey}`, 'Content-Type': 'application/json'},
    body: JSON.stringify({model: 'omni-moderation-latest', input: imageInputs}),
  });
  if (!response.ok) {
    await markForHumanReview(admin, takeId, 'moderation_provider_error');
    return json({status: 'under_review'});
  }
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
