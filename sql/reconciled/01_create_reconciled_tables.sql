-- Phase 4: Reconciled layer tables
-- Run after the staging layer has been created and loaded.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA IF NOT EXISTS reconciled;

CREATE TABLE IF NOT EXISTS reconciled.geography_area (
    nta_id TEXT PRIMARY KEY,
    nta_name TEXT NOT NULL,
    nta_type TEXT,
    nta_abbrev TEXT,
    cdta_id TEXT,
    cdta_name TEXT,
    borough_code TEXT,
    borough_name TEXT NOT NULL,
    county_fips TEXT,
    city_name TEXT NOT NULL DEFAULT 'New York City',
    geom GEOMETRY(MULTIPOLYGON, 4326) NOT NULL,
    source_file TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reconciled.station (
    station_id TEXT PRIMARY KEY,
    station_name TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    geom GEOMETRY(POINT, 4326),
    observation_count BIGINT NOT NULL,
    first_seen_at TIMESTAMP,
    last_seen_at TIMESTAMP,
    nta_id TEXT REFERENCES reconciled.geography_area (nta_id),
    borough_name TEXT,
    geo_assignment_status TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reconciled.calendar_day (
    date_value DATE PRIMARY KEY,
    year_number INTEGER NOT NULL,
    quarter_number INTEGER NOT NULL,
    month_number INTEGER NOT NULL,
    month_name TEXT NOT NULL,
    week_of_year INTEGER NOT NULL,
    day_of_month INTEGER NOT NULL,
    iso_day_of_week INTEGER NOT NULL,
    day_name TEXT NOT NULL,
    is_weekend BOOLEAN NOT NULL,
    season_name TEXT NOT NULL,
    is_public_holiday BOOLEAN NOT NULL,
    holiday_name TEXT,
    holiday_type TEXT,
    is_holiday_eve BOOLEAN NOT NULL,
    is_post_holiday BOOLEAN NOT NULL,
    is_bridge_day BOOLEAN NOT NULL,
    is_long_weekend BOOLEAN NOT NULL,
    holiday_window TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reconciled.daily_weather (
    observation_date DATE PRIMARY KEY REFERENCES reconciled.calendar_day (date_value),
    station TEXT NOT NULL,
    station_name TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    elevation NUMERIC,
    avg_temperature_c NUMERIC,
    max_temperature_c NUMERIC,
    min_temperature_c NUMERIC,
    precipitation_mm NUMERIC,
    snow_mm NUMERIC,
    snow_depth_mm NUMERIC,
    avg_wind_speed_mps NUMERIC,
    fastest_2min_wind_mps NUMERIC,
    condition_class TEXT NOT NULL,
    severity_score INTEGER NOT NULL,
    severity_label TEXT NOT NULL,
    weather_flags JSONB NOT NULL,
    source_file TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reconciled.trip (
    ride_id TEXT PRIMARY KEY,
    rideable_type TEXT NOT NULL,
    rider_type TEXT NOT NULL,
    started_at TIMESTAMP NOT NULL,
    ended_at TIMESTAMP NOT NULL,
    start_date DATE NOT NULL REFERENCES reconciled.calendar_day (date_value),
    end_date DATE NOT NULL REFERENCES reconciled.calendar_day (date_value),
    start_hour INTEGER NOT NULL CHECK (start_hour BETWEEN 0 AND 23),
    end_hour INTEGER NOT NULL CHECK (end_hour BETWEEN 0 AND 23),
    duration_seconds INTEGER NOT NULL CHECK (duration_seconds > 0 AND duration_seconds <= 86400),
    duration_minutes NUMERIC(10, 2) NOT NULL,
    approximate_distance_km NUMERIC(10, 3),
    start_station_id TEXT NOT NULL REFERENCES reconciled.station (station_id),
    end_station_id TEXT NOT NULL REFERENCES reconciled.station (station_id),
    start_geom GEOMETRY(POINT, 4326),
    end_geom GEOMETRY(POINT, 4326),
    is_night_trip BOOLEAN NOT NULL,
    is_weekend_start BOOLEAN NOT NULL,
    start_nta_id TEXT REFERENCES reconciled.geography_area (nta_id),
    end_nta_id TEXT REFERENCES reconciled.geography_area (nta_id),
    start_borough_name TEXT,
    end_borough_name TEXT,
    flow_direction TEXT NOT NULL,
    source_file TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reconciled.trip_rejection (
    rejection_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ride_id TEXT,
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    start_station_id TEXT,
    end_station_id TEXT,
    duration_seconds INTEGER,
    rejection_reasons TEXT[] NOT NULL,
    primary_rejection_reason TEXT NOT NULL,
    source_file TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_reconciled_geography_area_geom
    ON reconciled.geography_area USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_reconciled_station_geom
    ON reconciled.station USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_reconciled_station_nta
    ON reconciled.station (nta_id);

CREATE INDEX IF NOT EXISTS idx_reconciled_calendar_holiday_window
    ON reconciled.calendar_day (holiday_window);

CREATE INDEX IF NOT EXISTS idx_reconciled_weather_condition
    ON reconciled.daily_weather (condition_class, severity_label);

CREATE INDEX IF NOT EXISTS idx_reconciled_trip_start_date
    ON reconciled.trip (start_date);

CREATE INDEX IF NOT EXISTS idx_reconciled_trip_start_station
    ON reconciled.trip (start_station_id);

CREATE INDEX IF NOT EXISTS idx_reconciled_trip_end_station
    ON reconciled.trip (end_station_id);

CREATE INDEX IF NOT EXISTS idx_reconciled_trip_start_nta
    ON reconciled.trip (start_nta_id);

CREATE INDEX IF NOT EXISTS idx_reconciled_trip_end_nta
    ON reconciled.trip (end_nta_id);

CREATE INDEX IF NOT EXISTS idx_reconciled_trip_flow_direction
    ON reconciled.trip (flow_direction);

CREATE INDEX IF NOT EXISTS idx_reconciled_trip_start_geom
    ON reconciled.trip USING GIST (start_geom);

CREATE INDEX IF NOT EXISTS idx_reconciled_trip_end_geom
    ON reconciled.trip USING GIST (end_geom);
