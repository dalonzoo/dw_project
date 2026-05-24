-- Phase 4: Rebuild reconciled tables from staging.
-- This script intentionally reloads only the reconciled schema tables.

BEGIN;

TRUNCATE TABLE
    reconciled.trip_rejection,
    reconciled.trip,
    reconciled.daily_weather,
    reconciled.calendar_day,
    reconciled.station,
    reconciled.geography_area
RESTART IDENTITY;

INSERT INTO reconciled.geography_area (
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
    geom,
    source_file
)
SELECT
    nta_id,
    nta_name,
    properties ->> 'ntatype' AS nta_type,
    properties ->> 'ntaabbrev' AS nta_abbrev,
    properties ->> 'cdta2020' AS cdta_id,
    properties ->> 'cdtaname' AS cdta_name,
    properties ->> 'borocode' AS borough_code,
    COALESCE(borough_name, properties ->> 'boroname') AS borough_name,
    properties ->> 'countyfips' AS county_fips,
    'New York City' AS city_name,
    ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3))::GEOMETRY(MULTIPOLYGON, 4326) AS geom,
    source_file
FROM staging.nyc_nta_raw
WHERE nta_id IS NOT NULL
  AND nta_name IS NOT NULL
  AND geom IS NOT NULL;

WITH station_observations AS (
    SELECT
        NULLIF(start_station_id, '') AS station_id,
        NULLIF(start_station_name, '') AS station_name,
        start_lat AS latitude,
        start_lng AS longitude,
        started_at AS observed_at
    FROM staging.citibike_trip_raw
    WHERE NULLIF(start_station_id, '') IS NOT NULL

    UNION ALL

    SELECT
        NULLIF(end_station_id, '') AS station_id,
        NULLIF(end_station_name, '') AS station_name,
        end_lat AS latitude,
        end_lng AS longitude,
        ended_at AS observed_at
    FROM staging.citibike_trip_raw
    WHERE NULLIF(end_station_id, '') IS NOT NULL
),
station_name_rank AS (
    SELECT
        station_id,
        station_name,
        ROW_NUMBER() OVER (
            PARTITION BY station_id
            ORDER BY COUNT(*) DESC, station_name
        ) AS name_rank
    FROM station_observations
    WHERE station_name IS NOT NULL
    GROUP BY station_id, station_name
),
station_points AS (
    SELECT
        station_id,
        AVG(latitude) FILTER (WHERE latitude IS NOT NULL AND longitude IS NOT NULL) AS latitude,
        AVG(longitude) FILTER (WHERE latitude IS NOT NULL AND longitude IS NOT NULL) AS longitude,
        COUNT(*) AS observation_count,
        MIN(observed_at) AS first_seen_at,
        MAX(observed_at) AS last_seen_at
    FROM station_observations
    GROUP BY station_id
)
INSERT INTO reconciled.station (
    station_id,
    station_name,
    latitude,
    longitude,
    geom,
    observation_count,
    first_seen_at,
    last_seen_at,
    nta_id,
    borough_name,
    geo_assignment_status
)
SELECT
    sp.station_id,
    COALESCE(snr.station_name, sp.station_id) AS station_name,
    sp.latitude,
    sp.longitude,
    CASE
        WHEN sp.latitude IS NOT NULL AND sp.longitude IS NOT NULL
            THEN ST_SetSRID(ST_MakePoint(sp.longitude, sp.latitude), 4326)::GEOMETRY(POINT, 4326)
        ELSE NULL
    END AS geom,
    sp.observation_count,
    sp.first_seen_at,
    sp.last_seen_at,
    geo.nta_id,
    geo.borough_name,
    CASE
        WHEN sp.latitude IS NULL OR sp.longitude IS NULL THEN 'no_coordinates'
        WHEN geo.nta_id IS NULL THEN 'outside_nyc_or_unknown'
        ELSE 'assigned_nta'
    END AS geo_assignment_status
