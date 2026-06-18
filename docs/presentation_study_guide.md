# Guida di studio per la presentazione

Questa guida serve per preparare la discussione del progetto **Urban Night Mobility Data Warehouse** davanti a un professore di Data Management.

L'obiettivo non e' memorizzare file e query, ma saper spiegare il progetto come una pipeline di gestione dati completa: sorgenti, integrazione, qualita', modellazione multidimensionale, popolamento del data warehouse e analisi OLAP.

## 1. Elevator pitch

Frase breve da sapere bene:

> Il progetto realizza un data warehouse PostgreSQL/PostGIS per analizzare la mobilita' notturna di Citi Bike a New York. Le corse vengono integrate con meteo, festivita' e confini geografici NYC. La pipeline passa da dati raw a staging, poi a un livello reconciled pulito, infine a un warehouse dimensionale usato per analisi OLAP.

Da citare subito:

- Dominio: mobilita' urbana notturna.
- DBMS: PostgreSQL con estensione PostGIS.
- Sorgente principale: Citi Bike trips.
- Sorgenti di arricchimento: NOAA weather, Nager.Date holidays, NYC NTA e borough boundaries.
- Output: modello dimensionale, query OLAP, controlli qualita', grafici e presentazione.

## 2. Mappa mentale del progetto

Schema logico:

```text
data_raw
  -> staging
  -> reconciled
  -> dw
  -> sql/olap + charts + presentation
```

Significato dei livelli:

| Livello | Cosa contiene | Perche' esiste |
| --- | --- | --- |
| `data_raw/` | File scaricati localmente | Conserva le sorgenti originali fuori da Git |
| `staging` | Tabelle raw-ish | Caricamento con trasformazioni minime e tracciabilita' |
| `reconciled` | Dati puliti e integrati | Uniforma semantica, scarti, geografia, calendario e meteo |
| `dw` | Fatti e dimensioni | Supporta analisi OLAP efficienti e leggibili |
| `audit` / quality | Controlli e riconciliazioni | Dimostra riproducibilita' e correttezza |

File da conoscere:

- `README.md`: panoramica completa e baseline validata.
- `docs/source_inventory.md`: sorgenti, metodi di acquisizione e row count.
- `docs/modeling_notes.md`: grana, misure, dimensioni e scelta star/snowflake.
- `docs/hands_on_walkthrough.md`: scaletta demo in DBeaver.
- `sql/olap/01_olap_analysis.sql`: query OLAP principali.
- `sql/quality/01_quality_checks.sql`: controlli di qualita'.
- `presentation/Urban-Night-Mobility-Data-Warehouse_final.pdf`: slide finali.

## 3. Problema analitico

Domanda generale:

> Come cambia la mobilita' notturna Citi Bike a New York rispetto a geografia, tempo, meteo, festivita', tipo utente, tipo bici e flussi tra stazioni?

Domande specifiche:

- Quali borough e NTA generano piu' domanda notturna?
- I weekend e le festivita' aumentano la quota di corse notturne?
- I membri e gli utenti casual reagiscono diversamente al meteo?
- Le e-bike sono usate diversamente dalle bici classiche di notte?
- Quali stazioni hanno squilibrio tra partenze e arrivi?
- Quali corridoi NTA-to-NTA dominano la mobilita' notturna?

Perche' e' un problema da data warehouse:

- Richiede integrazione di piu' sorgenti eterogenee.
- Richiede gerarchie analitiche, per esempio ora -> parte del giorno, stazione -> NTA -> borough.
- Richiede aggregazioni ripetute e confronti multidimensionali.
- Non e' solo una query su un CSV: ci sono pulizia, vincoli, chiavi, qualita' e schema dimensionale.

## 4. Sorgenti dati

