# Test the editor beta

This is **Verdant v0.8.0**, the Phase 8 Godot editor beta. The repository contains the entire playable project, original art/audio, fonts, tests, and documentation. No APK or AAB is required or built for this milestone.

## Download and launch

1. Open the GitHub repository's `main` branch and choose **Code → Download ZIP**.
2. Extract the ZIP completely. Do not run the project from inside the ZIP viewer.
3. Install **Godot 4.6.3 standard**, available for Windows, macOS, and Linux. The .NET edition is unnecessary.
4. Open Godot's Project Manager, choose **Import**, and select `project.godot` in the extracted folder.
5. Open the project and wait for the import progress to finish. First import rebuilds the local `.godot` cache.
6. Press **F5**. A populated island should appear. Press Space to pause or resume.

Use the Compatibility renderer already selected in the project. No Android SDK, Xcode, export templates, Python, Pillow, account, or internet connection is needed to play once Godot and the project are downloaded. An unconfigured Android export preset does not prevent running the main scene. If Godot asks for a main scene, select `scenes/main.tscn`.

F6 runs the currently open scene; F5 runs the game's configured main scene. The editor's Stop button ends the process immediately and is **not** the game's save-and-quit action: save before using it. Closing the game window attempts an autosave first.

## First playtest

| Try | Expected result |
| --- | --- |
| Shape → Meadow, then drag across the coast | Land appears continuously; coast edges update without leaving seams. |
| Move tool or right-drag; use the mouse wheel | The camera pans/zooms without painting. |
| Add several settlers on connected fertile land | Adults can establish a village, work, haul goods, farm, and build. |
| Observe → Villages / Lives / Society | Real stores, families, cultures, knowledge, and history appear in live dashboards. |
| New world → Frontier continent | Three initial groups can grow into distinct realms. |
| Observe → Planet; call rain or drought | Conditions and crop growth respond. |
| Settings (sliders icon) | Adjust master/ambience/effects, reading size, contrast, motion, focus pause, and frame limit; choose Apply. |
| Alt-Tab with focus pause enabled | Simulation/audio pause; returning resumes without simulating elapsed background time. |

Most controls work by mouse; Tab/Shift+Tab navigate focusable controls, arrows adjust sliders/selectors, and Escape closes panels. `V` selects Move, `I` selects Inspect, and Ctrl/Cmd+S saves. The `?` field guide explains the mechanics. The project currently uses landscape layouts; start at the default 1440 × 900 desktop window.

## Save and recovery test

1. Open the world shelf (folder/load icon), select an empty slot, name it, and choose **Save in slot**.
2. Return to play, make an obvious terrain change, and press Ctrl/Cmd+S. It updates that named slot and retains the previous valid version.
3. Reopen the shelf and choose **Load previous version**. The earlier terrain should return. The world you left is first preserved in autosave.
4. Choose **Load world** to return to the latest named version.
5. Create a new world, then quick-save. The prior named slot must remain intact; new-world quick save uses the independent `world.json` file.
6. Stop and rerun the game. Launch shows a demonstration world; open the shelf to load your named world. Settings should persist independently.

Godot's **Project → Open User Data Folder** opens the actual save location. Direct editor launches use Godot's normal per-OS user directory; `tools/godot.sh` uses the checkout's ignored `.local/data` unless an XDG path is supplied. These are different save locations. Files are local to your computer and are not uploaded to GitHub.

The shelf has six `worlds/slot-NN.json` files; `world.json` and `autosave.json` are separate. Each successful replacement keeps one `.bak`. The game validates a primary, then its backup, then a complete `.tmp`; unreadable copies do not replace the active world. See [recovery details](BETA.md). Do not edit your only copy of a valuable world for testing.

## Report feedback

Include the commit/version, OS, Godot version, renderer/GPU if known, world seed/year, exact actions, and expected versus observed behavior. For an error, copy the first error and its stack from Godot's Debugger/Output panel. A screenshot helps for clipping or unreadable controls. Save the affected world before stopping the editor when possible.

The fixed limits remain 144 × 96 tiles, 350 living creatures, and 2,048 lifetime family records. Performance measurements in this repository are from Linux cloud hardware, not your device. Mobile SDK/export setup, hardware thermal/safe-area/low-storage tests, APK/AAB packaging, and store publication remain deferred.
