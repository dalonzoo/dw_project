# Project Proposal - Urban Night Mobility Data Warehouse

**Names and student IDs:** [Name Surname, matricola] - [Name Surname, matricola]

**Chosen type of project:** Data Warehousing - integration of multiple data sources through ETL, DFM design, star or snowflake schema implementation in PostgreSQL, and OLAP analysis.

**Dataset(s):**
- Citi Bike official trip history data: https://citibikenyc.com/system-data
- NOAA NCEI Daily Summaries weather data: https://www.ncei.noaa.gov/access/search/data-search/daily-summaries
- Nager.Date public holidays API: https://date.nager.at/Api
- NYC neighborhood, community district, and borough boundary data for geographic enrichment:
  - 2020 Neighborhood Tabulation Areas: https://catalog.data.gov/dataset/2020-neighborhood-tabulation-areas-ntas
  - Borough Boundaries: https://catalog.data.gov/dataset/borough-boundaries

**Brief description of the work:**
The project will build a data warehouse to analyze how urban night mobility patterns change on weekdays, weekends, holidays, long weekends, and under different weather conditions. Citi Bike monthly trip files will be loaded into a staging layer, cleaned, and integrated with daily weather, public holiday data, and geographic boundaries to enrich stations with neighborhood, community district, and borough information. A reconciled layer will standardize trips, stations, weather observations, calendar attributes, and geographic areas before populating a dimensional warehouse. The DFM will model bike trips as the main fact, with measures such as trip count, duration, distance approximation, member/casual ratio, late-night share, and station inflow/outflow balance. The main non-trivial OLAP dimensions will be Time, Geography, Calendar/Event, and Weather, with hierarchies such as timestamp-hour-part of day-day-month-season-year, station-neighborhood-community district-borough-city, date-weekend-holiday window-holiday type, and weather observation-condition-severity. Additional dimensions will include Station, User Type, and Rideable Type. OLAP queries will compare nightlife mobility across neighborhoods and boroughs, quantify weather impact on casual versus member riders, identify stations with strong weekend-night demand, and detect calendar effects around holidays and long weekends. The project will emphasize careful ETL, a well-motivated DFM, and SQL analyses that turn raw trip logs into interpretable mobility insights.