| Sorgente | Uso nel progetto | Concetto da spiegare |
| --- | --- | --- |
| Citi Bike System Data | Corse, stazioni osservate, timestamp, rider type, rideable type | Sorgente fact-like principale |
| NOAA Daily Summaries | Meteo giornaliero Central Park 2024 | Arricchimento contestuale |
| Nager.Date API | Festivita' pubbliche USA 2024 | Dimensione calendario/evento |
| NYC NTA boundaries | Poligoni NTA e CDTA | Gerarchia geografica fine |
| NYC Borough boundaries | Poligoni dei borough | Gerarchia geografica alta |

Baseline locale validata:

| Metrica | Valore |
| --- | ---: |
| Righe Citi Bike in staging | 1,888,085 |
| Corse accettate nel reconciled | 1,881,951 |
| Corse scartate | 6,134 |
| Fatti `dw.fact_trip` | 1,881,951 |
| Fatti aggregati `dw.fact_station_day_hour` | 801,443 |
| Corse notturne | 285,097 |
| Stazioni riconciliate | 2,262 |
| Stazioni assegnate a NTA NYC | 2,223 |

Nota da dire se il professore chiede il periodo:

> La baseline validata usa il campione Citi Bike di gennaio 2024, mentre meteo, festivita' e geografie coprono il 2024. La pipeline e' pensata per scalare all'intero anno 2024.

## 5. Staging layer

Tabelle principali:

- `staging.citibike_trip_raw`
- `staging.weather_raw`
- `staging.holiday_raw`
- `staging.nyc_nta_raw`
- `staging.nyc_borough_raw`

Concetto:

> Lo staging e' il punto di atterraggio nel DB. Mantiene i dati quasi raw, aggiungendo solo metadati di caricamento. Serve per audit, ripetibilita' e separazione tra acquisizione e trasformazione.

Perche' non pulire subito tutto:

- Si conserva tracciabilita' verso la sorgente.
- Gli errori si possono contare e spiegare.
- Le regole di pulizia stanno in un livello esplicito, il reconciled.

Esempio utile:

> In staging ci sono anche righe Citi Bike con coordinate mancanti. Non vengono eliminate subito: vengono preservate e gestite nel reconciled.

## 6. Reconciled layer

Tabelle principali:

- `reconciled.trip`
- `reconciled.trip_rejection`
- `reconciled.station`
- `reconciled.calendar_day`
- `reconciled.daily_weather`
- `reconciled.geography_area`

Concetto:

> Il reconciled layer e' il livello relazionale pulito e integrato. Non e' ancora il data warehouse dimensionale: serve a rendere coerenti le sorgenti prima di costruire fatti e dimensioni.

Regole di accettazione delle corse:

- `ride_id` presente.
- `started_at` ed `ended_at` presenti.
- `ended_at` successivo a `started_at`.
- durata massima 24 ore.
- start/end station ID presenti.

Scarti:

- Le righe non valide finiscono in `reconciled.trip_rejection`.
- Ogni scarto conserva motivo o motivi di rifiuto.
- Questo evita scarti silenziosi.

Attributi derivati importanti:

- `duration_seconds`, `duration_minutes`.
- `approximate_distance_km`, calcolata con distanza sferica tra coordinate.
- `is_night_trip`, vero per corse iniziate dalle 20:00 alle 05:59.
- `is_weekend_start`.
- `flow_direction`: `same_station`, `within_nta`, `cross_nta_same_borough`, `cross_borough`, `outside_or_unknown`.

PostGIS:

> PostGIS viene usato per associare le stazioni ai poligoni NTA tramite point-in-polygon. In questo modo una stazione diventa analizzabile nella gerarchia station -> NTA -> CDTA -> borough -> city.

Dettaglio tecnico da sapere:

- Le stazioni sono ricostruite dalle osservazioni di start/end station.
- Le coordinate vengono mediate dalle osservazioni valide.
- L'assegnazione geografica usa la posizione della stazione e i poligoni NYC.
- Le stazioni fuori NYC, per esempio Jersey City o Hoboken, restano `outside_nyc_or_unknown`.

## 7. Data warehouse dimensionale

Fatto principale:

