-- Phase 6: Validation checks for populated warehouse tables.

SELECT 'dim_date' AS table_name, COUNT(*) AS row_count FROM dw.dim_date
UNION ALL
SELECT 'dim_time', COUNT(*) FROM dw.dim_time
UNION ALL
SELECT 'dim_calendar_event', COUNT(*) FROM dw.dim_calendar_event
UNION ALL
SELECT 'dim_weather', COUNT(*) FROM dw.dim_weather
UNION ALL
SELECT 'dim_geography', COUNT(*) FROM dw.dim_geography
UNION ALL
SELECT 'dim_station', COUNT(*) FROM dw.dim_station
UNION ALL
SELECT 'dim_user_type', COUNT(*) FROM dw.dim_user_type
UNION ALL
SELECT 'dim_rideable_type', COUNT(*) FROM dw.dim_rideable_type
UNION ALL
SELECT 'fact_trip', COUNT(*) FROM dw.fact_trip
UNION ALL
SELECT 'fact_station_day_hour', COUNT(*) FROM dw.fact_station_day_hour
ORDER BY table_name;

SELECT
    (SELECT COUNT(*) FROM reconciled.trip) AS reconciled_trips,
    (SELECT COUNT(*) FROM dw.fact_trip) AS fact_trips,
    (SELECT SUM(trip_count) FROM dw.fact_trip) AS fact_trip_count_measure,
    (SELECT COUNT(*) FROM reconciled.trip) - (SELECT COUNT(*) FROM dw.fact_trip) AS row_count_gap;

SELECT
    (SELECT COUNT(*) FROM reconciled.calendar_day) AS reconciled_calendar_days,
    (SELECT COUNT(*) FROM dw.dim_date WHERE date_key <> 0) AS warehouse_calendar_days,
    (SELECT COUNT(*) FROM reconciled.daily_weather) AS reconciled_weather_days,
    (SELECT COUNT(*) FROM dw.dim_weather WHERE weather_key <> 0) AS warehouse_weather_days,
    (SELECT COUNT(*) FROM reconciled.geography_area) AS reconciled_geographies,
    (SELECT COUNT(*) FROM dw.dim_geography WHERE geography_key <> 0) AS warehouse_geographies,
    (SELECT COUNT(*) FROM reconciled.station) AS reconciled_stations,
    (SELECT COUNT(*) FROM dw.dim_station WHERE station_key <> 0) AS warehouse_stations;

SELECT
    COUNT(*) FILTER (WHERE start_date_key = 0 OR end_date_key = 0) AS trips_using_unknown_date,
    COUNT(*) FILTER (WHERE start_time_key = 0 OR end_time_key = 0) AS trips_using_unknown_time,
    COUNT(*) FILTER (WHERE start_calendar_event_key = 0) AS trips_using_unknown_calendar_event,
    COUNT(*) FILTER (WHERE start_weather_key = 0) AS trips_using_unknown_weather,
    COUNT(*) FILTER (WHERE start_station_key = 0 OR end_station_key = 0) AS trips_using_unknown_station,
    COUNT(*) FILTER (WHERE start_geography_key = 0 OR end_geography_key = 0) AS trips_using_unknown_geography,
    COUNT(*) FILTER (WHERE user_type_key = 0) AS trips_using_unknown_user_type,
    COUNT(*) FILTER (WHERE rideable_type_key = 0) AS trips_using_unknown_rideable_type
FROM dw.fact_trip;

SELECT
    flow_direction,
    SUM(trip_count) AS trips,
    ROUND(100.0 * SUM(trip_count) / SUM(SUM(trip_count)) OVER (), 2) AS pct_trips
FROM dw.fact_trip
GROUP BY flow_direction
ORDER BY trips DESC;

SELECT
    SUM(trip_count) AS total_trips,
    SUM(night_trip_count) AS night_trips,
    ROUND(100.0 * SUM(night_trip_count) / SUM(trip_count), 2) AS pct_night_trips,
    ROUND(AVG(duration_minutes), 2) AS avg_duration_minutes,
    ROUND(AVG(approximate_distance_km), 3) AS avg_approx_distance_km
FROM dw.fact_trip;

SELECT
    (SELECT SUM(trip_count) FROM dw.fact_trip) AS ride_grain_trip_count,
    (SELECT SUM(trip_starts) FROM dw.fact_station_day_hour) AS aggregate_trip_starts,
    (SELECT SUM(trip_ends) FROM dw.fact_station_day_hour) AS aggregate_trip_ends,
    (SELECT SUM(night_trip_count) FROM dw.fact_trip) AS ride_grain_night_trips,
    (SELECT SUM(night_trip_starts) FROM dw.fact_station_day_hour) AS aggregate_night_starts;

SELECT
    dd.year_number,
    dd.month_number,
    dt.day_night_class,
    SUM(f.trip_count) AS trips,
    ROUND(AVG(f.duration_minutes), 2) AS avg_duration_minutes
FROM dw.fact_trip f
JOIN dw.dim_date dd
    ON f.start_date_key = dd.date_key
JOIN dw.dim_time dt
    ON f.start_time_key = dt.time_key
GROUP BY dd.year_number, dd.month_number, dt.day_night_class
ORDER BY dd.year_number, dd.month_number, dt.day_night_class;

