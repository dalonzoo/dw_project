SELECT
    current_database() AS database_name,
    version() AS postgresql_version,
    PostGIS_Version() AS postgis_version;

SELECT
    schema_name
FROM information_schema.schemata
WHERE schema_name IN ('staging', 'reconciled', 'dw', 'audit')
ORDER BY schema_name;

SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema IN ('staging', 'reconciled', 'dw', 'audit')
ORDER BY table_schema, table_name;
