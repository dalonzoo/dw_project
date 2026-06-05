# Scripts

Python scripts for acquisition, loading, cleaning, and checks will live here.

Planned order:

1. Download source files into `data_raw/`
2. Load staging tables
3. Build reconciled tables
4. Populate warehouse tables
5. Run data quality checks

## Current runnable scripts

```powershell
.\.venv\Scripts\python scripts\download_holidays.py --year 2024 --country-code US
.\.venv\Scripts\python scripts\download_citibike.py --months 202401
.\.venv\Scripts\python scripts\download_weather_noaa.py
.\.venv\Scripts\python scripts\download_nyc_boundaries.py
.\.venv\Scripts\python scripts\load_staging.py --create-tables --dataset all
.\.venv\Scripts\python scripts\build_reconciled.py
.\.venv\Scripts\python scripts\build_warehouse_schema.py
.\.venv\Scripts\python scripts\build_warehouse.py
.\.venv\Scripts\python scripts\run_quality_checks.py
```
