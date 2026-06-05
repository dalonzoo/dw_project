-- Phase 8 - Quality Checks And Reproducibility
-- Urban Night Mobility Data Warehouse

-- Run after staging, reconciled, and dw layers have been built.
-- The queries are read-only and are intended for DBeaver or psql.

-- Check 1: Source inventory row counts versus staging tables
-- Expected values refer to the documented January 2024 development sample.

WITH expected_counts AS (
    SELECT 'citibike_trip_raw' AS table_name, 1888085::BIGINT AS expected_rows
    UNION ALL SELECT 'weather_raw', 366
    UNION ALL SELECT 'holiday_raw', 17
    UNION ALL SELECT 'nyc_nta_raw', 262
    UNION ALL SELECT 'nyc_borough_raw', 5
), actual_counts AS (
    SELECT 'citibike_trip_raw' AS table_name, COUNT(*)::BIGINT AS actual_rows FROM staging.citibike_trip_raw
    UNION ALL SELECT 'weather_raw', COUNT(*) FROM staging.weather_raw
    UNION ALL SELECT 'holiday_raw', COUNT(*) FROM staging.holiday_raw
    UNION ALL SELECT 'nyc_nta_raw', COUNT(*) FROM staging.nyc_nta_raw
    UNION ALL SELECT 'nyc_borough_raw', COUNT(*) FROM staging.nyc_borough_raw
)
SELECT
    e.table_name,
    e.expected_rows,
    a.actual_rows,
    a.actual_rows - e.expected_rows AS row_count_delta,
    CASE WHEN a.actual_rows = e.expected_rows THEN 'PASS' ELSE 'CHECK' END AS status
FROM expected_counts e
JOIN actual_counts a
    ON e.table_name = a.table_name
ORDER BY e.table_name;

-- Check 2: Staging trips accounted for by reconciled accepted/rejected rows

SELECT
    (SELECT COUNT(*) FROM staging.citibike_trip_raw) AS staging_trip_rows,
    (SELECT COUNT(*) FROM reconciled.trip) AS accepted_trips,
    (SELECT COUNT(*) FROM reconciled.trip_rejection) AS rejected_trips,
    (SELECT COUNT(*) FROM reconciled.trip) +
        (SELECT COUNT(*) FROM reconciled.trip_rejection) AS accounted_trips,
    (SELECT COUNT(*) FROM staging.citibike_trip_raw) -
        ((SELECT COUNT(*) FROM reconciled.trip) +
         (SELECT COUNT(*) FROM reconciled.trip_rejection)) AS accounting_gap,
    CASE
        WHEN (SELECT COUNT(*) FROM staging.citibike_trip_raw) =
             ((SELECT COUNT(*) FROM reconciled.trip) +
              (SELECT COUNT(*) FROM reconciled.trip_rejection))
        THEN 'PASS'
        ELSE 'CHECK'
    END AS status;

-- Check 3: Duplicate ride IDs in staging and reconciled layers

WITH staging_duplicates AS (
    SELECT
        COUNT(*) AS duplicate_ride_id_groups,
        COALESCE(SUM(duplicate_count - 1), 0)::BIGINT AS duplicate_extra_rows
    FROM (
        SELECT ride_id, COUNT(*) AS duplicate_count
        FROM staging.citibike_trip_raw
        WHERE ride_id IS NOT NULL
        GROUP BY ride_id
        HAVING COUNT(*) > 1
    ) d
), reconciled_duplicates AS (
    SELECT
        COUNT(*) AS duplicate_ride_id_groups
    FROM (
        SELECT ride_id, COUNT(*) AS duplicate_count
        FROM reconciled.trip
        GROUP BY ride_id
        HAVING COUNT(*) > 1
    ) d
)
SELECT
    s.duplicate_ride_id_groups AS staging_duplicate_groups,
    s.duplicate_extra_rows AS staging_duplicate_extra_rows,
    r.duplicate_ride_id_groups AS reconciled_duplicate_groups,
    CASE WHEN r.duplicate_ride_id_groups = 0 THEN 'PASS' ELSE 'CHECK' END AS status
FROM staging_duplicates s
CROSS JOIN reconciled_duplicates r;

-- Check 4: Invalid timestamps, durations, and rejection reasons

SELECT
    COUNT(*) FILTER (WHERE started_at IS NULL OR ended_at IS NULL) AS staging_missing_timestamps,
    COUNT(*) FILTER (WHERE ended_at <= started_at) AS staging_non_positive_time_ranges,
    COUNT(*) FILTER (WHERE ended_at > started_at + INTERVAL '1 day') AS staging_duration_over_24h,
    COUNT(*) FILTER (WHERE start_station_id IS NULL OR end_station_id IS NULL) AS staging_missing_station_id,
    COUNT(*) FILTER (
        WHERE start_lat IS NULL OR start_lng IS NULL OR end_lat IS NULL OR end_lng IS NULL
    ) AS staging_missing_coordinates