- `dw.fact_trip`
- Grana: una riga = una corsa Citi Bike accettata.

Fatto aggregato:

- `dw.fact_station_day_hour`
- Grana: una riga = una stazione, un giorno, un'ora.
- Serve per query piu' rapide su flussi e sbilanciamenti.

Dimensioni:

| Dimensione | Cosa permette di analizzare |
| --- | --- |
| `dw.dim_date` | giorno, settimana, mese, trimestre, stagione, anno |
| `dw.dim_time` | ora, parte del giorno, giorno/notte |
| `dw.dim_calendar_event` | festivita', eve, post-holiday, bridge day, long weekend |
| `dw.dim_weather` | condizione meteo, severita', temperatura, precipitazione |
| `dw.dim_geography` | NTA, CDTA, borough, citta' |
| `dw.dim_station` | stazione e geografia associata |
| `dw.dim_user_type` | member vs casual |
| `dw.dim_rideable_type` | classic vs electric |

Misure in `fact_trip`:

- `trip_count`: sempre 1, misura additiva base.
- `duration_seconds`, `duration_minutes`.
- `approximate_distance_km`.
- `night_trip_count`.
- `member_trip_count`, `casual_trip_count`.
- indicatori di flusso: within NTA, cross borough, ecc.

Concetti teorici da collegare:

| Concetto | Come appare nel progetto |
| --- | --- |
| Grana del fatto | `fact_trip` = una corsa; `fact_station_day_hour` = stazione-giorno-ora |
| Chiave surrogata | Le dimensioni usano chiavi come `date_key`, `station_key`, `weather_key` |
| Chiave naturale | `ride_id`, `station_id`, `nta_id` arrivano dalle sorgenti |
| Role-playing dimension | data, ora, stazione e geografia appaiono come start e end |
| Dimensione degenere | `flow_direction` e' una classificazione nel fatto |
| Misura additiva | `trip_count`, `night_trip_count`, indicatori 0/1 |
| Misura semi-additiva/non banale | medie di durata o distanza vanno ricalcolate con attenzione |
| Unknown member | chiave 0 nelle dimensioni per riferimenti mancanti o fuori dominio |

## 8. Star schema o snowflake?

Risposta breve:

> Il progetto usa un modello ibrido star/snowflake. Il fatto e' collegato direttamente alle dimensioni principali per semplificare le query OLAP, ma `dim_station` referenzia `dim_geography`, creando un bordo snowflake controllato per rappresentare la gerarchia geografica reale.

Perche' e' difendibile:

- Una star pura sarebbe semplice ma duplicativa sulla geografia.
- Uno snowflake completo sarebbe piu' normalizzato ma piu' difficile da usare in demo e query.
- La scelta ibrida mantiene leggibilita' e mostra una gerarchia reale.
- `dim_geography` resta denormalizzata a livello NTA per evitare troppe join inutili.

Da dire se chiedono perche' `dim_date` e `dim_calendar_event` sono separate:

> La data risponde a domande temporali standard, come mese o stagione. Calendar event risponde a domande semantiche su festivita', holiday eve, post-holiday e long weekend. Separarle rende piu' chiaro il modello analitico.

## 9. ETL e riproducibilita'

Ordine di esecuzione:

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

Come spiegarlo:

- Gli script Python gestiscono download e orchestrazione.
- Gli script SQL contengono DDL, trasformazioni, vincoli e controlli.
- PostgreSQL conserva i dati nei vari schema.
- PostGIS abilita l'arricchimento spaziale.
- DBeaver viene usato per ispezione, query e demo.

Dipendenze Python da ricordare:

- `pandas`: caricamento e manipolazione tabellare.
- `requests`: download da API o URL.
- `SQLAlchemy` e `psycopg2`: connessione a PostgreSQL.
- `geopandas`, `shapely`, `pyogrio`, `geoalchemy2`: dati geografici e PostGIS.

## 10. Qualita' dei dati

Idea centrale:

