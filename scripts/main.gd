extends Control
## Composition root: input -> model, fixed-step simulation, presentation, persistence.
var world := WorldState.new()
var simulation: Simulation
var view: WorldView
var hud: GameHUD
var speed := 1
var accumulator := 0.0
var refresh_timer := 0.0
var autosave_timer := 0.0
var modal: Control
var modal_pauses := true
var village_panel: VillagePanel
var kingdom_panel: KingdomPanel
var life_panel: LifePanel
var environment_panel: EnvironmentPanel
var society_panel: SocietyPanel
var library_panel: SaveLibraryPanel
var settings_panel: SettingsPanel
var library := SaveLibrary.new()
var preferences := PlayerSettings.new()
var audio: GameAudio
var settings_path := "user://settings.json"
var active_slot := -1
var active_label := ""
var unfocused := false
var save_error := ""
var closing := false
var inspected_cell := Vector2i(70, 48)
var suspended := false
var inspected_id := -1
var manual_save_path := SaveStore.MANUAL_PATH
var autosave_path := SaveStore.AUTO_PATH

func _ready() -> void:
	if OS.has_feature("mobile"):
		get_window().content_scale_size = Vector2i(960, 540)
	get_tree().auto_accept_quit = false
	preferences.path = settings_path
	preferences.restore()
	world.generate(41827)
	simulation = Simulation.new(world)
	view = WorldView.new()
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.bind_world(world)
	hud = GameHUD.new()
	add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.tool_selected.connect(func(tool: String): view.tool = tool; if tool != "inspect": hud.sidebar_visible = false; hud._layout())
	hud.brush_changed.connect(func(radius: int): view.brush = radius)
	hud.speed_changed.connect(_set_speed)
	hud.action_requested.connect(_action)
	view.applied.connect(_apply)
	view.inspected.connect(_inspect)
	view.camera_changed.connect(func(value: float): hud.zoom_label.text = "%s%%" % roundi(value * 100))
	audio = GameAudio.new(); add_child(audio)
	hud.feedback_requested.connect(func(): audio.play_cue())
	_apply_preferences()
	hud.refresh(world)
	# A populated world makes the first launch immediately explorable.
	hud.toast("Welcome, worldmaker. Start small. See what grows.")

func _process(delta: float) -> void:
	if world == null or hud == null: return
	if (modal == null or not modal_pauses) and not suspended and not (unfocused and preferences.values.pause_unfocused):
		accumulator += minf(delta, 0.25) * speed
		var steps := 0
		while accumulator >= Simulation.STEP_SECONDS and steps < 8:
			simulation.step()
			accumulator -= Simulation.STEP_SECONDS
			steps += 1
		if steps == 8: accumulator = minf(accumulator, Simulation.STEP_SECONDS)
		refresh_timer += delta
		autosave_timer += delta
		if refresh_timer > 0.5:
			refresh_timer = 0.0
			hud.refresh(world)
			_refresh_inspector()
		if autosave_timer >= 60:
			autosave_timer = 0
			var error := SaveStore.save_world(world, autosave_path)
			if error != OK: hud.toast("Autosave failed. Free some device storage and try again.")

func _set_speed(value: int) -> void:
	speed = value
	hud.set_speed(value)
	if value == 0: accumulator = 0

func _apply(tool: String, cell: Vector2i) -> void:
	if modal != null: return
	audio.play_cue("paint")
	if tool.begins_with("terrain_"):
		world.paint(cell, view.brush, tool.trim_prefix("terrain_").to_int())
	elif tool.begins_with("biome_"):
		world.paint_biome(cell, view.brush, tool.trim_prefix("biome_").to_int())
	elif tool in ["settler", "rabbit", "deer"]:
		if not world.spawn(tool, cell):
			hud.toast("This world’s family history is full. Start a new world to welcome more life." if world.lineage.size() >= Heredity.MAX_RECORDS else "Life needs open land." if world.units.size() < WorldState.MAX_UNITS else "This small world is full (350 creatures).")
	else:
		world.power(cell, view.brush + (2 if tool == "meteor" else 0), tool)
	simulation.politics.refresh()
	simulation.military.reconcile()
	refresh_timer = 1

