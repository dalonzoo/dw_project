-- Phase 6: Populate dimensional warehouse from the reconciled layer.
-- This script rebuilds only the dw schema contents.

BEGIN;

TRUNCATE TABLE
    dw.fact_station_day_hour,
    dw.fact_trip,
    dw.dim_station,
    dw.dim_rideable_type,
    dw.dim_user_type,
    dw.dim_weather,
    dw.dim_calendar_event,
    dw.dim_time,
    dw.dim_date,
    dw.dim_geography
RESTART IDENTITY;

INSERT INTO dw.dim_date (
    date_key,
    date_value,
    year_number,
    quarter_number,
    month_number,
    month_name,
    week_of_year,
    day_of_month,
    iso_day_of_week,
    day_name,
    is_weekend,
    season_name
)
VALUES (
    0,
    NULL,
    NULL,
    NULL,
    NULL,
    'Unknown',
    NULL,
    NULL,
    NULL,
    'Unknown',
    NULL,
    'unknown'
);

INSERT INTO dw.dim_time (
    time_key,
    hour_number,
    hour_label,
    part_of_day,
    day_night_class,
    is_night_hour
)
VALUES (
    0,
    NULL,
    'Unknown',
    'unknown',
    'unknown',
    NULL
);

INSERT INTO dw.dim_calendar_event (
    calendar_event_key,
    date_value,
    is_public_holiday,
    holiday_name,
    holiday_type,
    is_holiday_eve,
    is_post_holiday,
    is_bridge_day,
    is_long_weekend,
    holiday_window,
    event_group
)
VALUES (
    0,
    NULL,
    NULL,
    'Unknown',
    'unknown',
    NULL,
    NULL,
    NULL,
    NULL,
    'unknown',
    'unknown'
);

INSERT INTO dw.dim_weather (
    weather_key,
    observation_date,
    weather_station,
    weather_station_name,
    condition_class,
    severity_score,
    severity_label,
    avg_temperature_c,
    max_temperature_c,
    min_temperature_c,
    precipitation_mm,
    snow_mm,
    snow_depth_mm,
    avg_wind_speed_mps,
    fastest_2min_wind_mps,
    weather_flags
)
VALUES (
    0,
    NULL,
    'UNKNOWN',
    'Unknown',
    'unknown',
    NULL,
    'unknown',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    '{}'::JSONB
);

INSERT INTO dw.dim_geography (
    geography_key,
    geography_code,
    nta_id,
    nta_name,
    nta_type,
    nta_abbrev,
    cdta_id,
    cdta_name,
    borough_code,
    borough_name,
    county_fips,
    city_name,
    geography_level,
    is_unknown,
    geom
)
VALUES (
    0,
    'UNKNOWN',
    NULL,
    'Unknown or outside NYC',
    'unknown',
    NULL,
    NULL,
    'Unknown',
    NULL,
    'Unknown',
    NULL,
    'Unknown',
    'unknown',
    TRUE,
    NULL
);

INSERT INTO dw.dim_station (
    station_key,
    station_id,
    station_name,
    latitude,
    longitude,
    geom,
    geography_key,
    borough_name,
    geo_assignment_status,
    observation_count,
    first_seen_at,
    last_seen_at,
    is_unknown
)
VALUES (
    0,
    'UNKNOWN',
    'Unknown station',
    NULL,
    NULL,
    NULL,
    0,
    'Unknown',
    'unknown',
    0,
    NULL,
    NULL,
    TRUE
);

INSERT INTO dw.dim_user_type (
    user_type_key,
    rider_type,
    rider_type_label,
    is_member,
    is_casual
)
VALUES (
    0,
    'unknown',
    'Unknown',
    FALSE,
    FALSE
);

INSERT INTO dw.dim_rideable_type (
    rideable_type_key,
    rideable_type,
    rideable_type_label,
    is_electric
)
VALUES (
    0,
    'unknown',
    'Unknown',
    FALSE
);

INSERT INTO dw.dim_date (
    date_value,
    year_number,
    quarter_number,
    month_number,
    month_name,
    week_of_year,
    day_of_month,
    iso_day_of_week,
    day_name,
    is_weekend,
    season_name
)
SELECT
    date_value,
    year_number,
    quarter_number,
    month_number,
    month_name,
    week_of_year,
    day_of_month,
    iso_day_of_week,
    day_name,
    is_weekend,
    season_name
FROM reconciled.calendar_day
ORDER BY date_value;

