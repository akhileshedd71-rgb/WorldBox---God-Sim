class_name SocietyPanel
extends VBoxContainer
## Live social inspection and retained history; no identity-editing shortcuts.
var game: Control
var world: WorldState
var selected := -1
var picker: OptionButton
var member_picker: OptionButton
var history_filter: OptionButton
var scope_filter: OptionButton
var age_filter: OptionButton
var kingdom_filter: OptionButton
var ruler_picker: OptionButton
var metric_picker: OptionButton
var time_button: Button
var life_button: Button
var ruler_button: Button
var status: Label
var overview: Label
var knowledge: Label
var history_label: Label
var discovery_label: Label
var emblem: TextureRect
var chart: SocietyChart
var page_buttons := {}
var pages := {}
static func plural(count: int, noun: String) -> String:
	return "%s %s%s" % [count, noun, "" if count == 1 else "s"]
var clock := 0.0
var roster: Array = []
var rulers: Array = []
func label(text: String, parent: Node, color: Color = GameHUD.INK) -> Label:
	var node: Label = game.hud.label(text, 13, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node
func option(titles: Array, parent: Node) -> OptionButton:
	var node := OptionButton.new()
	node.custom_minimum_size = Vector2(100, 48)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.fit_to_longest_item = false
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for title in titles: node.add_item(title)
	parent.add_child(node)
	return node
func setup(controller: Control, culture: int = -1) -> void:
	game = controller; world = game.world; selected = culture
	add_theme_constant_override("separation", 12)
	var row := HBoxContainer.new(); add_child(row)
	picker = option([], row)
	picker.item_selected.connect(func(n: int): selected = picker.get_item_id(n); refresh())
	time_button = game.hud.button("Pause", "pause", func(): game._set_speed(0 if game.speed > 0 else 1); refresh())
	row.add_child(time_button)
	status = label("", self, GameHUD.ACCENT)
	var tabs := HBoxContainer.new(); add_child(tabs)
	for title in ["People", "Knowledge", "History", "Discoveries"]:
		var b: Button = game.hud.button(title, "", func(): set_page(title))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b); page_buttons[title] = b
		var page := VBoxContainer.new(); page.add_theme_constant_override("separation", 12)
		add_child(page); pages[title] = page
	var identity := HBoxContainer.new(); pages.People.add_child(identity)
	emblem = TextureRect.new(); emblem.custom_minimum_size = Vector2(64, 64)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	identity.add_child(emblem)
	overview = label("", identity); overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	member_picker = option([], pages.People)
	life_button = game.hud.button("Follow this life & family", "family", func(): game._life_dialog(member_picker.get_selected_id()))
	pages.People.add_child(life_button)
	label("Clans are social households. Two resident clan members add +1 yearly loyalty. Two local followers of the same hearth faith add +0.125 recovery per tick while fed and free of illness. These effects pause with Society.\n\nMigrants keep their clan and ancestry. Living with a strict local majority teaches its culture after 2 years, belief after 3, and language after 4. Soldiers and travelers do not assimilate on duty.", pages.People, GameHUD.MUTED)
	knowledge = label("", pages.Knowledge, GameHUD.ACCENT)
	var teaching_note := label("Work creates knowledge, never free supplies. Nearby villages on connected land exchange learning each year unless their kingdoms are at war. Shared language teaches up to 4 progress per neighbor; different languages teach 1. A teacher cannot share knowledge it has not learned.\n\nSociety enables learned work, solidarity, and communal care. Cultural exchange separately controls shared learning and gradual adoption. Laws can pause either.", pages.Knowledge, GameHUD.MUTED)
	metric_picker = option(["Settler population", "Stored food", "Stored wood", "Stored stone"], pages.Knowledge)
	metric_picker.item_selected.connect(func(_n: int): refresh())
	chart = SocietyChart.new(); pages.Knowledge.add_child(chart)
	label("World totals · up to 120 yearly samples. Stored resources exclude cargo and abandoned villages. The vertical axis follows the selected measure.", pages.Knowledge, GameHUD.MUTED)
	pages.Knowledge.move_child(teaching_note, -1)
	var filters := HBoxContainer.new(); pages.History.add_child(filters)
	history_filter = option(["All social events", "Founding", "Knowledge", "Exchange", "Discoveries", "Rulers"], filters)
	scope_filter = option(["All cultures", "Selected culture"], filters)
	age_filter = option(["All years", "Last 10 years", "Last 50 years"], filters)
	for control in [history_filter, scope_filter, age_filter]: control.item_selected.connect(func(_n: int): refresh())
	kingdom_filter = option([], pages.History)
	kingdom_filter.item_selected.connect(func(_n: int): refresh())
	ruler_picker = option([], pages.History)
	ruler_button = game.hud.button("Open ruler's life & family", "crown", func(): game._life_dialog(ruler_picker.get_selected_id()))
	pages.History.add_child(ruler_button)
	history_label = label("", pages.History)
	label("Retains 192 social events and 256 ruler transitions. Old-save rulers are marked Observed: earlier reigns were not recorded.", pages.History, GameHUD.MUTED)
	discovery_label = label("", pages.Discoveries, GameHUD.ACCENT)
	label("Try different worlds, connect settlements, and follow a family through generations. Discoveries award journal emblems when the world meets their conditions. They grant no resources or stat bonuses. Progress belongs to this saved world.", pages.Discoveries, GameHUD.MUTED)
	set_page("People"); refresh()