func _inspect(cell: Vector2i) -> void:
	if not world.contains(cell.x, cell.y): return
	inspected_cell = cell
	if view.show_politics and world.contains(cell.x, cell.y):
		var owner := world.territory[world.index(cell.x, cell.y)]
		if owner >= 0: _kingdom_dialog(owner); return
	inspected_id = -1
	view.selected_id = -1
	var best := 4.0
	for u in world.units:
		var distance := Vector2(u.x - cell.x, u.y - cell.y).length()
		if distance < best:
			best = distance
			inspected_id = u.id
	if inspected_id >= 0:
		view.selected_id = inspected_id
		_refresh_inspector()
		return
	for v in world.villages:
		if v.alive and Vector2(v.x - cell.x, v.y - cell.y).length() < 6:
			_village_dialog(v.id)
			return
	var i := world.index(cell.x, cell.y)
	hud.inspect_text(BiomeCatalog.NAMES[world.biomes[i]] + " · " + ["Water", "Lowland", "Peak"][world.elevation[i]], "TILE %s, %s\n%s°C · Moisture %s%%\nForage %s · Wood %s · Stone %s\n%s\nObserve → Planet explains growth." % [cell.x, cell.y, EnvironmentSimulation.temperature(world, i), world.moisture[i], int(world.food[i]), world.trees[i], world.stone[i], "Burning — rain can help." if world.fire[i] > 0 else ("Open to wandering life." if world.habitable(cell.x, cell.y) else "A natural barrier to land creatures.")])

func _refresh_inspector() -> void:
	if inspected_id < 0: return
	for u in world.units:
		if u.id == inspected_id:
			var home: String = world.villages[u.village].name if u.village >= 0 else "The open wilds"
			hud.inspect_text(u.name + " · " + u.species.capitalize(), "Age %s  ·  %s\nHealth %s  ·  Hunger %s%%\nCarrying: %s\n%s" % [u.age, u.state, int(u.health), int(u.hunger), ("%s %s" % [u.cargo, u.cargo_type]) if u.cargo > 0 else "nothing", home])
			hud.inspector_text.text += "\n" + EnvironmentSimulation.health_text(world, u)
			if u.army >= 0:
				var a: Dictionary = world.armies[u.army]
				hud.inspector_text.text += "\n\n%s · morale %s%%\n%s rations · %s" % [u.weapon.replace("_", " ").capitalize(), a.morale, a.food, a.outcome]
			if u.army < 0: hud.inspector_text.text += "\n%s · Generation %s\nOpen Observe → Lives for traits and family." % [Heredity.variant(u), Heredity.record(world, u.id).generation]
			return
	var record := Heredity.record(world, inspected_id)
	if not record.is_empty():
		hud.inspect_text(record.name + " · remembered", "Lived %s years.\nOpen Observe → Lives for family and memories." % record.last_age)
		view.selected_id = -1
		return
	hud.inspect_text("A life remembered", "This creature's story has ended.\n\nThe world keeps turning.")
	inspected_id = -1
	view.selected_id = -1

func _action(action: String) -> void:
	match action:
		"new": _new_world_dialog()
		"save":
			var error := library.save_slot(world, active_slot, active_label) if active_slot >= 0 else SaveStore.save_world(world, manual_save_path)
			if error == OK: audio.play_cue("save")
			hud.toast("World saved. A little history, kept safe." if error == OK else "Save failed. Check available device storage.")
		"load": _load_dialog()
		"settings": _settings_dialog()
		"laws": _laws_dialog()
		"history": _history_dialog()
		"villages": _village_dialog()
		"kingdoms": _kingdom_dialog()
		"lives": _life_dialog(inspected_id)
		"environment": _environment_dialog()
		"society": _society_dialog()
		"politics":
			simulation.politics.refresh()
			view.show_politics = not view.show_politics
			hud.set_political_view(view.show_politics)
			hud.toast("Political borders shown. Inspect a realm to meet its ruler." if view.show_politics else "Terrain view restored.")
		"help": _help_dialog()
		"zoom_in": view.zoom_at(1.25, view.map_area().get_center())
		"zoom_out": view.zoom_at(0.8, view.map_area().get_center())
		"fit": view.fit()