INSERT INTO dw.dim_time (
    hour_number,
    hour_label,
    part_of_day,
    day_night_class,
    is_night_hour
)
SELECT
    hour_number,
    LPAD(hour_number::TEXT, 2, '0') || ':00' AS hour_label,
    CASE
        WHEN hour_number BETWEEN 0 AND 5 THEN 'late_night'
        WHEN hour_number BETWEEN 6 AND 9 THEN 'morning'
        WHEN hour_number BETWEEN 10 AND 15 THEN 'midday_afternoon'
        WHEN hour_number BETWEEN 16 AND 19 THEN 'evening'
        ELSE 'night'
    END AS part_of_day,
    CASE
        WHEN hour_number BETWEEN 0 AND 5 OR hour_number BETWEEN 20 AND 23 THEN 'night'
        ELSE 'day'
    END AS day_night_class,
    hour_number BETWEEN 0 AND 5 OR hour_number BETWEEN 20 AND 23 AS is_night_hour
FROM GENERATE_SERIES(0, 23) AS hour_number
ORDER BY hour_number;

INSERT INTO dw.dim_calendar_event (
    date_value,
    is_public_holiday,
    holiday_name,
    holiday_type,
    is_holiday_eve,
    is_post_holiday,
    is_bridge_day,
    is_long_weekend,
    holiday_window,
    event_group
)
SELECT
    date_value,
    is_public_holiday,
    holiday_name,
    holiday_type,
    is_holiday_eve,
    is_post_holiday,
    is_bridge_day,
    is_long_weekend,
    holiday_window,
    CASE
        WHEN is_public_holiday THEN 'public_holiday'
        WHEN is_bridge_day THEN 'bridge_day'
        WHEN is_long_weekend THEN 'long_weekend'
        WHEN is_holiday_eve OR is_post_holiday THEN 'holiday_context'
        ELSE 'regular'
    END AS event_group
FROM reconciled.calendar_day
ORDER BY date_value;

INSERT INTO dw.dim_weather (
    observation_date,
    weather_station,
    weather_station_name,
    condition_class,
    severity_score,
    severity_label,
    avg_temperature_c,
    max_temperature_c,
    min_temperature_c,
    precipitation_mm,
    snow_mm,
    snow_depth_mm,
    avg_wind_speed_mps,
    fastest_2min_wind_mps,
    weather_flags
)
SELECT
    observation_date,
    station AS weather_station,
    station_name AS weather_station_name,
    condition_class,
    severity_score,
    severity_label,
    avg_temperature_c,
    max_temperature_c,
    min_temperature_c,
    precipitation_mm,
    snow_mm,
    snow_depth_mm,
    avg_wind_speed_mps,
    fastest_2min_wind_mps,
    weather_flags
FROM reconciled.daily_weather
ORDER BY observation_date;

INSERT INTO dw.dim_geography (
    geography_code,
    nta_id,
    nta_name,
    nta_type,
    nta_abbrev,
    cdta_id,
    cdta_name,
    borough_code,
    borough_name,
    county_fips,
    city_name,
    geography_level,
    is_unknown,
    geom
)
SELECT
    'NTA:' || nta_id AS geography_code,
    nta_id,
    nta_name,
    nta_type,
    nta_abbrev,
    cdta_id,
    cdta_name,
    borough_code,
    borough_name,
    county_fips,
    city_name,
    'nta' AS geography_level,
    FALSE AS is_unknown,
    geom
FROM reconciled.geography_area
ORDER BY borough_name, cdta_id, nta_id;

INSERT INTO dw.dim_station (
    station_id,
    station_name,
    latitude,
    longitude,
    geom,
    geography_key,
    borough_name,
    geo_assignment_status,
    observation_count,
    first_seen_at,
    last_seen_at,
    is_unknown
)
SELECT
    s.station_id,
    s.station_name,
    s.latitude,
    s.longitude,
    s.geom,
    COALESCE(g.geography_key, 0) AS geography_key,
    COALESCE(s.borough_name, 'Unknown') AS borough_name,
    s.geo_assignment_status,
    s.observation_count,
    s.first_seen_at,
    s.last_seen_at,
    FALSE AS is_unknown
FROM reconciled.station s
LEFT JOIN dw.dim_geography g
    ON s.nta_id = g.nta_id
ORDER BY s.station_id;

INSERT INTO dw.dim_user_type (
    rider_type,
    rider_type_label,
    is_member,
    is_casual
)
SELECT
    rider_type,
    CASE
        WHEN rider_type = 'member' THEN 'Member'
        WHEN rider_type = 'casual' THEN 'Casual'
        ELSE INITCAP(REPLACE(rider_type, '_', ' '))
    END AS rider_type_label,
    rider_type = 'member' AS is_member,
    rider_type = 'casual' AS is_casual
