// Посредник между веб-версией приложения и API Яндекс Музыки.
// Зачем: браузер не разрешает странице с одного сайта обращаться к API другого
// без специальных заголовков (CORS), а у Яндекса их нет. Посредник просто пересылает
// запрос и добавляет эти заголовки. Токены он нигде не сохраняет и не логирует.
//
// Принимает запросы только со страницы вашего сайта (ALLOWED_ORIGIN) и пересылает
// их только на api.music.yandex.net.

const TARGET = 'https://api.music.yandex.net';

// Заголовки, которые пересылаем в Яндекс (остальные, включая cookie, отбрасываем).
const FORWARD_HEADERS = ['authorization', 'x-yandex-music-client', 'accept-language', 'content-type'];

function corsHeaders(origin) {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, X-Yandex-Music-Client, Accept-Language, Content-Type',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
  };
}

export default {
  async fetch(request, env) {
    const allowed = (env.ALLOWED_ORIGIN || '').trim();
    const origin = request.headers.get('Origin') || '';

    if (!allowed || origin !== allowed) {
      return new Response('Forbidden', { status: 403 });
    }

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }
    if (request.method !== 'GET' && request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405, headers: corsHeaders(origin) });
    }

    const url = new URL(request.url);
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
