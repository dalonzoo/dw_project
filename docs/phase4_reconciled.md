# Phase 4 - Reconciled Layer

## Goal

Phase 4 converts the raw staging tables into clean, integrated relational tables.

The reconciled layer is still not the dimensional warehouse. Its purpose is to make source data semantically consistent before building facts and dimensions.

## Inputs

The build reads from these staging tables:

- `staging.citibike_trip_raw`
- `staging.weather_raw`
- `staging.holiday_raw`
- `staging.nyc_nta_raw`
- `staging.nyc_borough_raw`

## Outputs

The build creates and loads these reconciled tables:

- `reconciled.geography_area`
- `reconciled.station`
- `reconciled.calendar_day`
- `reconciled.daily_weather`
- `reconciled.trip`
- `reconciled.trip_rejection`

## Run Order

From the project root:

```powershell
.\.venv\Scripts\python scripts\build_reconciled.py
```

The script executes:

1. `sql/reconciled/01_create_reconciled_tables.sql`
2. `sql/reconciled/02_load_reconciled.sql`
3. `sql/reconciled/03_validate_reconciled.sql`

You can also open the three SQL files in DBeaver and run them in the same order.

## Cleaning Rules

Trips are accepted into `reconciled.trip` only when:

- `ride_id` is present.
- `started_at` and `ended_at` are present.
- `ended_at` is after `started_at`.
- Duration is at most 24 hours.
- Start and end station IDs are present.

Rejected rows are preserved in `reconciled.trip_rejection` with one or more rejection reasons.

For the January 2024 development sample:

- Accepted trips: `1,881,951`
- Rejected trips: `6,134`
- Accounted source rows: `1,888,085`

Main rejection reasons:

- Missing end station ID: `5,505`
- Missing start station ID: `1,160`
- Extreme duration over 24 hours: `607`

The reason counts overlap because one rejected trip can have more than one issue.

## Derived Attributes

`reconciled.station` is built from observed start and end station records.

Station coordinates are averaged from valid observations, then assigned to NYC NTAs with PostGIS `ST_Covers`.

For the January 2024 development sample:

- Stations assigned to an NYC NTA: `2,223`
- Stations outside NYC or unknown: `39`

The outside/unknown stations are mostly Citi Bike stations in Jersey City or Hoboken, which are not covered by NYC NTA polygons.

`reconciled.calendar_day` includes:

- Day, week, month, quarter, season, and weekend attributes.
- Public holiday, holiday eve, post-holiday, bridge day, and long-weekend flags.
- A compact `holiday_window` label for OLAP slicing.

The holiday source has 17 rows but 14 unique holiday dates; duplicate holiday names on the same date are deduplicated in the calendar table.

`reconciled.daily_weather` includes:

- Temperature, precipitation, snow, wind, and NOAA weather flags.
- A derived `condition_class`.
- A derived `severity_score` and `severity_label`.

`reconciled.trip` includes:

- Duration in seconds and minutes.
- Approximate straight-line distance in km.
- Night trip flag using the 20:00-05:59 window.
- Weekend-start flag.
- Start/end NTA and borough.
- Flow direction:
  - `same_station`
  - `within_nta`
  - `cross_nta_same_borough`
  - `cross_borough`
  - `outside_or_unknown`

## Validation Snapshot

Latest local validation:

| Table | Rows |
| --- | ---: |
| `reconciled.calendar_day` | 367 |
| `reconciled.daily_weather` | 366 |
| `reconciled.geography_area` | 262 |
| `reconciled.station` | 2,262 |
| `reconciled.trip` | 1,881,951 |
| `reconciled.trip_rejection` | 6,134 |

Main trip flow distribution:

| Flow direction | Trips | Percent |
| --- | ---: | ---: |
| `cross_nta_same_borough` | 1,289,983 | 68.54 |
| `within_nta` | 429,121 | 22.80 |
| `cross_borough` | 126,731 | 6.73 |
| `same_station` | 35,933 | 1.91 |
| `outside_or_unknown` | 183 | 0.01 |

Night trips in the development sample:

- Night trips: `285,097`
- Share of accepted trips: `15.15%`
- Average duration: `10.83` minutes
- Average approximate distance: `1.775` km

## DBeaver Walkthrough

Use this sequence to inspect the result visually:

1. Open the `urban_night_mobility_dw` PostgreSQL connection.
2. Refresh the database object tree.
3. Expand `Schemas > reconciled > Tables`.
4. Open `reconciled.trip`, `reconciled.station`, and `reconciled.geography_area`.
5. Open `sql/reconciled/03_validate_reconciled.sql` in a SQL editor.
6. Execute one validation query at a time to show row counts, rejected rows, station coverage, and flow direction.

The strongest demo query at this stage is the flow-direction validation because it already shows integrated trip, station, and geography semantics before the warehouse is built.
