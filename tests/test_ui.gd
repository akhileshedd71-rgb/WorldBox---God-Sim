extends SceneTree
## Exercises the actual scene, control signals, input gestures, and responsive layout.
var checks := 0
var failures := 0
var game: Control

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if value: print("PASS: ", description)
	else: failures += 1; printerr("FAIL: ", description)

func touch(index_value: int, p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index_value
	e.position = p
	e.pressed = pressed
	game.view._gui_input(e)

func tap_control(control: Control, scroll: ScrollContainer = null) -> void:
	if scroll != null:
		scroll.ensure_control_visible(control)
		await process_frame
		await process_frame
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = root.get_screen_transform() * control.get_global_rect().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	game = load("res://scenes/main.tscn").instantiate()
	game.manual_save_path = "user://ui-test-world.json"
	game.autosave_path = "user://ui-test-autosave.json"
	root.add_child(game)
	await process_frame
	await process_frame
	game._set_speed(0)
	Input.use_accumulated_input = false
	check(game.world.units.size() == 34 and game.view.terrain_cache.textures.size() == 54, "main scene starts with a rendered, populated world")
	var button_center: Vector2 = game.hud.tool_buttons.terrain_3.get_global_rect().get_center()
	var physical_touch := InputEventScreenTouch.new()
	physical_touch.index = 0
	physical_touch.position = root.get_screen_transform() * button_center
	physical_touch.pressed = true
	Input.parse_input_event(physical_touch)
	await process_frame
	physical_touch = physical_touch.duplicate()
	physical_touch.pressed = false
	Input.parse_input_event(physical_touch)
	await process_frame
	check(game.view.tool == "terrain_3", "engine touch-to-mouse path activates actual HUD buttons")
	var current: int = game.world.tick
	game._process(1.0)
	check(game.world.tick == current, "pause freezes simulation time")
	game.hud.speed_buttons[5].pressed.emit()
	game._process(0.25)
	check(game.world.tick == current + 5, "5x control advances five fixed simulation steps")
	game._set_speed(0)
	game.hud.tool_buttons.terrain_3.pressed.emit()
	check(game.view.tool == "terrain_3", "terrain palette selection reaches the world view")
	game.hud.brush_buttons[2].pressed.emit()
	check(game.view.brush == 4, "large brush control changes painting radius")
	var cell := Vector2i(72, 48)
	var p: Vector2 = game.view.origin() + (Vector2(cell) * 16 + Vector2(8, 8)) * game.view.scale_factor()
	touch(0, p, true)
	touch(0, p, false)
	check(game.world.terrain[game.world.index(cell.x, cell.y)] == WorldState.Terrain.FOREST, "a single-finger tap paints the selected terrain")
	game.hud.choose_tool("terrain_0")
	var old: PackedByteArray = game.world.terrain.duplicate()
	touch(0, p, true)
	touch(1, p + Vector2(80, 0), true)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = p + Vector2(140, 0)
	drag.relative = Vector2(60, 0)
	game.view._gui_input(drag)
	touch(1, drag.position, false)
	touch(0, p, false)
	check(game.world.terrain == old, "two-finger pinch never paints terrain")
	check(game.view.zoom_level > 1, "two-finger pinch changes the camera zoom")
	game._action("fit")
	check(is_equal_approx(game.view.zoom_level, 1.0), "fit button restores the camera")
	game.hud.choose_tool("pan")
	var old_center: Vector2 = game.view.camera_center
	touch(0, p, true)
	drag.index = 0
	drag.position = p + Vector2(35, 0)
	drag.relative = Vector2(35, 0)
	game.view._gui_input(drag)
	touch(0, drag.position, false)
	check(game.view.camera_center != old_center, "one-finger Move gesture pans the camera")
	game.hud._select_category("Life")
	game.hud.tool_buttons.settler.pressed.emit()
	var land: Vector2i = game.world.find_land(Vector2i(50, 50), true)
	var before_count: int = game.world.units.size()
	game._apply(game.view.tool, land)
	check(game.world.units.size() == before_count + 1, "life palette spawns a settler on land")
	# Inject raw device touch through Input, including its generated mouse events.
	land = Vector2i(72, 48)
	game.world.paint(land, 2, WorldState.Terrain.MEADOW)
	game.view.fit()
	var touch_point: Vector2 = game.view.origin() + (Vector2(land) * 16 + Vector2(8, 8)) * game.view.scale_factor()
	physical_touch = InputEventScreenTouch.new()
	physical_touch.index = 0
	physical_touch.position = root.get_screen_transform() * touch_point
	physical_touch.pressed = true
	before_count = game.world.units.size()
	Input.parse_input_event(physical_touch)
	await process_frame
	physical_touch = physical_touch.duplicate()
	physical_touch.pressed = false
	Input.parse_input_event(physical_touch)
	await process_frame
	check(game.world.units.size() == before_count + 1, "engine touch pipeline spawns once without duplicate emulated mouse painting")
	game.hud.choose_tool("inspect")
	game._inspect(land)
	check(game.inspected_id >= 0 and game.hud.inspector_title.text.contains("Settler"), "inspection opens a living creature's details")
	game._action("laws")
	game._set_speed(1)
	current = game.world.tick
	game._process(1.0)
	check(game.modal != null and game.world.tick == current, "world-law dialog pauses the simulation")
	var switches: Array[Node] = game.modal.find_children("*", "CheckButton", true, false)
	switches[0].button_pressed = false
	check(not game.world.laws.hunger, "world-law switch updates the simulation rules")
	game._close_dialog()
	game._set_speed(0)
	await process_frame
	game._action("save")
	check(SaveStore.load_world(game.manual_save_path).has("world"), "Save action writes a loadable world")
	game._action("load")
	check(game.modal != null, "Load opens an explicit replacement dialog")
	game._close_dialog()
	await process_frame
	game._action("new")
	var input: LineEdit = game.modal.find_children("*", "LineEdit", true, false)[0]
	var create_button: Button
	for b in game.modal.find_children("*", "Button", true, false):
		if b.text == "Create world": create_button = b
	input.text = "invalid-seed"
	var old_seed: int = game.world.world_seed
	create_button.pressed.emit()
	check(game.modal != null and game.world.world_seed == old_seed, "invalid new-world seeds preserve the current world")
	input.text = "12345"
	game.modal.find_children("*", "CheckButton", true, false)[0].button_pressed = false
	create_button.pressed.emit()
	check(game.modal == null and game.world.world_seed == 12345 and game.world.units.is_empty(), "new-world dialog creates the requested empty seeded world")
	var preserved := SaveStore.load_world(game.autosave_path)
	check(preserved.has("world") and preserved.world.world_seed == old_seed, "new-world creation first preserves the prior world in autosave")
	await process_frame
	game._action("load")
	for b in game.modal.find_children("*", "Button", true, false):
		if b.text == "Saved world": b.pressed.emit(); break
	check(game.modal == null and game.world.world_seed == old_seed, "manual load restores the saved world through the UI")
	await process_frame
	var rightmost: Control = game.hud.top_actions.get_child(game.hud.top_actions.get_child_count() - 1)
	check(rightmost.get_global_rect().end.x <= game.size.x, "desktop header actions stay within the viewport")
	root.content_scale_size = Vector2i(960, 540)
	root.size = Vector2i(960, 540)
	await process_frame
	await process_frame
	game.hud._layout()
	await process_frame
	check(game.hud.compact and not game.hud.stats_panel.visible, "phone layout hides the persistent sidebar")
	check(game.hud.dock.get_rect().end.x <= game.size.x and game.hud.dock.get_rect().end.y <= game.size.y, "phone tool dock stays in the viewport")
	check(rightmost.get_global_rect().end.x <= game.size.x, "phone header actions stay within the viewport")
	check(game.hud.tool_row.get_rect().size.x <= game.hud.dock.size.x, "phone tool palette does not overflow its dock")
	game._action("history")
	check(game.modal != null and game.hud.mobile_stats.visible, "phone layout exposes population and the world chronicle")
	game._close_dialog()
	await process_frame
	for n in 120: game.simulation.step()
	game.hud._select_category("Observe")
	await process_frame
	button_center = game.hud.tool_buttons.villages.get_global_rect().get_center()
	physical_touch = InputEventScreenTouch.new()
	physical_touch.index = 0
	physical_touch.position = root.get_screen_transform() * button_center
	physical_touch.pressed = true
	Input.parse_input_event(physical_touch)
	await process_frame
	physical_touch = physical_touch.duplicate()
	physical_touch.pressed = false
	Input.parse_input_event(physical_touch)
	await process_frame
	check(game.modal != null and game.village_panel != null, "touching Observe / Villages opens the settlement dashboard")
	if game.village_panel != null:
		var dashboard: VillagePanel = game.village_panel
		check(dashboard.stores.text.contains("FOOD") and dashboard.stores.text.contains("STONE") and dashboard.work.text.contains("AT WORK"), "village dashboard displays real stores and current job counts")
		check(not dashboard.chart.history.is_empty(), "village dashboard receives the settlement population history")
		var dashboard_panel: Control = game.modal.find_children("*", "PanelContainer", true, false)[0]
		check(dashboard_panel.size.x <= game.size.x and dashboard_panel.size.y <= game.size.y, "village dashboard fits a 960 by 540 landscape phone")
		current = game.world.tick
		dashboard.time_button.pressed.emit()
		game._process(0.25)
		check(game.world.tick == current + 1, "dashboard Resume lets the village simulation run while observing it")
		dashboard.time_button.pressed.emit()
		current = game.world.tick
		game._process(0.25)
		check(game.world.tick == current and game.speed == 0, "dashboard Pause freezes time without closing the panel")
		var v: Dictionary = game.world.villages[dashboard.selected]
		v.food = 17
		dashboard.refresh()
		check(dashboard.stores.text.contains("FOOD  17"), "dashboard refresh follows changed pantry values")
	game._close_dialog()
	await process_frame
	game.world = WorldState.new()
	game.world.generate(41827, 2)
	game._bind_world()
	for n in 72: game.simulation.step()
	game.hud._select_category("Observe")
	game.hud.tool_buttons.politics.pressed.emit()
	await process_frame
	await process_frame
	check(game.view.show_politics and game.view.political_texture != null, "Borders control renders the actual kingdom ownership overlay")
	button_center = game.hud.tool_buttons.kingdoms.get_global_rect().get_center()
	physical_touch = InputEventScreenTouch.new()
	physical_touch.index = 0
	physical_touch.position = root.get_screen_transform() * button_center
	physical_touch.pressed = true
	Input.parse_input_event(physical_touch)
	await process_frame
	physical_touch = physical_touch.duplicate()
	physical_touch.pressed = false
	Input.parse_input_event(physical_touch)
	await process_frame
	check(game.kingdom_panel != null, "native phone touch opens Observe / Kingdoms")
	if game.kingdom_panel != null:
		var politics_panel: KingdomPanel = game.kingdom_panel
		check(politics_panel.picker.item_count == 3 and politics_panel.summary.text.contains("Ruler:"), "kingdom dashboard lists three realms and their actual ruler")
		var political_panel: Control = game.modal.find_children("*", "PanelContainer", true, false)[0]
		check(political_panel.size.x <= game.size.x and political_panel.size.y <= game.size.y, "kingdom inspector fits the landscape phone viewport")
		politics_panel.page_buttons.Diplomacy.pressed.emit()
		check(politics_panel.peace_button.is_visible_in_tree() and not politics_panel.towns_label.visible, "Diplomacy tab exposes political powers without scrolling past settlements")
		politics_panel.peace_button.pressed.emit()
		politics_panel.peace_button.pressed.emit()
		check(politics_panel.relations_label.text.contains("Alliance"), "peace intervention updates both diplomatic state and the visible explanation")
		for n in 4: politics_panel.discord_button.pressed.emit()
		check(politics_panel.relations_label.text.contains("Rivalry"), "discord intervention exposes the changed diplomatic relationship")
		var capital_id: int = game.world.kingdoms[politics_panel.selected].capital
		game.world.villages[capital_id].loyalty = 40
		politics_panel.favor_button.pressed.emit()
		check(game.world.villages[capital_id].loyalty == 52 and politics_panel.towns_label.text.contains("52%"), "favor changes village loyalty and refreshes the dashboard")
		politics_panel.picker.select(1)
		politics_panel.picker.item_selected.emit(1)
		check(politics_panel.selected == 1 and politics_panel.partner_id != 1 and politics_panel.summary.text.contains("Ruler:"), "realm selection updates the inspected polity and excludes self-diplomacy")
		var political_scroll: ScrollContainer = game.modal.find_children("*", "ScrollContainer", true, false)[0]
		for n in 8: game.simulation.politics.record(game.world.kingdoms[politics_panel.selected], "Border report %s: the settlements exchanged news about their supplies and changing frontier conditions." % n, "diplomacy")
		politics_panel.refresh()
		politics_panel.page_buttons.Chronicle.pressed.emit()
		await process_frame
		political_scroll.scroll_vertical = 200
		await process_frame
		check(political_scroll.scroll_vertical > 0, "phone Chronicle tab scrolls through a long realm history")
		politics_panel.overlay_button.button_pressed = false
		check(not game.view.show_politics, "dashboard border switch restores terrain view")
		current = game.world.tick
		politics_panel.time_button.pressed.emit()
		game._process(0.25)
		check(game.world.tick == current + 1, "political dashboard can resume the live simulation")
		politics_panel.time_button.pressed.emit()
		politics_panel.set_page("Diplomacy")
		political_scroll.scroll_vertical = 0
		await process_frame
		await tap_control(politics_panel.war_button, political_scroll)
		check(game.simulation.military.at_war(politics_panel.selected, politics_panel.partner_id) and politics_panel.peace_button.text == "Make peace", "native phone touch declares war with the named realm and exposes the peace action")
		politics_panel.set_page("War")
		political_scroll.scroll_vertical = 0
		await process_frame
		var war_panel: MilitaryPanel = politics_panel.military_panel
		var military_home: Dictionary = game.world.villages[war_panel.village_id]
		military_home.wood = 80
		military_home.stone = 80
		military_home.food = 80
		for u in game.simulation.politics.members(military_home.id):
			u.x = military_home.x
			u.y = military_home.y
			u.hunger = 0
			u.cargo = 0
			u.cargo_type = ""
			game.simulation.economy.reset_job(u)
		war_panel.refresh()
		var population_before: int = game.world.units.size()
		await tap_control(war_panel.recruit_button, political_scroll)
		var company: Dictionary = game.simulation.military.army_for(military_home.id)
		check(not company.is_empty() and game.world.units.size() == population_before, "phone Mobilize recruits existing villagers through the real simulation")
		check(war_panel.report.text.contains("morale") and war_panel.report.text.contains("rations") and war_panel.report.text.contains("Target:"), "War page exposes troop strength, morale, supply, and the target settlement")
		await tap_control(war_panel.tower_button, political_scroll)
		check(military_home.fort_progress == 1 and war_panel.report.text.contains("Building watchtower"), "phone tower action charges stores and starts construction")
		await tap_control(war_panel.guard_button, political_scroll)
		check(not company.is_empty() and company.order == "defend" and war_panel.guard_button.text == "Advance", "Defend home changes the actual company order")
		await tap_control(war_panel.guard_button, political_scroll)
		check(not company.is_empty() and company.order == "attack", "Advance returns a defending company to its enemy target")
		check(political_panel.size.x <= game.size.x and political_panel.size.y <= game.size.y and war_panel.recruit_button.size.y >= 48, "War controls remain scrollable and thumb-sized in the phone viewport")
		await tap_control(war_panel.focus_button, political_scroll)
		check(game.modal == null and game.view.selected_id > 0 and game.view.zoom_level == 5 and game.hud.inspector_text.text.contains("morale"), "Follow company focuses a real soldier and opens its equipment inspection")
		game._kingdom_dialog(military_home.kingdom)
		game.kingdom_panel.set_page("Diplomacy")
		game.kingdom_panel.peace_button.pressed.emit()
		check(not game.simulation.military.at_war(0, 1) and company.order == "return", "Make peace ends the war and recalls the followed company")
	game._close_dialog()
	await process_frame
	game._action("politics")
	var seat: Dictionary = game.world.villages[game.world.kingdoms[0].capital]
	game._inspect(Vector2i(seat.x, seat.y))
	check(game.kingdom_panel != null and game.kingdom_panel.selected == 0, "inspecting claimed land opens its owning kingdom")
	game._close_dialog()
	await process_frame
	game._action("laws")
	await process_frame
	var laws_panel: Control = game.modal.find_children("*", "PanelContainer", true, false)[0]
	check(laws_panel.size.x <= game.size.x and laws_panel.size.y <= game.size.y, "expanded world laws remain within the phone viewport")
	game._close_dialog()
	await process_frame
	var pause_key := InputEventKey.new()
	pause_key.keycode = KEY_SPACE
	pause_key.pressed = true
	game.hud.speed_buttons[1].grab_focus()
	root.push_input(pause_key)
	check(game.speed == 1, "Space resumes time even when a toolbar button has keyboard focus")
	game._action("help")
	await process_frame
	var panel: Control = game.modal.find_children("*", "PanelContainer", true, false)[0]
	check(panel.size.y <= game.size.y and panel.size.x <= game.size.x, "field guide fits the phone viewport")
	game._close_dialog()
	await process_frame
	DirAccess.remove_absolute(game.manual_save_path)
	if FileAccess.file_exists(game.autosave_path): DirAccess.remove_absolute(game.autosave_path)
	game.audio.shutdown()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("\nUI RESULT: %s checks, %s passed, %s failed" % [checks, checks - failures, failures])
	quit(0 if failures == 0 else 1)
