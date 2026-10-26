// Посредник между веб-версией приложения и API Яндекс Музыки.
// Зачем: браузер не разрешает странице с одного сайта обращаться к API другого
// без специальных заголовков (CORS), а у Яндекса их нет. Посредник просто пересылает
// запрос и добавляет эти заголовки. Токены он нигде не сохраняет и не логирует.
//
// Обычные запросы (поиск, плейлисты и т.д.) принимаются только со страницы вашего
// сайта (ALLOWED_ORIGIN) и пересылаются только на api.music.yandex.net.
//
// Отдельный маршрут /resolve-stream/<trackId> нужен для самого звука: Яндекс для
// части треков (например, без активной подписки Плюс) отдает ссылку не сразу, а в
// два шага, и второй шаг браузер делать не может - CORS блокирует запрос напрямую к
// серверам Яндекса. Этот маршрут делает оба шага сам (сервер не ограничен CORS) и
// отправляет браузер (через HTTP-редирект) прямо на готовый файл. Тег <audio> может
// идти по чужому адресу без CORS, в отличие от обычного fetch()/XHR в коде страницы.

const TARGET = 'https://api.music.yandex.net';

// Заголовки, которые пересылаем в Яндекс (остальные, включая cookie, отбрасываем).
const FORWARD_HEADERS = ['authorization', 'x-yandex-music-client', 'accept-language', 'content-type'];

// Константа для подписи ссылок на треки, взятая из мобильного приложения Яндекс Музыки
// (описана в открытом обсуждении библиотеки yandex-music-api, issue #566).
const SIGN_SECRET = 'p93jhgh689SBReK6ghtw62';
const CLIENT_HEADER = 'YandexMusicAndroid/24022571';

function corsHeaders(origin) {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, X-Yandex-Music-Client, Accept-Language, Content-Type',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
  };
}

async function hmacSha256Base64(secret, message) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
  );
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(message));
  let binary = '';
  for (const b of new Uint8Array(sig)) binary += String.fromCharCode(b);
  return btoa(binary);
}

// --- Компактная реализация MD5 (нужна только для старой схемы ссылок на mp3;
// Web Crypto в воркерах MD5 не поддерживает). Вход и выход - как у md5(str) -> hex.
function md5Hex(str) {
  function rotl(x, c) { return (x << c) | (x >>> (32 - c)); }
  function toBytesUtf8(s) { return new TextEncoder().encode(s); }

  const K = new Uint32Array([
    0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
    0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,
    0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
    0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
    0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
    0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
    0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
    0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391,
  ]);
  const S = [
    7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
    5, 9,14,20, 5, 9,14,20, 5, 9,14,20, 5, 9,14,20,
    4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
    6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21,
  ];

  const msg = toBytesUtf8(str);
  const bitLen = msg.length * 8;
  let padLen = (msg.length % 64 < 56) ? (56 - msg.length % 64) : (120 - msg.length % 64);
  const total = msg.length + padLen + 8;
  const buf = new Uint8Array(total);
  buf.set(msg, 0);
  buf[msg.length] = 0x80;
  const view = new DataView(buf.buffer);
  view.setUint32(total - 8, bitLen >>> 0, true);
  view.setUint32(total - 4, Math.floor(bitLen / 0x100000000) >>> 0, true);

  let a0 = 0x67452301, b0 = 0xefcdab89, c0 = 0x98badcfe, d0 = 0x10325476;

  for (let chunkStart = 0; chunkStart < total; chunkStart += 64) {
    const M = new Uint32Array(16);
    for (let i = 0; i < 16; i++) M[i] = view.getUint32(chunkStart + i * 4, true);
    let A = a0, B = b0, C = c0, D = d0;
    for (let i = 0; i < 64; i++) {
      let F, g;
      if (i < 16) { F = (B & C) | (~B & D); g = i; }
      else if (i < 32) { F = (D & B) | (~D & C); g = (5 * i + 1) % 16; }
      else if (i < 48) { F = B ^ C ^ D; g = (3 * i + 5) % 16; }
      else { F = C ^ (B | ~D); g = (7 * i) % 16; }
      F = (F + A + K[i] + M[g]) >>> 0;
      A = D; D = C; C = B;
      B = (B + rotl(F, S[i])) >>> 0;
    }
    a0 = (a0 + A) >>> 0; b0 = (b0 + B) >>> 0; c0 = (c0 + C) >>> 0; d0 = (d0 + D) >>> 0;
  }

  function hex(n) {
    const bytes = [n & 0xff, (n >>> 8) & 0xff, (n >>> 16) & 0xff, (n >>> 24) & 0xff];
    return bytes.map((b) => b.toString(16).padStart(2, '0')).join('');
  }
  return hex(a0) + hex(b0) + hex(c0) + hex(d0);
}

