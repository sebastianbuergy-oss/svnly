import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {corsHeaders, json} from '../_shared/cors.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

async function listRecursively(client: ReturnType<typeof createClient>, bucket: string, prefix: string): Promise<string[]> {
  const result: string[] = [];
  const {data, error} = await client.storage.from(bucket).list(prefix, {limit: 1000});
  if (error) throw error;
  for (const entry of data ?? []) {
    const path = prefix ? `${prefix}/${entry.name}` : entry.name;
    if (entry.id) result.push(path);
    else result.push(...await listRecursively(client, bucket, path));
  }
  return result;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', {headers: corsHeaders});
  if (request.method !== 'POST') return json({error: 'method_not_allowed'}, 405);
  const authorization = request.headers.get('Authorization');
  if (!authorization) return json({error: 'authentication_required'}, 401);

  const userClient = createClient(url, anonKey, {global: {headers: {Authorization: authorization}}});
  const {data: {user}, error: userError} = await userClient.auth.getUser();
  if (userError || !user) return json({error: 'invalid_session'}, 401);
  const {error: requestError} = await userClient.rpc('request_account_deletion');
  if (requestError) return json({error: requestError.message}, 400);

  const admin = createClient(url, serviceKey, {auth: {persistSession: false}});
  try {
    for (const bucket of ['takes','take-thumbnails','avatars']) {
      const paths = await listRecursively(admin, bucket, user.id);
      for (let offset = 0; offset < paths.length; offset += 100) {
        const {error} = await admin.storage.from(bucket).remove(paths.slice(offset, offset + 100));
        if (error) throw error;
      }
    }
    await admin.from('admin_audit_log').insert({
      actor_id: null,
      action: 'account_deletion_completed',
      target_type: 'anonymized_user',
      target_id: user.id,
      metadata: {requested_by_user: true, completed_at: new Date().toISOString()},
    });
    const {error: deleteError} = await admin.auth.admin.deleteUser(user.id, false);
    if (deleteError) throw deleteError;
    return json({status: 'deleted'});
  } catch (error) {
    await admin.from('account_deletion_jobs').update({
      status: 'failed',
      error_code: error instanceof Error ? error.name : 'unknown',
    }).eq('user_id', user.id);
    return json({error: 'deletion_job_failed'}, 500);
  }
});