FROM (
    SELECT DISTINCT rider_type
    FROM reconciled.trip
    WHERE rider_type IS NOT NULL
) rider_types
ORDER BY rider_type;

INSERT INTO dw.dim_rideable_type (
    rideable_type,
    rideable_type_label,
    is_electric
)
SELECT
    rideable_type,
    INITCAP(REPLACE(rideable_type, '_', ' ')) AS rideable_type_label,
    rideable_type ILIKE 'electric%' AS is_electric
FROM (
    SELECT DISTINCT rideable_type
    FROM reconciled.trip
    WHERE rideable_type IS NOT NULL
) rideable_types
ORDER BY rideable_type;

INSERT INTO dw.fact_trip (
    ride_id,
    start_date_key,
    end_date_key,
    start_time_key,
    end_time_key,
    start_calendar_event_key,
    start_weather_key,
    start_station_key,
    end_station_key,
    start_geography_key,
    end_geography_key,
    user_type_key,
    rideable_type_key,
    started_at,
    ended_at,
    duration_seconds,
    duration_minutes,
    approximate_distance_km,
    trip_count,
    is_night_trip,
    night_trip_count,
    member_trip_count,
    casual_trip_count,
    same_station_trip_count,
    within_nta_trip_count,
    cross_nta_same_borough_trip_count,
    cross_borough_trip_count,
    outside_or_unknown_trip_count,
    flow_direction,
    source_file
)
SELECT
    t.ride_id,
    COALESCE(sd.date_key, 0) AS start_date_key,
    COALESCE(ed.date_key, 0) AS end_date_key,
    COALESCE(st.time_key, 0) AS start_time_key,
    COALESCE(et.time_key, 0) AS end_time_key,
    COALESCE(ce.calendar_event_key, 0) AS start_calendar_event_key,
    COALESCE(w.weather_key, 0) AS start_weather_key,
    COALESCE(ss.station_key, 0) AS start_station_key,
    COALESCE(es.station_key, 0) AS end_station_key,
    COALESCE(sg.geography_key, 0) AS start_geography_key,
    COALESCE(eg.geography_key, 0) AS end_geography_key,
    COALESCE(ut.user_type_key, 0) AS user_type_key,
    COALESCE(rt.rideable_type_key, 0) AS rideable_type_key,
    t.started_at,
    t.ended_at,
    t.duration_seconds,
    t.duration_minutes,
    t.approximate_distance_km,
    1 AS trip_count,
    t.is_night_trip,
    CASE WHEN t.is_night_trip THEN 1 ELSE 0 END AS night_trip_count,
    CASE WHEN t.rider_type = 'member' THEN 1 ELSE 0 END AS member_trip_count,
    CASE WHEN t.rider_type = 'casual' THEN 1 ELSE 0 END AS casual_trip_count,
    CASE WHEN t.flow_direction = 'same_station' THEN 1 ELSE 0 END AS same_station_trip_count,
    CASE WHEN t.flow_direction = 'within_nta' THEN 1 ELSE 0 END AS within_nta_trip_count,
    CASE WHEN t.flow_direction = 'cross_nta_same_borough' THEN 1 ELSE 0 END AS cross_nta_same_borough_trip_count,
    CASE WHEN t.flow_direction = 'cross_borough' THEN 1 ELSE 0 END AS cross_borough_trip_count,
    CASE WHEN t.flow_direction = 'outside_or_unknown' THEN 1 ELSE 0 END AS outside_or_unknown_trip_count,
    t.flow_direction,
    t.source_file
FROM reconciled.trip t
LEFT JOIN dw.dim_date sd
    ON t.start_date = sd.date_value
LEFT JOIN dw.dim_date ed
    ON t.end_date = ed.date_value
LEFT JOIN dw.dim_time st
    ON t.start_hour = st.hour_number
LEFT JOIN dw.dim_time et
    ON t.end_hour = et.hour_number
LEFT JOIN dw.dim_calendar_event ce
    ON t.start_date = ce.date_value
LEFT JOIN dw.dim_weather w
    ON t.start_date = w.observation_date
LEFT JOIN dw.dim_station ss
    ON t.start_station_id = ss.station_id
LEFT JOIN dw.dim_station es
    ON t.end_station_id = es.station_id
LEFT JOIN dw.dim_geography sg
    ON t.start_nta_id = sg.nta_id
