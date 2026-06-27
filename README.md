# FNMNL Lead Research Infrastructure Demo

Small educational demo for imagining the infrastructure behind the HN post in `start.md`: Vue 3, Ruby/Sinatra, Postgres, Railway, and Cloudflare for an electronic music platform that wants to survive bursty catalog traffic near 500 RPS without paying for constant overcapacity.

The app is intentionally typical. It is not a product clone. It is an infra-shaped slice: public artists/releases/events, a write path for follows, health/readiness checks, metrics, edge cache config, Railway config, and a k6 load test.

## Quick Start

Prerequisites:

- Docker with Docker Compose
- `curl`
- Optional: local `k6`; the helper script can run k6 through Docker

Launch everything:

```bash
scripts/demo up
```

That builds the Sinatra image, starts Postgres, runs the API with Puma, and starts the Vue dev server. Keep this terminal open so you can watch service logs.

Open:

- Vue app: http://localhost:5174
- Sinatra API: http://localhost:4567/api/catalog
- Health: http://localhost:4567/healthz
- Readiness: http://localhost:4567/readyz
- Metrics: http://localhost:4567/metrics

In another terminal, smoke-test the running stack:

```bash
scripts/demo smoke
```

You should see:

- JSON from `/healthz`
- JSON from `/readyz`
- the beginning of the catalog JSON response
- a `200 OK` response from the Vue dev server

Stop the stack:

```bash
scripts/demo down
```

Reset everything, including the local Postgres volume:

```bash
scripts/demo clean
```

## Build And Verify

Run syntax checks and a frontend production build:

```bash
scripts/demo build
```

The build command runs:

- `ruby -c app.rb`
- `ruby -c db.rb`
- `npm install`
- `npm run build`

It removes `frontend/dist/` afterward because this repo treats built frontend output as generated.

## Load Test

Run a short smoke load test through Docker:

```bash
scripts/demo load
```

Override the arrival rate and duration:

```bash
RPS=100 DURATION=30s scripts/demo load
```

The full target from the HN post would be closer to:

```bash
RPS=500 DURATION=2m scripts/demo load
```

If you have local k6 installed, you can run the test directly:

```bash
k6 run -e BASE_URL=http://localhost:4567 -e RPS=500 -e DURATION=2m loadtest/catalog.js
```

For a real Cloudflare/Railway test, point `BASE_URL` at the Cloudflare hostname and compare it with Railway origin-only results. A high Cloudflare cache hit ratio should make the 500 RPS target much cheaper than sending every request to Sinatra.

## What To Inspect

Use the app as an infrastructure map:

1. Open the Vue app and watch it call `GET /api/catalog`.
2. Inspect the response headers for `cache-control: public, max-age=30, s-maxage=120`.
3. Submit the follow form and see the separate `POST /api/follows` write path.
4. Open `/metrics` to see Prometheus-style request counters.
5. Read `infra/cloudflare/worker.js` to see where edge caching and write rate limits would sit.
6. Read `railway.toml` and `api/puma.rb` to see how Railway would start and health-check the API.

## Manual Commands

Launch without the helper script:

```bash
docker compose up --build
```

Check service state:

```bash
docker compose ps
```

Follow logs:

```bash
docker compose logs -f
```

Probe the API manually:

```bash
curl http://localhost:4567/healthz
curl http://localhost:4567/readyz
curl http://localhost:4567/api/catalog
curl http://localhost:4567/metrics
```

## Project Map

- `scripts/demo`: launch, smoke-test, build, load-test, and cleanup helper.
- `api/`: Ruby Sinatra app, Puma config, schema migration, seed data, API endpoints.
- `frontend/`: Vue 3 Vite app that consumes the API and demonstrates core product flows.
- `railway.toml`: Railway deployment settings for the API container.
- `infra/railway/`: copy of the Railway settings kept with the infrastructure notes.
- `infra/cloudflare/`: Worker sketch for cache behavior and write-path controls.
- `loadtest/`: k6 constant-arrival-rate test for the catalog and follow paths.
- `docs/infra-notes.md`: concise explanation of scaling, monitoring, and recovery decisions.

## Modeled Architecture

```text
Visitor
  -> Cloudflare DNS/TLS/WAF/cache/rate limits
  -> Vue static app, likely Cloudflare Pages
  -> Cloudflare Worker for /api/*
  -> Railway Sinatra API, Puma workers/threads
  -> Railway Postgres
```

The important design choice is separating cacheable public reads from writes. Public event, release, and artist pages should be cached at the edge. Follows, applications, admin edits, and personalized views should hit origin with rate limits and clear database capacity planning.
