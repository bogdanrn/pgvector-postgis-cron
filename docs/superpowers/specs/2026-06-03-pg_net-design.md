# Add pg_net (async HTTP) to pgvector-postgis-cron

**Date:** 2026-06-03
**Status:** Approved

## Goal

Add async HTTP-from-Postgres capability to the custom PG18 image via
[`pg_net`](https://github.com/supabase/pg_net) (Supabase). Chosen over
`pgsql-http` because the workload is fire-and-forget: cron jobs and triggers
emit webhooks / API calls with no need for an inline response. pg_net pairs
naturally with the already-present `pg_cron`.

## Decision rationale

| | pg_net (chosen) | pgsql-http (rejected) |
|---|---|---|
| Mode | Async — queue + background worker, response in `net._http_response` | Sync — blocks the calling transaction |
| Fit | Cron/trigger fan-out without blocking the worker | Inline fetch, response used in same query |
| Install | Source build (not in apt) | `apt install postgresql-18-http` |

The sync-blocking behavior of pgsql-http would stall the pg_cron background
worker on every outbound call, so it is not used.

## Ground-truth findings (verified in base image)

- `pg_net` is **not** packaged in PGDG apt; only `postgresql-18-http` exists.
  Therefore pg_net must be **built from source**.
- Latest release: **v0.20.3** (2025-05). Compiles cleanly against PG18.
- Build dependencies (confirmed by a successful build in
  `pgvector/pgvector:pg18-trixie`):
  `build-essential git ca-certificates postgresql-server-dev-18
  libcurl4-openssl-dev libicu-dev`.
  - `libicu-dev` is required: PG18's `utils/pg_locale.h` pulls in
    `unicode/ucol.h`; without it the build fails with
    `fatal error: unicode/ucol.h: No such file or directory`.
- Runtime dependency: `libcurl4` — the compiled `pg_net.so` links
  `libcurl.so.4`. Must be present in the final image.
- Install produces three artifacts under the PG18 tree:
  - `/usr/lib/postgresql/18/lib/pg_net.so`
  - `/usr/share/postgresql/18/extension/pg_net.control`
  - `/usr/share/postgresql/18/extension/pg_net*.sql`
- pg_net requires `pg_net` in `shared_preload_libraries` (it runs a background
  worker) and creates a schema named `net`.

## Architecture — multi-stage Dockerfile

Two stages keep compilers and dev headers out of the shipped image.

**Stage 1 (`build`):** start from the same base, install build deps, clone
pg_net at the pinned tag, `make && make install`.

**Stage 2 (final):** start from the same base, install the existing apt
extensions plus the `libcurl4` runtime library, then `COPY --from=build` the
three pg_net artifacts.

```dockerfile
FROM pgvector/pgvector:pg18-trixie AS build
ARG PG_NET_VERSION=0.20.3
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential git ca-certificates \
      postgresql-server-dev-18 libcurl4-openssl-dev libicu-dev \
 && git clone --depth 1 --branch v${PG_NET_VERSION} \
      https://github.com/supabase/pg_net.git /tmp/pg_net \
 && make -C /tmp/pg_net -j"$(nproc)" \
 && make -C /tmp/pg_net install

FROM pgvector/pgvector:pg18-trixie
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      postgresql-contrib \
      postgresql-18-postgis-3 \
      postgresql-18-postgis-3-scripts \
      postgresql-18-cron \
      libcurl4 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /usr/lib/postgresql/18/lib/pg_net.so \
     /usr/lib/postgresql/18/lib/
COPY --from=build /usr/share/postgresql/18/extension/pg_net* \
     /usr/share/postgresql/18/extension/
```

`PG_NET_VERSION` is an `ARG` pinned to `0.20.3` for reproducibility and easy
bumps.

## Configuration

Server config (documented in README; set in `postgresql.conf` at runtime):

```
shared_preload_libraries = 'pg_stat_statements,pg_cron,pg_net'
```

Enable per-database:

```sql
CREATE EXTENSION pg_net;
```

## Multi-arch

The existing publish workflow builds linux/amd64 + linux/arm64 via buildx.
The source build compiles natively per platform inside each buildx stage;
all build/runtime deps (`libicu-dev`, `libcurl4-openssl-dev`, `libcurl4`)
exist on both arches. No workflow change required.

## README update

Add `pg_net` to the extension list and record:
- It is async (queue → `net._http_response`).
- The updated `shared_preload_libraries` line.

## Verification

1. `docker buildx build` succeeds for amd64 (and arm64 if available locally).
2. In a running container with the updated `shared_preload_libraries`:
   `CREATE EXTENSION pg_net;` succeeds.
3. A smoke call resolves into `net._http_response`:
   ```sql
   SELECT net.http_get('https://example.com');
   -- after a moment:
   SELECT status_code FROM net._http_response ORDER BY id DESC LIMIT 1;
   ```

## Out of scope

- pgsql-http (rejected above).
- Any application-level SQL using pg_net beyond the smoke test.
