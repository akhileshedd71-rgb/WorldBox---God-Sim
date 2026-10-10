extends SceneTree
var checks := 0
var failures := 0
var game: Control
const DIRECTORY := "user://beta-ui"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: ", description)
	else: failures += 1; printerr("FAIL: ", description)
func tap(control: Control, scroll: ScrollContainer = null) -> void:
	if scroll != null:
		await process_frame; scroll.ensure_control_visible(control); await process_frame; await process_frame
	var e := InputEventScreenTouch.new()
	e.index = 0; e.position = root.get_screen_transform() * control.get_global_rect().get_center(); e.pressed = true
	Input.parse_input_event(e); await process_frame
	e = e.duplicate(); e.pressed = false; Input.parse_input_event(e); await process_frame
func cleanup() -> void:
	if DirAccess.dir_exists_absolute(DIRECTORY.path_join("worlds")):
		for file in DirAccess.get_files_at(DIRECTORY.path_join("worlds")): DirAccess.remove_absolute(DIRECTORY.path_join("worlds").path_join(file))
		DirAccess.remove_absolute(DIRECTORY.path_join("worlds"))
	for file in DirAccess.get_files_at(DIRECTORY): DirAccess.remove_absolute(DIRECTORY.path_join(file))
	DirAccess.remove_absolute(DIRECTORY)
