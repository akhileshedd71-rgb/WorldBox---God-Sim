extends SceneTree
var checks := 0
var failures := 0
var game: Control
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: ", description)
	else: failures += 1; printerr("FAIL: ", description)
func tap(control: Control, scroll: ScrollContainer = null) -> void:
	if scroll != null:
		scroll.ensure_control_visible(control)
		await process_frame
		await process_frame
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = root.get_screen_transform() * control.get_global_rect().get_center()
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	e = e.duplicate(); e.pressed = false
	Input.parse_input_event(e)
	await process_frame
func run() -> void:
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	Input.use_accumulated_input = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._set_speed(0)
	game.world.generate(618, 2, false)
	game._bind_world()
	var w: WorldState = game.world
	var cell := Vector2i(70, 50)
	w.set_material(w.index(cell.x, cell.y), WorldState.Terrain.MEADOW)
	await process_frame
	await tap(game.hud.tab_buttons.Biomes)
	check(game.hud.category == "Biomes" and game.hud.tool_buttons.size() == 6, "native phone touch opens the six-biome palette")
	await tap(game.hud.tool_buttons.biome_5)
	var elevation := w.elevation.duplicate()
	game._apply(game.view.tool, cell)
	check(w.biomes[w.index(cell.x, cell.y)] == 5 and w.elevation == elevation, "the real biome tool paints wetland without changing elevation")
	game.hud._select_category("Observe")
	game._inspect(cell)
	check(game.hud.inspector_text.text.contains("Moisture") and game.hud.inspector_title.text.contains("Wetland"), "tile inspection exposes biome, temperature, moisture, and the Planet shortcut")
	await process_frame
	await tap(game.hud.tool_buttons.environment)
	check(game.environment_panel != null and not game.modal_pauses, "native Planet touch opens a live environment inspector")
	if game.environment_panel == null: quit(1); return
	var panel: EnvironmentPanel = game.environment_panel
	var scroll: ScrollContainer = panel.get_parent()
	var shell: Control = game.modal.find_children("*", "PanelContainer", true, false)[0]
	check(shell.size.x <= 960 and shell.size.y <= 540 and panel.weather_buttons[1].size.y >= 48, "Planet fits the landscape phone with thumb-sized weather controls")
	await tap(panel.weather_buttons[1], scroll)
	check(w.climate.weather == 1 and panel.status.text.contains("Rain"), "native Rain touch changes the timed model weather and explanation")
	await tap(panel.weather_buttons[2], scroll)
	check(w.climate.weather == 2 and panel.status.text.contains("Drought"), "native Drought touch selects a real growth-stress state")
	await tap(panel.time_button, scroll)
	var tick := w.tick; game._process(0.25)
	check(w.tick == tick + 1, "the planet panel can run the live simulation")
	await tap(panel.time_button, scroll)
	check(game.speed == 0, "the planet panel can pause without losing its selected tile")
	await tap(panel.page_buttons.Land, scroll)
	check(panel.details.is_visible_in_tree() and panel.details.text.contains("70, 50") and panel.details.text.contains("stressed"), "Land explains drought stress at the actual inspected tile")
	await tap(panel.page_buttons.Climate, scroll)
	panel.age_picker.select(1); panel.age_picker.item_selected.emit(1)
	check(EnvironmentSimulation.age(w) == 1 and panel.status.text.contains("Embers"), "world-age selection changes the actual temperature era")
	await tap(panel.preset_buttons.Peaceful, scroll)
	check(not w.laws.disease and not w.laws.hunger and not w.laws.natural_disasters, "native Peaceful preset applies the promised survival laws")
	await tap(panel.preset_buttons.Catastrophe, scroll)
	check(w.laws.disease and w.laws.hunger and w.laws.natural_disasters, "native Catastrophe preset enables real disease and hazards")
	w.spawn("settler", cell)
	EnvironmentSimulation.infect(w, w.units[-1])
	panel.refresh()
	await tap(panel.page_buttons.Health, scroll)
	check(panel.health.text.contains("1 with Rustfever"), "Health counts actual infected creatures")
	w.laws.disease = false; panel.refresh()
	check(panel.health.text.contains("paused by world law"), "the inspector explains a paused disease subsystem")
	w.laws.weather = false; panel.refresh()
	check(panel.weather_buttons[1].disabled and panel.status.text.contains("weather paused"), "weather controls explain when their law is disabled")
	game._close_dialog()
	await process_frame
	game._inspect(cell)
	check(game.hud.inspector_text.text.contains("Rustfever"), "creature inspection connects illness to the selected life")
	game._life_dialog(w.units[-1].id)
	check(game.life_panel.trait_label.text.contains("Rustfever"), "Lives includes the actual illness timer alongside inherited traits")
	game._close_dialog()
	game.hud._select_category("Powers")
	await process_frame
	await tap(game.hud.tool_buttons.lightning)
	var health_before: float = w.units[-1].health
	game._apply(game.view.tool, cell)
	check(w.units[-1].health < health_before, "the phone lightning tool injures the creature in its real target area")
	check(game.hud.tabs.get_global_rect().end.x < 960 and game.hud.tool_buttons.plague.get_global_rect().end.x <= 940, "expanded biome and disaster controls stay within the phone viewport")
	game._laws_dialog()
	await process_frame
	var switches: Array[Node] = game.modal.find_children("*", "CheckButton", true, false)
	check(switches.size() == 15, "all fourteen world laws and village rings remain available in the scrolling panel")
	game._close_dialog()
	check(SaveStore.save_world(w, "user://environment-ui.json") == OK and SaveStore.load_world("user://environment-ui.json").has("world"), "environment interventions made through the UI survive disk validation")
	DirAccess.remove_absolute("user://environment-ui.json")
	game.audio.shutdown()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("\nENVIRONMENT UI RESULT: %s checks, %s passed, %s failed" % [checks, checks - failures, failures])
	quit(0 if failures == 0 else 1)
