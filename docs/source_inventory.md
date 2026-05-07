# Source Inventory

This file will track every external source used by the warehouse.

| Source | Period | Acquisition Method | Local Path | Extracted At UTC | Row Count | Notes |
| --- | --- | --- | --- | --- | ---: | --- |
| Citi Bike System Data | 2024 development sample | `python scripts/download_citibike.py --months 202401` | `data_raw/citibike/202401-citibike-tripdata.zip` | 2026-05-07T15:39:23+00:00 | 1888085 | January sample: 369035302-byte ZIP with 2 CSV members. Final run should use `--months all-2024`. |
| NOAA NCEI Daily Summaries | 2024 | `python scripts/download_weather_noaa.py` | `data_raw/weather/noaa_daily_USW00094728_2024-01-01_2024-12-31.csv` | 2026-05-07T15:43:27+00:00 | 366 | Central Park station `GHCND:USW00094728`; columns include temperature, precipitation, snow, wind, and weather-type flags. Weather class/severity derivation is postponed to reconciled layer. |
| Nager.Date Holidays API | 2024 | `python scripts/download_holidays.py --year 2024 --country-code US` | `data_raw/holidays/us_public_holidays_2024.json` | 2026-05-07T15:32:23+00:00 | 17 | US public holidays from public API. |
| NYC 2020 Neighborhood Tabulation Areas | current version | `python scripts/download_nyc_boundaries.py --datasets nta2020` | `data_raw/geo/nyc_nta2020.geojson` | 2026-05-07T15:48:12+00:00 | 262 | MultiPolygon NTA features from NYC Open Data Socrata ID `9nt8-h7nd`; includes NTA, CDTA, borough, and county fields. Station point-in-polygon enrichment is postponed to Phase 4. |
| NYC Borough Boundaries | current version | `python scripts/download_nyc_boundaries.py --datasets borough` | `data_raw/geo/nyc_borough_boundaries.geojson` | 2026-05-07T15:48:15+00:00 | 5 | MultiPolygon borough features from NYC Open Data Socrata ID `gthc-hcne`; used for geography hierarchy and demo maps. |

Update this file every time a source is downloaded or refreshed.