func set_page(title: String) -> void:
	for key in pages: pages[key].visible = key == title; game.hud._highlight(page_buttons[key], key == title)
func refresh() -> void:
	time_button.text = "Resume" if game.speed == 0 else "Pause"
	time_button.icon = load("res://assets/icons/%s.svg" % ("play" if game.speed == 0 else "pause"))
	if picker.item_count != maxi(1, world.cultures.size()) or (selected < 0 and not world.cultures.is_empty()):
		picker.clear()
		for c in world.cultures: picker.add_item(c.name, c.id)
		if world.cultures.is_empty(): picker.add_item("Cultures begin in villages", -1)
		elif selected < 0 or selected >= world.cultures.size(): selected = 0
		if selected >= 0: picker.select(picker.get_item_index(selected))
	picker.disabled = world.cultures.is_empty()
	status.text = "%s · %s · %s · %s\n%s · %s" % [plural(world.cultures.size(), "culture"), plural(world.clans.size(), "clan"), plural(world.languages.size(), "language"), plural(world.beliefs.size(), "faith"), "Society active" if world.laws.society else "Society paused in Laws", "Exchange active" if world.laws.cultural_exchange and world.laws.society else "Exchange paused"]
	var people: Array = world.lineage.filter(func(r: Dictionary) -> bool: return selected >= 0 and r.culture == selected)
	var ids: Array = people.map(func(r: Dictionary) -> int: return r.id)
	if ids != roster or member_picker.item_count == 0:
		var chosen := member_picker.get_selected_id()
		roster = ids; member_picker.clear()
		for r in people: member_picker.add_item("%s #%s%s" % [r.name, r.id, " · remembered" if r.death_tick >= 0 else ""], r.id)
		if people.is_empty(): member_picker.add_item("No recorded members", -1)
		elif chosen in ids: member_picker.select(member_picker.get_item_index(chosen))
	member_picker.disabled = people.is_empty(); life_button.disabled = people.is_empty()
	var living: Array = people.filter(func(r: Dictionary) -> bool: return r.death_tick < 0)
	var lines: Array[String] = []
	for field in ["clan", "language", "belief"]:
		var counts := {}
		for r in living: counts[r[field]] = counts.get(r[field], 0) + 1
		for id in counts: lines.append("%s · %s" % [SocietySimulation.title(world, field, id), counts[id]])
	overview.text = "%s living · %s remembered\n%s" % [living.size(), people.size() - living.size(), "\n".join(lines)]
	if selected < 0: overview.text = "Give settlers space to form a village. Their learned traditions will appear here."
	emblem.texture = load("res://assets/icons/society.svg")
	emblem.modulate = KingdomPolitics.COLORS[maxi(0, selected) % KingdomPolitics.COLORS.size()]
	knowledge.text = "A village starts a culture; real work grows its knowledge."
	if selected >= 0:
		var c := world.cultures[selected]
		knowledge.text = "CROP ROTATION · %s / 96\n%s\n\nMASONRY · %s / 4\n%s" % [c.harvest, "Learned · farm work takes 1 fewer tick (minimum 1)." if c.harvest >= 96 else "Harvest 96 crop food, or learn from nearby cultures.", c.building, "Learned · a house takes 4 work ticks instead of 6." if c.building >= 4 else "Complete 4 houses, or learn from nearby cultures."]
	chart.history = world.society_samples
	chart.metric = ["population", "food", "wood", "stone"][metric_picker.selected]; chart.queue_redraw()
	_refresh_history()
	lines.clear()
	for key in SocietySimulation.OBJECTIVES:
		var earned: Array = world.discoveries.filter(func(d: Dictionary) -> bool: return d.key == key)
		var goal: Array = SocietySimulation.OBJECTIVES[key]
		lines.append("%s %s%s\n%s" % ["◆" if not earned.is_empty() else "◇", goal[0], " · Year %s" % (1 + int(earned[0].tick) / 48) if not earned.is_empty() else "", goal[1]])
	discovery_label.text = "\n\n".join(lines)