FROM staging.citibike_trip_raw;

SELECT
    primary_rejection_reason,
    COUNT(*) AS rejected_rows
FROM reconciled.trip_rejection
GROUP BY primary_rejection_reason
ORDER BY rejected_rows DESC, primary_rejection_reason;

-- Check 5: Station geographic enrichment coverage

SELECT
    geo_assignment_status,
    COUNT(*) AS stations,
    SUM(observation_count) AS station_observations,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_stations,
    ROUND(100.0 * SUM(observation_count) / SUM(SUM(observation_count)) OVER (), 2) AS pct_observations
FROM reconciled.station
GROUP BY geo_assignment_status
ORDER BY stations DESC;

SELECT
    COUNT(*) AS total_stations,
    COUNT(*) FILTER (WHERE nta_id IS NOT NULL) AS stations_assigned_to_nta,
    COUNT(*) FILTER (WHERE nta_id IS NULL) AS stations_outside_or_unknown,
    ROUND(100.0 * COUNT(*) FILTER (WHERE nta_id IS NOT NULL) / NULLIF(COUNT(*), 0), 2) AS pct_assigned_to_nta
FROM reconciled.station;

-- Check 6: Calendar and weather coverage for accepted trips

SELECT
    COUNT(*) AS accepted_trips,
    COUNT(*) FILTER (WHERE cd.date_value IS NULL) AS trips_without_calendar_day,
    COUNT(*) FILTER (WHERE dwth.observation_date IS NULL) AS trips_without_weather_day,
    ROUND(100.0 * COUNT(*) FILTER (WHERE dwth.observation_date IS NOT NULL) / NULLIF(COUNT(*), 0), 2) AS pct_with_weather
FROM reconciled.trip t
LEFT JOIN reconciled.calendar_day cd
    ON t.start_date = cd.date_value
LEFT JOIN reconciled.daily_weather dwth
    ON t.start_date = dwth.observation_date;

SELECT
    MIN(date_value) AS first_calendar_day,
    MAX(date_value) AS last_calendar_day,
    COUNT(*) AS calendar_days,
    COUNT(*) FILTER (WHERE is_public_holiday) AS public_holidays,
    COUNT(*) FILTER (WHERE holiday_window <> 'regular') AS non_regular_holiday_window_days
FROM reconciled.calendar_day;

-- Check 7: Fact rows with valid or controlled dimension keys

SELECT
    COUNT(*) AS fact_rows,
    COUNT(*) FILTER (WHERE f.start_date_key = 0 OR f.end_date_key = 0) AS unknown_date_keys,
    COUNT(*) FILTER (WHERE f.start_time_key = 0 OR f.end_time_key = 0) AS unknown_time_keys,
    COUNT(*) FILTER (WHERE f.start_calendar_event_key = 0) AS unknown_calendar_event_keys,
    COUNT(*) FILTER (WHERE f.start_weather_key = 0) AS unknown_weather_keys,
    COUNT(*) FILTER (WHERE f.start_station_key = 0 OR f.end_station_key = 0) AS unknown_station_keys,
    COUNT(*) FILTER (WHERE f.start_geography_key = 0 OR f.end_geography_key = 0) AS unknown_geography_keys,
    COUNT(*) FILTER (WHERE f.user_type_key = 0) AS unknown_user_type_keys,
    COUNT(*) FILTER (WHERE f.rideable_type_key = 0) AS unknown_rideable_type_keys
FROM dw.fact_trip f;

SELECT
    COUNT(*) AS fact_rows,
    COUNT(*) FILTER (WHERE dd_start.date_key IS NULL OR dd_end.date_key IS NULL) AS broken_date_fk_rows,
    COUNT(*) FILTER (WHERE dt_start.time_key IS NULL OR dt_end.time_key IS NULL) AS broken_time_fk_rows,
    COUNT(*) FILTER (WHERE ce.calendar_event_key IS NULL) AS broken_calendar_event_fk_rows,
    COUNT(*) FILTER (WHERE w.weather_key IS NULL) AS broken_weather_fk_rows,
    COUNT(*) FILTER (WHERE s_start.station_key IS NULL OR s_end.station_key IS NULL) AS broken_station_fk_rows,
    COUNT(*) FILTER (WHERE g_start.geography_key IS NULL OR g_end.geography_key IS NULL) AS broken_geography_fk_rows,
    COUNT(*) FILTER (WHERE u.user_type_key IS NULL) AS broken_user_type_fk_rows,
    COUNT(*) FILTER (WHERE r.rideable_type_key IS NULL) AS broken_rideable_type_fk_rows