func run() -> void:
	if DirAccess.dir_exists_absolute(DIRECTORY): cleanup()
	root.size = Vector2i(960, 540); root.content_scale_size = Vector2i(960, 540)
	Input.use_accumulated_input = false
	game = load("res://scenes/main.tscn").instantiate()
	game.settings_path = DIRECTORY.path_join("settings.json")
	game.manual_save_path = DIRECTORY.path_join("quick.json")
	game.autosave_path = DIRECTORY.path_join("auto.json")
	game.library.directory = DIRECTORY.path_join("worlds")
	root.add_child(game); await process_frame; game._set_speed(0)
	await process_frame; await process_frame
	check(game.audio.ambience.stream is AudioStreamWAV and game.audio.ambience.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the real main scene starts the original looping ambience")
	var settings_button: Button
	for button in game.hud.top_actions.get_children():
		if button.tooltip_text.begins_with("Audio,"): settings_button = button
	check(settings_button != null and game.hud.top_actions.get_global_rect().end.x <= 960, "the seven-action phone header includes Settings without overflow")
	await tap(settings_button)
	check(game.settings_panel != null and game.modal_pauses, "native Settings touch opens a paused preferences panel")
	if game.settings_panel == null: quit(1); return
	var settings: SettingsPanel = game.settings_panel
	var scroll: ScrollContainer = settings.get_parent()
	var shell: Control = game.modal.find_children("*", "PanelContainer", true, false)[0]
	check(shell.size.x <= 960 and shell.size.y <= 540 and settings.apply_button.custom_minimum_size.y >= 48, "settings scroll within the phone viewport with thumb-sized actions")
	settings.sliders.master.value = 0
	await tap(settings.toggles.large_text, scroll)
	await tap(settings.toggles.high_contrast, scroll)
	await tap(settings.toggles.reduced_motion, scroll)
	settings.limit.select(1)
	await tap(settings.apply_button, scroll)
	check(game.modal == null and game.preferences.values.master == 0 and game.preferences.values.large_text and game.preferences.values.reduced_motion, "Apply saves actual volume, text, and motion choices")
	check(game.hud.text_scale == 1.15 and game.hud.high_contrast and game.view.reduced_motion, "saved reading and motion settings reach the real HUD and world canvas")
	check(Engine.max_fps == 30 and game.audio.ambience.stream_paused, "frame limit and mute affect the active engine and audio player")
	var copy := PlayerSettings.new(); copy.path = game.settings_path; copy.restore()
	check(copy.values.master == 0 and copy.values.large_text and copy.values.frame_limit == 30, "preferences survive a new settings instance")
	var played: int = game.audio.played; game.audio.play_cue("paint")
	check(game.audio.played == played, "muted interaction cues never start playback")
	var tick: int = game.world.tick
	game._set_speed(1); game._process(0.25)
	check(game.world.tick == tick + 1, "30 FPS mode retains the same fixed simulation step")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	tick = game.world.tick; game._process(0.25)
	check(game.world.tick == tick and game.audio.suspended, "focus loss freezes simulation and suspends audio when enabled")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN); game._process(0.25)
	check(game.world.tick == tick + 1 and not game.audio.suspended, "focus return resumes the chosen speed without a catch-up burst")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	tick = game.world.tick; game._process(1)
	check(game.suspended and game.world.tick == tick and SaveStore.load_world(game.autosave_path).has("world"), "suspension preserves a valid world and stops time")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED); game._set_speed(0)
	game._action("load"); await process_frame
	check(game.library_panel != null and game.library_panel.picker.item_count == 6, "world shelf presents six named slots alongside quick save and autosave")
	var panel: SaveLibraryPanel = game.library_panel; scroll = panel.get_parent()
	shell = game.modal.find_children("*", "PanelContainer", true, false)[0]
	check(shell.size.x <= 960 and shell.size.y <= 540 and panel.load_button.disabled, "larger-text shelf fits the phone and disables empty loads")
	panel.name_input.text = " "
	await tap(panel.save_button, scroll)
	check(panel.message.text.contains("name first") and not game.library.inspect_slot(0).occupied, "empty slot labels show feedback without writing a file")
	panel.name_input.text = "My first island"
	var seed: int = game.world.world_seed
	await tap(panel.save_button, scroll)
	check(game.active_slot == 0 and game.library.read_slot(0).label == "My first island" and panel.message.text.contains("Saved"), "native Save writes the named world and selects it for quick save")
	game.world.world_name = "After the rain"; game._action("save")
	check(game.library.read_slot(0).world.world_name == "After the rain" and game.library.read_slot(0, true).world.world_name != "After the rain", "quick save updates the active named slot and retains its previous version")
	panel.refresh()
	check(not panel.backup_button.disabled and not panel.load_button.disabled, "existing named worlds expose current and previous-version load actions")
	game.world.world_name = "Unsaved experiment"
	await tap(panel.backup_button, scroll)
	check(game.modal == null and game.world.world_seed == seed and game.world.world_name != "After the rain", "native recovery action loads the earlier world")
	check(SaveStore.load_world(game.autosave_path).world.world_name == "Unsaved experiment", "loading preserves the world being replaced in autosave first")
	game._action("load"); await process_frame
	panel = game.library_panel; scroll = panel.get_parent()
	var before := JSON.stringify(SaveStore.encode(game.world), "", true, true)
	game._restore_world({"error": "Damaged slot"}, 3)
	check(JSON.stringify(SaveStore.encode(game.world), "", true, true) == before and game.active_slot == 0, "failed loads leave active world and quick-save destination intact")
	await tap(panel.load_button, scroll)
	check(game.modal == null and game.world.world_name == "After the rain", "native Load restores the current named version")
	game._action("new"); await process_frame
	game.modal.find_children("*", "LineEdit", true, false)[0].text = "1831"
	for b in game.modal.find_children("*", "Button", true, false):
		if b.text == "Create world": b.pressed.emit(); break
	check(game.active_slot == -1 and game.world.world_seed == 1831, "a newly generated world cannot accidentally overwrite the previous named slot through quick save")
	game._action("save")
	check(SaveStore.load_world(game.manual_save_path).world.world_seed == 1831 and game.library.read_slot(0).world.world_seed == seed, "new-world quick save and the named shelf remain independent")
	var world_rng: int = game.world.rng.state
	var environment_rng: int = game.world.climate_rng.state
	game.preferences.values.master = 0.5; game._apply_preferences(); game.audio.next_cue = 0; game.audio.play_cue("save")
	check(game.audio.cue.playing and game.world.rng.state == world_rng and game.world.climate_rng.state == environment_rng, "audible local feedback does not consume either simulation random stream")
	game.view.fx.clear(); game.view.tool = "rain"; game.view.last_paint = Vector2i(-999, -999)
	game.view._apply(game.view.origin() + Vector2(30.5, 30.5) * WorldView.TILE * game.view.scale_factor())
	check(game.view.fx.is_empty(), "reduced-motion painting omits animated tool rings")
	game.audio.shutdown()
	await create_timer(0.15).timeout
	game.queue_free(); await process_frame
	await create_timer(0.15).timeout
	cleanup()
	Engine.max_fps = 60
	print("\nBETA UI RESULT: %s checks, %s passed, %s failed" % [checks, checks - failures, failures])
	quit(0 if failures == 0 else 1)