FROM station_points sp
LEFT JOIN station_name_rank snr
    ON sp.station_id = snr.station_id
   AND snr.name_rank = 1
LEFT JOIN LATERAL (
    SELECT ga.nta_id, ga.borough_name
    FROM reconciled.geography_area ga
    WHERE sp.latitude IS NOT NULL
      AND sp.longitude IS NOT NULL
      AND ST_Covers(ga.geom, ST_SetSRID(ST_MakePoint(sp.longitude, sp.latitude), 4326))
    ORDER BY ST_Area(ga.geom)
    LIMIT 1
) geo ON TRUE;

WITH date_bounds AS (
    SELECT MIN(min_date) AS min_date, MAX(max_date) AS max_date
    FROM (
        SELECT
            MIN(LEAST(started_at::DATE, ended_at::DATE)) AS min_date,
            MAX(GREATEST(started_at::DATE, ended_at::DATE)) AS max_date
        FROM staging.citibike_trip_raw
        WHERE started_at IS NOT NULL
          AND ended_at IS NOT NULL

        UNION ALL

        SELECT MIN(observation_date), MAX(observation_date)
        FROM staging.weather_raw

        UNION ALL

        SELECT MIN(holiday_date), MAX(holiday_date)
        FROM staging.holiday_raw
    ) sources
),
calendar_dates AS (
    SELECT GENERATE_SERIES(min_date, max_date, INTERVAL '1 day')::DATE AS date_value
    FROM date_bounds
),
holiday_by_day AS (
    SELECT
        holiday_date,
        STRING_AGG(DISTINCT holiday_name, '; ') AS holiday_name,
        STRING_AGG(DISTINCT COALESCE(holiday_types::TEXT, '[]'), '; ') AS holiday_type
    FROM staging.holiday_raw
    WHERE holiday_date IS NOT NULL
    GROUP BY holiday_date
),
date_flags AS (
    SELECT
        d.date_value,
        h.holiday_name,
        h.holiday_type,
        h.holiday_date IS NOT NULL AS is_public_holiday,
        EXISTS (
            SELECT 1
            FROM holiday_by_day h2
            WHERE h2.holiday_date = d.date_value + 1
        ) AS is_holiday_eve,
        EXISTS (
            SELECT 1
            FROM holiday_by_day h2
            WHERE h2.holiday_date = d.date_value - 1
        ) AS is_post_holiday,
        (
            h.holiday_date IS NULL
            AND EXTRACT(ISODOW FROM d.date_value) BETWEEN 1 AND 5
            AND (
                (
                    EXISTS (
                        SELECT 1
                        FROM holiday_by_day h2
                        WHERE h2.holiday_date = d.date_value - 1
                    )
                    AND EXTRACT(ISODOW FROM d.date_value + 1) IN (6, 7)
                )
                OR
                (
                    EXISTS (
                        SELECT 1
                        FROM holiday_by_day h2
                        WHERE h2.holiday_date = d.date_value + 1
                    )
                    AND EXTRACT(ISODOW FROM d.date_value - 1) IN (6, 7)
                )
            )
        ) AS is_bridge_day,
        EXISTS (
            SELECT 1
            FROM holiday_by_day h2
            WHERE (
                EXTRACT(ISODOW FROM h2.holiday_date) = 5
                AND d.date_value BETWEEN h2.holiday_date AND h2.holiday_date + 2
            )
            OR (
                EXTRACT(ISODOW FROM h2.holiday_date) = 1
                AND d.date_value BETWEEN h2.holiday_date - 2 AND h2.holiday_date
            )
        ) AS is_long_weekend_base
    FROM calendar_dates d
    LEFT JOIN holiday_by_day h
        ON d.date_value = h.holiday_date
)
INSERT INTO reconciled.calendar_day (
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
    season_name,
    is_public_holiday,
    holiday_name,
    holiday_type,
    is_holiday_eve,
    is_post_holiday,
    is_bridge_day,
    is_long_weekend,
    holiday_window
)
SELECT
    date_value,
    EXTRACT(YEAR FROM date_value)::INTEGER AS year_number,
    EXTRACT(QUARTER FROM date_value)::INTEGER AS quarter_number,
    EXTRACT(MONTH FROM date_value)::INTEGER AS month_number,
    TO_CHAR(date_value, 'FMMonth') AS month_name,
    EXTRACT(WEEK FROM date_value)::INTEGER AS week_of_year,
    EXTRACT(DAY FROM date_value)::INTEGER AS day_of_month,
    EXTRACT(ISODOW FROM date_value)::INTEGER AS iso_day_of_week,
    TO_CHAR(date_value, 'FMDay') AS day_name,
    EXTRACT(ISODOW FROM date_value) IN (6, 7) AS is_weekend,
    CASE
        WHEN EXTRACT(MONTH FROM date_value) IN (12, 1, 2) THEN 'winter'
        WHEN EXTRACT(MONTH FROM date_value) IN (3, 4, 5) THEN 'spring'
        WHEN EXTRACT(MONTH FROM date_value) IN (6, 7, 8) THEN 'summer'
        ELSE 'autumn'
    END AS season_name,
    is_public_holiday,
    holiday_name,
    holiday_type,
    is_holiday_eve,
    is_post_holiday,
    is_bridge_day,
    is_long_weekend_base OR is_bridge_day AS is_long_weekend,
    CASE
        WHEN is_public_holiday THEN 'holiday'
        WHEN is_bridge_day THEN 'bridge_day'
        WHEN is_holiday_eve THEN 'holiday_eve'
        WHEN is_post_holiday THEN 'post_holiday'
        WHEN is_long_weekend_base THEN 'long_weekend'
        ELSE 'regular'
    END AS holiday_window
