# Project Proposal - Movie Taste and Streaming-Era Discovery Data Warehouse

**Names and student IDs:** [Name Surname, matricola] - [Name Surname, matricola]

**Chosen type of project:** Data Warehousing - integration of multiple data sources through ETL, DFM design, snowflake schema implementation in PostgreSQL, and OLAP analysis.

**Dataset(s):**
- MovieLens 32M ratings and tags dataset: https://grouplens.org/datasets/movielens/32m/
- MovieLens Tag Genome dataset for semantic movie descriptors: https://grouplens.org/datasets/movielens/tag-genome-2021/
- The Movie Database API for movie metadata enrichment: https://developer.themoviedb.org/docs/getting-started

**Brief description of the work:**
The project will build a data warehouse to analyze how movie taste, genre combinations, release periods, and semantic tags influence rating behavior and long-term discovery. MovieLens ratings, user tags, links, and tag-genome data will be loaded into a staging layer and integrated with TMDb metadata such as release dates, genres, languages, countries, runtime, popularity, and production information. The reconciled layer will resolve movie identifiers across sources, normalize multi-valued attributes such as genres and tags, and create derived attributes such as release decade, runtime band, popularity band, and mainstream/niche profile. The DFM will include rating and tagging facts, with measures such as number of ratings, average rating, rating variance, tag relevance, recency of discovery, and popularity indicators. Non-trivial dimensions will include Time, Movie, Genre, Semantic Tag, Release Cohort, Language/Country, User Segment, and Production Metadata, with hierarchies suitable for roll-up and drill-down. OLAP queries will compare cult movies versus mainstream movies, study whether older films are rediscovered by newer users, identify genre/tag combinations associated with high but polarized ratings, and analyze how runtime, language, and release decade affect rating behavior. The final report will present the DFM, snowflake schema, ETL choices, SQL queries, and dashboards or tables that communicate insights not directly visible from the raw files.