> La qualita' non e' un controllo finale cosmetico: e' presente in ogni passaggio tramite row count, rejection accounting, vincoli, foreign key, unknown keys e riconciliazione tra fatti.

Controlli principali:

- Source inventory vs righe staging.
- Ogni riga Citi Bike e' accettata o scartata.
- Duplicati `ride_id`.
- Timestamp mancanti o durate non valide.
- Motivi di scarto.
- Copertura geografica delle stazioni.
- Copertura calendario/meteo.
- Foreign key e unknown surrogate keys.
- Riconciliazione `fact_trip` vs `fact_station_day_hour`.
- Sanity check sulle misure.

Frase pronta:

> La qualita' piu' importante e' l'accounting: 1,888,085 righe staging = 1,881,951 corse accettate + 6,134 scarti. Quindi nessuna riga sparisce senza spiegazione.

Unknown keys:

> Le chiavi surrogate 0 non nascondono errori: rendono esplicito quando una dimensione manca o e' fuori copertura, permettendo comunque il caricamento del fatto e il monitoraggio della qualita'.

Esempi nel progetto:

- 364 trip con weather unknown per partenze il 31 dicembre 2023, mentre la sorgente meteo copre il 2024.
- 183 trip con geography unknown/outside per flussi fuori copertura NYC.

## 11. OLAP: cosa dimostrare

Operazioni OLAP usate:

| Operazione | Esempio nel progetto |
| --- | --- |
| Slice | filtrare solo `is_night_trip = TRUE` |
| Dice | confrontare rider type + weather severity |
| Roll-up | aggregare da NTA a borough |
| Drill-down | passare da giorno/notte a singola ora |
| Pivot-like aggregation | confrontare classic/electric per day/night e meteo |

Analisi principali:

1. Night demand by borough and day type.
2. Weather impact on casual vs member riders.
3. Station inflow/outflow imbalance.
4. Electric vs classic bike usage at night and under weather severity.
5. Top night origin-destination corridors.
6. Holiday and long-weekend effects.
7. Hourly night mobility profile.

Findings da ricordare:

- Manhattan domina la domanda notturna, seguita da Brooklyn.
- Le corse notturne sono spesso locali, dentro la stessa NTA.
- Le festivita' aumentano la quota relativa di corse notturne.
- Alcune stazioni hanno forte sbilanciamento tra partenze e arrivi.
- I member generano piu' volume, i casual tendono ad avere durate medie piu' alte.
- La definizione 20:00-05:59 e' verificabile nel profilo orario.

Esempio di spiegazione query:

> La prima query fa una slice sulle corse notturne, poi fa roll-up geografico al borough e dice per weekday/weekend e holiday window. Questo dimostra che il modello dimensionale supporta confronti multidimensionali leggibili.

## 12. Demo consigliata in 5 minuti

Sequenza robusta:

1. Apri README e mostra architettura a livelli.
2. In DBeaver mostra gli schema `staging`, `reconciled`, `dw`.
3. Esegui accounting staging -> reconciled:

```sql
SELECT
    (SELECT COUNT(*) FROM staging.citibike_trip_raw) AS staging_rows,
    (SELECT COUNT(*) FROM reconciled.trip) AS accepted_trips,
    (SELECT COUNT(*) FROM reconciled.trip_rejection) AS rejected_trips,
    (SELECT COUNT(*) FROM reconciled.trip) +
        (SELECT COUNT(*) FROM reconciled.trip_rejection) AS accounted_rows;
```

4. Mostra `dw.fact_trip` e dimensioni in ER diagram.
5. Esegui riconciliazione fact ride-grain vs aggregate:

```sql
SELECT
    (SELECT SUM(trip_count) FROM dw.fact_trip) AS ride_grain_trips,
    (SELECT SUM(trip_starts) FROM dw.fact_station_day_hour) AS aggregate_starts,
    (SELECT SUM(trip_ends) FROM dw.fact_station_day_hour) AS aggregate_ends,
    (SELECT SUM(night_trip_count) FROM dw.fact_trip) AS ride_grain_night_trips,
    (SELECT SUM(night_trip_starts) FROM dw.fact_station_day_hour) AS aggregate_night_starts;
```

