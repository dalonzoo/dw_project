# Project Proposal - League of Legends Esports Meta Data Warehouse

**Names and student IDs:** [Name Surname, matricola] - [Name Surname, matricola]

**Chosen type of project:** Data Warehousing - integration of multiple data sources through ETL, DFM design, snowflake schema implementation in PostgreSQL, and OLAP analysis.

**Dataset(s):**
- Oracle's Elixir League of Legends professional match data: https://www.kaggle.com/datasets/lauffing/oracles-elixir-league-of-legends-pro-play-data
- Riot Games Data Dragon static game data for champions, tags, roles, and patch assets: https://developer.riotgames.com/docs/lol#data-dragon

**Brief description of the work:**
The project will build a data warehouse for analyzing how the competitive League of Legends meta changes across regions, patches, tournaments, teams, players, and champion classes. Raw yearly match files from Oracle's Elixir will be loaded into a staging layer and integrated with Riot Data Dragon champion metadata, resolving inconsistencies in champion names, patches, leagues, and player/team identifiers. A reconciled layer will represent matches, teams, players, champions, roles, patches, and tournament context before loading a snowflake schema. The DFM will include facts for game performance and pick/ban presence, with measures such as win rate, pick rate, ban rate, gold difference, objective control, KDA, damage, and game duration. Non-trivial dimensions will include Time, Competition, Region/League, Team, Player/Role, Champion/Class, and Patch, each with hierarchies suitable for roll-up, drill-down, slice, and dice operations. OLAP queries will study regional differences in champion priority, patch-driven meta shifts, side advantage, objective-control profiles of winning teams, and cases where champion popularity rises before performance improves. The final report will focus on insights that are not directly visible from the raw CSV files and will include the SQL queries used on the populated warehouse.
