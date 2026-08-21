import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {createApnsProviderToken, loadApnsConfiguration, sendApns} from '../_shared/apns.ts';
import {corsHeaders, json} from '../_shared/cors.ts';
import {decryptDeviceToken} from '../_shared/device_crypto.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const cronSecret = Deno.env.get('CRON_SECRET') ?? '';
const encryptionKey = Deno.env.get('DEVICE_TOKEN_ENCRYPTION_KEY') ?? '';

type Notification = {
  id: string; user_id: string; category: string; title_key: string; body_key: string;
  data: Record<string, unknown>; attempts: number;
};
type Device = {
  id: string; user_id: string; encrypted_token: string;
  environment: 'sandbox' | 'production'; locale: string;
};

const copies: Record<string, Record<string, string>> = {
  reaction_title: {en: 'New reaction', de: 'Neue Reaktion'},
  reaction_body: {en: 'Someone reacted to your take.', de: 'Jemand hat auf deinen Take reagiert.'},
  comment_title: {en: 'New comment', de: 'Neuer Kommentar'},
  comment_body: {en: 'Your take received a new comment.', de: 'Dein Take hat einen neuen Kommentar.'},
  follow_request_title: {en: 'Follow request', de: 'Follower-Anfrage'},
  follow_request_body: {en: 'Someone wants to follow you.', de: 'Jemand möchte dir folgen.'},
  new_follower_title: {en: 'New follower', de: 'Neuer Follower'},
  new_follower_body: {en: 'Someone started following you.', de: 'Jemand folgt dir jetzt.'},
  daily_challenge_title: {en: "Today's SVNLY is live", de: 'Das heutige SVNLY ist da'},
  daily_challenge_body: {en: 'You have one take and seven seconds.', de: 'Du hast einen Take und sieben Sekunden.'},
  streak_title: {en: 'Keep your streak alive', de: 'Halte deine Serie am Leben'},
  streak_body: {en: 'Complete today’s challenge before the day ends.', de: 'Erledige die heutige Challenge, bevor der Tag endet.'},
  moderation_published_title: {en: 'Take published', de: 'Take veröffentlicht'},
  moderation_published_body: {en: 'Your take is now visible.', de: 'Dein Take ist jetzt sichtbar.'},
  moderation_under_review_title: {en: 'Take under review', de: 'Take wird geprüft'},
  moderation_under_review_body: {en: 'A moderator will review your take.', de: 'Ein Moderator prüft deinen Take.'},
  moderation_rejected_title: {en: 'Take not published', de: 'Take nicht veröffentlicht'},
  moderation_rejected_body: {en: 'Open SVNLY for details.', de: 'Öffne SVNLY für Details.'},
  moderation_removed_title: {en: 'Take removed', de: 'Take entfernt'},
  moderation_removed_body: {en: 'Open SVNLY for details.', de: 'Öffne SVNLY für Details.'},
};

function localized(key: string, locale: string): string {
  const language = locale.toLowerCase().startsWith('de') ? 'de' : 'en';
  return copies[key]?.[language] ?? key.replaceAll('_', ' ');
}

function preferenceColumn(category: string): string | null {
  const values: Record<string, string> = {
    daily_challenge: 'daily_challenge_push', streak: 'streak_push', reaction: 'reaction_push',
    comment: 'comment_push', follower: 'follower_push', moderation: 'moderation_push',
    product_news: 'product_news_push',
  };
  return values[category] ?? null;
}

async function authorized(request: Request): Promise<boolean> {
  if (!cronSecret) return false;
  const supplied = request.headers.get('x-cron-secret') ?? '';
  const [expectedHash, suppliedHash] = await Promise.all([cronSecret, supplied].map(async (value) =>
    new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)))));
  return expectedHash.byteLength === suppliedHash.byteLength &&
    expectedHash.every((byte, index) => byte === suppliedHash[index]);
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', {headers: corsHeaders});
  if (request.method !== 'POST') return json({error: 'method_not_allowed'}, 405);
  if (!await authorized(request)) return json({error: 'unauthorized'}, 401);
  if (!encryptionKey) return json({error: 'server_not_configured'}, 503);

  const admin = createClient(url, serviceKey, {auth: {persistSession: false}});
  try {
    const configuration = loadApnsConfiguration();
    const authorization = await createApnsProviderToken(configuration);
    const {data, error: claimError} = await admin.rpc('claim_notification_batch', {p_limit: 100});
    if (claimError) throw claimError;
    const notifications = (data ?? []) as Notification[];
    if (notifications.length === 0) return json({processed: 0, sent: 0});
    const userIds = [...new Set(notifications.map((notification) => notification.user_id))];
    const [{data: preferences, error: preferenceError}, {data: devices, error: deviceError}] = await Promise.all([
      admin.from('notification_preferences').select('*').in('user_id', userIds),
      admin.from('device_tokens').select('id,user_id,encrypted_token,environment,locale')
        .in('user_id', userIds).is('invalidated_at', null),
    ]);
    if (preferenceError || deviceError) throw preferenceError ?? deviceError;
    const preferencesByUser = new Map((preferences ?? []).map((item) => [item.user_id as string, item]));
    const devicesByUser = new Map<string, Device[]>();
    for (const device of (devices ?? []) as Device[]) {
      devicesByUser.set(device.user_id, [...(devicesByUser.get(device.user_id) ?? []), device]);
    }

    let sent = 0;
    for (const notification of notifications) {
      const prefKey = preferenceColumn(notification.category);
      const preference = preferencesByUser.get(notification.user_id);
      const enabled = prefKey ? preference?.[prefKey] !== false : false;
      const recipients = enabled ? devicesByUser.get(notification.user_id) ?? [] : [];
      let delivered = false;
      let retryable = false;
      let lastError = enabled ? 'no_active_device' : 'preference_disabled';
      for (const device of recipients) {
        try {
          const token = await decryptDeviceToken(device.encrypted_token, encryptionKey);
          const result = await sendApns(configuration, {
            token,
            environment: device.environment,
            title: localized(notification.title_key, device.locale),
            body: localized(notification.body_key, device.locale),
            data: {...notification.data, notification_id: notification.id},
            collapseId: `${notification.category}:${notification.user_id}`,
          }, authorization);
          if (result.ok) {
            delivered = true;
          } else {
            lastError = result.reason ?? `HTTP_${result.status}`;
            if (result.status === 410 || ['BadDeviceToken', 'DeviceTokenNotForTopic', 'Unregistered'].includes(lastError)) {
              await admin.from('device_tokens').update({invalidated_at: new Date().toISOString()}).eq('id', device.id);
            } else if (result.status === 429 || result.status >= 500) {
              retryable = true;
            }
          }
        } catch (error) {
          lastError = error instanceof Error ? error.message : 'device_delivery_failed';
        }
      }
      const retry = !delivered && retryable && notification.attempts < 10;
      const status = delivered ? 'sent' : retry ? 'queued' : recipients.length ? 'failed' : 'no_device';
      const update: Record<string, unknown> = {
        delivery_status: status,
        sent_at: delivered ? new Date().toISOString() : null,
        last_error: delivered ? null : lastError.slice(0, 500),
      };
      if (retry) update.not_before = new Date(Date.now() + Math.min(3600, 2 ** notification.attempts * 30) * 1000).toISOString();
      await admin.from('notifications').update(update).eq('id', notification.id);
      if (delivered) sent++;
    }
    return json({processed: notifications.length, sent});
  } catch (error) {
    console.error('send-apns failed', error instanceof Error ? error.message : 'unknown');
    return json({error: 'delivery_failed'}, 500);
  }
});
