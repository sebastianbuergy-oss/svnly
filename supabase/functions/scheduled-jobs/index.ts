import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {corsHeaders, json} from '../_shared/cors.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const cronSecret = Deno.env.get('CRON_SECRET') ?? '';

async function authorized(request: Request): Promise<boolean> {
  if (!cronSecret) return false;
  const supplied = request.headers.get('x-cron-secret') ?? '';
  const hashes = await Promise.all([cronSecret, supplied].map(async (value) =>
    new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)))));
  return hashes[0].every((byte, index) => byte === hashes[1][index]);
}

async function callInternal(name: string, body: Record<string, unknown> = {}): Promise<boolean> {
  const response = await fetch(`${url}/functions/v1/${name}`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json', 'x-cron-secret': cronSecret},
    body: JSON.stringify(body),
  });
  return response.ok;
}

async function removeIfPresent(
  admin: ReturnType<typeof createClient>,
  bucket: string,
  paths: string[],
): Promise<void> {
  if (paths.length === 0) return;
  const {error} = await admin.storage.from(bucket).remove(paths);
  if (error) throw error;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', {headers: corsHeaders});
  if (request.method !== 'POST') return json({error: 'method_not_allowed'}, 405);
  if (!await authorized(request)) return json({error: 'unauthorized'}, 401);
  const admin = createClient(url, serviceKey, {auth: {persistSession: false}});
  try {
    // A voluntary deletion is hidden transactionally before Storage cleanup.
    // Retry any private bytes whose receipt is still attached to that row.
    const {data: pendingDeletionMedia, error: pendingDeletionError} = await admin
      .from('takes')
      .select('id,storage_path,thumbnail_path')
      .eq('status', 'deleted')
      .or('storage_path.not.is.null,thumbnail_path.not.is.null')
      .limit(100);
    if (pendingDeletionError) throw pendingDeletionError;
    let voluntaryMediaDeleted = 0;
    for (const take of pendingDeletionMedia ?? []) {
      try {
        await removeIfPresent(admin, 'takes', take.storage_path ? [take.storage_path] : []);
        await removeIfPresent(
          admin,
          'take-thumbnails',
          take.thumbnail_path ? [take.thumbnail_path] : [],
        );
        await removeIfPresent(admin, 'moderation-artifacts', [
          `${take.id}/frames/frame-01.jpg`, `${take.id}/frames/frame-02.jpg`,
          `${take.id}/frames/frame-03.jpg`, `${take.id}/manifest.txt`,
        ]);
        const {error} = await admin.rpc('complete_take_media_cleanup', {p_take_id: take.id});
        if (error) throw error;
        voluntaryMediaDeleted++;
      } catch (_) {
        // Keep the paths intact; the next scheduled run retries safely.
      }
    }

    const {data: queue, error: queueError} = await admin.from('moderation_queue')
      .select('target_id').eq('target_type', 'take').eq('source', 'automated').eq('status', 'open')
      .order('created_at').limit(10);
    if (queueError) throw queueError;
    const queuedIds = (queue ?? []).map((item) => item.target_id as string);
    const {data: processable, error: processableError} = queuedIds.length === 0
      ? {data: [], error: null}
      : await admin.from('takes').select('id').in('id', queuedIds).eq('status', 'processing');
    if (processableError) throw processableError;
    let moderationStarted = 0;
    for (const take of processable ?? []) {
      if (await callInternal('moderate-take', {takeId: take.id})) moderationStarted++;
    }

    // The Free plan includes 1 GiB of file storage. Keep a deterministic
    // 21-day ceiling even when a user has not selected auto-delete, while
    // still honouring any shorter user-selected retention period.
    const freeTierRetentionDays = 21;
    const cutoff = new Date(Date.now() - freeTierRetentionDays * 86400000).toISOString();
    const {data: settings, error: settingsError} = await admin.from('user_settings')
      .select('user_id,auto_delete_days');
    if (settingsError) throw settingsError;
    const deletionDays = new Map((settings ?? []).map((item) =>
      [item.user_id as string, Number(item.auto_delete_days)]));
    const ownerIds = [...deletionDays.keys()];
    const {data: expiredTakes, error: expiredError} = ownerIds.length === 0
      ? {data: [], error: null}
      : await admin.from('takes').select('id,storage_path,thumbnail_path,user_id,created_at')
        .in('user_id', ownerIds).neq('status', 'deleted').lt('created_at', cutoff)
        .order('created_at').limit(100);
    if (expiredError) throw expiredError;
    let mediaDeleted = 0;
    for (const take of expiredTakes ?? []) {
      const requestedDays = deletionDays.get(take.user_id as string);
      const days = Math.min(requestedDays ?? freeTierRetentionDays, freeTierRetentionDays);
      if (new Date(take.created_at).getTime() > Date.now() - days * 86400000) continue;
      try {
        await removeIfPresent(admin, 'takes', take.storage_path ? [take.storage_path] : []);
        await removeIfPresent(
          admin,
          'take-thumbnails',
          take.thumbnail_path ? [take.thumbnail_path] : [],
        );
        await removeIfPresent(admin, 'moderation-artifacts', [
          `${take.id}/frames/frame-01.jpg`, `${take.id}/frames/frame-02.jpg`,
          `${take.id}/frames/frame-03.jpg`, `${take.id}/manifest.txt`,
        ]);
        const {error} = await admin.from('takes').update({
          status: 'deleted', deleted_at: new Date().toISOString(), storage_path: null, thumbnail_path: null,
        }).eq('id', take.id);
        if (error) throw error;
        mediaDeleted++;
      } catch (_) {
        // Preserve the row paths until a later run can prove cleanup complete.
      }
    }
    const pushStarted = await callInternal('send-apns');
    return json({
      moderation_started: moderationStarted,
      voluntary_media_deleted: voluntaryMediaDeleted,
      media_deleted: mediaDeleted,
      push_started: pushStarted,
    });
  } catch (error) {
    console.error('scheduled-jobs failed', error instanceof Error ? error.message : 'unknown');
    return json({error: 'scheduled_job_failed'}, 500);
  }
});