6. Esegui una query OLAP forte, per esempio night demand by borough.
7. Chiudi con un grafico in `docs/charts/phase7/`.

## 13. Scaletta orale da 10-15 minuti

0:00-1:00 - Contesto e obiettivo

- Mobilita' notturna Citi Bike a NYC.
- Integrazione con meteo, festivita' e geografia.
- Obiettivo: data warehouse riproducibile e analisi OLAP.

1:00-2:30 - Sorgenti

- Citi Bike come sorgente principale.
- NOAA, Nager.Date, NYC boundaries come arricchimenti.
- Source inventory e row count.

2:30-4:00 - Architettura

- `data_raw`, `staging`, `reconciled`, `dw`, quality.
- Perche' separare i livelli.

4:00-6:00 - Reconciled

- Regole di pulizia.
- Scarti tracciati.
- PostGIS point-in-polygon.
- Attributi derivati.

6:00-8:30 - Modellazione dimensionale

- Grana di `fact_trip`.
- Fact aggregata station-day-hour.
- Dimensioni e gerarchie.
- Star/snowflake ibrido.
- Chiavi surrogate e unknown rows.

8:30-11:00 - OLAP

- Spiega 2 o 3 query, non tutte.
- Collega ogni query a slice/dice/roll-up/drill-down.
- Mostra 2 finding quantitativi.

11:00-12:30 - Qualita'

- Accounting staging -> accepted/rejected.
- Riconciliazione fact -> aggregate.
- Foreign key e unknown keys.

12:30-15:00 - Demo e conclusione

- Mostra DBeaver.
- Esegui una query.
- Concludi con limiti e sviluppi futuri.

## 14. Domande probabili del professore

**Perche' avete creato un reconciled layer invece di caricare direttamente il data warehouse?**

Per separare pulizia e integrazione dalla modellazione dimensionale. Il reconciled rende esplicite regole di validazione, scarti, attributi derivati e join spaziali. Il warehouse, invece, rimane ottimizzato per analisi OLAP.

**Qual e' la grana del fatto principale?**

Una riga in `dw.fact_trip` rappresenta una singola corsa Citi Bike accettata. La grana e' quindi ride-level.

**Qual e' la grana del fatto aggregato?**

Una riga in `dw.fact_station_day_hour` rappresenta una stazione, un giorno e un'ora. Riassume partenze, arrivi, night starts e indicatori per tipo utente/bici.

**Perche' usare PostGIS?**

Perche' le sorgenti geografiche sono poligoni e le stazioni sono punti. PostGIS permette point-in-polygon e indici spaziali, quindi assegna ogni stazione a NTA e borough in modo controllato.

**Come definite una corsa notturna?**

Una corsa e' notturna se l'ora di partenza e' tra le 20:00 e le 05:59. La definizione e' materializzata in `is_night_trip` e validata con il profilo orario OLAP.

**Perche' usare chiavi surrogate?**

Nel warehouse le chiavi surrogate isolano il modello analitico dalle chiavi naturali delle sorgenti, semplificano foreign key e permettono unknown rows controllate.

**Perche' alcune dimensioni hanno riga unknown con chiave 0?**

Per evitare che una mancanza dimensionale blocchi il caricamento del fatto. Il dato resta analizzabile e la mancanza diventa misurabile nei quality checks.

**Qual e' la differenza tra `dim_station` e `dim_geography`?**

`dim_station` descrive la stazione fisica Citi Bike. `dim_geography` descrive l'area amministrativa/analitica, cioe' NTA, CDTA, borough e city. Una stazione punta a una geografia.

**Che cosa rende OLAP il progetto?**

Il modello supporta aggregazioni multidimensionali su fatti e dimensioni: roll-up geografici, drill-down orari, slice su night trips, dice su meteo e tipo utente, confronti calendario/eventi.

