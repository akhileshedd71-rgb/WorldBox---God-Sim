# Phase 8 — Godot editor beta

Version **0.8.0** prepares the existing sandbox for direct Godot playtesting. Download the GitHub source and follow [the editor checklist](GODOT_TESTING.md). This milestone intentionally builds no APK or AAB. Mobile release acceptance remains open in [the roadmap](../ROADMAP.md).

## A shelf for worlds

Open the header's world shelf to find six named slots, the legacy quick save, and autosave. Each named slot shows its label, last saved UTC time, year, population, seed, and recovery status. Slot labels accept up to 48 characters. Labels are data; filenames are fixed numeric slots, so punctuation cannot become a filesystem path.

**Save in slot** saves the current world. An occupied slot says **Replace slot** and keeps one previous valid version. **Load world** restores its current or recovered copy; **Load previous version** explicitly chooses its backup. Loading first preserves the current world in autosave. If preservation fails, the load does not replace the active world.

Ctrl/Cmd+S and the save icon update the most recently saved or loaded named slot in that session. A newly generated world resets this destination to the independent quick-save file. Autosave always remains separate. Launch begins with the demonstration world, allowing the player to choose which world to restore.

The simulation schema remains **v7**. Named saves add `slot_label` and `saved_at` metadata outside simulation state; all genuine v1–v7 fixtures load and can be placed on the shelf. No simulation migration was invented for a presentation/storage change.

## Recoverable writes

`SafeFiles` performs these operations synchronously:

1. Validate the proposed data before touching an existing world.
2. If an interrupted `.tmp` is the only good copy, protect it as `.bak` first.
3. Write and flush a new `.tmp`, close it, and validate its contents.
4. If the existing primary is valid, copy it to `.bak.tmp`, validate it, and rename it to `.bak`.
5. Rename the validated `.tmp` into the primary path.

An invalid existing primary never replaces a good backup. A failed validation or backup operation aborts replacement. Readers try the primary first, then `.bak`, then `.tmp`, with file-size and full schema/reference checks. Recovery is read-only and reports its source; saving explicitly makes the recovered world current. Backups retain one generation, not unlimited history.

The same helper protects quick save, autosave, named slots, and preferences. World's file limit remains eight MB; preferences are read with a 16 KB limit. There is no separate catalog whose loss could hide all slots. Opening the shelf validates its bounded set of files; it can briefly pause on large archives.

Tests simulate corrupt primaries, damaged backups, interrupted first saves, complete temporary recovery, rejected new state, and earlier-version imports. File flush and rename behavior has been tested on Linux. This does **not** establish power-loss, full-disk, or filesystem guarantees on every OS/device; those remain acceptance tests. The editor Stop button can terminate the process without running the game's quit notification.

## Personal settings and sound

Settings persist in a separate versioned `settings.json` so loading an old world cannot reset them. Choose **Apply & save settings** to persist changes; leaving without Apply keeps the previous settings. Invalid preferences are rejected, damaged preferences recover from backup, and unrecoverable preferences use explicit defaults.

| Setting | Behavior |
| --- | --- |
| Master / ambience / effects | Independently control the original local loop and short interaction cues; zero master mutes playback. |
| Larger reading text | Scales reading labels to 115% and slightly enlarges default control text. It is not a full operating-system magnifier. |
| Higher contrast | Brightens muted reading text and increases focus-outline contrast. World information still has text labels. |
| Reduced motion | Stops weather animation, movement interpolation, and new animated tool rings; simulation rules remain active. |
| Pause when unfocused | Pauses model advancement and audio while another window has focus; the selected simulation speed is retained. |
| 30 / 60 FPS target | Sets the engine frame limit; the four-ticks-per-second model and 1×/2×/5× time controls keep their meaning. |

`tools/generate_audio.py` uses only Python's standard library to generate an original 16-second pentatonic ambience and touch, paint, and save cues. WAVs are committed; Python is unnecessary for play. Ambience loops in `GameAudio`; feedback is rate limited and has one cue player. Explicit streaming playback and a short audio-thread drain release active sounds when closing. Audio uses no simulation RNG and never changes world outcomes. `tools/generate_assets.py` includes the original settings icon.

Application suspension saves and pauses; resumption clears accumulated frame time. A desktop window-close save failure keeps the window open with retry/exit choices. Haptics, translations, screen-reader certification, and native device behavior remain future acceptance work.

## Terrain rendering budget

`TerrainChunks` replaces one 2304 × 1536 texture rebuild with **54 textures**, each covering 16 × 16 cells. Compact signatures include terrain, elevation, biome, and visible vegetation/stone/snow. A changed signature marks its own chunk plus affected neighboring chunks so coastal borders remain correct. Identical visible states cause no uploads.

Initial loading fills the map; subsequent updates rebuild at most **four dirty chunks per frame**. Scans remain throttled to approximately eight per second, and pending chunks keep their most recent world data. Drawing culls off-screen chunks. Political overlays remain separate. The cache is derived, is never serialized, and cannot change simulation state or random draws. Tool rings are capped at 64.

The beta tests measure initial rendering and a local edit, verify affected upload counts, budgets, snow/vegetation invalidation, coast seams, and unchanged model state. These are host measurements, not device FPS claims. World size, population, and archive limits remain unchanged until device profiling supports an increase.

## Delivery and remaining gates

The repository is the deliverable: import `project.godot` and press F5. Source assets are included; `.godot`, `.local`, private user saves, logs, credentials, and builds are excluded from Git.

The editor beta adds automated storage/render/input tests and actual rendered desktop/phone captures. User playtesting comes next. Native Android/iOS builds, real device soak tests, safe areas, low-storage/power-loss scenarios, hardware audio/haptics, and store release are not completed by cloud/editor checks.
