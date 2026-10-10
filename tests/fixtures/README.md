# Save fixtures

`v1_world.json` was written with the Phase 1 `SaveStore` before implementing Phase 2. It contains the populated seed 41827 after 60 simulation ticks, including Phase 1 abstract housing/resource counters. It is a compatibility fixture, not a newly generated v2 save with its version changed.

`tests/test_economy.gd` checks migration, preservation of IDs/time/RNG/lives, physical legacy housing sites, v2 revalidation, non-mutation of input, and subsequent play. Never overwrite this fixture when changing the current schema.

`v2_world.json` was written by the Phase 2 `SaveStore` before Phase 3 development. It contains seed 41827 after 600 ticks, including real stores, farms, houses, and in-flight work. `test_politics.gd` migrates both original fixtures to v3 and checks IDs, time, RNG, living entities, and schema validity. Neither fixture is regenerated from the current serializer.

`v3_world.json` was written with the unchanged Phase 3 serializer before implementing Phase 4. It contains Frontier seed 41827 after 600 ticks: 113 creatures and three kingdoms, with political and economic state. `test_military.gd` migrates all three genuine fixtures to v4 and checks unchanged time, IDs, RNG, lives, empty military assignments, and full revalidation. Do not regenerate it using the v4 serializer.

`v4_world.json` was captured with the unchanged Phase 4 serializer before Phase 5 development. Frontier seed 41827 ran for 1,200 ticks, war was declared between kingdoms 0 and 1, then it ran 62 more ticks. The fixture has 213 creatures and five military company records. `test_heredity.gd` checks all four original fixtures for neutral migration, unknown ancestry, preserved identities/time/RNG, non-mutation, and v5 validation. Never regenerate this fixture from the current serializer.

`v5_world.json` was written with the unchanged Phase 5 serializer before Phase 6 development. Frontier seed 41827 at tick 960 contains 156 living creatures, 172 family records, three kingdoms, and one favorite. It was validated by the v5 loader before any v6 implementation. `test_environment.gd` verifies all five original migrations, including preserved v5 ancestry/favorites and dormant new climate laws. Never regenerate it with the current serializer.

`v6_world.json` was captured with the unchanged Phase 6 serializer before Phase 7 implementation. Frontier seed 41827 at tick 960 has 158 living creatures, 172 family records, three kingdoms, one favorite, an infected creature, timed rain, and one active volcano. The original v6 loader validated it before schema changes. `test_society.gd` migrates all six fixtures, preserves RNG/IDs/time/ancestry and v6 climate/hazards, keeps new social laws dormant, and revalidates v7. Never regenerate this fixture using the current serializer.

`v7_world.json` was captured using the unchanged Phase 7 serializer before Phase 8 recovery changes. Seed 41827 at tick 960 contains 59 living creatures, one culture with both technologies learned, one ruler transition, and a favorite. The original v7 loader validated it. The editor beta keeps world schema v7: named labels/timestamps are slot metadata and preferences use a separate format. `test_beta.gd` verifies all seven genuine fixtures through the named shelf and exact v7 preservation. Do not regenerate prior fixtures.
