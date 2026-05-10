-- Phase 3: Staging layer raw tables
-- Run from database urban_night_mobility_dw.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE IF NOT EXISTS staging.citibike_trip_raw (
    ride_id TEXT,
    rideable_type TEXT,
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    start_station_name TEXT,
    start_station_id TEXT,
    end_station_name TEXT,
    end_station_id TEXT,
    start_lat DOUBLE PRECISION,
    start_lng DOUBLE PRECISION,
    end_lat DOUBLE PRECISION,
    end_lng DOUBLE PRECISION,
    member_casual TEXT,
    source_file TEXT,
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS staging.weather_raw (
    station TEXT,
    station_name TEXT,
    observation_date DATE,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    elevation NUMERIC,
    tavg NUMERIC,
    tmax NUMERIC,
    tmin NUMERIC,
    prcp NUMERIC,
    snow NUMERIC,
    snwd NUMERIC,
    awnd NUMERIC,
    wsf2 NUMERIC,
    wt01 INTEGER,
    wt02 INTEGER,
    wt03 INTEGER,
    wt08 INTEGER,
    source_file TEXT,
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS staging.holiday_raw (
    holiday_date DATE,
    local_name TEXT,
    holiday_name TEXT,
    country_code TEXT,
    fixed BOOLEAN,
    global_holiday BOOLEAN,
    counties JSONB,
    launch_year INTEGER,
    holiday_types JSONB,
    source_file TEXT,
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS staging.nyc_nta_raw (
    nta_id TEXT,
    nta_name TEXT,
    borough_name TEXT,
    properties JSONB,
    geom GEOMETRY(MULTIPOLYGON, 4326),
    source_file TEXT,
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS staging.nyc_borough_raw (
    borough_code TEXT,
    borough_name TEXT,
    properties JSONB,
    geom GEOMETRY(MULTIPOLYGON, 4326),
    source_file TEXT,
    ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_citibike_trip_raw_started_at
    ON staging.citibike_trip_raw (started_at);

CREATE INDEX IF NOT EXISTS idx_citibike_trip_raw_ride_id
    ON staging.citibike_trip_raw (ride_id);

CREATE INDEX IF NOT EXISTS idx_weather_raw_observation_date
    ON staging.weather_raw (observation_date);

CREATE INDEX IF NOT EXISTS idx_holiday_raw_holiday_date
    ON staging.holiday_raw (holiday_date);

CREATE INDEX IF NOT EXISTS idx_nyc_nta_raw_geom
    ON staging.nyc_nta_raw USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_nyc_borough_raw_geom
    ON staging.nyc_borough_raw USING GIST (geom);