FROM date_flags;

WITH normalized_weather AS (
    SELECT
        station,
        station_name,
        observation_date,
        latitude,
        longitude,
        elevation,
        CASE
            WHEN tavg IS NOT NULL THEN tavg
            WHEN tmax IS NOT NULL AND tmin IS NOT NULL THEN (tmax + tmin) / 2.0
            ELSE NULL
        END AS avg_temperature_c,
        tmax AS max_temperature_c,
        tmin AS min_temperature_c,
        COALESCE(prcp, 0) AS precipitation_mm,
        COALESCE(snow, 0) AS snow_mm,
        snwd AS snow_depth_mm,
        awnd AS avg_wind_speed_mps,
        wsf2 AS fastest_2min_wind_mps,
        COALESCE(wt01, 0) AS wt01,
        COALESCE(wt02, 0) AS wt02,
        COALESCE(wt03, 0) AS wt03,
        COALESCE(wt08, 0) AS wt08,
        source_file
    FROM staging.weather_raw
    WHERE observation_date IS NOT NULL
),
scored_weather AS (
    SELECT
        *,
        CASE
            WHEN snow_mm > 0 OR wt03 = 1 THEN 'snow_or_thunder'
            WHEN precipitation_mm >= 10 THEN 'heavy_rain'
            WHEN precipitation_mm > 0 OR wt01 = 1 OR wt02 = 1 THEN 'wet_or_foggy'
            WHEN wt08 = 1 THEN 'haze'
            ELSE 'dry'
        END AS condition_class,
        (
            CASE WHEN snow_mm > 0 THEN 2 ELSE 0 END
            + CASE
                WHEN precipitation_mm >= 10 THEN 2
                WHEN precipitation_mm > 0 THEN 1
                ELSE 0
              END
            + CASE
                WHEN avg_wind_speed_mps >= 8 THEN 2
                WHEN avg_wind_speed_mps >= 5 THEN 1
                ELSE 0
              END
            + CASE
                WHEN min_temperature_c <= -5 OR max_temperature_c >= 35 THEN 1
                ELSE 0
              END
            + CASE
                WHEN wt03 = 1 THEN 2
                WHEN wt01 = 1 OR wt02 = 1 OR wt08 = 1 THEN 1
                ELSE 0
              END
        ) AS severity_score
    FROM normalized_weather
)
INSERT INTO reconciled.daily_weather (
    observation_date,
    station,
    station_name,
    latitude,
    longitude,
    elevation,
    avg_temperature_c,
    max_temperature_c,
    min_temperature_c,
    precipitation_mm,
    snow_mm,
    snow_depth_mm,
    avg_wind_speed_mps,
    fastest_2min_wind_mps,
    condition_class,
    severity_score,
    severity_label,
    weather_flags,
    source_file
)
SELECT
    observation_date,
    station,
    station_name,
    latitude,
    longitude,
    elevation,
    avg_temperature_c,
    max_temperature_c,
    min_temperature_c,
    precipitation_mm,
    snow_mm,
    snow_depth_mm,
    avg_wind_speed_mps,
    fastest_2min_wind_mps,
    condition_class,
    severity_score,
    CASE
        WHEN severity_score = 0 THEN 'none'
        WHEN severity_score = 1 THEN 'low'
        WHEN severity_score = 2 THEN 'moderate'
        ELSE 'high'
    END AS severity_label,
    JSONB_BUILD_OBJECT(
        'fog', wt01 = 1,
        'heavy_fog', wt02 = 1,
        'thunder', wt03 = 1,
        'haze', wt08 = 1
    ) AS weather_flags,
    source_file