func _dialog(title: String, subtitle: String) -> VBoxContainer:
	_close_dialog()
	view.mouse_down = false
	modal = Control.new()
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.06, 0.08, 0.83)
	modal.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	panel.theme = hud.theme
	panel.add_theme_stylebox_override("panel", GameHUD.box(GameHUD.PANEL, Color("607467"), 16))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["top", "bottom", "left", "right"]: margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 15)
	margin.add_child(body)
	var title_row := HBoxContainer.new()
	body.add_child(title_row)
	var heading := hud.label(title, 24, GameHUD.ACCENT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(heading)
	var close := hud.button("", "close", _close_dialog)
	close.tooltip_text = "Close"
	title_row.add_child(close)
	var desc := hud.label(subtitle, 13, GameHUD.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(desc)
	close.grab_focus()
	return body

func _close_dialog() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null
	village_panel = null
	kingdom_panel = null
	life_panel = null
	environment_panel = null
	society_panel = null
	library_panel = null
	settings_panel = null
	modal_pauses = true
	accumulator = 0

func _new_world_dialog() -> void:
	var body := _dialog("A new beginning", "Make room for a different story. Your current world will be kept in the autosave slot.")
	var seed_input := LineEdit.new()
	seed_input.text = str(randi_range(1, 999999))
	seed_input.placeholder_text = "World seed (0–2147483647)"
	seed_input.custom_minimum_size.y = 48
	body.add_child(hud.label("WORLD SEED", 11, GameHUD.ACCENT))
	body.add_child(seed_input)
	var style := OptionButton.new()
	style.add_item("Continents · room to grow", 0)
	style.add_item("Archipelago · a world apart", 1)
	style.add_item("Frontier continent · three peoples", 2)
	style.custom_minimum_size.y = 48
	body.add_child(style)
	var life := CheckButton.new()
	life.text = "Begin with settlers and wildlife"
	life.button_pressed = true
	life.custom_minimum_size.y = 48
	body.add_child(life)
	var error_label := hud.label("", 12, Color("edbd96"))
	body.add_child(error_label)
	body.add_child(hud.button("Create world", "world", func():
		if not seed_input.text.is_valid_int() or seed_input.text.to_int() < 0 or seed_input.text.to_int() > 2147483647:
			error_label.text = "Use a whole-number seed from 0 to 2147483647."
			return
		if SaveStore.save_world(world, autosave_path) != OK:
			error_label.text = "Could not preserve this world. Check device storage."
			return
		active_slot = -1; active_label = ""
		world = WorldState.new()
		world.generate(seed_input.text.to_int(), style.selected, life.button_pressed)
		_bind_world()
		_close_dialog()
		hud.toast("A fresh horizon. Your story starts here.")
	))

func _load_dialog() -> void:
	var body := _dialog("Your world shelf", "Keep an island, return to a story, or recover its previous version.")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(530, size.y - 195))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	library_panel = SaveLibraryPanel.new()
	library_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(library_panel); library_panel.setup(self)

func _restore_world(result: Dictionary, slot: int = -1) -> void:
	if result.has("error"):
		hud.toast(result.error); return
	# Read the destination first: loading autosave may then rotate that same file.
	if SaveStore.save_world(world, autosave_path) != OK:
		hud.toast("Could not preserve this world. Free some storage before loading."); return
	world = result.world; active_slot = slot; active_label = result.get("label", "")
	_bind_world(); _close_dialog()
	hud.toast("Recovered a valid copy. Save again to keep it." if result.get("recovered", false) else "Welcome back to " + world.world_name + ".")

func _settings_dialog() -> void:
	var body := _dialog("Make yourself at home", "Sound, reading comfort, and how your world feels.")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(530, size.y - 195))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	settings_panel = SettingsPanel.new(); settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(settings_panel); settings_panel.setup(self)

func _apply_preferences() -> void:
	hud.apply_preferences(preferences.values)
	view.reduced_motion = preferences.values.reduced_motion
	Engine.max_fps = preferences.values.frame_limit
	audio.apply(preferences.values)
	audio.set_suspended(suspended or (unfocused and preferences.values.pause_unfocused))

func _bind_world() -> void:
	simulation = Simulation.new(world)
	view.bind_world(world)
	inspected_id = -1
	hud.inspector_title.text = "A closer look"
	hud.inspector_text.text = "Choose Inspect and touch the world."
	hud.refresh(world)
	accumulator = 0
	autosave_timer = 0

