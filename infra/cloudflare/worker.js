export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const apiOrigin = env.API_ORIGIN;

    if (url.pathname.startsWith("/api/follows") && request.method === "POST") {
      return rateLimitedProxy(request, apiOrigin, env);
    }

    if (request.method === "GET" && url.pathname.startsWith("/api/")) {
      const cache = caches.default;
      const cacheKey = new Request(request.url, request);
      const cached = await cache.match(cacheKey);
      if (cached) return withCacheStatus(cached, "HIT");

      const response = await proxy(request, apiOrigin);
      const headers = new Headers(response.headers);
      headers.set("Cache-Control", headers.get("Cache-Control") || "public, max-age=30, s-maxage=120");
      headers.set("CDN-Cache-Control", "max-age=120");
      const cacheable = new Response(response.body, { status: response.status, headers });

      if (response.ok) ctx.waitUntil(cache.put(cacheKey, cacheable.clone()));
      return withCacheStatus(cacheable, "MISS");
    }

    return proxy(request, apiOrigin);
  }
};

async function proxy(request, origin) {
  const inbound = new URL(request.url);
  const target = new URL(inbound.pathname + inbound.search, origin);
  const proxied = new Request(target, request);
  proxied.headers.set("X-Forwarded-Host", inbound.host);
  return fetch(proxied);
}

async function rateLimitedProxy(request, origin, env) {
  const ip = request.headers.get("CF-Connecting-IP") || "unknown";
  const key = `follow:${ip}`;
  const current = Number((await env.RATE_LIMIT?.get(key)) || "0");

  if (current >= 30) {
    return new Response(JSON.stringify({ error: "rate limited" }), {
      status: 429,
      headers: { "Content-Type": "application/json" }
    });
  }

  await env.RATE_LIMIT?.put(key, String(current + 1), { expirationTtl: 60 });
  return proxy(request, origin);
}

function withCacheStatus(response, status) {
  const headers = new Headers(response.headers);
  headers.set("X-Edge-Cache", status);
  return new Response(response.body, { status: response.status, headers });
}
