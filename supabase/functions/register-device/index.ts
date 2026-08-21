import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {corsHeaders, json} from '../_shared/cors.ts';
import {encryptDeviceToken, tokenHash} from '../_shared/device_crypto.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const encryptionKey = Deno.env.get('DEVICE_TOKEN_ENCRYPTION_KEY');

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', {headers: corsHeaders});
  if (!['POST', 'DELETE'].includes(request.method)) return json({error: 'method_not_allowed'}, 405);
  const bearer = request.headers.get('Authorization') ?? '';
  const client = createClient(url, anonKey, {global: {headers: {Authorization: bearer}}});
  const {data: {user}, error: authError} = await client.auth.getUser();
  if (authError || !user) return json({error: 'unauthorized'}, 401);
  if (!encryptionKey) return json({error: 'server_not_configured'}, 503);

  try {
    const body = await request.json() as Record<string, unknown>;
    const rawToken = String(body.token ?? '').toLowerCase();
    if (!/^[0-9a-f]{64,200}$/.test(rawToken) || rawToken.length % 2 !== 0) {
      return json({error: 'invalid_device_token'}, 400);
    }
    const hash = await tokenHash(rawToken);
    const admin = createClient(url, serviceKey, {auth: {persistSession: false}});
    if (request.method === 'DELETE') {
      const {error} = await admin.from('device_tokens').update({invalidated_at: new Date().toISOString()})
        .eq('token_hash', hash).eq('user_id', user.id);
      if (error) throw error;
      return json({invalidated: true});
    }

    const environment = String(body.environment ?? '');
    const locale = String(body.locale ?? 'en').slice(0, 35);
    const timezone = String(body.timezone ?? 'UTC').slice(0, 80);
    if (!['sandbox', 'production'].includes(environment)) return json({error: 'invalid_environment'}, 400);
    const encrypted = await encryptDeviceToken(rawToken, encryptionKey);
    const now = new Date().toISOString();
    const {error} = await admin.from('device_tokens').upsert({
      user_id: user.id,
      token_hash: hash,
      encrypted_token: encrypted,
      environment,
      locale,
      timezone,
      last_seen_at: now,
      invalidated_at: null,
    }, {onConflict: 'token_hash'});
    if (error) throw error;
    return json({registered: true});
  } catch (error) {
    console.error('register-device failed', error instanceof Error ? error.message : 'unknown');
    return json({error: 'registration_failed'}, 500);
  }
});