func _laws_dialog() -> void:
	var body := _dialog("The laws of this world", "A small change can have a long shadow. The world is paused while this panel is open.")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(360, size.y - 210))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for entry in [["hunger", "Hunger", "Creatures need forage to survive."], ["births", "New life", "Nearby, well-fed adults can reproduce."], ["old_age", "The passage of time", "Creatures eventually die of old age."], ["fire_spread", "Spreading fire", "Flames can travel into neighboring vegetation."], ["expansion", "New settlements", "Villages may send overland expeditions."], ["diplomacy", "Politics", "Relations and loyalty change over time."], ["weather", "Weather", "Rain, drought, snow, and soil moisture."], ["seasons", "Seasons", "Spring, summer, autumn, and winter."], ["ages", "World ages", "Long eras change heat and cold."], ["vegetation", "Plant growth", "Forage, trees, and crops can grow."], ["disease", "Disease", "Transmission, damage, recovery, immunity."], ["natural_disasters", "Natural disasters", "Spontaneous lightning, quakes, volcanoes."], ["society", "Society", "Knowledge, clan loyalty, and communal care."], ["cultural_exchange", "Cultural exchange", "Shared learning and gradual adoption."]]:
		var b := CheckButton.new()
		b.text = entry[1] + "  ·  " + entry[2]
		b.button_pressed = world.laws[entry[0]]
		b.custom_minimum_size.y = 48
		b.add_theme_font_size_override("font_size", 13)
		b.toggled.connect(func(value: bool): world.laws[entry[0]] = value)
		list.add_child(b)
	var borders := CheckButton.new()
	borders.text = "Show village influence rings"
	borders.button_pressed = view.show_villages
	borders.custom_minimum_size.y = 48
	borders.toggled.connect(func(value: bool): view.show_villages = value)
	list.add_child(borders)

func _help_dialog() -> void:
	var body := _dialog("A field guide for worldmakers", "There is no finish line. Make a world worth watching.")
	var guide := hud.label("01   SHAPE\nChoose a terrain and paint. S / M / L changes the brush.\n\n02   GIVE LIFE\nFour nearby adult settlers can found a village. They carry food, timber, and stone home, tend crops, and build houses.\n\n03   LET IT UNFOLD\nOpen Observe → Villages to follow stores, work, and population. Births need spare housing and food. Canals can cut workers off from supplies. Rain helps crops; fire and meteors destroy them.\n\n04   SHAPE A REALM\nObserve → Borders colors claimed land; Inspect it to meet the ruler. Kingdoms shows loyalty, expeditions, and diplomacy. Favor a realm, encourage peace, or sow discord. A Frontier continent starts three peoples.\n\n05   WAR & PEACE\nDeclare war in Kingdoms → Diplomacy. War shows recruitment, rations, morale, and watchtowers. Follow a company on the map, order a retreat, or make peace. Sea crossings need a paid transport boat.\n\n06   FOLLOW A LIFE\nObserve → Lives shows inherited traits, parents, children, and memories. Favorite a creature to find it again, even after death. Traits affect hunger, work, recovery, lifespan, and combat.\n\n07   A CHANGING PLANET\nBiomes paints ecosystems without changing coastlines. Observe → Planet explains climate, growth, and illness. Call rain or drought, change the world age, or choose a law preset. Powers adds lightning, earthquakes, volcanoes, and Rustfever.\n\n08   SOCIETY & MEMORY\nObserve → Society follows cultures, clans, languages, and hearth faiths. Harvests and houses build knowledge. Migration carries traditions; years together can change them. Filter the chronicle, follow rulers, and earn discovery emblems. Laws can pause social effects or cultural exchange.\n\nMOVE  Drag with Move selected; two fingers always pan and pinch. On desktop, right-drag and scroll work with any tool.\n\n09   KEEP YOUR WORLDS\nThe world shelf holds six named slots, quick save, and autosave. Saving keeps one previous version. Settings controls audio, larger reading text, contrast, motion, focus pause, and a 30/60 frame limit.\n\nKEYS  Space: pause   V: move   I: inspect   Ctrl+S: save\n\nYour worlds save locally. Open the world shelf to return to a saved world.", 14)
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(340, size.y - 200))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(guide)