FROM scored_weather;

WITH source_trips AS (
    SELECT
        *,
        CASE
            WHEN started_at IS NOT NULL AND ended_at IS NOT NULL
                THEN EXTRACT(EPOCH FROM ended_at - started_at)::INTEGER
            ELSE NULL
        END AS duration_seconds
    FROM staging.citibike_trip_raw
),
reasoned AS (
    SELECT
        ride_id,
        started_at,
        ended_at,
        start_station_id,
        end_station_id,
        duration_seconds,
        ARRAY_REMOVE(ARRAY[
            CASE WHEN NULLIF(ride_id, '') IS NULL THEN 'missing_ride_id' END,
            CASE WHEN started_at IS NULL OR ended_at IS NULL THEN 'missing_timestamp' END,
            CASE
                WHEN started_at IS NOT NULL AND ended_at IS NOT NULL AND ended_at <= started_at
                    THEN 'non_positive_duration'
            END,
            CASE WHEN duration_seconds > 86400 THEN 'extreme_duration_over_24h' END,
            CASE WHEN NULLIF(start_station_id, '') IS NULL THEN 'missing_start_station_id' END,
            CASE WHEN NULLIF(end_station_id, '') IS NULL THEN 'missing_end_station_id' END
        ], NULL) AS rejection_reasons,
        source_file
    FROM source_trips
)
INSERT INTO reconciled.trip_rejection (
    ride_id,
    started_at,
    ended_at,
    start_station_id,
    end_station_id,
    duration_seconds,
    rejection_reasons,
    primary_rejection_reason,
    source_file
)
SELECT
    ride_id,
    started_at,
    ended_at,
    start_station_id,
    end_station_id,
    duration_seconds,
    rejection_reasons,
    rejection_reasons[1] AS primary_rejection_reason,
    source_file
FROM reasoned
WHERE CARDINALITY(rejection_reasons) > 0;