func _refresh_history() -> void:
	var show_rulers := history_filter.selected == 5
	kingdom_filter.visible = show_rulers; ruler_picker.visible = show_rulers; ruler_button.visible = show_rulers
	scope_filter.disabled = show_rulers
	if kingdom_filter.item_count != world.kingdoms.size() + 1:
		var chosen := kingdom_filter.get_selected_id()
		kingdom_filter.clear(); kingdom_filter.add_item("All kingdoms", -1)
		for k in world.kingdoms: kingdom_filter.add_item(k.name, k.id)
		kingdom_filter.select(maxi(0, kingdom_filter.get_item_index(chosen)))
	var start := world.tick - ([2147483647, 480, 2400][age_filter.selected] as int)
	var lines: Array[String] = []
	var entries: Array = world.ruler_history if show_rulers else world.society_history
	var people: Array = []
	for e in entries:
		if e.tick < start: continue
		if show_rulers:
			if kingdom_filter.get_selected_id() >= 0 and e.kingdom != kingdom_filter.get_selected_id(): continue
			var r := Heredity.record(world, e.person)
			lines.append("Year %s · %s\n%s · %s" % [1 + int(e.tick) / 48, world.kingdoms[e.kingdom].name, "%s #%s" % [r.name, r.id] if not r.is_empty() else "Vacant throne", e.kind.capitalize()])
			if not r.is_empty() and e.person not in people: people.append(e.person)
		else:
			if scope_filter.selected == 1 and e.culture != selected: continue
			if history_filter.selected > 0 and e.kind != ["", "founding", "knowledge", "exchange", "discovery"][history_filter.selected]: continue
			lines.append("Year %s · %s\n%s" % [1 + int(e.tick) / 48, e.kind.capitalize(), e.text])
	history_label.text = "\n\n".join(lines) if not lines.is_empty() else "No recorded events match these filters."
	if people != rulers or ruler_picker.item_count == 0:
		rulers = people; ruler_picker.clear()
		for id in people:
			var r := Heredity.record(world, id); ruler_picker.add_item("%s #%s" % [r.name, id], id)
		if people.is_empty(): ruler_picker.add_item("No recorded rulers", -1)
	ruler_picker.disabled = people.is_empty(); ruler_button.disabled = people.is_empty()
func _process(delta: float) -> void:
	clock += delta
	if clock >= 0.5: clock = 0; refresh()
