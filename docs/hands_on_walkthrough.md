# Hands-On Walkthrough

Questa traccia serve per ripercorrere il progetto in locale, fase per fase.
Ogni sezione contiene:

- cosa stai verificando;
- il comando o la query da eseguire;
- il significato da spiegare durante l'esposizione.

## 0. Stato del repository

```powershell
git status --short --branch
git log --oneline --decorate -n 8
```

Da osservare:

- `main...origin/main` senza file modificati significa che il locale e' allineato al remoto.
- Gli ultimi commit mostrano Phase 7, Phase 8 e la bozza di presentazione.

Frase da esposizione:

> Il progetto e' organizzato in milestone Git piccole: ogni fase aggiunge script, SQL, documentazione e validazioni.

## 1. Source acquisition

```powershell
Get-ChildItem -Recurse data_raw |
    Where-Object { -not $_.PSIsContainer } |
    Select-Object FullName, Length
```

Da confrontare con:

```powershell
Get-Content docs\source_inventory.md
```

Da osservare:

- Citi Bike January 2024 e' il file raw grande.
- Weather, holidays e boundary NYC sono file raw piu' piccoli.
- I raw data sono ignorati da Git; si versionano script e documentazione.

Frase da esposizione:

> Le sorgenti sono scaricate in modo riproducibile e documentate in source inventory, ma i dati pesanti non vengono committati.

## 2. Staging layer

Query:

```sql
SELECT 'citibike_trip_raw' AS table_name, COUNT(*) AS rows FROM staging.citibike_trip_raw
UNION ALL SELECT 'weather_raw', COUNT(*) FROM staging.weather_raw
UNION ALL SELECT 'holiday_raw', COUNT(*) FROM staging.holiday_raw
UNION ALL SELECT 'nyc_nta_raw', COUNT(*) FROM staging.nyc_nta_raw
UNION ALL SELECT 'nyc_borough_raw', COUNT(*) FROM staging.nyc_borough_raw
ORDER BY table_name;
```

Expected baseline:

| Table | Rows |
| --- | ---: |
| `staging.citibike_trip_raw` | 1,888,085 |
| `staging.weather_raw` | 366 |
| `staging.holiday_raw` | 17 |
| `staging.nyc_nta_raw` | 262 |
| `staging.nyc_borough_raw` | 5 |

Frase da esposizione:

> Lo staging e' il landing raw-ish: carichiamo le sorgenti con trasformazioni minime per mantenere tracciabilita' e audit.

## 3. Reconciled layer

Query di accounting:

```sql
SELECT
    (SELECT COUNT(*) FROM staging.citibike_trip_raw) AS staging_rows,
    (SELECT COUNT(*) FROM reconciled.trip) AS accepted_trips,
    (SELECT COUNT(*) FROM reconciled.trip_rejection) AS rejected_trips,
    (SELECT COUNT(*) FROM reconciled.trip) +
        (SELECT COUNT(*) FROM reconciled.trip_rejection) AS accounted_rows;
```

Expected baseline:

| Metric | Value |
| --- | ---: |
| staging rows | 1,888,085 |
| accepted trips | 1,881,951 |
| rejected trips | 6,134 |
| accounted rows | 1,888,085 |

Query rejection reasons:

```sql
SELECT primary_rejection_reason, COUNT(*) AS rejected_rows
FROM reconciled.trip_rejection
GROUP BY primary_rejection_reason
ORDER BY rejected_rows DESC;
```

Query flow direction:

```sql
SELECT
    flow_direction,
    COUNT(*) AS trips,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM reconciled.trip
GROUP BY flow_direction
ORDER BY trips DESC;
```

Frase da esposizione:

> Il reconciled layer pulisce e integra: ogni trip raw e' o accettata o classificata tra gli scarti, e le corse accettate ricevono attributi derivati come durata, night flag, distanza approssimata e flow direction.

## 4. PostGIS geography enrichment

Query:

```sql
SELECT geo_assignment_status, COUNT(*) AS stations
FROM reconciled.station
GROUP BY geo_assignment_status
ORDER BY stations DESC;
```

Expected baseline:

| Status | Stations |
| --- | ---: |
| `assigned_nta` | 2,223 |
| `outside_nyc_or_unknown` | 39 |

Frase da esposizione:

> PostGIS serve per assegnare le stazioni a NTA e borough con point-in-polygon; questo abilita la gerarchia geografica station -> NTA -> CDTA -> borough -> city.

## 5. Warehouse schema

Query:

```sql
SELECT table_name, COUNT(*) AS columns
FROM information_schema.columns
WHERE table_schema = 'dw'
GROUP BY table_name
ORDER BY table_name;
```

Query row counts:

```sql
SELECT 'dim_date' AS table_name, COUNT(*) AS rows FROM dw.dim_date
UNION ALL SELECT 'dim_time', COUNT(*) FROM dw.dim_time
UNION ALL SELECT 'dim_calendar_event', COUNT(*) FROM dw.dim_calendar_event
UNION ALL SELECT 'dim_weather', COUNT(*) FROM dw.dim_weather
UNION ALL SELECT 'dim_geography', COUNT(*) FROM dw.dim_geography
UNION ALL SELECT 'dim_station', COUNT(*) FROM dw.dim_station
UNION ALL SELECT 'dim_user_type', COUNT(*) FROM dw.dim_user_type
UNION ALL SELECT 'dim_rideable_type', COUNT(*) FROM dw.dim_rideable_type
UNION ALL SELECT 'fact_trip', COUNT(*) FROM dw.fact_trip
UNION ALL SELECT 'fact_station_day_hour', COUNT(*) FROM dw.fact_station_day_hour
ORDER BY table_name;
```