LEFT JOIN dw.dim_geography eg
    ON t.end_nta_id = eg.nta_id
LEFT JOIN dw.dim_user_type ut
    ON t.rider_type = ut.rider_type
LEFT JOIN dw.dim_rideable_type rt
    ON t.rideable_type = rt.rideable_type;

WITH start_agg AS (
    SELECT
        start_station_id AS station_id,
        start_date AS date_value,
        start_hour AS hour_number,
        COUNT(*)::INTEGER AS trip_starts,
        COUNT(*) FILTER (WHERE is_night_trip)::INTEGER AS night_trip_starts,
        COUNT(*) FILTER (WHERE rider_type = 'member')::INTEGER AS member_trip_starts,
        COUNT(*) FILTER (WHERE rider_type = 'casual')::INTEGER AS casual_trip_starts,
        COUNT(*) FILTER (WHERE rideable_type ILIKE 'electric%')::INTEGER AS electric_trip_starts,
        COUNT(*) FILTER (WHERE rideable_type NOT ILIKE 'electric%')::INTEGER AS classic_trip_starts,
        SUM(duration_seconds)::BIGINT AS total_start_duration_seconds,
        ROUND(AVG(duration_minutes), 2) AS avg_start_duration_minutes,
        COALESCE(ROUND(SUM(approximate_distance_km), 3), 0)::NUMERIC(14, 3) AS total_start_distance_km
    FROM reconciled.trip
    GROUP BY start_station_id, start_date, start_hour
),
end_agg AS (
    SELECT
        end_station_id AS station_id,
        end_date AS date_value,
        end_hour AS hour_number,
        COUNT(*)::INTEGER AS trip_ends
    FROM reconciled.trip
    GROUP BY end_station_id, end_date, end_hour
),
station_day_hour AS (
    SELECT
        COALESCE(s.station_id, e.station_id) AS station_id,
        COALESCE(s.date_value, e.date_value) AS date_value,
        COALESCE(s.hour_number, e.hour_number) AS hour_number,
        COALESCE(s.trip_starts, 0) AS trip_starts,
        COALESCE(e.trip_ends, 0) AS trip_ends,
        COALESCE(s.night_trip_starts, 0) AS night_trip_starts,
        COALESCE(s.member_trip_starts, 0) AS member_trip_starts,
        COALESCE(s.casual_trip_starts, 0) AS casual_trip_starts,
        COALESCE(s.electric_trip_starts, 0) AS electric_trip_starts,
        COALESCE(s.classic_trip_starts, 0) AS classic_trip_starts,
        COALESCE(s.total_start_duration_seconds, 0) AS total_start_duration_seconds,
        s.avg_start_duration_minutes,
        COALESCE(s.total_start_distance_km, 0) AS total_start_distance_km
    FROM start_agg s
    FULL OUTER JOIN end_agg e
        ON s.station_id = e.station_id
       AND s.date_value = e.date_value
       AND s.hour_number = e.hour_number
)
INSERT INTO dw.fact_station_day_hour (
    station_key,
    date_key,
    time_key,
    calendar_event_key,
    weather_key,
    trip_starts,
    trip_ends,
    night_trip_starts,
    member_trip_starts,
    casual_trip_starts,
    electric_trip_starts,
    classic_trip_starts,
    total_start_duration_seconds,
    avg_start_duration_minutes,
    total_start_distance_km
)
SELECT
    COALESCE(ds.station_key, 0) AS station_key,
    COALESCE(dd.date_key, 0) AS date_key,
    COALESCE(dt.time_key, 0) AS time_key,
    COALESCE(ce.calendar_event_key, 0) AS calendar_event_key,
    COALESCE(w.weather_key, 0) AS weather_key,
    sdh.trip_starts,
    sdh.trip_ends,
    sdh.night_trip_starts,
    sdh.member_trip_starts,
    sdh.casual_trip_starts,
    sdh.electric_trip_starts,
    sdh.classic_trip_starts,
    sdh.total_start_duration_seconds,
    sdh.avg_start_duration_minutes,
    sdh.total_start_distance_km
FROM station_day_hour sdh
LEFT JOIN dw.dim_station ds
    ON sdh.station_id = ds.station_id
LEFT JOIN dw.dim_date dd
    ON sdh.date_value = dd.date_value
LEFT JOIN dw.dim_time dt
    ON sdh.hour_number = dt.hour_number
LEFT JOIN dw.dim_calendar_event ce
    ON sdh.date_value = ce.date_value
LEFT JOIN dw.dim_weather w
    ON sdh.date_value = w.observation_date;

COMMIT;

