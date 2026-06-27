# Infrastructure Notes

This demo models a limited-beta electronic music platform where most traffic is public catalog browsing and the risky spikes come from announcements, drops, lineups, and newsletter follows.

## Runtime Shape

- Cloudflare fronts the app, terminates TLS, caches public `GET /api/*` responses, and can rate-limit write paths.
- Railway runs the Sinatra API as a container built from `api/Dockerfile`.
- Railway Postgres stores artists, releases, events, and follows.
- Vue 3 is served separately during local development. In production it could be a Cloudflare Pages app or static assets behind Cloudflare.

## 500 RPS Strategy

The cheapest path is to avoid sending 500 RPS to Ruby whenever possible:

- Cache `GET /api/catalog` at Cloudflare for 120 seconds with short browser TTLs.
- Keep high-cardinality authenticated or personalized endpoints out of shared cache.
- Run Puma with multiple workers and bounded threads so concurrency is explicit.
- Size the Postgres pool below the database connection limit and watch queue time.
- Load-test both origin-only and edge-cached paths, because those answer different questions.

## What To Watch

- p50/p95/p99 latency on `/api/catalog` and `/api/follows`.
- 5xx rate and Railway restarts.
- Postgres CPU, active connections, lock waits, and slow queries.
- Cloudflare cache hit ratio and edge 429 counts.
- Queue time in the Ruby app when arrival rate exceeds capacity.

## Auto-Recovery Sketch

- Railway health checks call `/healthz` and restart failed containers.
- `/readyz` verifies database reachability and should be used before routing traffic.
- Cloudflare can keep serving cached catalog responses during brief origin incidents.
- Alerts should fire on sustained 5xx rate, high p95 latency, low cache hit ratio, and Postgres saturation.
