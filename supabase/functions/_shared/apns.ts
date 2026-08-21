type ApnsConfiguration = {
  teamId: string;
  keyId: string;
  bundleId: string;
  privateKeyBase64: string;
};

type ApnsMessage = {
  token: string;
  environment: 'sandbox' | 'production';
  title: string;
  body: string;
  data: Record<string, unknown>;
  collapseId?: string;
};

export type ApnsResult = {ok: boolean; status: number; reason?: string};

function base64Url(value: Uint8Array | string): string {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value;
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function privateKeyDer(value: string): Uint8Array {
  const pem = new TextDecoder().decode(Uint8Array.from(atob(value), (character) => character.charCodeAt(0)));
  const body = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  return Uint8Array.from(atob(body), (character) => character.charCodeAt(0));
}

async function providerToken(configuration: ApnsConfiguration): Promise<string> {
  const header = base64Url(JSON.stringify({alg: 'ES256', kid: configuration.keyId}));
  const claims = base64Url(JSON.stringify({iss: configuration.teamId, iat: Math.floor(Date.now() / 1000)}));
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    privateKeyDer(configuration.privateKeyBase64),
    {name: 'ECDSA', namedCurve: 'P-256'},
    false,
    ['sign'],
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    {name: 'ECDSA', hash: 'SHA-256'}, key, new TextEncoder().encode(unsigned),
  ));
  return `${unsigned}.${base64Url(signature)}`;
}

export function loadApnsConfiguration(): ApnsConfiguration {
  const configuration = {
    teamId: Deno.env.get('APNS_TEAM_ID') ?? '',
    keyId: Deno.env.get('APNS_KEY_ID') ?? '',
    bundleId: Deno.env.get('APNS_BUNDLE_ID') ?? '',
    privateKeyBase64: Deno.env.get('APNS_PRIVATE_KEY_BASE64') ?? '',
  };
  if (Object.values(configuration).some((value) => !value)) throw new Error('APNs configuration incomplete');
  return configuration;
}

export async function sendApns(
  configuration: ApnsConfiguration,
  message: ApnsMessage,
  authorization: string,
): Promise<ApnsResult> {
  const host = message.environment === 'sandbox' ? 'api.sandbox.push.apple.com' : 'api.push.apple.com';
  const headers: Record<string, string> = {
    authorization: `bearer ${authorization}`,
    'apns-topic': configuration.bundleId,
    'apns-push-type': 'alert',
    'apns-priority': '10',
    'apns-expiration': String(Math.floor(Date.now() / 1000) + 86400),
    'content-type': 'application/json',
  };
  if (message.collapseId) headers['apns-collapse-id'] = message.collapseId.slice(0, 64);
  const response = await fetch(`https://${host}/3/device/${message.token}`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      aps: {alert: {title: message.title, body: message.body}, sound: 'default'},
      ...message.data,
    }),
  });
  if (response.ok) return {ok: true, status: response.status};
  let reason = `HTTP_${response.status}`;
  try {
    const body = await response.json() as {reason?: string};
    reason = body.reason ?? reason;
  } catch (_) {
    // APNs may return an empty body for transport errors.
  }
  return {ok: false, status: response.status, reason};
}

export async function createApnsProviderToken(configuration: ApnsConfiguration): Promise<string> {
  return await providerToken(configuration);
}
