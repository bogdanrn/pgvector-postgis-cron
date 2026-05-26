FROM pgvector/pgvector:pg18-trixie

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    postgresql-contrib \
    postgresql-18-postgis-3 \
    postgresql-18-postgis-3-scripts \
    postgresql-18-cron \
  && rm -rf /var/lib/apt/lists/*
