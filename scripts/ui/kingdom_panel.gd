class_name KingdomPanel
extends VBoxContainer
## Live political inspector; interventions act on named realms, never hidden targets.
var game: Control
var hud: GameHUD
var world: WorldState
var politics: KingdomPolitics
var picker: OptionButton
var partner: OptionButton
var summary: Label
var towns_label: Label
var relations_label: Label
var journey_label: Label
var history_label: Label
var time_button: Button
var favor_button: Button
var peace_button: Button
var discord_button: Button
var war_button: Button
var military_panel: MilitaryPanel
var overlay_button: CheckButton
var action_row: HBoxContainer
var diplomacy_row: HBoxContainer
var influence_hint: Label
var page_buttons := {}
var page := "Realm"
var selected := -1
var partner_id := -1
var known_count := -1
var clock := 0.0
var living_roster: Array = []

func setup(controller: Control, kingdom_id: int = -1) -> void:
	game = controller
	hud = game.hud
	world = game.world
	politics = game.simulation.politics
	selected = kingdom_id
	add_theme_constant_override("separation", 10)
	var row := HBoxContainer.new()
	add_child(row)
	picker = OptionButton.new()
	picker.custom_minimum_size.y = 48
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(picker)
	picker.item_selected.connect(func(n: int): selected = picker.get_item_id(n); _partners(); refresh())
	time_button = hud.button("Pause", "pause", func(): game._set_speed(0 if game.speed > 0 else 1); refresh())
	row.add_child(time_button)
	var pages := HBoxContainer.new()
	add_child(pages)
	for title in ["Realm", "Diplomacy", "War", "Chronicle"]:
		var button := hud.button(title, "", func(): set_page(title))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pages.add_child(button)
		page_buttons[title] = button
	overlay_button = CheckButton.new()
	overlay_button.text = "Show political borders on the map"
	overlay_button.custom_minimum_size.y = 48
	overlay_button.button_pressed = game.view.show_politics
	overlay_button.toggled.connect(func(value: bool): game.view.show_politics = value; hud.set_political_view(value); game.view.queue_redraw())
	add_child(overlay_button)
	summary = hud.label("", 17, GameHUD.ACCENT)
	towns_label = hud.label("", 13)
	journey_label = hud.label("", 13, GameHUD.MUTED)
	relations_label = hud.label("", 13)
	for label in [summary, towns_label, journey_label, relations_label]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(label)
	action_row = HBoxContainer.new()
	var actions := action_row
	add_child(actions)
	favor_button = hud.button("Bestow favor", "crown", func(): _act("favor"))
	actions.add_child(favor_button)
	partner = OptionButton.new()
	partner.custom_minimum_size.y = 48
	partner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(partner)
	partner.item_selected.connect(func(n: int): partner_id = partner.get_item_id(n); refresh())
	diplomacy_row = HBoxContainer.new()
	var diplomacy_actions := diplomacy_row
	add_child(diplomacy_actions)
	peace_button = hud.button("Encourage peace", "peace", func(): _act("peace"))
	discord_button = hud.button("Sow discord", "discord", func(): _act("discord"))
	for button in [peace_button, discord_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		diplomacy_actions.add_child(button)
	war_button = hud.button("Declare war", "war", func():
		if game.simulation.military.declare_war(selected, partner_id): hud.toast("War declared. Villages will muster when supplies allow.")
		refresh())
	add_child(war_button)
	military_panel = MilitaryPanel.new()
	add_child(military_panel)
	military_panel.setup(self)
	var hint := hud.label("Allies support loyalty. Rival borders restrict expeditions.\nFavor strengthens loyalty for five years. War sends villagers into battle.", 12, GameHUD.MUTED)
	influence_hint = hint
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	history_label = hud.label("", 12, GameHUD.MUTED)
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(history_label)
	set_page("Realm")
	refresh()

func _partners() -> void:
	partner.clear()
	var previous := partner_id
	partner_id = -1
	for k in world.kingdoms:
		if k.alive and k.id != selected: partner.add_item(k.name, k.id)
	if partner.item_count == 0:
		partner.add_item("No other living realm")
		partner.disabled = true
	else:
		partner.disabled = false
		var n := partner.get_item_index(previous)
		partner.select(maxi(0, n))
		partner_id = partner.get_selected_id()

func _act(power: String) -> void:
	var ok: bool = game.simulation.military.make_peace(selected, partner_id) if power == "peace" else politics.influence(selected, power, partner_id)
	if ok:
		hud.toast({"favor": "Favor steadies this realm for five years.", "peace": "A call for peace reaches both rulers.", "discord": "Distrust spreads between the two realms."}[power])
		refresh()

func refresh() -> void:
	if picker == null: return
	time_button.text = "Resume" if game.speed == 0 else "Pause"
	time_button.icon = load("res://assets/icons/%s.svg" % ("play" if game.speed == 0 else "pause"))
	if known_count != world.kingdoms.size():
		known_count = world.kingdoms.size()
		picker.clear()
		for k in world.kingdoms: picker.add_item(k.name, k.id)
		if known_count == 0:
			picker.add_item("No kingdoms yet")
			picker.disabled = true
		else:
			picker.disabled = false
			selected = clampi(selected, 0, known_count - 1)
			picker.select(selected)
		_partners()
	var roster: Array = []
	for realm in world.kingdoms:
		if realm.alive: roster.append(realm.id)
	if roster != living_roster:
		living_roster = roster
		_partners()
	var alive: bool = selected >= 0 and world.kingdoms[selected].alive
	favor_button.disabled = not alive
	peace_button.disabled = not alive or partner_id < 0 or not world.kingdoms[partner_id].alive
	discord_button.disabled = peace_button.disabled
	war_button.disabled = peace_button.disabled or game.simulation.military.at_war(selected, partner_id)
	peace_button.text = "Make peace" if game.simulation.military.at_war(selected, partner_id) else "Encourage peace"
	military_panel.refresh()
	if selected < 0:
		summary.text = "A kingdom begins with a living village."
		towns_label.text = "Try a new Frontier continent for three groups of settlers."
		return
	var k := world.kingdoms[selected]
	picker.set_item_text(picker.selected, k.name + (" · fallen" if not k.alive else ""))
	var leader := politics.unit_by_id(k.ruler)
	var population := 0
	var towns: Array[String] = []
	for v in politics.villages(selected):
		population += v.population
		towns.append("%s%s · loyalty %s%%\n%s" % [v.name, " (capital)" if v.id == k.capital else "", v.loyalty, v.loyalty_reason.capitalize()])
	summary.text = "%s settlers  ·  %s settlements  ·  Year %s\n%s" % [population, towns.size(), world.year(), ("Ruler: %s · age %s" % [leader.name, leader.age]) if not leader.is_empty() else ("Awaiting an adult ruler" if k.alive else "This realm has fallen")]
	summary.add_theme_color_override("font_color", KingdomPolitics.COLORS[selected % KingdomPolitics.COLORS.size()])
	towns_label.text = "\n".join(towns)
	var journeys: Array[String] = []
	for e in world.expeditions:
		if e.active and e.kingdom == selected: journeys.append("%s settlers travelling · %s food remaining" % [e.members.size(), e.food])
	journey_label.text = "EXPANSION  " + ("\n".join(journeys) if not journeys.is_empty() else (world.villages[k.capital].expansion_reason if alive else "No living settlements"))
	var relations: Array[String] = []
	for r in world.relations:
		if r.a != selected and r.b != selected: continue
		var other: Dictionary = world.kingdoms[r.b if r.a == selected else r.a]
		if not other.alive: continue
		relations.append("%s · %s (%+d)\n%s" % [other.name, "WAR" if r.war else r.status.capitalize(), r.score, r.reason])
	relations_label.text = "DIPLOMACY\n" + ("\n".join(relations) if not relations.is_empty() else "No shared frontier or diplomatic ties yet.")
	var history: Array[String] = []
	for e in k.history.slice(0, 8): history.append("Year %s · %s" % [e.year, e.text])
	history_label.text = "REALM CHRONICLE\n" + "\n".join(history)

func _process(delta: float) -> void:
	clock += delta
	if clock >= 0.5: clock = 0; refresh()

func set_page(value: String) -> void:
	page = value
	summary.visible = page != "War"
	for title in page_buttons: hud._highlight(page_buttons[title], title == page)
	for control in [overlay_button, towns_label, journey_label]: control.visible = page == "Realm"
	for control in [relations_label, action_row, diplomacy_row, war_button, influence_hint]: control.visible = page == "Diplomacy"
	history_label.visible = page == "Chronicle"
	military_panel.visible = page == "War"
