# Verification and limitations

## Automated checks

Run `./tools/check.sh` from the repository. It creates isolated temporary user/cache/config directories so checks cannot overwrite a player's save slots, then performs:

1. Godot asset import and script compilation.
2. `tests/run_tests.gd`: **42 checks** covering seeded worlds, brushes, powers, movement barriers, hunger/aging/birth laws, village growth, saves, damaged-primary rejection and backup recovery, and simulation bounds.
3. `tests/test_economy.gd`: **46 checks** for finite goods, delivery, navigation barriers, costs, farming, maturity/capacity, v1 migration, century survival, scarcity, and complete-state continuation.
4. `tests/test_politics.gd`: **58 checks** covering autonomous expansion, conservation/travel, diplomacy, independence, succession/collapse, navigation barriers, v1/v2 migration, corrupt political references, and in-flight save continuation.
5. `tests/test_military.gd`: **83 checks** covering recruitment conservation/costs, melee/ranged combat, defenses, friendly/civilian immunity, casualties, morale, capture, peace, interrupted navigation, transport, migrations, and battle/voyage continuation.
6. `tests/test_heredity.gd`: **74 checks** for species resources, bounded traits, real work/combat effects, inheritance/mutation, three generations, archived relatives, favorite/history limits, all four legacy fixtures, malformed saves, and exact continuation.
7. `tests/test_environment.gd`: **76 checks** for independent biomes, growth/resources, weather/season/age laws, disease/barriers/immunity, finite disasters, v1–v5 migration, malformed saves, and 240-tick continuation.
8. `tests/test_society.gd`: **88 checks** for independent identities, household learning, real work effects, clan loyalty, communal care, teaching/language/war/barriers, gradual adoption and clocks, archived rulers, v1–v6 migration, malformed references, budgets, and exact continuation.
9. `tests/test_beta.gd`: **55 checks** for recoverable writes, rejected replacements, six named slots, genuine v1–v7 imports, independent settings validation/recovery, terrain invalidation, coast seams, and bounded uploads.
10. `tests/test_ui.gd`: **60 checks** loading the actual main scene and exercising controls, touch gestures, pause/speed behavior, inspection, saving/loading, new worlds, laws, and desktop/compact layouts.
11. `tests/test_life_ui.gd`: **22 checks** for native phone touches, traits, parents/children, favorites, memories, death, filters, map focus, scrolling, and disk reload.
12. `tests/test_environment_ui.gd`: **22 checks** for native biome/weather/disaster touches, climate controls, law presets, inspection, layout, and save validation.
13. `tests/test_society_ui.gd`: **23 checks** for native phone Society controls, culture/member selection, graphs, history filters, ruler/family/community links, discoveries, dormant effects, empty worlds, and disk validation.
14. `tests/test_beta_ui.gd`: **27 checks** for native Settings/shelf controls, preference persistence, mute, focus/suspension, previous-version loading, preservation before load, independent new-world saves, and reduced motion.
15. `tools/startup_smoke.gd`: run the configured main scene for 120 frames, request its normal window close, and verify that it preserved a valid autosave.

The script preserves nonzero engine/test exit codes and also scans for Godot `SCRIPT ERROR`/`ERROR` output, because some engine import failures can return zero. The economy conservation case fixes climate laws off to verify base work timings/costs; century survival keeps climate on, and the environment suite checks growth/yield differences. The political alliance-delta case disables Society to isolate its existing +2 alliance benefit; social tests separately verify the +1 clan contribution. Legacy ancestry comparisons exclude only the newly added social fields and still compare every original field. The fire regression now asserts confined vegetation loss with preserved biomes. No assertions are skipped. Tests use their own save filenames; production data is not a test fixture.

Save tests load a JSON file and advance both original/restored worlds another 120 ticks, comparing terrain/resources, creatures, and villages. Malformed versions, tile values, coordinates, stat types, missing laws, missing files, and truncated JSON are explicitly rejected as primary inputs; a valid backup may still recover the world. Recovery tests assert that the original files remain unchanged until a deliberate save.

Gesture tests feed `InputEventScreenTouch` and `InputEventScreenDrag` through the view's input handler. Additional tests inject touch through `Input.parse_input_event`, verifying that Godot's emulated mouse events activate actual HUD buttons and do not apply map tools twice. War declaration, mobilization, tower construction, army orders, follow-on-map, favorites, and family navigation are also exercised using actual engine touch events; other controls are exercised through their signals. These checks establish engine/logical input behavior, not physical driver/device compatibility; device tests are still needed.

## Measured here

On the prepared Linux x86-64 cloud machine with Godot 4.6.3:

- Model/persistence suite: 42 / 42 checks passed.
- Economy/navigation/migration suite: 46 / 46 checks passed.
- Politics/migration suite: 58 / 58 checks passed.
- Military/transport/migration suite: 83 / 83 checks passed.
- Scene/UI suite: 60 / 60 checks passed. Heredity suite: 74 / 74; life-inspector suite: 22 / 22. Environment suite: 76 / 76; environmental UI: 22 / 22. Society suite: 88 / 88; society UI: 23 / 23. Beta storage/rendering suite: 55 / 55; beta UI: 27 / 27. **676 total assertions passed across thirteen suites.**
- Phase 7 rendered seed 41827 at tick 960: 45 settlers in two villages, crop rotation at 96/96, masonry at 4/4, and an annual population curve. Knowledge was earned through actual work.
- Mixed-household residence saved one tick before its first threshold resumed with identical cultural, belief, and language adoption, personal memories, and discoveries. All genuine v1–v6 fixtures migrated; v6 live health/work/genetics, climate, hazards, and earlier family records were preserved. Both new laws remain dormant on migration.
- The full social world continued identically for 144 ticks after JSON reload; real colony travel retained all four social identities.
- Historical Phase 5 rendered seed 41827 at tick 960: a living second-generation settler is inspected with actual inherited traits and parent links. Family JSON continuation also matches over 240 ticks.
- Historical Phase 4 natural-war observation: Frontier seed 41827 developed for 1,200 ticks, then a declared war raised five real companies by tick 1,224 without adding test resources; subsequent fighting reduced troop counts and caused retreats.
- Military scenarios: capture ended a one-settlement realm, peace returned surviving soldiers to work, actual boats carried an invasion and brought survivors home, and blocked/edited routes preserved valid positions and saves.
- Shared political scenario: three autonomous kingdoms expanded to six settlements and established two shared-border relations, with 120 original settlers preserved.
- Historical Phase 3 Frontier preset after 2,400 ticks: three realms, 13 villages, 327 settlers and 23 wildlife, respecting the existing 350-creature cap. This is a seeded observation, not a guarantee for every world.
- Resource-rich island at year 101 with climate enabled: 44 settlers, 61 births, 29 deaths, eight houses, 118 stored food, and 900 food harvested.
- Agricultural-island comparison after 600 ticks: 12 surviving settlers with farms; zero after all farm plots were destroyed.
- Full saved state after JSON round trip remained identical over the next 120 ticks for economy, expeditions, marching companies, battles, and sea crossings. Interrupted-route cases also match after reload.
- Phase 6 environment scenario: actual worker harvest over 300 ticks was 36 food with sustained rain versus zero with sustained drought; neither case received added harvests.
- An infected, otherwise healthy creature survived the 64-tick illness and gained immunity; contact transmission respects species and connected-land barriers. Disabling the disease law froze damage and timers.
- Final Frontier seed 41827 established three independent realms and two natural diplomatic contacts within 25 years after starting-spacing adjustment.
- Weather, illness, and a finite eruption survived JSON reload and matched every persisted field over the next 240 ticks. All genuine v1–v5 fixtures migrated.
- Historical Phase 7: exported `build/verdant.pck` and started the packed main scene headlessly. This pack requires Godot; it is not an APK or a standalone executable.
- Actual Compatibility-renderer frames captured using Mesa llvmpipe software graphics, including Phase 8 larger-text world shelf and desktop settings.
- Terrain cache: initial 54-chunk fill **102.66 ms**; one local edit **7.79 ms**, uploading **1 of 54** textures. Separate assertions verify unchanged worlds upload nothing and large edits respect the four-chunk budget. These timings cover cache work on this host, not complete game frames.
- Fresh source copied without `.godot` or `.local` imported and launched using Godot 4.6.3. A normal window-close notification preserved the world and released audio before quitting. The UI/startup checks also cover explicit streaming playback cleanup. Audio teardown waits for the mixer before quitting; the smoke test uses the actual window-close path rather than an abrupt `--quit-after` teardown.
- A 500-tick stress run starting at 350 creatures maintained bounds and valid live-unit state; the final verification run measured **31.30 ms/tick** on this host.

The benchmark covers model execution, not full-frame rendering or phone performance. It is deliberately not an FPS/device claim. The runner prints current timing on each execution.

## Graphical validation

Run the game in the Godot editor, then try the field guide's create/observe/intervene loop. `tools/capture.gd` creates reproducible screenshots of the actual scene. Screenshots in this folder show a large desktop layout and a compact 960 × 540 landscape layout.

Cloud graphical inspection uses the system's Xorg dummy driver and `DISPLAY=:99`. `tools/start_test_display.sh` starts it if necessary and stores local configuration/logs under `/tmp/verdant-xorg-<uid>-99/`. This is a local test display, not a user-facing web preview. The process is temporary and is not needed for headless tests or a developer's normal graphical editor.