Expected baseline:

| Table | Rows |
| --- | ---: |
| `dw.fact_trip` | 1,881,951 |
| `dw.fact_station_day_hour` | 801,443 |
| `dw.dim_station` | 2,263 |
| `dw.dim_geography` | 263 |
| `dw.dim_date` | 368 |
| `dw.dim_weather` | 367 |

Frase da esposizione:

> Il warehouse usa un modello ibrido star/snowflake: il fatto principale e' a grana corsa, mentre la fact aggregata station-day-hour serve per query OLAP e demo piu' rapide.

## 6. Fact reconciliation

Query:

```sql
SELECT
    (SELECT SUM(trip_count) FROM dw.fact_trip) AS ride_grain_trips,
    (SELECT SUM(trip_starts) FROM dw.fact_station_day_hour) AS aggregate_starts,
    (SELECT SUM(trip_ends) FROM dw.fact_station_day_hour) AS aggregate_ends,
    (SELECT SUM(night_trip_count) FROM dw.fact_trip) AS ride_grain_night_trips,
    (SELECT SUM(night_trip_starts) FROM dw.fact_station_day_hour) AS aggregate_night_starts;
```

Expected baseline:

| Metric | Value |
| --- | ---: |
| ride grain trips | 1,881,951 |
| aggregate starts | 1,881,951 |
| aggregate ends | 1,881,951 |
| ride grain night trips | 285,097 |
| aggregate night starts | 285,097 |

Frase da esposizione:

> La fact aggregata non altera la popolazione: i totali riconciliano con la fact a grana corsa.

## 7. OLAP mini-demo

Night demand by borough and day type:

```sql
SELECT
    COALESCE(g.borough_name, 'Unknown') AS start_borough,
    CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    COALESCE(e.holiday_window, 'ordinary_day') AS holiday_window,
    SUM(f.trip_count) AS night_trips,
    ROUND(AVG(f.duration_minutes), 2) AS avg_duration_minutes
FROM dw.fact_trip f
JOIN dw.dim_date d
    ON f.start_date_key = d.date_key
JOIN dw.dim_geography g
    ON f.start_geography_key = g.geography_key
JOIN dw.dim_calendar_event e
    ON f.start_calendar_event_key = e.calendar_event_key
WHERE f.is_night_trip = TRUE
GROUP BY
    COALESCE(g.borough_name, 'Unknown'),
    CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END,
    COALESCE(e.holiday_window, 'ordinary_day')
ORDER BY night_trips DESC
LIMIT 10;
```

Frase da esposizione:

> Questa query fa slice sui night trips, roll-up a borough e dice per weekday/weekend e holiday window.

Holiday effect:

```sql
SELECT
    COALESCE(e.event_group, 'ordinary_day') AS event_group,
    COALESCE(e.holiday_window, 'ordinary_day') AS holiday_window,
    SUM(f.trip_count) AS trips,
    SUM(CASE WHEN f.is_night_trip THEN f.trip_count ELSE 0 END) AS night_trips,
    ROUND(
        100.0 * SUM(CASE WHEN f.is_night_trip THEN f.trip_count ELSE 0 END)
        / NULLIF(SUM(f.trip_count), 0),
        2
    ) AS night_trip_percentage
FROM dw.fact_trip f
JOIN dw.dim_calendar_event e
    ON f.start_calendar_event_key = e.calendar_event_key
GROUP BY
    COALESCE(e.event_group, 'ordinary_day'),
    COALESCE(e.holiday_window, 'ordinary_day')
ORDER BY trips DESC;
```

Frase da esposizione:

> La dimensione calendar event permette di confrontare regular, holiday, holiday eve, post holiday e long weekend senza riscrivere la logica evento nella query.

## 8. Quality checks

```powershell
.\.venv\Scripts\python scripts\run_quality_checks.py
```

Da osservare:

- source/staging row counts in `PASS`;
- accepted + rejected = staging rows;
- duplicate ride IDs a zero;
- broken foreign keys a zero;
- aggregate fact riconciliata con fact ride-grain.

Frase da esposizione:

> I quality check dimostrano che la pipeline e' riproducibile e che le trasformazioni tra livelli sono auditable.

## 9. Chart assets for slides

I grafici Phase 7 sono in:

```text
docs/charts/phase7/
```

Uso consigliato:

| File | Quando mostrarlo |
| --- | --- |
| `01_night_trips_by_borough_daytype.svg` | Dopo la query su night demand per borough e weekday/weekend. |
| `02_holiday_night_share.svg` | Quando spieghi perche' la calendar-event dimension e' utile. |
| `03_top_night_nta_corridors.svg` | Quando passi dal roll-up per borough al dettaglio origine-destinazione NTA. |
| `04_station_net_flow_imbalance.svg` | Quando vuoi correlare i top NTA corridors con il night net-flow delle stesse aree. |

Frase da esposizione:

> I grafici non sostituiscono le query: sono visualizzazioni delle query OLAP, utili per rendere leggibili gli insight principali durante la presentazione.
