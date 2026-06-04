# Phase 6 - Warehouse Population

## Goal

Phase 6 populates the dimensional warehouse from the completed reconciled layer.

The phase turns clean integrated entities into OLAP-ready dimensions and facts.

## Inputs

The load reads from:

- `reconciled.calendar_day`
- `reconciled.daily_weather`
- `reconciled.geography_area`
- `reconciled.station`
- `reconciled.trip`

## Outputs

The load rebuilds:

- `dw.dim_date`
- `dw.dim_time`
- `dw.dim_calendar_event`
- `dw.dim_weather`
- `dw.dim_geography`
- `dw.dim_station`
- `dw.dim_user_type`
- `dw.dim_rideable_type`
- `dw.fact_trip`
- `dw.fact_station_day_hour`

## Run Order

From the project root:

```powershell
.\.venv\Scripts\python scripts\build_warehouse.py
```

The script executes:

1. `sql/dw/01_create_warehouse_tables.sql`
2. `sql/dw/03_load_warehouse.sql`
3. `sql/dw/04_validate_warehouse_load.sql`

You can also open the SQL files in DBeaver and run them in the same order.

## Loading Logic

The load starts by inserting controlled key `0` rows in every dimension.

These rows protect fact loading when a dimensional reference is missing, outside NYC, or not observed in the source.

The dimension loading order is:

1. Date, time, calendar event, and weather dimensions.
2. Geography dimension.
3. Station dimension, which references geography.
4. User type and rideable type dimensions.

The fact loading order is:

1. `dw.fact_trip`, one row per accepted reconciled ride.
2. `dw.fact_station_day_hour`, one aggregate row per station, calendar day, and hour.

## Theoretical Notes

`dw.fact_trip` uses surrogate keys instead of source natural keys. This is the main dimensional modeling shift from the reconciled layer.

Examples:

- `start_date` becomes `start_date_key`.
- `start_station_id` becomes `start_station_key`.
- `start_nta_id` becomes `start_geography_key`.

`dw.dim_date`, `dw.dim_time`, `dw.dim_station`, and `dw.dim_geography` are role-playing dimensions in the fact because a trip has both start and end contexts.

`dw.fact_station_day_hour` is an aggregate fact. It is not a new source; it summarizes `fact_trip` for faster OLAP queries and demos.

## DBeaver Walkthrough

1. Open the `urban_night_mobility_dw` PostgreSQL connection.
2. Refresh `Schemas > dw > Tables`.
3. Open `dw.fact_trip` and confirm rows are visible.
4. Open `dw.dim_date`, `dw.dim_station`, and `dw.dim_geography`.
5. Open `sql/dw/04_validate_warehouse_load.sql`.
6. Execute one validation query at a time.

The strongest demo query at this stage is the aggregate reconciliation:

```sql
SELECT
    (SELECT SUM(trip_count) FROM dw.fact_trip) AS ride_grain_trip_count,
    (SELECT SUM(trip_starts) FROM dw.fact_station_day_hour) AS aggregate_trip_starts,
    (SELECT SUM(trip_ends) FROM dw.fact_station_day_hour) AS aggregate_trip_ends;
```

All three values should match.

## Validation Snapshot

Latest local validation for the January 2024 development sample:

| Table | Rows |
| --- | ---: |
| `dw.dim_calendar_event` | 368 |
| `dw.dim_date` | 368 |
| `dw.dim_geography` | 263 |
| `dw.dim_rideable_type` | 3 |
| `dw.dim_station` | 2,263 |
| `dw.dim_time` | 25 |
| `dw.dim_user_type` | 3 |
| `dw.dim_weather` | 367 |
| `dw.fact_station_day_hour` | 801,443 |
| `dw.fact_trip` | 1,881,951 |

Fact reconciliation:

- Reconciled accepted trips: `1,881,951`
- Warehouse ride-grain fact rows: `1,881,951`
- `SUM(dw.fact_trip.trip_count)`: `1,881,951`
- Row count gap: `0`

Aggregate reconciliation:

- `SUM(dw.fact_station_day_hour.trip_starts)`: `1,881,951`
- `SUM(dw.fact_station_day_hour.trip_ends)`: `1,881,951`
- `SUM(dw.fact_station_day_hour.night_trip_starts)`: `285,097`
- `SUM(dw.fact_trip.night_trip_count)`: `285,097`

Controlled unknown usage:

| Unknown reference | Trips |
| --- | ---: |
| Date | 0 |
| Time | 0 |
| Calendar event | 0 |
| Weather | 364 |
| Station | 0 |
| Geography | 183 |
| User type | 0 |
| Rideable type | 0 |

The 364 unknown weather trips start on December 31, 2023, while the weather source covers calendar year 2024. The 183 unknown geography trips are the same outside-or-unknown flows already documented in the reconciled layer.
