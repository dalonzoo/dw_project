-- ============================================================
-- Phase 7 - OLAP Analysis
-- Urban Night Mobility Data Warehouse
-- ============================================================

-- ============================================================
-- Analysis 1: Night demand by borough and day type
-- Business question:
-- Which boroughs generate the highest night mobility demand,
-- and how does demand change between weekdays, weekends,
-- and holiday windows?
-- OLAP operations:
-- Slice on night trips; roll-up to borough; dice by day type
-- and holiday window.
-- ============================================================

SELECT
    COALESCE(g.borough_name, 'Unknown') AS start_borough,
    CASE
        WHEN d.is_weekend THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type,
    COALESCE(e.holiday_window, 'ordinary_day') AS holiday_window,
    SUM(f.trip_count) AS night_trips,
    ROUND(AVG(f.duration_minutes), 2) AS avg_duration_minutes,
    ROUND(AVG(f.approximate_distance_km), 3) AS avg_distance_km
FROM dw.fact_trip f
JOIN dw.dim_date d
    ON f.start_date_key = d.date_key
JOIN dw.dim_geography g
    ON f.start_geography_key = g.geography_key
JOIN dw.dim_calendar_event e
    ON f.start_calendar_event_key = e.calendar_event_key
WHERE f.is_night_trip = TRUE
GROUP BY
    COALESCE(g.borough_name, 'Unknown'),
    CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END,
    COALESCE(e.holiday_window, 'ordinary_day')
ORDER BY night_trips DESC;


-- ============================================================
-- Analysis 2: Weather impact on casual vs member riders
-- Business question:
-- How does weather severity affect demand for members and
-- casual riders?
-- OLAP operations:
-- Dice by rider type and weather class; aggregate trip count,
-- duration, and distance.
-- ============================================================

SELECT
    u.rider_type,
    w.condition_class,
    w.severity_label,
    SUM(f.trip_count) AS trips,
    ROUND(AVG(f.duration_minutes), 2) AS avg_duration_minutes,
    ROUND(AVG(f.approximate_distance_km), 3) AS avg_distance_km
FROM dw.fact_trip f
JOIN dw.dim_user_type u
    ON f.user_type_key = u.user_type_key
JOIN dw.dim_weather w
    ON f.start_weather_key = w.weather_key
GROUP BY
    u.rider_type,
    w.condition_class,
    w.severity_label
ORDER BY
    u.rider_type,
    trips DESC;


-- ============================================================
-- Analysis 3: Station inflow/outflow imbalance
-- Business question:
-- Which stations have the strongest imbalance between arrivals
-- and departures?
-- OLAP operations:
-- Use aggregate station-day-hour fact; roll up to station and
-- borough.
-- ============================================================

SELECT
    s.station_name,
    s.borough_name,
    SUM(f.trip_starts) AS total_starts,
    SUM(f.trip_ends) AS total_ends,
    SUM(f.net_flow_count) AS net_flow,
    ABS(SUM(f.net_flow_count)) AS absolute_imbalance
FROM dw.fact_station_day_hour f
JOIN dw.dim_station s
    ON f.station_key = s.station_key
WHERE s.is_unknown = FALSE
GROUP BY
    s.station_name,
    s.borough_name
HAVING SUM(f.trip_starts) + SUM(f.trip_ends) > 100
ORDER BY absolute_imbalance DESC
LIMIT 25;


-- ============================================================
-- Analysis 4: Electric vs classic bike usage at night and bad weather
-- Business question:
-- Are electric bikes used differently from classic bikes during
-- night hours and under different weather severity classes?
-- OLAP operations:
-- Pivot-like aggregation by rideable type, day/night class,
-- and weather severity.
-- ============================================================

SELECT
    r.rideable_type_label,
    CASE
        WHEN f.is_night_trip THEN 'Night'
        ELSE 'Day'
    END AS day_night_class,
    w.severity_label,
    SUM(f.trip_count) AS trips,
    ROUND(AVG(f.duration_minutes), 2) AS avg_duration_minutes,
    ROUND(AVG(f.approximate_distance_km), 3) AS avg_distance_km
FROM dw.fact_trip f
JOIN dw.dim_rideable_type r
    ON f.rideable_type_key = r.rideable_type_key
