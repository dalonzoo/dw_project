# Phase 3 — Staging Layer

## Goal

Phase 3 creates the raw staging layer for the Urban Night Mobility data warehouse.

The staging layer is the first database landing area after source extraction. It stores source data with minimal transformation so that later reconciled and dimensional layers can be built in a controlled and auditable way.

## Staging tables

The following tables are created in schema `staging`:

- `staging.citibike_trip_raw`
- `staging.weather_raw`
- `staging.holiday_raw`
- `staging.nyc_nta_raw`
- `staging.nyc_borough_raw`

## Local setup

Create the database if needed:

```bash
createdb urban_night_mobility_dw
```

Connect:

```bash
psql urban_night_mobility_dw
```

Enable PostGIS:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
SELECT PostGIS_Version();
```

## Create staging tables

From the project root:

```bash
psql urban_night_mobility_dw -f sql/staging/01_create_staging_tables.sql
```

Or through Python:

```bash
python scripts/load_staging.py --create-tables --dataset citibike
```

## Download source files

Examples:

```bash
python scripts/download_citibike.py --months 202401
python scripts/download_weather_noaa.py
python scripts/download_holidays.py
python scripts/download_nyc_boundaries.py
```

## Load source files into staging

Load everything:

```bash
python scripts/load_staging.py --create-tables --dataset all
```

Load one dataset only:

```bash
python scripts/load_staging.py --dataset citibike
python scripts/load_staging.py --dataset weather
python scripts/load_staging.py --dataset holidays
python scripts/load_staging.py --dataset geography
```

## Validate staging loads

```bash
psql urban_night_mobility_dw -f sql/staging/02_validate_staging_loads.sql
```

## Git policy

Commit SQL scripts, ETL scripts, documentation, and dependency files.

Do not commit raw data, local `.env` files, database dumps, or generated outputs.
