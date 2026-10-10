# Game design

## Identity

**Working title:** Verdant — Pocket Worlds. A single-player, offline, top-down 2D god sandbox for landscape phones and tablets, with desktop development controls. The player shapes conditions and watches life respond. There is no campaign victory or mandatory progression in the first milestone.

The user-provided research is the feature inspiration. Names, interface, code, and small generated assets in this project form an original implementation; no proprietary WorldBox files are required. The research's feature/version claims have not been independently verified.

## Four pillars

1. **Create:** draw shores, seed a meadow, place a few creatures.
2. **Observe:** notice foraging, new offspring, village founding, and changing counts.
3. **Intervene:** bless a struggling group, rain on a fire, isolate a community.
4. **Transform:** burn a woodland or reshape a coast with a meteor; watch what remains.

The intended session loop is generate → shape → introduce life → observe consequences → intervene → save an interesting world. Every feature should make at least one part of that loop more interesting.

## Current world

The world has 144 × 96 cells and 16-pixel base art. A seed drives layered noise and island masks. Continents, archipelago, and Frontier presets share the same world dimensions. Rendering uses nearest filtering.

| Material | Movement | Forage | Current purpose |
| --- | --- | --- | --- |
| Ocean | Blocks land creatures | None | Waterways and island separation |
| Sand | Walkable | None | Beaches and barren ground |
| Meadow | Walkable | Regenerates | Food and settlement land |
| Forest | Walkable | Regenerates | Food, trees, visual habitat |
| Mountain | Blocks land creatures | None | Geographic barrier |
| Snow | Walkable | Sparse | Harsh, low-resource ground |

Elevation, biome, trees, stone, forage, fire, crops, and farm ownership have separate layers. The six Shape presets set elevation and biome together; Biomes offers independent ecology painting. Trees can be harvested without replacing the underlying biome; woodland regrows slowly.

## Life and time

One simulation tick is 0.25 seconds at 1×. Forty-eight ticks make one year, so the base calendar advances a year every 12 seconds. The simulation can pause or run at 1×, 2×, or 5×. Settings dialogs and app suspension pause it; the village, kingdom, life, and planet dashboards follow the selected time speed.

Each creature stores a stable ID, species, name, grid position, age, health, hunger, reproduction cooldown, village membership, and current activity. The first roster is settlers, rabbits, and deer. Working villagers follow four-neighbor A* routes to resources and their depot. Wildlife, nomads, and idle adults use local movement: favor forage when hungry, avoid fire, and stay near their village when assigned. They do not hunt each other.

- Health is 0–100; hunger is 0–100, with larger values meaning greater hunger.
- Hunger rises by 0.5 per tick. Wildlife/nomads above 18 hunger consume one forage when available and recover 20 hunger. Village members prefer a pantry meal at home: one stored food removes 40 hunger.
- Hunger over 85 costs 2.5 health per tick. A well-fed living creature recovers 0.25 health per tick.
- Meadow/forest forage regrows in staggered batches, capped at 20 per cell.
- Nearby adults of the same species can reproduce when healthy, fed, and off cooldown. Settler/rabbit/deer maturity is 16/2/3 years. Settlers require the same village, available housing, and stored food surplus; wildlife requires local forage.
- A successful reproduction gives both parents a 192-tick cooldown for settlers, or 120 for wildlife. Settler births consume two stored food. Offspring start at age zero. Both parent IDs and inherited genes are retained.
- With old age enabled, health declines after 85 years for settlers, 16 for rabbits, and 32 for deer.
- Population is capped at 350 across species. The UI explains when the limit is reached.

Fourteen world laws control hunger, births, old-age mortality, fire spread, new expeditions, automatic politics, weather, seasons, ages, vegetation, disease, spontaneous disasters, social effects, and cultural exchange. These switches are saved with the world. Turning hunger off prevents hunger growth/damage; it does not automatically feed already hungry creatures.

## Villages and resources

Four nearby adults on connected fertile terrain may establish a village. Nearby unsettled adults join reachable villages. Each settlement has a depot, food/wood/stone stores, real house sites, farm plots, job counts, and yearly history. Its camp shelters 12 settlers; eight possible houses add up to 32 more places.

Workers gather finite resources and carry them home. Houses consume wood and stone before construction adds capacity. Crops must be sown, grown, harvested, and carried; pantry meals and births consume food. Children eat and grow before working. See [the economy guide](ECONOMY.md) for exact values and priorities.

Village rings indicate local influence, not political territory or guaranteed navigable reach. If population disappears or the depot's land becomes uninhabitable, the village is abandoned; history remains, structures and farms clear, and surviving members can join/found another settlement.

## Kingdoms and politics

Independent villages form kingdoms. Existing adults carry food and materials along land routes to establish colonies in the same kingdom. Rulers succeed one another, capitals can transfer, and losing the final settlement collapses a realm. Settlements under sustained food or isolation pressure can become independent.

Connected claims form borders. Prosperity, ruler outlook, and scarcity influence neighboring relations; alliances support loyalty and rivalry closes expedition transit. The political inspector exposes these causes and lets the player bestow favor, encourage peace, or sow discord. See [the politics guide](POLITICS.md) for the exact rules and limits. Phase 4 adds explicit wars, paid soldiers, capture, and transport; rivalry remains a separate political posture.

