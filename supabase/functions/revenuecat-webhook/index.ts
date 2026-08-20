import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {json} from '../_shared/cors.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const webhookSecret = Deno.env.get('REVENUECAT_WEBHOOK_SECRET')!;

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({error: 'method_not_allowed'}, 405);
  if (!webhookSecret || request.headers.get('Authorization') !== `Bearer ${webhookSecret}`) {
    return json({error: 'unauthorized'}, 401);
  }
  const payload = await request.json();
  const event = payload.event;
  const userId = event?.app_user_id;
  const eventId = event?.id;
  if (!userId || !eventId) return json({error: 'invalid_payload'}, 400);
  const isActive = ['INITIAL_PURCHASE','RENEWAL','UNCANCELLATION','PRODUCT_CHANGE','TEMPORARY_ENTITLEMENT_GRANT'].includes(event.type);
  const expiresAtMs = event.expiration_at_ms as number | null;
  const admin = createClient(url, serviceKey, {auth: {persistSession: false}});
  const {error} = await admin.from('entitlements').upsert({
    user_id: userId,
    entitlement_id: 'svnly_plus',
    is_active: isActive && (!expiresAtMs || expiresAtMs > Date.now()),
    product_id: event.product_id ?? null,
    expires_at: expiresAtMs ? new Date(expiresAtMs).toISOString() : null,
    source_event_id: eventId,
    updated_at: new Date().toISOString(),
  }, {onConflict: 'source_event_id'});
  if (error) return json({error: 'database_error'}, 500);
  return json({status: 'ok'});
});