WITH source_trips AS (
    SELECT
        *,
        EXTRACT(EPOCH FROM ended_at - started_at)::INTEGER AS duration_seconds
    FROM staging.citibike_trip_raw
    WHERE NULLIF(ride_id, '') IS NOT NULL
      AND started_at IS NOT NULL
      AND ended_at IS NOT NULL
      AND ended_at > started_at
      AND EXTRACT(EPOCH FROM ended_at - started_at) <= 86400
      AND NULLIF(start_station_id, '') IS NOT NULL
      AND NULLIF(end_station_id, '') IS NOT NULL
),
deduped_trips AS (
    SELECT DISTINCT ON (ride_id)
        *
    FROM source_trips
    ORDER BY ride_id, started_at, ended_at
),
trip_points AS (
    SELECT
        t.ride_id,
        t.rideable_type,
        t.member_casual AS rider_type,
        t.started_at,
        t.ended_at,
        t.started_at::DATE AS start_date,
        t.ended_at::DATE AS end_date,
        EXTRACT(HOUR FROM t.started_at)::INTEGER AS start_hour,
        EXTRACT(HOUR FROM t.ended_at)::INTEGER AS end_hour,
        t.duration_seconds,
        ROUND((t.duration_seconds / 60.0)::NUMERIC, 2) AS duration_minutes,
        NULLIF(t.start_station_id, '') AS start_station_id,
        NULLIF(t.end_station_id, '') AS end_station_id,
        CASE
            WHEN COALESCE(t.start_lng, ss.longitude) IS NOT NULL
             AND COALESCE(t.start_lat, ss.latitude) IS NOT NULL
                THEN ST_SetSRID(
                    ST_MakePoint(COALESCE(t.start_lng, ss.longitude), COALESCE(t.start_lat, ss.latitude)),
                    4326
                )::GEOMETRY(POINT, 4326)
            ELSE NULL
        END AS start_geom,
        CASE
            WHEN COALESCE(t.end_lng, es.longitude) IS NOT NULL
             AND COALESCE(t.end_lat, es.latitude) IS NOT NULL
                THEN ST_SetSRID(
                    ST_MakePoint(COALESCE(t.end_lng, es.longitude), COALESCE(t.end_lat, es.latitude)),
                    4326
                )::GEOMETRY(POINT, 4326)
            ELSE NULL
        END AS end_geom,
        ss.nta_id AS start_nta_id,
        es.nta_id AS end_nta_id,
        ss.borough_name AS start_borough_name,
        es.borough_name AS end_borough_name,
        t.source_file
    FROM deduped_trips t
    JOIN reconciled.station ss
        ON NULLIF(t.start_station_id, '') = ss.station_id
    JOIN reconciled.station es
        ON NULLIF(t.end_station_id, '') = es.station_id
)
INSERT INTO reconciled.trip (
    ride_id,
    rideable_type,
    rider_type,
    started_at,
    ended_at,
    start_date,
    end_date,
    start_hour,
    end_hour,
    duration_seconds,
    duration_minutes,
    approximate_distance_km,
    start_station_id,
    end_station_id,
    start_geom,
    end_geom,
    is_night_trip,
    is_weekend_start,
    start_nta_id,
    end_nta_id,
    start_borough_name,
    end_borough_name,
    flow_direction,
    source_file
)
SELECT
    ride_id,
    rideable_type,
    rider_type,
    started_at,
    ended_at,
    start_date,
    end_date,
    start_hour,
    end_hour,
    duration_seconds,
    duration_minutes,
    CASE
        WHEN start_geom IS NOT NULL AND end_geom IS NOT NULL
            THEN ROUND((ST_DistanceSphere(start_geom, end_geom) / 1000.0)::NUMERIC, 3)
        ELSE NULL
    END AS approximate_distance_km,
    start_station_id,
    end_station_id,
    start_geom,
    end_geom,
    start_hour >= 20 OR start_hour < 6 AS is_night_trip,
    EXTRACT(ISODOW FROM start_date) IN (6, 7) AS is_weekend_start,
    start_nta_id,
    end_nta_id,
    start_borough_name,
    end_borough_name,
    CASE
        WHEN start_station_id = end_station_id THEN 'same_station'
        WHEN start_nta_id IS NULL OR end_nta_id IS NULL THEN 'outside_or_unknown'
        WHEN start_nta_id = end_nta_id THEN 'within_nta'
        WHEN start_borough_name = end_borough_name THEN 'cross_nta_same_borough'
        ELSE 'cross_borough'
    END AS flow_direction,
    source_file
FROM trip_points;

COMMIT;
