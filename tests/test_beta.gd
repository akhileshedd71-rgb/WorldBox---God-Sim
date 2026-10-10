extends SceneTree
var checks := 0
var failures := 0
const DIRECTORY := "user://beta-tests"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: ", description)
	else: failures += 1; printerr("FAIL: ", description)
func write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE); file.store_string(value); file.close()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	_recovery()
	_library()
	_settings()
	await _terrain()
	for file in DirAccess.get_files_at(DIRECTORY): DirAccess.remove_absolute(DIRECTORY.path_join(file))
	DirAccess.remove_absolute(DIRECTORY)
	print("\nBETA RESULT: %s checks, %s passed, %s failed" % [checks, checks - failures, failures])
	quit(0 if failures == 0 else 1)
func _recovery() -> void:
	var path := DIRECTORY.path_join("recover.json")
	var w := WorldState.new(); w.generate(818, 0, false)
	check(SaveStore.save_world(w, path) == OK, "first save creates a validated primary without requiring an old file")
	check(not FileAccess.file_exists(path + ".tmp") and not FileAccess.file_exists(path + ".bak"), "first atomic rename leaves no staging or invented backup")
	w.world_name = "Second horizon"
	check(SaveStore.save_world(w, path) == OK, "a second save atomically replaces the primary")
	check(SaveStore.load_world(path).world.world_name == "Second horizon" and SaveStore.load_world(path + ".bak").world.world_name != "Second horizon", "replacement keeps the previous valid world as backup")
	var prior := FileAccess.get_sha256(path)
	var backup := FileAccess.get_sha256(path + ".bak")
	w.units.append({"broken": true})
	check(SaveStore.save_world(w, path) == ERR_INVALID_DATA and FileAccess.get_sha256(path) == prior and FileAccess.get_sha256(path + ".bak") == backup, "invalid new state cannot overwrite either good copy")
	w.units.clear()
	write(path, "{truncated")
	var result := SaveStore.load_world(path)
	check(result.has("world") and result.recovered and result.source.ends_with(".bak"), "a corrupt primary recovers the validated backup with an explicit recovery flag")
	check(FileAccess.get_file_as_string(path) == "{truncated", "loading recovery is read-only until the player saves")
	check(SaveStore.save_world(w, path) == OK and FileAccess.get_sha256(path + ".bak") == backup, "saving after corruption never rotates damaged bytes over the good backup")
	DirAccess.remove_absolute(path); DirAccess.remove_absolute(path + ".bak")
	write(path + ".tmp", JSON.stringify(SaveStore.encode(w), "", true, true))
	result = SaveStore.load_world(path)
	check(result.has("world") and result.source.ends_with(".tmp"), "an interrupted first save can recover a complete validated temporary")
	w.world_name = "Third horizon"
	check(SaveStore.save_world(w, path) == OK and SaveStore.load_world(path + ".bak").world.world_name == "Second horizon", "reusing a temporary first protects it when it is the only valid world")
	write(path, "{}"); write(path + ".bak", "{"); write(path + ".tmp", "[null]")
	check(SaveStore.load_world(path).has("error"), "invalid primary, backup, and temporary are all rejected")
	write(path, JSON.stringify(SaveStore.encode(w), "", true, true))
	check(SafeFiles.read_one(path, SaveStore._valid_file, 16).get("error", "").contains("large"), "readers enforce their byte budget before parsing an oversized valid file")
func _library() -> void:
	var library := SaveLibrary.new(); library.directory = DIRECTORY
	check(library.inspect_slot(0).valid == false and not library.inspect_slot(0).occupied, "an unused named slot reports empty state")
	var w := WorldState.new(); w.generate(218, 0, false)
	for n in SaveLibrary.SLOT_COUNT:
		w.world_name = "Island %s" % n; w.tick = n * 48
		check(library.save_slot(w, n, "Experiment %s" % n) == OK, "named slot %s saves independently" % (n + 1))
	check(library.read_slot(0).world.tick == 0 and library.read_slot(5).world.tick == 240, "all six slots retain their own worlds")
	var info := library.inspect_slot(5)
	check(info.label == "Experiment 5" and info.year == 6 and info.population == 0 and info.saved_at > 0, "shelf summaries come from validated labels, timestamps, and world data")
	var prior := FileAccess.get_sha256(library.path(0))
	check(library.save_slot(w, -1, "Bad") == ERR_INVALID_PARAMETER and library.save_slot(w, 6, "Bad") == ERR_INVALID_PARAMETER, "invalid slot indices cannot address files")
	check(library.save_slot(w, 0, " ") == ERR_INVALID_PARAMETER and library.save_slot(w, 0, "x".repeat(49)) == ERR_INVALID_PARAMETER and prior == FileAccess.get_sha256(library.path(0)), "empty and oversized labels leave the old slot untouched")
	check(library.save_slot(w, 0, "../A world 🏝") == OK and library.read_slot(0).label == "../A world 🏝" and library.path(0).ends_with("slot-01.json"), "Unicode and path-like labels remain data, never filenames")
	check(library.read_slot(0, true).world.tick == 0, "a previous named version can be explicitly loaded")
	for version in range(1, 8):
		var old := SaveStore.load_world("res://tests/fixtures/v%s_world.json" % version)
		check(old.has("world") and library.save_slot(old.world, 1, "From phase %s" % version) == OK and library.read_slot(1).has("world"), "genuine v%s worlds import into the named shelf" % version)
	var source := SaveStore.load_world("res://tests/fixtures/v7_world.json")
	var stored := library.read_slot(1)
	check(JSON.stringify(SaveStore.encode(source.world), "", true, true) == JSON.stringify(SaveStore.encode(stored.world), "", true, true), "saving a v7 world in the shelf preserves every simulation field")
	write(library.path(1), "{bad")
	check(library.inspect_slot(1).recovered and library.read_slot(1).recovered, "the shelf explains automatic recovery before loading")