JOIN dw.dim_weather w
    ON f.start_weather_key = w.weather_key
GROUP BY
    r.rideable_type_label,
    CASE WHEN f.is_night_trip THEN 'Night' ELSE 'Day' END,
    w.severity_label
ORDER BY
    r.rideable_type_label,
    day_night_class,
    trips DESC;


-- ============================================================
-- Analysis 5: Top night origin-destination corridors
-- Business question:
-- Which borough-to-borough and NTA-to-NTA corridors dominate
-- night mobility?
-- OLAP operations:
-- Slice on night trips; group by origin-destination geography.
-- ============================================================

SELECT
    COALESCE(start_geo.borough_name, 'Unknown') AS start_borough,
    COALESCE(end_geo.borough_name, 'Unknown') AS end_borough,
    COALESCE(start_geo.nta_name, 'Unknown') AS start_nta,
    COALESCE(end_geo.nta_name, 'Unknown') AS end_nta,
    SUM(f.trip_count) AS night_trips,
    ROUND(AVG(f.duration_minutes), 2) AS avg_duration_minutes,
    ROUND(AVG(f.approximate_distance_km), 3) AS avg_distance_km
FROM dw.fact_trip f
JOIN dw.dim_geography start_geo
    ON f.start_geography_key = start_geo.geography_key
JOIN dw.dim_geography end_geo
    ON f.end_geography_key = end_geo.geography_key
WHERE f.is_night_trip = TRUE
GROUP BY
    COALESCE(start_geo.borough_name, 'Unknown'),
    COALESCE(end_geo.borough_name, 'Unknown'),
    COALESCE(start_geo.nta_name, 'Unknown'),
    COALESCE(end_geo.nta_name, 'Unknown')
ORDER BY night_trips DESC
LIMIT 30;


-- ============================================================
-- Analysis 6: Holiday and long-weekend effects
-- Business question:
-- Do holidays, holiday eves, post-holidays, and long weekends
-- change trip demand and night-trip share?
-- OLAP operations:
-- Roll up trips by calendar-event classification and compare
-- demand indicators.
-- ============================================================

SELECT
    COALESCE(e.event_group, 'ordinary_day') AS event_group,
    COALESCE(e.holiday_window, 'ordinary_day') AS holiday_window,
    e.is_public_holiday,
    e.is_holiday_eve,
    e.is_post_holiday,
    e.is_long_weekend,
    SUM(f.trip_count) AS trips,
    SUM(CASE WHEN f.is_night_trip THEN f.trip_count ELSE 0 END) AS night_trips,
    ROUND(
        100.0 * SUM(CASE WHEN f.is_night_trip THEN f.trip_count ELSE 0 END)
        / NULLIF(SUM(f.trip_count), 0),
        2
    ) AS night_trip_percentage,
    ROUND(AVG(f.duration_minutes), 2) AS avg_duration_minutes,
    ROUND(AVG(f.approximate_distance_km), 3) AS avg_distance_km
FROM dw.fact_trip f
JOIN dw.dim_calendar_event e
    ON f.start_calendar_event_key = e.calendar_event_key
GROUP BY
    COALESCE(e.event_group, 'ordinary_day'),
    COALESCE(e.holiday_window, 'ordinary_day'),
    e.is_public_holiday,
    e.is_holiday_eve,
    e.is_post_holiday,
    e.is_long_weekend
ORDER BY trips DESC;


-- ============================================================
-- Analysis 7: Hourly night mobility profile
-- Business question:
-- At which hours is night mobility most concentrated?
-- OLAP operations:
-- Drill down from day-level demand to hourly demand using
-- the time dimension.
-- ============================================================

SELECT
    t.hour_number,
    CASE
        WHEN d.is_weekend THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type,
    SUM(f.trip_count) AS trips,
    SUM(CASE WHEN f.is_night_trip THEN f.trip_count ELSE 0 END) AS night_trips,
    ROUND(AVG(f.duration_minutes), 2) AS avg_duration_minutes
FROM dw.fact_trip f
JOIN dw.dim_time t
    ON f.start_time_key = t.time_key
JOIN dw.dim_date d
    ON f.start_date_key = d.date_key
GROUP BY
    t.hour_number,
    CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END
ORDER BY
    t.hour_number,
    day_type;