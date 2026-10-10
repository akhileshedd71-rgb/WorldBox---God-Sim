# Development roadmap

Build small systems that produce interesting consequences together. Finish each acceptance gate before expanding the simulation budget. The supplied document describes a mature game's feature catalogue; it is the long-term reference, not the scope of one milestone.

## Milestone overview

| Phase | Deliverable | Status | Dependencies |
| --- | --- | --- | --- |
| 1 | A living island: editable world, autonomous life, mobile controls, saves | **Implemented** | Godot 4.6.3 |
| 2 | A self-sustaining village: real resources, farms, housing, better navigation | **Implemented** | 1 |
| 3 | Kingdoms and politics: territory, rulers, expansion, diplomacy | **Implemented** | 2 |
| 4 | War and defense: soldiers, equipment, capture, transport | **Implemented** | 3 |
| 5 | Heredity: traits, families, species adaptations, subspecies | **Implemented** | 2; integrate with 3–4 |
| 6 | A changing planet: separate biomes, weather, ages, diseases, larger disasters | **Implemented** | 2, 5 |
| 7 | Society and memory: culture, clans, language, religion, genealogy | **Implemented** | 3, 5 |
| 8 | Mobile beta and release: performance, accessibility, audio, device matrix | **Editor beta delivered; mobile validation pending** | Stable core above |

Phases 1–3 in the reference are combined into the first playable milestone. Phase 1 also includes deliberately small previews of villages and powers so there is already a create → observe → intervene loop. These previews do not complete the later economy or disaster phases.

## Phase 1 — A living island

**Delivered**

- [x] Godot project and mobile-compatible renderer.
- [x] Seeded continents/archipelagos and six terrain materials.
- [x] Brush painting, pan/zoom, and touch gesture arbitration.
- [x] Settlers, rabbits, deer, local movement, forage, hunger, aging, and reproduction.
- [x] Simple village founding, visible housing, and chronicle events.
- [x] Rain/fire/blessing/meteor, four world laws, and time controls.
- [x] Inspector, live counts, new-world flow, manual save, and autosave.
- [x] Original art, test runner, documentation, and screenshots from the game.

**Gate:** a new player can generate or edit an island, introduce life, observe village growth, intervene, save, and reload. Deterministic generation and save continuation, invalid-save rejection, simulation invariants, and touch input are tested. This gate covers the Godot prototype, not mobile release certification.

## Phase 2 — A self-sustaining village

**Delivered in v0.2.0.** Resource counters and decorative fields have been replaced by work, carried goods, stores, crop growth, and paid construction. See [the economy guide](docs/ECONOMY.md).

- [x] Separate elevation, biome, vegetation, and resource layers.
- [x] Spatial unit index; shared A* grid and connected components invalidated by terrain edits.
- [x] Foraging, logging, mining, hauling, farming, building, eating, and rest.
- [x] Finite regenerative wood, finite stone, bounded storage, and paid construction.
- [x] Crop stages, physical harvest, shortages, and pantry consumption.
- [x] Housing/food constraints on births and species-specific maturity.
- [x] Live village dashboard with jobs, stores, housing, and population graph.
- [x] Save schema v2; explicit v1 migration using a genuine Phase 1 fixture.

**Gate:** an isolated settlement survives 100 simulated years when resources suffice; shortages cause a readable decline; destroying farms changes population; villagers cannot cross an ocean or wall to collect resources. Save/reload reproduces the same next 100 ticks. Test on one Android device before raising the entity cap.

**Gate status:** automated century survival, controlled farm-loss decline, barrier/navigation, migration, and 120-tick full-state save continuation pass. The phone dashboard is rendered and touch-tested in Godot. Android hardware profiling remains outstanding; the cap stays at 350.

## Phase 3 — Kingdoms and politics

**Delivered in v0.3.0.** See [the politics guide](docs/POLITICS.md).

- [x] Multiple settlements per kingdom; stable IDs and connected territorial claims.
- [x] Adult rulers, succession, capital transfer, and collapse.
- [x] Border contact, explained diplomatic decisions, alliances, rivalry, loyalty, and independence.
- [x] Four-person expeditions using village supplies, actual overland travel, and housing/food pressure.
- [x] Political overlay; Realm/Diplomacy/Chronicle inspector; favor, peace, and discord interventions.
- [x] Frontier continent preset with three separated peoples.
- [x] Schema v3 and genuine v1/v2 migration fixtures; full-state continuation during travel.

