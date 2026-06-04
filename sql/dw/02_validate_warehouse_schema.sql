-- Phase 5: Warehouse schema validation checks.
-- These checks validate structure only. Row counts will be meaningful after Phase 6 population.

SELECT
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'dw'
  AND table_name IN (
      'dim_date',
      'dim_time',
      'dim_calendar_event',
      'dim_weather',
      'dim_geography',
      'dim_station',
      'dim_user_type',
      'dim_rideable_type',
      'fact_trip',
      'fact_station_day_hour'
  )
ORDER BY table_name;

SELECT
    table_name,
    COUNT(*) AS columns
FROM information_schema.columns
WHERE table_schema = 'dw'
GROUP BY table_name
ORDER BY table_name;

SELECT
    tc.table_name,
    tc.constraint_name,
    ccu.table_name AS referenced_table
FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_catalog = ccu.constraint_catalog
   AND tc.constraint_schema = ccu.constraint_schema
   AND tc.constraint_name = ccu.constraint_name
WHERE tc.table_schema = 'dw'
  AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name, tc.constraint_name;

SELECT
    indexname,
    tablename
FROM pg_indexes
WHERE schemaname = 'dw'
ORDER BY tablename, indexname;

