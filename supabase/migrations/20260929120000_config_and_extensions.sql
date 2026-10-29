-- ---------------------------------------------------------------------------
-- pgvector: vector type and hnsw/ivfflat indexes, installed in the extensions
-- schema (same as uuid-ossp, pgcrypto). Already applied live.
-- ---------------------------------------------------------------------------
create extension if not exists vector with schema extensions;