**Gate:** three kingdoms expand on a shared map, encounter borders, and make explainable diplomatic decisions. Removing a ruler or settlement preserves valid ownership. Landlocked groups do not silently colonize another island.

**Gate status:** all scenarios pass, including three autonomous expansions to six settlements, contact and diplomatic causes, succession/collapse, independence, route interruption, and 120-tick save continuation. The phone inspector and political map are rendered and touch-tested. The 350-creature limit is unchanged. Rivalry restricts travel; declared military war is now implemented in Phase 4.

## Phase 4 — War and defense

**Delivered in v0.4.0.** See [the warfare guide](docs/WARFARE.md).

- [x] Recruitment from existing adults, reciprocal company membership, and real equipment/ration costs.
- [x] Stone spears, wooden bows, target selection, blocked line of sight, damage, cooldowns, morale, and retreat.
- [x] Paid, worker-finished watchtowers, reactive defenders, siege, and settlement capture.
- [x] Explicit declared war and peace; ownership, succession, capture, and collapse integration.
- [x] Paid transport boats, shore boarding, water-only travel, landing, terrain-edit recovery, and return crossings.
- [x] Phone War inspector, army orders, follow-on-map, original sprites, effects, health bars, and company banners.
- [x] Save schema v4 and a genuine v3 fixture; migrations and deterministic battle/voyage continuation.
- [ ] Roads and walls: deferred until navigation profiling on hardware, as planned.

**Gate:** a declared war can end through peace or capture; defenders react; casualties affect economy; armies do not attack friendly units or travel across impassable tiles. No combat system assumes a rendered node exists for every unit.

**Gate status:** automated scenarios pass for recruitment, combat, defenders, capture/collapse, peace, retreat, casualties, barriers, sea crossings, interrupted routes, and save compatibility. Actual phone touch controls and rendered desktop/phone views are checked. The 350-creature cap remains unchanged. Physical-device profiling remains outstanding; native packaging belongs to mobile beta.

## Phase 5 — Heredity and distinctive lives

**Delivered in v0.5.0.** See [the heredity guide](docs/HEREDITY.md).

- [x] Resource-based species definitions and a bounded, mutually exclusive trait model.
- [x] Two-parent inheritance, rare mutation, stable parent IDs, generations, and close-kin pairing exclusions.
- [x] Habitat adaptations with hunger effects and named subspecies; inherited original appearance variants.
- [x] Measurable hunger, recovery, lifespan, gathering, and weapon-damage effects.
- [x] Live Traits/Family/Memories inspection, navigable parents/children, favorites, and remembered deaths.
- [x] Schema v5 with a genuine v4 fixture; migration from all earlier versions and exact family continuation.

**Gate:** seeded family trees are repeatable, traits have measurable effects, and parent links remain valid after death. Trait edits cannot create contradictory or unbounded statistics. Full chromosome puzzle editors and possession remain stretch goals.

**Gate status:** model and native phone touch checks pass, including three generations with an archived grandparent, atomic rejection of incompatible traits, real worker/combat effects, favorites after death, bounded history, and save/reload. The archive holds 2,048 lifetime records without silently pruning ancestors; reaching it stops new lives. The living population cap stays at 350. The UI focuses on inspection; visual genome editors remain future work.

## Phase 6 — A changing planet

**Delivered in v0.6.0.** See [the environment guide](docs/ENVIRONMENT.md).

- [x] Independent temperate, woodland, arid, wetland, tundra, and original glimmergrove biomes.
- [x] Staggered vegetation growth/spread, finite ecosystem resources, and inherited habitat integration.
- [x] Rain/drought/snow/storms, soil moisture, snow cover/melt, temperature, seasons, and three world ages.
- [x] Crop/forage stress, thermal appetite, and actual changes in worker harvests.
- [x] Rustfever contact transmission, bounded infection, immunity, recovery, and personal memories.
- [x] Lightning, earthquakes, finite volcanoes, plague, and optional spontaneous disasters.
- [x] Live phone Climate/Land/Health inspector, twelve laws, and three explained presets.
- [x] Schema v6, a genuine v5 fixture, all earlier migrations, and exact environmental continuation.

**Gate:** rain extinguishes fire and changes growth; drought produces food stress; disease can spread and recover; disabling a law stops its subsystem. Confirm cascading effects without hardcoding a civilization's collapse.

