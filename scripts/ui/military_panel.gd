class_name MilitaryPanel
extends VBoxContainer
## Native controls inside the kingdom inspector's scrollable War page.
var owner_panel: KingdomPanel
var game: Control
var picker: OptionButton
var report: Label
var recruit_button: Button
var tower_button: Button
var retreat_button: Button
var guard_button: Button
var focus_button: Button
var village_id := -1
var roster: Array = []

func setup(parent_panel: KingdomPanel) -> void:
	owner_panel = parent_panel
	game = parent_panel.game
	add_theme_constant_override("separation", 10)
	picker = OptionButton.new()
	picker.custom_minimum_size.y = 48
	add_child(picker)
	picker.item_selected.connect(func(n: int): village_id = picker.get_item_id(n); refresh())
	report = game.hud.label("", 13)
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(report)
	var row := HBoxContainer.new()
	add_child(row)
	recruit_button = game.hud.button("Mobilize", "war", func():
		var ok: bool = game.simulation.military.recruit(village_id)
		game.hud.toast("Villagers have taken up arms." if ok else "Needs war, four available adults, and equipment supplies.")
		refresh())
	tower_button = game.hud.button("Build tower", "tower", func():
		var ok: bool = game.simulation.military.fortify(village_id)
		game.hud.toast("Watchtower funded. Nearby workers will finish it." if ok else "Needs 16 wood, 12 stone, and no existing tower.")
		refresh())
	for button in [recruit_button, tower_button]: button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(button)
	var orders := HBoxContainer.new()
	add_child(orders)
	guard_button = game.hud.button("Defend home", "", func():
		var a: Dictionary = game.simulation.military.army_for(village_id)
		if not a.is_empty():
			a.order = "attack" if a.order == "defend" else "defend"
			a.capture = 0
			a.outcome = "Marching to the enemy" if a.order == "attack" else "Ordered to defend home"
			a.last_progress = game.world.tick
		refresh())
	retreat_button = game.hud.button("Return home", "", func():
		var a: Dictionary = game.simulation.military.army_for(village_id)
		if not a.is_empty(): game.simulation.military.recall(a)
		refresh())
	for button in [guard_button, retreat_button]: button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; orders.add_child(button)
	focus_button = game.hud.button("Follow company on map", "inspect", _focus)
	add_child(focus_button)
	var hint: Label = game.hud.label("Each soldier needs 2 wood + 1 stone + 2 food. At least four adults must be available; half the village stays home.\n\nWatchtower: 16 wood + 12 stone, finished by nearby adults.\nTransport: 20 wood + 8 food when a company needs a sea crossing.\n\nDeclare war or make peace in Diplomacy. Holding a settlement for six seconds at normal speed captures it once its defenders and tower are cleared.", 12, GameHUD.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)

func refresh() -> void:
	var towns: Array = game.simulation.politics.villages(owner_panel.selected)
	var current: Array = towns.map(func(v: Dictionary) -> int: return v.id)
	if current != roster:
		roster = current
		picker.clear()
		for v in towns: picker.add_item(v.name, v.id)
		if village_id not in current: village_id = current[0] if not current.is_empty() else -1
		if village_id >= 0: picker.select(picker.get_item_index(village_id))
	picker.disabled = village_id < 0
	for button in [recruit_button, tower_button, retreat_button, guard_button, focus_button]: button.disabled = village_id < 0
	if village_id < 0:
		report.text = "No living settlements in this realm."
		return
	var v: Dictionary = game.world.villages[village_id]
	var a: Dictionary = game.simulation.military.army_for(village_id)
	var tower := "Watchtower %s / 160" % v.tower if v.tower > 0 else ("Building watchtower %s / 16" % v.fort_progress if v.fort_progress > 0 else "No watchtower")
	report.text = "%s food · %s wood · %s stone\n%s\n" % [v.food, v.wood, v.stone, tower]
	if a.is_empty():
		report.text += "No company raised. Soldiers come from this village's workers."
	else:
		report.text += "%s soldiers · morale %s%% · %s rations\nOrder: %s · Target: %s\n%s" % [a.members.size(), a.morale, a.food, a.order.capitalize(), game.world.villages[a.target].name, a.outcome]
	recruit_button.disabled = not a.is_empty() or game.simulation.military.enemy_town(v) < 0
	tower_button.disabled = v.tower > 0 or v.fort_progress > 0 or v.wood < 16 or v.stone < 12
	retreat_button.disabled = a.is_empty() or a.order == "return"
	guard_button.disabled = a.is_empty() or a.order == "return" or a.boat.state in ["boarding", "sailing"]
	guard_button.text = "Advance" if not a.is_empty() and a.order == "defend" else "Defend home"
	focus_button.disabled = a.is_empty()

func _focus() -> void:
	var a: Dictionary = game.simulation.military.army_for(village_id)
	if a.is_empty(): return
	var units: Array = game.simulation.military.people(a)
	if units.is_empty(): return
	var u: Dictionary = units[0]
	game.view.camera_center = Vector2(u.x, u.y) * WorldView.TILE
	game.view.zoom_level = 5
	game.view.camera_changed.emit(5.0)
	game.view.selected_id = u.id
	game.inspected_id = u.id
	game.hud.choose_tool("inspect")
	game._close_dialog()
	game._refresh_inspector()
