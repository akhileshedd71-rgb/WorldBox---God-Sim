# Art direction and asset provenance

Verdant uses warm foliage, muted teal seas, sand/gold accents, and a dark botanical interface. Terrain and creatures are pixel art; controls use restrained line icons. The world stays readable at a distance, while zoom reveals creatures and houses.

## Source assets

| Asset | Source | Notes |
| --- | --- | --- |
| 24 terrain variations | `tools/generate_assets.py` | Four original 16 × 16 textures per material |
| Trees, pine, peak | Same generator | Original 16 × 16 transparent sprites |
| Settler, rabbit, deer, fire | Same generator | Original 16 × 16 silhouettes |
| Stone deposit, village depot | Same generator | Original 16 × 16 resource/storage sprites |
| Crop stages, foundations, carried goods | `world_view.gd` canvas geometry | Drawn from actual model state |
| House | Same generator | Original 32 × 32 building |
| Toolbar/app icons | Same generator | Original SVG paths, including crown, borders, peace, discord, and settings |
| Political overlay and village flags | `world_view.gd` canvas geometry | Derived from actual claims and stable kingdom colors |
| Ambience and three interaction cues | `tools/generate_audio.py` | Original synthesized WAVs; Python standard library only |
| Open Sans Regular/Semibold | Open Sans project, bundled via Debian | Apache License 2.0; license in `assets/fonts/LICENSE.txt` |

Font copyright: Digitized data copyright © 2010–2011, Google Corporation. Upstream: https://www.opensans.com/. The bundled font files are unmodified. The asset generator uses standard Python and Pillow; no image model, external sprite pack, or proprietary game asset is required.

## Regeneration

The generated images are committed, so this is optional:

```sh
python -m venv .local/art-env
.local/art-env/bin/pip install Pillow==11.3.0
.local/art-env/bin/python tools/generate_assets.py
./tools/godot.sh --headless --editor --import --quit
```

The generator has a fixed random seed. Changing it deliberately changes texture details. Keep the icon filenames aligned with the UI catalogue and sprite names aligned with species/tool names.

## Expansion rules

- Keep common ground tiles at 16 × 16; small creatures should read at that scale.
- Distinguish terrain through value and shape as well as hue.
- Reserve warm bright colors for player selection and major consequences.
- Keep character animation compact; add idle/walk/attack frames when those behaviors are implemented.
- Keep houses modular and visibly tied to settlement development.
- Avoid visual effects so large that they hide consequences on a phone.
- Keep sound under the separate audio/settings layer, independent of simulation randomness. Haptics remain future work.

## Screenshots

Documentation images are actual Godot viewport captures. `tools/capture.gd` loads the main scene, advances the same simulation by 960 ticks (20 years), pauses, selects Meadow, and captures the frame. Political captures use the Frontier preset and advance 2,400 ticks (50 years), then show actual claims or the kingdom inspector. It does not mock the UI or generate an illustration of an unimplemented game.

```sh
./tools/godot.sh --script tools/capture.gd
./tools/godot.sh --script tools/capture.gd -- --phone
./tools/godot.sh --script tools/capture.gd -- --phone --guide
./tools/godot.sh --script tools/capture.gd -- --phone --villages
./tools/godot.sh --script tools/capture.gd -- --settlement
./tools/godot.sh --script tools/capture.gd -- --politics
./tools/godot.sh --script tools/capture.gd -- --phone --kingdoms
./tools/godot.sh --script tools/capture.gd -- --phone --kingdoms --diplomacy
```

A working graphics display is required. On the prepared cloud machine, the local dummy X server can provide software rendering; see `TESTING.md`.

## Phase 4 additions

`generate_assets.py` also creates original stone-spear soldier, archer, watchtower, and transport-boat PNG sprites, plus war/tower SVG controls. Company markers use the realm palette; troop/morale labels and retreat arrows also communicate status. Strike and arrow cues are canvas primitives, bounded to 64 recent events; no per-soldier scene nodes are introduced. Actual Phase 4 captures are `screenshots/first-world-war.png` and `screenshots/phone-military.png`.

## Phase 5 additions

Twelve original 16 × 16 variants (`settler_0..3`, `rabbit_0..3`, `deer_0..3`) add clothing, hair, fur, and coat markings. The coat gene selects a variant without affecting statistics. The generator also creates family and favorite SVG controls; the world canvas draws favorite rings. The Lives inspector uses the same variant sprite for its portrait. Actual captures: `screenshots/first-world-lives.png` and `screenshots/phone-lives-family.png`.

## Phase 6 additions

The generator creates 28 original biome surface tiles, wetland reeds, glimmer trees, and ten ecosystem/weather/disaster SVG icons. Actual snow cover selects snowy ground; weather draws bounded rain/snow particles, sickness adds amber markers, and active vents glow. Captures `first-world-biomes.png`, `first-world-environment.png`, and `phone-environment.png` show the actual Phase 6 model at tick 960 with rain selected. Reproduce them with `--biomes`, `--environment`, and `--phone --environment` capture arguments.

## Phase 7 additions

The generator now includes an original woven community emblem, `assets/icons/society.svg`, used in the Observe palette and colored culture identity panel. Discovery emblems use filled/outline diamonds with text status. `phone-society.png` and `first-world-society-knowledge.png` are captures of the actual Phase 7 scene, reproduced with `--phone --society` and `--society --knowledge`. No external game art is included.

## Phase 8 additions

Four original mono WAV assets provide a 16-second looping meadow theme and short touch, paint, and save cues. Regenerate with `python3 tools/generate_audio.py`; the script uses only Python's standard library. Audio is synthesized from oscillator envelopes, with no third-party samples. Volume and mute are user controlled. `settings.svg` is an original toolbar icon from the image generator.

`phone-shelf.png` and `first-world-settings.png` show actual Phase 8 controls. Reproduce with `--phone --shelf --readable` and `--settings` respectively. Larger reading text is enabled in the shelf capture.