**Gate status:** model and native phone scenarios verify actual growth/yield changes, snow/melt, thermal adaptation, disease barriers/recovery, stopped subsystem clocks, bounded disasters, legacy migration, and 240-tick continuation. Century survival still runs with climate enabled. Weather is global; ecology, soil, and snow are local. Atmospheric fluids, roaming disaster creatures, larger worlds, and physical-device profiling remain future work.

## Phase 7 — Society and memory

**Delivered in v0.7.0.** See [the society guide](docs/SOCIETY.md).

- [x] Independent culture, clan, language, and hearth-faith registries with stable IDs.
- [x] Crop rotation and masonry from real work; shared-language learning between connected peaceful communities.
- [x] Migrating people retain identities; sustained residence teaches majority culture, belief, and language independently.
- [x] Clan solidarity affects loyalty; communal faith affects recovery; two new laws pause social effects/exchange.
- [x] Society inspector connected to the genealogy browser, retained ruler timelines, history filters, and population/resource graphs.
- [x] Four saved discovery emblems earned from observed conditions, without artificial resource rewards.
- [x] Schema v7, genuine v6 fixture, all prior migrations, and deterministic continuation.
- [ ] Advanced social/genetic editors remain deferred; this milestone focuses on simulation and inspection.

**Gate:** each social system affects at least one simulation rule, survives save/load, and explains its effect in the UI.

**Gate status:** rule-effect, migration, adoption, paused-timer, war/barrier, malformed-save, and native phone-control checks pass. Culture and clan survive real colony travel; archived identity stays separate from genetics and kingdom ownership. Social objects/history are bounded and the living cap remains 350. Old saves initialize neutral social state with both new laws off. Physical-device profiling remains part of mobile beta.

## Phase 8 — Editor beta, then mobile validation

**Editor beta delivered in v0.8.0.** The user requested GitHub source for Godot testing before any APK/AAB build. See [beta behavior](docs/BETA.md) and [the Godot checklist](docs/GODOT_TESTING.md).

- [x] Six named save slots plus independent quick save/autosave, previous-version backups, damaged/interrupted-write recovery, and preservation before loading.
- [x] Genuine v7 fixture; all seven source versions import into the shelf without changing world schema v7.
- [x] Persistent master/ambience/effect volumes, original synthesized ambience and cues.
- [x] Larger reading labels, higher contrast, reduced motion, keyboard controls, focus pause, and 30/60 frame targets.
- [x] Terrain signatures, 54 independently updated chunks, four-chunk runtime budget, unchanged-world upload avoidance, and bounded tool effects.
- [x] Editor/phone UI tests, save-recovery scenarios, local render measurements, documentation, and original assets committed with the source.
- [ ] User Godot playtest and fixes from actual feedback.
- [ ] Low/mid/high Android and at least two supported iOS devices; 30-minute thermal, memory, and gesture soak.
- [ ] Safe-area/reading/keyboard/screen-reader acceptance on hardware; haptics and localization coverage.
- [ ] Native filesystem power-loss/low-storage tests, device termination and resume, signed Android builds, and iOS Xcode archive.
- [ ] Store/privacy assets and final branding/device/OS/product decisions.

**Gate:** the editor beta must import and run from a clean GitHub download, preserve older saves, and pass recovery/input checks. Mobile release still requires a 30-minute device soak with no crashes, unbounded memory, save loss, or stuck gestures, plus real suspend/termination/low-storage testing. **No APK or AAB is built in this milestone.** Store publication remains a separate action.

The 60 FPS mid-range and stable 30 FPS low-end goals remain targets, not measured device claims. Keep 350 creatures and existing world/archive limits until hardware profiling supports larger presets.

## Deferred product choices

Choose final branding, target device/OS minimums, the first release's biome/species roster, and pricing during beta planning. This prototype has no ads, purchases, analytics, login, or multiplayer. Any monetization or telemetry needs a deliberate product decision and implementation; it is not part of the sandbox foundation.

## Recommended next implementation slice

Download the GitHub project and run the [Godot editor checklist](docs/GODOT_TESTING.md). Address playtest feedback next. Preserve the current save fixtures and creature/archive budgets. Begin native packaging only after the user requests it; APK/AAB builds are explicitly deferred. Device certification and store publication remain outstanding even when editor tests pass.
