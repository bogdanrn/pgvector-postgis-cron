# pgvector-postgis-cron

Custom PostgreSQL 18 image with:

- pgvector
- PostGIS
- pg_stat_statements
- pg_trgm
- unaccent
- pgcrypto
- btree_gin
- btree_gist
- pg_cron
- pg_net (async HTTP)


# conf
shared_preload_libraries = 'pg_stat_statements,pg_cron,pg_net'
cron.database_name = 'postgres'

pg_net is asynchronous: requests queue via the background worker and responses
land in `net._http_response`. Enable per-database with `CREATE EXTENSION pg_net;`.