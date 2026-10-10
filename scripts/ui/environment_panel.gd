class_name EnvironmentPanel
extends VBoxContainer
## Live environmental causes and interventions, shared by desktop and phone.
var game: Control
var world: WorldState
var selected_cell := Vector2i(70, 48)
var status: Label
var details: Label
var health: Label
var time_button: Button
var age_picker: OptionButton
var weather_buttons := {}
var preset_buttons := {}
var page_buttons := {}
var pages := {}
var clock := 0.0
func setup(controller: Control, cell: Vector2i) -> void:
	game = controller
	world = game.world
	selected_cell = cell if world.contains(cell.x, cell.y) else Vector2i(world.width / 2, world.height / 2)
	add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	add_child(top)
	status = game.hud.label("", 14, GameHUD.ACCENT)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(status)
	time_button = game.hud.button("Pause", "pause", func(): game._set_speed(0 if game.speed > 0 else 1); refresh())
	top.add_child(time_button)
	var tabs := HBoxContainer.new()
	add_child(tabs)
	for title in ["Climate", "Land", "Health"]:
		var b: Button = game.hud.button(title, "", func(): set_page(title))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		page_buttons[title] = b
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 12)
		add_child(page)
		pages[title] = page
	move_child(tabs, 1)
	var explanation: Label = game.hud.label("Guide the weather. Rain replenishes soil; drought stops growth. Snow melts into water. Cold and heat change appetite.", 13)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pages.Climate.add_child(explanation)
	var weather_grid := GridContainer.new()
	weather_grid.columns = 3
	pages.Climate.add_child(weather_grid)
	for kind in EnvironmentSimulation.WEATHER.size():
		var b: Button = game.hud.button(EnvironmentSimulation.WEATHER[kind], ["sun", "rain", "drought", "snow", "lightning"][kind], func(): EnvironmentSimulation.set_weather(world, kind); refresh())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weather_grid.add_child(b)
		weather_buttons[kind] = b
	var age_row := HBoxContainer.new()
	pages.Climate.add_child(age_row)
	age_row.add_child(game.hud.label("World age", 13))
	age_picker = OptionButton.new()
	age_picker.custom_minimum_size.y = 48
	age_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for title in EnvironmentSimulation.AGES: age_picker.add_item(title)
	age_picker.item_selected.connect(func(n: int):
		world.climate.age_clock = n * 1536
		world.add_event("The worldmaker calls the %s." % EnvironmentSimulation.AGES[n], "climate")
		refresh())
	age_row.add_child(age_picker)
	pages.Climate.add_child(game.hud.label("WORLD LAW PRESETS", 11, GameHUD.ACCENT))
	for title in ["Living planet", "Peaceful", "Catastrophe"]:
		var b: Button = game.hud.button(title, "laws", func(): EnvironmentSimulation.preset(world, title); refresh())
		pages.Climate.add_child(b)
		preset_buttons[title] = b
	var note: Label = game.hud.label("Peaceful turns off hunger, old age, illness, spreading fire, and natural disasters. Catastrophe enables those laws. Existing wars and god powers still have consequences. Fine-tune any law with the scales button.", 13, GameHUD.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pages.Climate.add_child(note)
	details = game.hud.label("", 13)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pages.Land.add_child(details)
	pages.Land.add_child(game.hud.button("Paint biomes", "biome", func(): game._close_dialog(); game.hud._select_category("Biomes")))
	var legend: Label = game.hud.label("TEMPERATE · balanced fields\nWOODLAND · renewing timber\nARID · sparse forage; no farms\nWETLAND · rich forage; rare Rustfever\nTUNDRA · cold, slow growth\nGLIMMERGROVE · quick timber, slower crops\n\nBiome painting preserves elevation and homes. Unfertile biomes remove farm plots. Plants need time to grow; painting creates no free timber.", 13)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pages.Land.add_child(legend)
	health = game.hud.label("", 13)
	health.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pages.Health.add_child(health)
	var illness_note: Label = game.hud.label("Rustfever spreads between nearby members of the same species on connected land. Illness lasts 64 ticks, interrupts natural recovery, and drains health. Survivors gain 192 ticks of immunity. Hunger makes illness more dangerous.\n\nThe Plague power seeds an outbreak; wetland exposure can rarely begin one naturally. Turn off Disease to pause transmission, damage, and all disease timers.\n\nInspect a creature or open Lives to see its condition and recovery memories.", 13)
	illness_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pages.Health.add_child(illness_note)
	set_page("Climate")
	refresh()
func set_page(title: String) -> void:
	for key in pages:
		pages[key].visible = key == title
		game.hud._highlight(page_buttons[key], key == title)
func refresh() -> void:
	time_button.text = "Resume" if game.speed == 0 else "Pause"
	time_button.icon = load("res://assets/icons/%s.svg" % ("play" if game.speed == 0 else "pause"))
	status.text = "%s · %s\n%s" % [EnvironmentSimulation.SEASONS[EnvironmentSimulation.season(world)], EnvironmentSimulation.WEATHER[EnvironmentSimulation.weather(world)], EnvironmentSimulation.AGES[EnvironmentSimulation.age(world)]]
	if not world.laws.weather: status.text += " · weather paused"
	for kind in weather_buttons:
		weather_buttons[kind].disabled = not world.laws.weather
		game.hud._highlight(weather_buttons[kind], kind == EnvironmentSimulation.weather(world))
	age_picker.disabled = not world.laws.ages
	age_picker.select(EnvironmentSimulation.age(world))
	var i := world.index(selected_cell.x, selected_cell.y)
	var interval := EnvironmentSimulation.growth_interval(world, i)
	details.text = "LAST INSPECTED TILE · %s, %s\n\n%s · %s\nTemperature %s°C · Moisture %s%%\nSnow cover %s / 8\nGrowth: %s\nForage %s · Wood %s · Stone %s\n\nInspect a tile on the map, then reopen Planet to follow its conditions." % [selected_cell.x, selected_cell.y, BiomeCatalog.NAMES[world.biomes[i]], ["Water", "Lowland", "Peak"][world.elevation[i]], EnvironmentSimulation.temperature(world, i), world.moisture[i], world.snow[i], "No plants on this terrain" if world.elevation[i] != 1 else ("Paused / stressed" if interval == 0 else ("Slow" if interval > 1 else "Growing")), int(world.food[i]), world.trees[i], world.stone[i]]
	var sick := 0
	var immune := 0
	for u in world.units:
		if u.sickness > 0: sick += 1
		elif u.immunity > 0: immune += 1
	health.text = "%s with Rustfever · %s immune\n%s\n\n%s active eruptions" % [sick, immune, "Transmission and recovery active" if world.laws.disease else "Disease is paused by world law", world.hazards.size()]
func _process(delta: float) -> void:
	clock += delta
	if clock >= 0.5: clock = 0; refresh()
