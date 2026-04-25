# Project Proposal - Steam Games Market and Player Engagement Data Warehouse

**Names and student IDs:** [Name Surname, matricola] - [Name Surname, matricola]

**Chosen type of project:** Data Warehousing - integration of multiple data sources through ETL, DFM design, snowflake schema implementation in PostgreSQL, and OLAP analysis.

**Dataset(s):**
- Game Recommendations on Steam, including games, anonymized users, and recommendation records: https://www.kaggle.com/datasets/antonkozyriev/game-recommendations-on-steam
- Steam Games Dataset with Steam API and SteamSpy metadata: https://www.kaggle.com/datasets/fronkongames/steam-games-dataset

**Brief description of the work:**
The project will build a data warehouse to study how game characteristics, pricing, platform support, and player engagement relate to recommendation behavior on Steam. The ETL process will load recommendation records, anonymized user aggregates, game metadata, tags, genres, prices, release dates, platform flags, and SteamSpy indicators into a staging area, then reconcile game identifiers and normalize multi-valued attributes such as genres, developers, publishers, categories, and tags. The DFM will include a recommendation fact and a game snapshot fact, with measures such as recommendation count, positive recommendation rate, average hours played, helpful votes, discount level, price, review volume, and platform support. Non-trivial dimensions will include Time, Game, Genre/Tag, Developer/Publisher, User Segment, Price Band, Platform, and Release Cohort, with hierarchies for OLAP roll-up and drill-down. OLAP queries will analyze whether indie games have different engagement curves than AAA games, how discounts affect recommendation ratios, which genre combinations retain players for longer, and how release cohort or platform support influences review behavior. To keep the workload feasible, very large tables can be loaded incrementally or aggregated during ETL while preserving enough detail for meaningful warehouse operations. The final report will include the DFM, snowflake schema, ETL decisions, populated tables, and SQL queries used to produce the analyses.