```sh
./tools/start_test_display.sh
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --phone
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --phone --villages
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --settlement
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --politics
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --phone --kingdoms --diplomacy
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --war
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --phone --military
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --lives
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --phone --lives --family
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --biomes
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --environment
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --phone --environment
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --phone --society
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --society --knowledge
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --phone --shelf --readable
DISPLAY=:99 ./tools/godot.sh --audio-driver Dummy --script tools/capture.gd -- --settings
```

The cloud software driver may report that VSync changes are unsupported. Godot's editor may also report the absent Android `build-tools` directory while inspecting the Android preset. Neither message means an Android package was built; native export still needs the prerequisites in `MOBILE.md`.

Required interactive regression scenarios:

- Paint a coast rapidly at different brush sizes; inspect the boundaries and forage.
- Spawn nearby settlers; watch sowing, hauling, and house construction; isolate workers by water and inspect the result.
- Open Observe → Villages, change the selected settlement, pause/resume, and compare the population/housing lines.
- Destroy farm plots or a house, then save/load immediately and after simulation resumes.
- Apply fire, pause, and use rain; resume and verify nearby fire behavior.
- Save a world, create another, and restore the manual/automatic slots.
- Use two fingers while a destructive tool is selected; confirm that the gesture moves the view without applying the tool.
- Generate a Frontier continent; inspect claimed land, switch rulers/partners in the dashboard, and use favor/peace/discord.
- Cut an expedition off with water, remove a capital, and inspect the political explanations and new ownership.
- Declare war in Diplomacy, use the War tab to mobilize/fortify/order troops, follow them on the map, and make peace.
- Interrupt a land/sea invasion with terrain edits; save while paused and while sailing; verify safe return/capture.
- Inspect a newborn, open Lives, follow both parents, star a relative, then verify its memory after death and reload.
- Use Realm/Diplomacy/War/Chronicle tabs at phone size and scroll long historical records.
- Paint every biome along a coast, verify unchanged elevation/homes, and inspect growth under rain, drought, winter, and the Age of Frost.
- Seed Rustfever, pause its law, resume it, and inspect recovery/immunity and saved memories.
- Trigger a volcano, edit its surroundings, save/reload mid-eruption, and verify expiry; exercise law presets and scroll Climate/Land/Health.
- Open Society, switch culture, follow a member and a remembered ruler to Lives, return to their culture, filter history, switch graph measures, and inspect discovery conditions.
- Save two named versions, load the previous version, create a new world, and confirm its quick save does not replace the older named world.
- Apply audio/reading/motion settings, restart, and verify persistence; test focus loss and 30/60 frame targets.
- Open/close each dialog at compact sizes and read scrolled field-guide text.

## Known limitations / future work

- Native Android/iOS export and physical-device tests have not run; SDK/templates/signing are separate prerequisites.
- World size is fixed; population cap is 350. Terrain baking uses 54 cached chunks with four runtime uploads per frame; initial binding builds all chunks. Navigation edits still rebuild the grid/components. Profile these before larger worlds.
- Workers have budgeted A* routes. Wildlife/nomads still move locally; no swimming, civilian trade, or civilian transport network. Military companies use paid transport boats. Routes can stall at active fire until it burns out.
- Each village has at most eight houses and 14 farm plots. There are no professions yet; climate/seasonal stress now affects crop growth.
- Weather is global; soil, snow, and biome growth are local. One disease and eight simultaneous finite volcanoes are supported; atmospheric fluids, flood simulation, and roaming disaster creatures remain future work.
- Audio includes one original loop and three cues; hardware output/interruptions and longer-session listening need playtesting. Localization, accessibility certification, analytics, and monetization remain future work.
- No terrain undo, migration from future versions, or automatic resume on cold launch.
- Save rename is tested on Linux. Interruption/low-storage behavior on Android/iOS must be exercised on real devices.
- Roads/walls, naval combat, formations, advanced social systems, and genetic/evolution editors remain roadmap items. Wars require explicit player intervention; rivalry only restricts expedition transit.
- Family history stops at 2,048 lifetime records; six memories per life and 32 favorites are retained. Reaching the archive cap stops new births/introductions without pruning ancestors. Genome editing UI and larger archives remain future work.
- Social records are bounded at 128 cultures, 256 clans, two languages, 128 faiths, 192 social events, 256 ruler transitions, 120 graph samples, and four discovery goals. All hearth faiths currently share one communal-care rule.
- Political records are bounded (128 kingdoms, 256 expeditions, 256 companies, 1,000 villages including history); IDs never recycle. Historical archival and larger budgets are future work.
- An expedition planner rejects a chosen route through rival territory rather than searching a separate diplomatic detour grid.

Do not raise these limits or label the project a mobile release candidate without completing the corresponding roadmap gates.

Phase 8 is delivered as source for Godot editor testing. No APK/AAB or new native export is built in this milestone. Follow [the playtest checklist](GODOT_TESTING.md) before native packaging.
