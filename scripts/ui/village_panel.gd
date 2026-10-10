class_name VillagePanel
extends VBoxContainer
## Live settlement dashboard shared by desktop and landscape phone.
var world: WorldState
var selected := -1
var picker: OptionButton
var overview: Label
var stores: Label
var work: Label
var growth: Label
var construction: Label
var realm_button: Button
var chart: PopulationChart
var refresh_clock := 0.0
var hud: GameHUD
var time_button: Button
var game: Control

func setup(state: WorldState, ui: GameHUD, controller: Control, village_id: int = -1) -> void:
	world = state
	hud = ui
	game = controller
	add_theme_constant_override("separation", 8)
	var row := HBoxContainer.new()
	add_child(row)
	picker = OptionButton.new()
	picker.custom_minimum_size = Vector2(0, 48)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(picker)
	picker.item_selected.connect(func(n: int): selected = picker.get_item_id(n); refresh())
	time_button = hud.button("Pause", "pause", func(): game._set_speed(0 if game.speed > 0 else 1); refresh())
	row.add_child(time_button)
	for v in world.villages:
		picker.add_item(v.name + (" · abandoned" if not v.alive else ""), v.id)
	if picker.item_count > 0:
		selected = village_id if village_id >= 0 else picker.get_item_id(0)
		picker.select(picker.get_item_index(selected))
	else:
		picker.add_item("No villages yet")
		picker.disabled = true
	overview = hud.label("", 17, GameHUD.ACCENT)
	stores = hud.label("", 14)
	work = hud.label("", 13, GameHUD.MUTED)
	construction = hud.label("", 13)
	growth = hud.label("", 12, GameHUD.MUTED)
	for label in [overview, stores, work, construction, growth]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(label)
	realm_button = hud.button("", "crown", func(): game._kingdom_dialog(world.villages[selected].kingdom))
	add_child(realm_button)
	var legend := hud.label("POPULATION   /   green: settlers     blue: housing", 11, GameHUD.ACCENT)
	add_child(legend)
	chart = PopulationChart.new()
	add_child(chart)
	refresh()

func refresh() -> void:
	time_button.text = "Resume" if game.speed == 0 else "Pause"
	time_button.icon = load("res://assets/icons/%s.svg" % ("play" if game.speed == 0 else "pause"))
	# Settlements may be founded while this view is open.
	if world.villages.size() > (0 if picker.disabled else picker.item_count):
		var previous := selected
		picker.clear()
		picker.disabled = false
		for v in world.villages: picker.add_item(v.name, v.id)
		selected = maxi(0, previous)
		picker.select(picker.get_item_index(selected))
	realm_button.visible = selected >= 0 and world.villages[selected].kingdom >= 0
	if selected < 0:
		overview.text = "A village starts with four nearby adults."
		stores.text = "Place settlers on fertile land with trees and stone nearby."
		work.text = "Time can keep running while you watch this panel."
		return
	var v := world.villages[selected]
	if v.kingdom >= 0: realm_button.text = "%s · loyalty %s%%" % [world.kingdoms[v.kingdom].name, v.loyalty]
	overview.text = "%s settlers / %s places    ·    %s houses    ·    Year %s" % [v.population, world.housing(v), v.houses, world.year()]
	stores.text = "FOOD  %s / %s     WOOD  %s     STONE  %s\n%s farm plots  ·  Each resource has %s storage places" % [v.food, world.storage(v), v.wood, v.stone, v.farms.size(), world.storage(v)]
	var jobs: Array[String] = []
	for key in VillageEconomy.JOBS:
		if v.jobs.get(key, 0) > 0: jobs.append("%s %s" % [key.capitalize(), v.jobs[key]])
	work.text = "AT WORK   " + "  ·  ".join(jobs)
	construction.text = "Building a house: %s / 6 work done" % v.build_progress if v.build_site >= 0 else "Next house needs 12 wood + 4 stone and demand for space."
	if v.houses == WorldState.MAX_HOUSES: construction.text = "All 8 houses are built. This village has room for 44."
	if not v.alive: construction.text = "Abandoned — this village's story is recorded here."
	elif v.shortage: construction.text = "Food is running low. Restore farms or nearby forage."
	growth.text = "%s births  ·  %s deaths  ·  %s harvested  ·  %s food consumed" % [v.births, v.deaths, v.harvested, v.consumed]
	chart.history = v.history
	chart.queue_redraw()

func _process(delta: float) -> void:
	refresh_clock += delta
	if refresh_clock >= 0.5:
		refresh_clock = 0
		refresh()
