-- Phase 3: Validation checks for staging loads

-- Row counts
SELECT 'citibike_trip_raw' AS table_name, COUNT(*) AS row_count FROM staging.citibike_trip_raw
UNION ALL
SELECT 'weather_raw', COUNT(*) FROM staging.weather_raw
UNION ALL
SELECT 'holiday_raw', COUNT(*) FROM staging.holiday_raw
UNION ALL
SELECT 'nyc_nta_raw', COUNT(*) FROM staging.nyc_nta_raw
UNION ALL
SELECT 'nyc_borough_raw', COUNT(*) FROM staging.nyc_borough_raw;

-- Citi Bike data quality checks
SELECT COUNT(*) AS citibike_null_start_coordinates
FROM staging.citibike_trip_raw
WHERE start_lat IS NULL OR start_lng IS NULL;

SELECT COUNT(*) AS citibike_invalid_time_ranges
FROM staging.citibike_trip_raw
WHERE ended_at < started_at;

SELECT ride_id, COUNT(*) AS duplicate_count
FROM staging.citibike_trip_raw
WHERE ride_id IS NOT NULL
GROUP BY ride_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, ride_id
LIMIT 20;

-- Weather date coverage
SELECT MIN(observation_date) AS first_weather_date,
       MAX(observation_date) AS last_weather_date,
       COUNT(*) AS weather_rows
FROM staging.weather_raw;

-- Holiday date coverage
SELECT MIN(holiday_date) AS first_holiday_date,
       MAX(holiday_date) AS last_holiday_date,
       COUNT(*) AS holiday_rows
FROM staging.holiday_raw;

-- Geometry validity
SELECT COUNT(*) AS invalid_nta_geometries
FROM staging.nyc_nta_raw
WHERE geom IS NOT NULL AND NOT ST_IsValid(geom);

SELECT COUNT(*) AS invalid_borough_geometries
FROM staging.nyc_borough_raw
WHERE geom IS NOT NULL AND NOT ST_IsValid(geom);