func _settings() -> void:
	var settings := PlayerSettings.new(); settings.path = DIRECTORY.path_join("settings.json"); settings.restore()
	check(settings.values == PlayerSettings.DEFAULTS, "missing preferences load explicit defaults")
	var next := settings.values.duplicate(); next.master = 0; next.large_text = true; next.frame_limit = 30
	check(settings.save(next) == OK, "audio, reading, and frame preferences persist outside world saves")
	var copy := PlayerSettings.new(); copy.path = settings.path; copy.restore()
	check(copy.values.master == 0 and copy.values.large_text and copy.values.frame_limit == 30, "a fresh preferences instance restores the saved settings")
	var before := FileAccess.get_sha256(settings.path)
	for key in ["master", "ambience", "effects", "large_text", "frame_limit"]:
		var bad := next.duplicate(); bad[key] = "invalid"
		check(settings.save(bad) == ERR_INVALID_DATA and FileAccess.get_sha256(settings.path) == before, "invalid %s settings preserve the last saved choices" % key)
	next.master = 0.5; settings.save(next); write(settings.path, "broken")
	copy.restore()
	check(copy.recovered and copy.values.master == 0, "damaged settings recover their previous valid version")
	write(settings.path + ".bak", "broken"); copy.restore()
	check(copy.values == PlayerSettings.DEFAULTS, "unrecoverable settings fall back safely without touching world files")
func _terrain() -> void:
	var view := WorldView.new(); root.add_child(view); await process_frame
	var w := WorldState.new(); w.generate(913, 0, false); view.bind_world(w)
	view.set_process(false)
	var start := Time.get_ticks_usec(); view._bake(); var full := Time.get_ticks_usec() - start
	check(view.terrain_cache.textures.size() == 54, "first terrain render fills all 54 small textures")
	view.terrain_cache.scan(); view.terrain_cache.flush()
	check(view.terrain_cache.last_rebuilt == 0, "unchanged visuals cause zero texture uploads")
	var p := Vector2i(40, 40); var i := w.index(p.x, p.y)
	var previous := w.terrain_revision
	w.set_material(i, WorldState.Terrain.MOUNTAIN if w.terrain[i] != WorldState.Terrain.MOUNTAIN else WorldState.Terrain.OCEAN)
	start = Time.get_ticks_usec(); view._bake(); var small := Time.get_ticks_usec() - start
	check(w.terrain_revision > previous and view.terrain_cache.last_rebuilt == 1, "an interior tile edit rebuilds one chunk instead of the full world")
	var changed := view.terrain_cache.last_rebuilt
	w.set_material(w.index(31, 47), WorldState.Terrain.OCEAN if w.terrain[w.index(31, 47)] != WorldState.Terrain.OCEAN else WorldState.Terrain.MEADOW)
	view.terrain_cache.scan()
	check(view.terrain_cache.dirty.size() == 3, "corner edits also invalidate neighboring chunks for coast accents")
	view.terrain_cache.flush(1)
	check(view.terrain_cache.last_rebuilt == 1 and view.terrain_cache.dirty.size() == 2, "the chunk budget leaves remaining work queued")
	view.terrain_cache.flush(54)
	var cell := w.index(40, 40); w.set_material(cell, WorldState.Terrain.MEADOW); w.trees[cell] = 0; w.stone[cell] = 0
	view._bake(); w.snow[cell] = 1; view.terrain_cache.scan()
	check(view.terrain_cache.dirty.size() == 1, "snow appearance participates in terrain invalidation")
	view.terrain_cache.flush(54); w.snow[cell] = 2; view.terrain_cache.scan()
	check(view.terrain_cache.dirty.is_empty(), "deeper existing snow does not upload an identical picture")
	w.snow[cell] = 0; w.trees[cell] = 1; view.terrain_cache.scan()
	check(not view.terrain_cache.dirty.is_empty(), "regrowing vegetation invalidates its visible chunk")
	view._bake(); view.terrain_cache.scan(); view.terrain_cache.flush(54)
	w.fill_material(WorldState.Terrain.OCEAN); view.terrain_cache.scan(); view.terrain_cache.flush(4)
	check(view.terrain_cache.last_rebuilt == 4 and view.terrain_cache.dirty.size() > 0, "a whole-world repaint respects the four-chunk frame budget")
	var same: Dictionary = SaveStore.encode(w).duplicate(true)
	while not view.terrain_cache.dirty.is_empty(): view.terrain_cache.flush(4)
	check(SaveStore.encode(w) == same, "render optimization never changes authoritative simulation state")
	w.set_material(w.index(31, 47), WorldState.Terrain.MEADOW); view._bake()
	check(view.terrain_cache.render_chunk(20).get_pixel(0, 240) == Color("377b7c"), "a coast accent correctly crosses the seam into a neighboring chunk")
	print("TERRAIN BENCHMARK: full initial %0.2f ms / local edit %0.2f ms; %s of 54 textures uploaded (host only)" % [full / 1000.0, small / 1000.0, changed])
	view.queue_free(); await process_frame
