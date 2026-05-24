-- Phase 4: Validation checks for reconciled loads.

SELECT 'geography_area' AS table_name, COUNT(*) AS row_count FROM reconciled.geography_area
UNION ALL
SELECT 'station', COUNT(*) FROM reconciled.station
UNION ALL
SELECT 'calendar_day', COUNT(*) FROM reconciled.calendar_day
UNION ALL
SELECT 'daily_weather', COUNT(*) FROM reconciled.daily_weather
UNION ALL
SELECT 'trip', COUNT(*) FROM reconciled.trip
UNION ALL
SELECT 'trip_rejection', COUNT(*) FROM reconciled.trip_rejection
ORDER BY table_name;

SELECT
    (SELECT COUNT(*) FROM staging.citibike_trip_raw) AS staging_trip_rows,
    (SELECT COUNT(*) FROM reconciled.trip) AS accepted_reconciled_trips,
    (SELECT COUNT(*) FROM reconciled.trip_rejection) AS rejected_staging_trips,
    (SELECT COUNT(*) FROM reconciled.trip) + (SELECT COUNT(*) FROM reconciled.trip_rejection) AS accounted_trip_rows;

SELECT
    primary_rejection_reason,
    COUNT(*) AS rejected_rows
FROM reconciled.trip_rejection
GROUP BY primary_rejection_reason
ORDER BY rejected_rows DESC, primary_rejection_reason;

SELECT
    reason AS rejection_reason,
    COUNT(*) AS rejected_rows
FROM reconciled.trip_rejection
CROSS JOIN LATERAL UNNEST(rejection_reasons) AS reason
GROUP BY reason
ORDER BY rejected_rows DESC, reason;

SELECT
    geo_assignment_status,
    COUNT(*) AS stations,
    SUM(observation_count) AS station_observations
FROM reconciled.station
GROUP BY geo_assignment_status
ORDER BY stations DESC;

SELECT
    flow_direction,
    COUNT(*) AS trips,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_trips
FROM reconciled.trip
GROUP BY flow_direction
ORDER BY trips DESC;

SELECT
    COUNT(*) FILTER (WHERE start_station_id IS NULL OR end_station_id IS NULL) AS trips_missing_station_reference,
    COUNT(*) FILTER (WHERE duration_seconds <= 0 OR duration_seconds > 86400) AS trips_invalid_duration,
    COUNT(*) FILTER (WHERE start_date IS NULL OR end_date IS NULL) AS trips_missing_calendar_reference,
    COUNT(*) FILTER (WHERE start_geom IS NULL OR end_geom IS NULL) AS trips_missing_geometry
FROM reconciled.trip;

SELECT
    MIN(date_value) AS first_calendar_day,
    MAX(date_value) AS last_calendar_day,
    COUNT(*) AS calendar_days,
    COUNT(*) FILTER (WHERE is_public_holiday) AS public_holidays,
    COUNT(*) FILTER (WHERE is_long_weekend) AS long_weekend_days,
    COUNT(*) FILTER (WHERE holiday_window <> 'regular') AS event_window_days
FROM reconciled.calendar_day;

SELECT
    condition_class,
    severity_label,
    COUNT(*) AS weather_days
FROM reconciled.daily_weather
GROUP BY condition_class, severity_label
ORDER BY condition_class, severity_label;

SELECT
    COUNT(*) AS total_trips,
    COUNT(*) FILTER (WHERE is_night_trip) AS night_trips,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_night_trip) / COUNT(*), 2) AS pct_night_trips,
    ROUND(AVG(duration_minutes), 2) AS avg_duration_minutes,
    ROUND(AVG(approximate_distance_km), 3) AS avg_approx_distance_km
FROM reconciled.trip;
