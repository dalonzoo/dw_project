# Recommendation After Excluding Gaming Topics

Since we are not game players, I would exclude both the League of Legends esports proposal and the Steam games proposal. They are technically strong, but domain familiarity matters during the presentation: the instructor can ask detailed questions, and we should be able to defend both the modeling choices and the analyses naturally.

**Best recommended option:** `proposal_2_urban_mobility_dw.md`

This is the strongest non-gaming choice because it is concrete, useful, and still suitable for a 22-year-old audience without being obvious. It lets us integrate several sources, design meaningful hierarchies, and produce analyses that are easy to explain: night mobility, weather impact, holidays, weekend behavior, station flows, and geographic differences.

**Second recommended option:** `proposal_4_movies_streaming_dw.md`

This is also a good fit if we prefer a more entertainment-oriented project. It has rich data, strong dimensional modeling potential, and interesting OLAP analyses, but it may require more careful ETL because of identifier matching and multi-valued movie attributes such as genres, tags, countries, and production companies.

For the highest grade target, I would choose the urban mobility proposal and make it slightly more ambitious during implementation by including a reconciled layer, at least three hierarchical dimensions, well-motivated SQL OLAP sessions, and clear visual reporting.