**Come dimostrate che la fact aggregata e' corretta?**

Confrontando i totali: `SUM(fact_trip.trip_count)` deve coincidere con `SUM(fact_station_day_hour.trip_starts)` e `SUM(fact_station_day_hour.trip_ends)`.

**Quali sono i limiti del progetto?**

La baseline validata usa gennaio 2024 per Citi Bike, quindi le conclusioni quantitative sono solide per il campione ma non definitive per tutto l'anno. Inoltre il meteo e' giornaliero e riferito a Central Park, quindi non cattura variazioni orarie o micro-locali.

## 15. Concetti da ripassare

Data warehouse:

- Differenza tra OLTP e OLAP.
- Schema a stella.
- Schema snowflake.
- Fatto, dimensione, misura.
- Grana del fatto.
- Chiave naturale vs chiave surrogata.
- Dimensioni role-playing.
- Dimensioni degenere.
- Misure additive, semi-additive e non additive.

ETL/ELT e qualita':

- Data lineage.
- Staging.
- Data cleaning.
- Reconciliation.
- Data quality checks.
- Reproducibilita'.
- Idempotenza e rerun safety.

Database:

- Primary key e foreign key.
- Vincoli `CHECK`.
- Indici B-tree.
- Indici spaziali GiST.
- JSONB per weather flags.
- Estensione PostGIS.

Geospatial:

- Point, polygon, multipolygon.
- SRID 4326.
- Point-in-polygon.
- Distanza sferica approssimata.

OLAP:

- Slice.
- Dice.
- Roll-up.
- Drill-down.
- Pivot.
- Aggregazioni con `GROUP BY`.

## 16. Limiti e possibili sviluppi

Limiti:

- Citi Bike validato su gennaio 2024, non ancora su full-year nel baseline.
- Meteo giornaliero, non orario.
- Una sola stazione meteo principale, Central Park.
- Distanza approssimata in linea d'aria, non distanza reale su rete stradale.
- Le geografie NYC non coprono stazioni fuori NYC.

Sviluppi futuri:

- Eseguire pipeline su tutto il 2024.
- Integrare meteo orario.
- Aggiungere eventi locali o POI nightlife.
- Usare routing stradale per distanze piu' realistiche.
- Creare dashboard BI sopra il warehouse.
- Aggiungere partizionamento su `fact_trip` per scalare meglio.

## 17. Mini glossario collegato al progetto

| Termine | Definizione nel progetto |
| --- | --- |
| Fact table | Tabella centrale con misure, per esempio `dw.fact_trip` |
| Dimension table | Tabella descrittiva per analisi, per esempio `dw.dim_date` |
| Grain | Significato di una riga del fatto |
| Surrogate key | Identificatore interno del DW, per esempio `station_key` |
| Natural key | Identificatore dalla sorgente, per esempio `station_id` |
| Role-playing dimension | Stessa dimensione usata in ruoli diversi, start/end |
| Reconciled layer | Livello integrato, pulito, ma non dimensionale |
| OLAP | Analisi multidimensionale aggregata |
| Slice | Filtro su una dimensione o proprieta' |
| Roll-up | Aggregazione verso un livello gerarchico piu' alto |
| Drill-down | Dettaglio verso un livello piu' fine |
| Unknown row | Riga dimensionale controllata con chiave 0 |

## 18. Checklist finale prima della discussione

- So spiegare in 60 secondi lo scopo del progetto.
- So disegnare a parole la pipeline `raw -> staging -> reconciled -> dw -> OLAP`.
- So dire la grana di entrambe le fact.
- So motivare il modello star/snowflake.
- So spiegare perche' PostGIS e' necessario.
- So spiegare almeno tre dimensioni con gerarchie.
- So collegare ogni analisi OLAP a slice, dice, roll-up o drill-down.
- So citare i numeri baseline principali.
- So mostrare una query di quality accounting.
- So indicare limiti e sviluppi futuri senza indebolire il progetto.

