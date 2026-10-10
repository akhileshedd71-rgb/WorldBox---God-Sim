class_name LifePanel
extends VBoxContainer
## A live, scrollable archive shared by people and wildlife, including the dead.
var game: Control
var world: WorldState
var filter: OptionButton
var picker: OptionButton
var time_button: Button
var favorite_button: Button
var focus_button: Button
var society_button: Button
var overview: Label
var portrait: TextureRect
var trait_label: Label
var memory_label: Label
var family_box: VBoxContainer
var page_buttons := {}
var page := "Traits"
var selected := -1
var roster: Array = []
var family_signature := ""
var parent_buttons: Array[Button] = []
var child_buttons: Array[Button] = []
var clock := 0.0
func setup(controller: Control, id: int = -1) -> void:
	game = controller
	world = game.world
	selected = id
	add_theme_constant_override("separation", 10)
	var row := HBoxContainer.new()
	add_child(row)
	filter = OptionButton.new()
	for title in ["Living", "Favorites", "Remembered", "All lives"]: filter.add_item(title)
	filter.custom_minimum_size.y = 48
	filter.size_flags_horizontal = Control.SIZE_FILL
	filter.custom_minimum_size.x = 100
	filter.fit_to_longest_item = false
	row.add_child(filter)
	if selected >= 0 and Heredity.unit(world, selected).is_empty(): filter.select(3)
	filter.item_selected.connect(func(_n: int): selected = -1; roster.clear(); refresh())
	time_button = game.hud.button("Pause", "pause", func(): game._set_speed(0 if game.speed > 0 else 1); refresh())
	row.add_child(time_button)
	picker = OptionButton.new()
	picker.custom_minimum_size.y = 48
	picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	picker.custom_minimum_size.x = 160
	picker.fit_to_longest_item = false
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(picker)
	row.move_child(picker, 1)
	picker.item_selected.connect(func(n: int): selected = picker.get_item_id(n); refresh())
	var identity := HBoxContainer.new()
	add_child(identity)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(48, 48) if game.hud.compact else Vector2(64, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	identity.add_child(portrait)
	overview = game.hud.label("", 14, GameHUD.ACCENT)
	overview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(overview)
	var actions := HBoxContainer.new()
	add_child(actions)
	favorite_button = game.hud.button("Favorite", "favorite", func():
		var r := Heredity.record(world, selected)
		if not r.is_empty() and not Heredity.set_favorite(world, selected, not r.favorite): game.hud.toast("All 32 favorite places are filled. Unstar a life to add another.")
		refresh())
	focus_button = game.hud.button("Find on map", "inspect", _focus)
	for button in [favorite_button, focus_button]: button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; actions.add_child(button)
	society_button = game.hud.button("Culture & community", "society", func(): game._society_dialog(Heredity.record(world, selected).culture))
	add_child(society_button)
	var pages := HBoxContainer.new()
	add_child(pages)
	for title in ["Traits", "Family", "Memories"]:
		var button: Button = game.hud.button(title, "", func(): set_page(title))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pages.add_child(button)
		page_buttons[title] = button
	trait_label = game.hud.label("", 13)
	trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(trait_label)
	family_box = VBoxContainer.new()
	family_box.add_theme_constant_override("separation", 8)
	add_child(family_box)
	memory_label = game.hud.label("", 13)
	memory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(memory_label)
	set_page("Traits")
	refresh()
func set_page(value: String) -> void:
	page = value
	for title in page_buttons: game.hud._highlight(page_buttons[title], title == value)
	trait_label.visible = page == "Traits"
	family_box.visible = page == "Family"
	memory_label.visible = page == "Memories"
func refresh() -> void:
	time_button.text = "Resume" if game.speed == 0 else "Pause"
	time_button.icon = load("res://assets/icons/%s.svg" % ("play" if game.speed == 0 else "pause"))
	var choices: Array = []
	for r in world.lineage:
		if filter.selected == 0 and r.death_tick >= 0: continue
		if filter.selected == 1 and not r.favorite: continue
		if filter.selected == 2 and r.death_tick < 0: continue
		choices.append(r.id)
	if choices != roster or picker.item_count == 0:
		roster = choices
		picker.clear()
		for id in choices:
			var r := Heredity.record(world, id)
			picker.add_item("%s · %s #%s%s" % [r.name, r.species.capitalize(), r.id, " · remembered" if r.death_tick >= 0 else ""], r.id)
		if selected not in choices: selected = choices[0] if not choices.is_empty() else -1
		if selected >= 0: picker.select(picker.get_item_index(selected))
		else: picker.add_item("No lives in this view")
	picker.disabled = selected < 0
	favorite_button.disabled = selected < 0
	focus_button.disabled = true
	society_button.disabled = selected < 0 or Heredity.record(world, selected).get("culture", -1) < 0
	if selected < 0:
		overview.text = "Star a life to keep its story close." if filter.selected == 1 else "No recorded lives here yet."
		portrait.texture = null
		trait_label.text = "Family history begins when life enters your world."
		memory_label.text = ""
		_clear_family()
		return
	var r := Heredity.record(world, selected)
	var u := Heredity.unit(world, selected)
	var age: int = r.last_age if u.is_empty() else u.age
	var inherited := {"species": r.species, "genome": r.genome}
	var coat := Heredity.value(inherited, "coat")
	portrait.texture = load("res://assets/sprites/%s_%s.png" % [r.species, coat])
	overview.text = "%s · %s\nGeneration %s · %s" % [r.name, Heredity.variant(inherited), r.generation, "Age %s" % age if r.death_tick < 0 else "Remembered · lived %s years" % age]
	favorite_button.text = "Starred" if r.favorite else "Favorite"
	game.hud._highlight(favorite_button, r.favorite)
	focus_button.disabled = u.is_empty() or u.health <= 0
	var lines: Array[String] = []
	for trait_key in Heredity.traits(inherited): lines.append("%s\n%s" % [trait_key.replace("_", " ").capitalize(), Heredity.TRAITS[trait_key].text])
	if lines.is_empty(): lines.append("Balanced traits\nThis life has no expressed modifiers.")
	lines.append("Lifespan threshold: %s years · Recovery: %s / tick" % [Heredity.lifespan(inherited), Heredity.recovery(inherited)])
	if SpeciesCatalog.get_species(r.species).forms_villages:
		lines.append("Gathering work: %s ticks · Weapon modifier: %+d" % [Heredity.work_ticks(inherited), Heredity.value(inherited, "vigor") * 2])
	if not u.is_empty(): lines.append("Current hunger increase: %.4f / tick\nHealth %s · Hunger %s%% · %s" % [Heredity.hunger_rate(world, u) * EnvironmentSimulation.hunger_multiplier(world, u), int(u.health), int(u.hunger), u.state])
	if not u.is_empty(): lines.append(EnvironmentSimulation.health_text(world, u))
	lines.append("Two inherited copies shape each trait. Opposing copies balance out; habitat adaptations need two matching copies. Appearance is inherited separately.")
	if r.culture >= 0:
		var identities: Array[String] = []
		for field in SocietySimulation.FIELDS: identities.append("%s: %s" % [field.capitalize(), SocietySimulation.title(world, field, r[field])])
		lines.append("Learned identity" + (" at death" if r.death_tick >= 0 else "") + "\n" + "\n".join(identities))
	trait_label.text = "\n\n".join(lines)
	var memories: Array[String] = []
	for e in r.events: memories.append("Year %s · %s" % [1 + int(e.tick) / 48, e.text])
	memory_label.text = "\n\n".join(memories)
	_update_family(r)
func _clear_family() -> void:
	for child in family_box.get_children(): family_box.remove_child(child); child.queue_free()
	parent_buttons.clear()
	child_buttons.clear()
	family_signature = ""
func _link(r: Dictionary, prefix: String) -> Button:
	var b: Button = game.hud.button("%s: %s #%s%s" % [prefix, r.name, r.id, " · remembered" if r.death_tick >= 0 else ""], "", func():
		filter.select(3)
		selected = r.id
		roster.clear()
		refresh.call_deferred())
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	family_box.add_child(b)
	return b
func _update_family(r: Dictionary) -> void:
	var children: Array[Dictionary] = []
	var siblings := 0
	for candidate in world.lineage:
		if r.id in candidate.parents: children.append(candidate)
		elif candidate.id != r.id:
			for parent in r.parents:
				if parent in candidate.parents: siblings += 1; break
	var signature := str([r.id, r.parents.map(func(id: int) -> Array: return [id, Heredity.record(world, id).death_tick]), children.map(func(c: Dictionary) -> Array: return [c.id, c.death_tick]), world.tick / 48])
	if signature == family_signature: return
	_clear_family()
	family_signature = signature
	var heading: Label = game.hud.label("%s recorded children · %s siblings / half-siblings" % [children.size(), siblings], 13, GameHUD.ACCENT)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	family_box.add_child(heading)
	if r.parents.is_empty():
		var unknown: Label = game.hud.label("Parents unknown · ancestry before arrival was not recorded.", 13, GameHUD.MUTED)
		unknown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		family_box.add_child(unknown)
	for id in r.parents: parent_buttons.append(_link(Heredity.record(world, int(id)), "Parent"))
	for child in children: child_buttons.append(_link(child, "Child"))
func _focus() -> void:
	var u := Heredity.unit(world, selected)
	if u.is_empty() or u.health <= 0: return
	game.view.camera_center = Vector2(u.x, u.y) * WorldView.TILE
	game.view.zoom_level = 5
	game.view.camera_changed.emit(5.0)
	game.inspected_id = selected
	game.view.selected_id = selected
	game.hud.choose_tool("inspect")
	game._close_dialog()
	game._refresh_inspector()
func _process(delta: float) -> void:
	clock += delta
	if clock >= 0.5: clock = 0; refresh()
