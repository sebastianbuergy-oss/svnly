function decodeBase64(value: string): Uint8Array {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function encodeBase64Url(value: Uint8Array): string {
  let binary = '';
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function asArrayBuffer(value: Uint8Array): ArrayBuffer {
  return Uint8Array.from(value).buffer;
}

async function importEncryptionKey(encodedKey: string): Promise<CryptoKey> {
  const raw = decodeBase64(encodedKey);
  if (raw.byteLength !== 32) throw new Error('DEVICE_TOKEN_ENCRYPTION_KEY must contain 32 bytes');
  return await crypto.subtle.importKey('raw', asArrayBuffer(raw), 'AES-GCM', false, ['encrypt', 'decrypt']);
}

export async function tokenHash(token: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

export async function encryptDeviceToken(token: string, encodedKey: string): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await importEncryptionKey(encodedKey);
  const cipher = new Uint8Array(await crypto.subtle.encrypt(
    {name: 'AES-GCM', iv, additionalData: new TextEncoder().encode('svnly-apns-token-v1')},
    key,
    new TextEncoder().encode(token),
  ));
  return `v1:${encodeBase64Url(iv)}:${encodeBase64Url(cipher)}`;
}

export async function decryptDeviceToken(value: string, encodedKey: string): Promise<string> {
  const [version, ivValue, cipherValue] = value.split(':');
  if (version !== 'v1' || !ivValue || !cipherValue) throw new Error('Unsupported token ciphertext');
  const key = await importEncryptionKey(encodedKey);
  const plaintext = await crypto.subtle.decrypt(
    {
      name: 'AES-GCM',
      iv: asArrayBuffer(decodeBase64(ivValue)),
      additionalData: new TextEncoder().encode('svnly-apns-token-v1'),
    },
    key,
    asArrayBuffer(decodeBase64(cipherValue)),
  );
  return new TextDecoder().decode(plaintext);
}
