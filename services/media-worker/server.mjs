import {createHash, timingSafeEqual} from 'node:crypto';
import {execFile} from 'node:child_process';
import {mkdtemp, readFile, rm, writeFile} from 'node:fs/promises';
import {createServer} from 'node:http';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {promisify} from 'node:util';

const exec = promisify(execFile);
const maximumSourceBytes = 12 * 1024 * 1024;
const maximumRequestBytes = 16 * 1024;
const frameTimes = ['0.70', '3.50', '6.30'];

export function authorized(header, expectedToken) {
  if (!expectedToken || !header?.startsWith('Bearer ')) return false;
  const provided = Buffer.from(header.slice(7));
  const expected = Buffer.from(expectedToken);
  return provided.length === expected.length && timingSafeEqual(provided, expected);
}

export function validateSourceUrl(value, allowedHost) {
  const url = new URL(value);
  if (url.protocol !== 'https:' || !allowedHost || url.hostname !== allowedHost) {
    throw new Error('untrusted_video_url');
  }
  return url;
}

export function validateProbe(probe) {
  const duration = Number(probe?.format?.duration);
  const video = probe?.streams?.find((stream) => stream.codec_type === 'video');
  if (!Number.isFinite(duration) || duration < 6.5 || duration > 8.5) {
    throw new Error('invalid_duration');
  }
  if (!video || !['h264', 'hevc'].includes(video.codec_name)) {
    throw new Error('invalid_video_codec');
  }
  if (video.width < 240 || video.height < 240 || video.width > 2160 || video.height > 2160) {
    throw new Error('invalid_dimensions');
  }
  return {duration, codec: video.codec_name, width: video.width, height: video.height};
}

async function readJson(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > maximumRequestBytes) throw new Error('request_too_large');
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

async function download(url) {
  const response = await fetch(url, {signal: AbortSignal.timeout(20_000)});
  if (!response.ok) throw new Error('video_download_failed');
  const declared = Number(response.headers.get('content-length') ?? 0);
  if (declared > maximumSourceBytes) throw new Error('video_too_large');
  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.length === 0 || bytes.length > maximumSourceBytes) throw new Error('invalid_video_size');
  return bytes;
}

async function extractFrames({takeId, videoUrl, allowedHost}) {
  if (!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(takeId)) throw new Error('invalid_take_id');
  const trustedUrl = validateSourceUrl(videoUrl, allowedHost);
  const directory = await mkdtemp(join(tmpdir(), 'svnly-media-'));
  try {
    const sourcePath = join(directory, 'source.mp4');
    await writeFile(sourcePath, await download(trustedUrl));
    const {stdout} = await exec('ffprobe', [
      '-v', 'error', '-show_streams', '-show_format', '-of', 'json', sourcePath,
    ], {timeout: 15_000, maxBuffer: 256 * 1024});
    const media = validateProbe(JSON.parse(stdout));
    const frames = [];
    for (let index = 0; index < frameTimes.length; index++) {
      const framePath = join(directory, `frame-${index + 1}.jpg`);
      await exec('ffmpeg', [
        '-hide_banner', '-loglevel', 'error', '-ss', frameTimes[index], '-i', sourcePath,
        '-frames:v', '1', '-vf', "scale='min(720,iw)':-2", '-q:v', '3', '-y', framePath,
      ], {timeout: 20_000, maxBuffer: 256 * 1024});
      const bytes = await readFile(framePath);
      if (bytes.length < 256 || bytes.length > 1024 * 1024) throw new Error('invalid_frame');
      frames.push({
        name: `frame-${String(index + 1).padStart(2, '0')}.jpg`,
        timestampSeconds: Number(frameTimes[index]),
        sha256: createHash('sha256').update(bytes).digest('hex'),
        base64: bytes.toString('base64'),
      });
    }
    return {takeId, extractorVersion: 'ffmpeg-6.1.2-v1', media, frames};
  } finally {
    await rm(directory, {recursive: true, force: true});
  }
}

function respond(response, status, body) {
  response.writeHead(status, {'content-type': 'application/json', 'cache-control': 'no-store'});
  response.end(JSON.stringify(body));
}

export function createMediaServer(environment = process.env) {
  return createServer(async (request, response) => {
    if (request.method === 'GET' && request.url === '/health') {
      respond(response, 200, {status: 'ok', extractorVersion: 'ffmpeg-6.1.2-v1'});
      return;
    }
    if (request.method !== 'POST' || request.url !== '/v1/extract') {
      respond(response, 404, {error: 'not_found'});
      return;
    }
    if (!authorized(request.headers.authorization, environment.MEDIA_WORKER_TOKEN)) {
      respond(response, 401, {error: 'unauthorized'});
      return;
    }
    try {
      const body = await readJson(request);
      const result = await extractFrames({...body, allowedHost: environment.ALLOWED_VIDEO_HOST});
      respond(response, 200, result);
    } catch (error) {
      const code = error instanceof Error ? error.message : 'extraction_failed';
      respond(response, 422, {error: code});
    }
  });
}

if (process.argv[1] === new URL(import.meta.url).pathname) {
  const port = Number(process.env.PORT ?? 8080);
  createMediaServer().listen(port, '0.0.0.0');
}
