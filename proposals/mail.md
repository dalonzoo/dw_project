Names and student IDs: Daniele D'Alonzo 2059687, Sara Inzerillo 2045179

Chosen type of project: Data Warehousing - integration of multiple data sources through ETL, DFM design, star or snowflake schema implementation in PostgreSQL, and OLAP analysis. (first proposal of the slides)

Datasets:

Citi Bike official trip history data: https://citibikenyc.com/system-data
NOAA NCEI Daily Summaries weather data: https://www.ncei.noaa.gov/access/search/data-search/daily-summaries
Nager.Date public holidays API: https://date.nager.at/Api
NYC borough or neighborhood boundary data for geographic enrichment: https://data.cityofnewyork.us/City-Government/Borough-Boundaries/tqmj-j8zm

Brief description of the work:

The project is to build a data warehouse to analyze how young urban mobility patterns change at night, on weekends, during holidays, and under different weather conditions. Citi Bike monthly trip files will be loaded into a staging layer, cleaned, and integrated with daily weather, public holiday data, and geographic boundaries to enrich stations with borough or neighborhood information. A reconciled layer will standardize trips, stations, weather observations, calendar attributes, and geographic areas before populating a dimensional warehouse. The DFM will model bike trips as the main fact, with measures such as trip count, duration, distance approximation, member/casual ratio, late-night share, and station inflow/outflow balance. Non-trivial dimensions will include Time, Weather, Geography, Station, User Type, Rideable Type, and Calendar Event, with hierarchies such as date-month-season, station-neighborhood-borough, and weather-condition-severity. OLAP queries will compare nightlife mobility across boroughs, quantify weather impact on casual versus member riders, identify stations with strong weekend-night demand, and detect calendar effects around holidays and long weekends. The project will emphasize careful ETL, a well-motivated DFM, and SQL analyses that turn raw trip logs into interpretable mobility insights.