async function resolveStream(trackId, token) {
  if (!/^\d+$/.test(trackId)) throw new Error('bad track id');
  if (!token) throw new Error('no token');

  const ts = Math.floor(Date.now() / 1000);
  const sign = await hmacSha256Base64(SIGN_SECRET, `${trackId}${ts}`);
  const headers = { Authorization: `OAuth ${token}`, 'X-Yandex-Music-Client': CLIENT_HEADER };

  const infoResp = await fetch(
    `${TARGET}/tracks/${trackId}/download-info?can_use_streaming=true&ts=${ts}&sign=${encodeURIComponent(sign)}`,
    { headers }
  );
  if (!infoResp.ok) throw new Error(`download-info: HTTP ${infoResp.status}`);
  const infoJson = await infoResp.json();
  const list = (infoJson.result || []).filter((e) => e.preview !== true);
  if (list.length === 0) throw new Error('empty track list (возможно, нужна подписка Плюс)');

  list.sort((a, b) => {
    const ca = a.codec === 'mp3' ? 0 : 1;
    const cb = b.codec === 'mp3' ? 0 : 1;
    if (ca !== cb) return ca - cb;
    return (b.bitrateInKbps || 0) - (a.bitrateInKbps || 0);
  });
  const best = list[0];
  const url = best.downloadInfoUrl;

  if (best.container === 'hls' || best.direct === true || /\.m3u8(\?|$)/.test(url)) {
    return url;
  }

  // Старая схема: второй запрос за host/path/ts/s, потом своя подпись.
  const sep = url.includes('?') ? '&' : '?';
  const metaResp = await fetch(`${url}${sep}format=json`, { headers });
  if (!metaResp.ok) throw new Error(`legacy meta: HTTP ${metaResp.status}`);
  const meta = await metaResp.json();
  const legacySign = md5Hex(`XGRlBW9FXlekgbPrRHuSiA${meta.path.substring(1)}${meta.s}`);
  return `https://${meta.host}/get-mp3/${legacySign}/${meta.ts}${meta.path}`;
}

export default {
  async fetch(request, env) {
    const allowed = (env.ALLOWED_ORIGIN || '').trim();
    const origin = request.headers.get('Origin') || '';
    const url = new URL(request.url);

    // /resolve-stream/<trackId>?token=... - используется тегом <audio>, который не
    // посылает Origin как обычный запрос со страницы, поэтому проверяем иначе: просто
    // требуем настоящий числовой id трека и непустой токен (сам Яндекс отклонит чужой
    // или неверный токен).
    const m = url.pathname.match(/^\/resolve-stream\/(\d+)$/);
    if (m) {
      try {
        const target = await resolveStream(m[1], url.searchParams.get('token') || '');
        return Response.redirect(target, 302);
      } catch (e) {
        return new Response(`Не удалось получить ссылку на трек: ${e.message}`, { status: 502 });
      }
    }

    if (!allowed || origin !== allowed) {
      return new Response('Forbidden', { status: 403 });
    }

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }
    if (request.method !== 'GET' && request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405, headers: corsHeaders(origin) });
    }

    const upstream = new Request(TARGET + url.pathname + url.search, {
      method: request.method,
      headers: (() => {
        const h = new Headers();
        for (const name of FORWARD_HEADERS) {
          const v = request.headers.get(name);
          if (v) h.set(name, v);
        }
        return h;
      })(),
      body: request.method === 'POST' ? await request.arrayBuffer() : undefined,
    });

    let resp;
    try {
      resp = await fetch(upstream);
    } catch (e) {
      return new Response('Bad gateway', { status: 502, headers: corsHeaders(origin) });
    }

    const headers = new Headers(resp.headers);
    headers.delete('set-cookie');
    for (const [k, v] of Object.entries(corsHeaders(origin))) headers.set(k, v);
    return new Response(resp.body, { status: resp.status, headers });
  },
};
