import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {corsHeaders, json} from '../_shared/cors.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

type DeletionReceipt = {
  take_id: string;
  video_path: string | null;
  thumbnail_path: string | null;
};

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

  const authorization = request.headers.get('Authorization');
  if (!authorization) return json({error: 'authentication_required'}, 401);

  let takeId = '';
  try {
    const payload = await request.json() as {take_id?: unknown};
    if (typeof payload.take_id !== 'string' ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(payload.take_id)) {
      return json({error: 'invalid_take_id'}, 400);
    }
    takeId = payload.take_id;
  } catch (_) {
    return json({error: 'invalid_request'}, 400);
  }

  const userClient = createClient(url, anonKey, {
    auth: {persistSession: false},
    global: {headers: {Authorization: authorization}},
  });
  const {data: {user}, error: userError} = await userClient.auth.getUser();
  if (userError || !user) return json({error: 'invalid_session'}, 401);

  const {data, error: deletionError} = await userClient.rpc('delete_my_take', {
    p_take_id: takeId,
  });
  if (deletionError) {
    const denied = deletionError.message.includes('take_not_owned');
    return json({error: denied ? 'take_not_owned' : 'take_deletion_failed'}, denied ? 403 : 400);
  }

  const receipt = (Array.isArray(data) ? data[0] : data) as DeletionReceipt | null;
  if (!receipt?.take_id) return json({error: 'take_deletion_failed'}, 500);

  const admin = createClient(url, serviceKey, {auth: {persistSession: false}});
  try {
    await removeIfPresent(admin, 'takes', receipt.video_path ? [receipt.video_path] : []);
    await removeIfPresent(
      admin,
      'take-thumbnails',
      receipt.thumbnail_path ? [receipt.thumbnail_path] : [],
    );
    await removeIfPresent(admin, 'moderation-artifacts', [
      `${takeId}/frames/frame-01.jpg`,
      `${takeId}/frames/frame-02.jpg`,
      `${takeId}/frames/frame-03.jpg`,
      `${takeId}/manifest.txt`,
    ]);
    const {error: completeError} = await admin.rpc('complete_take_media_cleanup', {
      p_take_id: takeId,
    });
    if (completeError) throw completeError;
    return json({status: 'deleted', cleanup: 'complete'});
  } catch (_) {
    // The take is already hidden. scheduled-jobs retries every path while the
    // private storage receipt remains attached to the deleted row.
    return json({status: 'deleted', cleanup: 'queued'});
  }
});