## Divine tools

| Tool | Implemented effect |
| --- | --- |
| Terrain brush | Replace cells inside a circular S/M/L brush; refresh local forage; clear fire |
| Species placement | Place one creature per new touched cell on walkable terrain |
| Rain | Extinguish fires, add up to seven forage, and advance planted crops eight stages |
| Blessing | Set nearby creatures to full health and zero hunger |
| Fire | Ignite fertile terrain; damage occupants; spread if allowed; preserve the biome and buildings while destroying vegetation/crops |
| Meteor | Turn affected terrain to sand and kill nearby creatures; append chronicle event |
| Inspect | On the political map, open the claimed kingdom; otherwise prefer creatures, villages, then tile |
| Political interventions | Favor changes loyalty; peace/discord change the selected relation; declare war recruits companies and peace recalls them |

There is no undo for terrain changes in v0.6. Save an experimental world before large edits. Paused worlds still accept painting and powers; death removal completes when time advances.

## War and defense

Phase 4 adds paid recruitment of existing adult villagers, bows and stone spears, shared rations and morale, retreat, watchtowers, and settlement capture. Wars require a player declaration and can end through peace or the fall of a realm. Companies walk on land and require paid physical boats for sea crossings. Captured villagers retain their homes and stores under a new owner. See [the warfare guide](WARFARE.md) for complete rules and costs.

## Heredity and distinctive lives

Phase 5 introduces resource-driven species and five-gene inheritance. Traits affect hunger, recovery, lifespan, gathering, and weapon damage. Matching habitat copies provide a local hunger advantage and identify a named subspecies. Original appearance variants are inherited independently. Births record both parents; deaths preserve the family record. Close relatives do not pair automatically.

**Observe → Lives** offers Traits, Family, and Memories, with navigable parents/children, filters, favorites, and map focus. Up to 2,048 lifetime records, six personal moments per life, and 32 favorites are retained. Reaching the archive limit stops new lives without deleting existing ancestors. See [heredity](HEREDITY.md).

## A changing planet

Phase 6 adds independently paintable ecosystems, renewing vegetation, rain/drought/storm/snow, soil moisture, snow cover/melt, four seasons, and three world ages. Temperature changes appetite; growth stress changes harvests through existing farms and workers. Rustfever spreads through local same-species contact, causes health loss, and grants temporary immunity on recovery. Lightning, earthquakes, finite volcanoes, and optional spontaneous hazards create bounded consequences.

**Observe → Planet** explains Climate, Land, and Health. Weather/age controls and three law presets let players make experiments. Each subsystem has a law guard, saved clocks, and deterministic continuation. Earlier saves migrate with new systems dormant until enabled. See [environment rules](ENVIRONMENT.md).

## Society and memory

Phase 7 separates learned culture, clan, language, and hearth faith from ancestry and kingdom ownership. Real crop harvests and completed houses build knowledge; peaceful connected neighbors teach at a rate affected by shared language. Clan solidarity helps village loyalty and communal faith helps ordinary recovery. Travelers carry their affiliations; sustained local residence can change culture, belief, and language independently. Two laws pause these effects and exchange.

**Observe → Society** connects communities to the family browser and adds retained ruler timelines, type/culture/year/kingdom history filters, population/resource graphs, and four discovery emblems. Objectives record observed experiments without creating supplies or stat boosts. See [society](SOCIETY.md).

## Mobile interaction

The map is the main surface; the bottom dock holds tools near the thumbs. Landscape orientation is configured. Small screens use a compact HUD with an on-demand inspector; larger screens have a persistent world summary and chronicle. Existing buttons use labels/icons and visible active states.

One finger applies a selected tool, or pans with Move selected. Two fingers always control the camera, with gesture state suppressing paint until both fingers lift. Pinch zoom anchors on the gesture midpoint. Painting interpolates cells between samples to prevent gaps in fast strokes. Starting the second finger after the first has already painted cannot undo the earlier intentional stroke.

Settings menus pause the world. The live observation dashboards keep time running unless paused, and can also pause/resume it. New-world generation preserves the current world in the autosave slot before replacing it. Loading is an explicit replacement action. Local save errors are shown to the player.

## Editor beta comforts

The world shelf provides six named worlds alongside quick save and autosave. Every replacement preserves one previous valid version, and loading preserves the active world before switching. Settings persist independently: master/ambience/effect volume, larger reading labels, higher contrast, reduced motion, focus pause, and a 30/60 FPS cap. Original local ambience and short interaction sounds add feedback without affecting simulation randomness.

Terrain rendering updates only dirty chunks, with bounded runtime uploads; the world and population caps remain unchanged. Phase 8 delivers source for Godot playtesting. Native packaging and device acceptance remain pending. See [the beta guide](BETA.md).

## Deliberate limits

The prototype includes no predation, advanced social editors, fluid flooding, roaming disaster creatures, possession, online services, or monetization. The [roadmap](../ROADMAP.md) defines how these become coherent future systems.
