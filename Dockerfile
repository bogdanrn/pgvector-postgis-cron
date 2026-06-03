FROM pgvector/pgvector:pg18-trixie AS build

ARG PG_NET_VERSION=0.20.3

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    ca-certificates \
    postgresql-server-dev-18 \
    libcurl4-openssl-dev \
    libicu-dev \
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
    ca-certificates \
    libcurl4 \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/lib/postgresql/18/lib/pg_net.so \
  /usr/lib/postgresql/18/lib/
COPY --from=build /usr/share/postgresql/18/extension/pg_net* \
  /usr/share/postgresql/18/extension/