func _village_dialog(village_id: int = -1) -> void:
	var body := _dialog("Village life", "Watch work become a home. Time follows the speed you selected.")
	modal_pauses = false
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(370, size.y - 195))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	village_panel = VillagePanel.new()
	village_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(village_panel)
	village_panel.setup(world, hud, self, village_id)

func _kingdom_dialog(kingdom_id: int = -1) -> void:
	simulation.politics.refresh()
	var body := _dialog("Crowns & frontiers", "Every border has a story. Follow a realm, or change its course.")
	modal_pauses = false
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(530, size.y - 195))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	kingdom_panel = KingdomPanel.new()
	kingdom_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(kingdom_panel)
	kingdom_panel.setup(self, kingdom_id)

func _life_dialog(id: int = -1) -> void:
	var body := _dialog("Lives & lineages", "Every life leaves a trace. Follow traits, family, and remembered moments.")
	modal_pauses = false
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(530, size.y - 195))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	life_panel = LifePanel.new()
	life_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(life_panel)
	life_panel.setup(self, id)

func _society_dialog(culture: int = -1) -> void:
	var body := _dialog("Society & memory", "Traditions travel with people. Watch a shared way of life take shape.")
	modal_pauses = false
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(530, size.y - 195))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	society_panel = SocietyPanel.new()
	society_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(society_panel)
	society_panel.setup(self, culture)

func _environment_dialog() -> void:
	var body := _dialog("A changing planet", "Follow the climate, tend the land, and watch life adapt.")
	modal_pauses = false
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(530, size.y - 195))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	environment_panel = EnvironmentPanel.new()
	environment_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(environment_panel)
	environment_panel.setup(self, inspected_cell)

func _history_dialog() -> void:
	var body := _dialog("The living world", "Year %s of %s · Seed %s" % [world.year(), world.world_name, world.world_seed])
	var count := 0
	for v in world.villages:
		if v.alive: count += 1
	body.add_child(hud.label("%s settlers    ·    %s wildlife    ·    %s villages" % [world.population("settler"), world.population() - world.population("settler"), count], 17, GameHUD.ACCENT))
	body.add_child(hud.button("Visit village dashboards", "village", _village_dialog))
	body.add_child(hud.button("Explore society & history", "society", _society_dialog))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(270, size.y - 290))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var entries := VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 18)
	scroll.add_child(entries)
	for e in world.events:
		var entry := hud.label("YEAR %s   /   %s" % [e.year, e.text], 14)
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entries.add_child(entry)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		if modal != null: _close_dialog()
		else: _help_dialog()
		get_viewport().set_input_as_handled()
		return
	if modal != null: return
	match event.keycode:
		KEY_SPACE: _set_speed(0 if speed > 0 else 1)
		KEY_V: hud.choose_tool("pan")
		KEY_I: hud.choose_tool("inspect")
		KEY_S:
			if event.ctrl_pressed or event.meta_pressed: _action("save")
			else: return
		_: return
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		unfocused = true
		if audio != null and preferences.values.pause_unfocused: audio.set_suspended(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		unfocused = false; accumulator = 0
		if audio != null: audio.set_suspended(suspended)
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		suspended = true
		if audio != null: audio.set_suspended(true)
		if world != null and not world.terrain.is_empty() and SaveStore.save_world(world, autosave_path) != OK:
			save_error = "Could not save before suspension. Free storage, then save your world."
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		suspended = false; accumulator = 0
		if audio != null: audio.set_suspended(unfocused and preferences.values.pause_unfocused)
		if not save_error.is_empty() and hud != null: hud.toast(save_error); save_error = ""
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if SaveStore.save_world(world, autosave_path) == OK: _quit_after_audio()
		else:
			var body := _dialog("Your world could not be saved", "Free some storage and try again, or exit without keeping the latest changes.")
			body.add_child(hud.button("Try saving again", "save", func(): _notification(NOTIFICATION_WM_CLOSE_REQUEST)))
			body.add_child(hud.button("Exit without saving", "close", func(): _quit_after_audio()))
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if modal != null: _close_dialog()
		else: _help_dialog()

func _quit_after_audio() -> void:
	if closing: return
	closing = true; suspended = true
	audio.shutdown()
	# Give the audio mixing thread time to drain playback commands before teardown.
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()
