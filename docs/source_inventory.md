# Source Inventory

This file will track every external source used by the warehouse.

| Source | Period | Acquisition Method | Local Path | Extracted At UTC | Row Count | Notes |
| --- | --- | --- | --- | --- | ---: | --- |
| Citi Bike System Data | 2024 development sample | `python scripts/download_citibike.py --months 202401` | `data_raw/citibike/202401-citibike-tripdata.zip` | 2026-05-07T15:39:23+00:00 | 1888085 | January sample: 369035302-byte ZIP with 2 CSV members. Final run should use `--months all-2024`. |
| NOAA GHCN-Daily | 2024 | TODO | `data_raw/weather/` | TODO | TODO | NYC-area station observations. |
| Nager.Date Holidays API | 2024 | `python scripts/download_holidays.py --year 2024 --country-code US` | `data_raw/holidays/us_public_holidays_2024.json` | 2026-05-07T15:32:23+00:00 | 17 | US public holidays from public API. |
| NYC Neighborhood Tabulation Areas | 2020 boundaries | TODO | `data_raw/geo/` | TODO | TODO | Spatial enrichment for stations. |
| NYC Borough Boundaries | current available source | TODO | `data_raw/geo/` | TODO | TODO | Borough hierarchy and demo map layer. |

Update this file every time a source is downloaded or refreshed.
