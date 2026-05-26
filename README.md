# pgvector-postgis

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


# conf
shared_preload_libraries = 'pg_stat_statements,pg_cron'
cron.database_name = 'postgres'