FROM dw.fact_trip f
LEFT JOIN dw.dim_date dd_start ON f.start_date_key = dd_start.date_key
LEFT JOIN dw.dim_date dd_end ON f.end_date_key = dd_end.date_key
LEFT JOIN dw.dim_time dt_start ON f.start_time_key = dt_start.time_key
LEFT JOIN dw.dim_time dt_end ON f.end_time_key = dt_end.time_key
LEFT JOIN dw.dim_calendar_event ce ON f.start_calendar_event_key = ce.calendar_event_key
LEFT JOIN dw.dim_weather w ON f.start_weather_key = w.weather_key
LEFT JOIN dw.dim_station s_start ON f.start_station_key = s_start.station_key
LEFT JOIN dw.dim_station s_end ON f.end_station_key = s_end.station_key
LEFT JOIN dw.dim_geography g_start ON f.start_geography_key = g_start.geography_key
LEFT JOIN dw.dim_geography g_end ON f.end_geography_key = g_end.geography_key
LEFT JOIN dw.dim_user_type u ON f.user_type_key = u.user_type_key
LEFT JOIN dw.dim_rideable_type r ON f.rideable_type_key = r.rideable_type_key;

-- Check 8: Reconciled-to-warehouse and aggregate fact reconciliation

SELECT
    (SELECT COUNT(*) FROM reconciled.trip) AS reconciled_trip_rows,
    (SELECT COUNT(*) FROM dw.fact_trip) AS fact_trip_rows,
    (SELECT SUM(trip_count) FROM dw.fact_trip) AS fact_trip_count_measure,
    (SELECT COUNT(*) FROM reconciled.trip) - (SELECT COUNT(*) FROM dw.fact_trip) AS row_count_gap,
    CASE
        WHEN (SELECT COUNT(*) FROM reconciled.trip) = (SELECT COUNT(*) FROM dw.fact_trip)
         AND (SELECT COUNT(*) FROM dw.fact_trip) = (SELECT SUM(trip_count) FROM dw.fact_trip)
        THEN 'PASS'
        ELSE 'CHECK'
    END AS status;

SELECT
    (SELECT SUM(trip_count) FROM dw.fact_trip) AS ride_grain_trips,
    (SELECT SUM(trip_starts) FROM dw.fact_station_day_hour) AS aggregate_trip_starts,
    (SELECT SUM(trip_ends) FROM dw.fact_station_day_hour) AS aggregate_trip_ends,
    (SELECT SUM(night_trip_count) FROM dw.fact_trip) AS ride_grain_night_trips,
    (SELECT SUM(night_trip_starts) FROM dw.fact_station_day_hour) AS aggregate_night_starts,
    (SELECT SUM(member_trip_count) FROM dw.fact_trip) AS ride_grain_member_trips,
    (SELECT SUM(member_trip_starts) FROM dw.fact_station_day_hour) AS aggregate_member_starts,
    (SELECT SUM(casual_trip_count) FROM dw.fact_trip) AS ride_grain_casual_trips,
    (SELECT SUM(casual_trip_starts) FROM dw.fact_station_day_hour) AS aggregate_casual_starts;

-- Check 9: Warehouse measure sanity checks

SELECT
    COUNT(*) FILTER (WHERE duration_seconds <= 0 OR duration_seconds > 86400) AS invalid_duration_rows,
    COUNT(*) FILTER (WHERE duration_minutes <= 0) AS invalid_duration_minutes_rows,
    COUNT(*) FILTER (WHERE approximate_distance_km < 0) AS negative_distance_rows,
    COUNT(*) FILTER (WHERE trip_count <> 1) AS invalid_trip_count_rows,
    COUNT(*) FILTER (WHERE night_trip_count NOT IN (0, 1)) AS invalid_night_count_rows,
    COUNT(*) FILTER (WHERE member_trip_count + casual_trip_count NOT IN (0, 1)) AS invalid_rider_indicator_rows
FROM dw.fact_trip;

-- Check 10: Demo-oriented dimensional coverage summary

SELECT 'date_days' AS metric, COUNT(*)::BIGINT AS value FROM dw.dim_date WHERE date_key <> 0
UNION ALL SELECT 'time_hours', COUNT(*) FROM dw.dim_time WHERE time_key <> 0
UNION ALL SELECT 'calendar_event_rows', COUNT(*) FROM dw.dim_calendar_event WHERE calendar_event_key <> 0
UNION ALL SELECT 'weather_days', COUNT(*) FROM dw.dim_weather WHERE weather_key <> 0
UNION ALL SELECT 'geographies', COUNT(*) FROM dw.dim_geography WHERE geography_key <> 0
UNION ALL SELECT 'stations', COUNT(*) FROM dw.dim_station WHERE station_key <> 0
UNION ALL SELECT 'ride_grain_facts', COUNT(*) FROM dw.fact_trip
UNION ALL SELECT 'station_day_hour_facts', COUNT(*) FROM dw.fact_station_day_hour
ORDER BY metric;
