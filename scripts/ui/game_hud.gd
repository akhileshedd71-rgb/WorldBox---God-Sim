class_name GameHUD
extends Control
signal tool_selected(tool: String)
signal brush_changed(radius: int)
signal action_requested(action: String)
signal speed_changed(speed: int)
signal feedback_requested
var text_scale := 1.0
var high_contrast := false

const INK := Color("e3ebdd")
const MUTED := Color("8ba6a8")
const ACCENT := Color("c9dda0")
const PANEL := Color("112d35")
const BORDER := Color("2d4d50")
const CATEGORIES := {
	"Shape": [["terrain_2", "Meadow", "meadow"], ["terrain_3", "Forest", "forest"], ["terrain_1", "Sand", "sand"], ["terrain_0", "Ocean", "ocean"], ["terrain_4", "Mountain", "mountain"], ["terrain_5", "Snow", "snow"]],
	"Biomes": [["biome_1", "Temperate", "meadow"], ["biome_2", "Woodland", "forest"], ["biome_4", "Arid", "drought"], ["biome_5", "Wetland", "wetland"], ["biome_3", "Tundra", "snow"], ["biome_6", "Glimmergrove", "glimmer"]],
	"Life": [["settler", "Settlers", "settler"], ["rabbit", "Rabbits", "rabbit"], ["deer", "Deer", "deer"]],
	"Powers": [["rain", "Rain", "rain"], ["bless", "Blessing", "bless"], ["fire", "Fire", "fire"], ["meteor", "Meteor", "meteor"], ["lightning", "Lightning", "lightning"], ["quake", "Quake", "quake"], ["volcano", "Volcano", "volcano"], ["plague", "Plague", "plague"]],
	"Observe": [["pan", "Move", "pan"], ["inspect", "Inspect", "inspect"], ["villages", "Villages", "village"], ["politics", "Borders", "borders"], ["kingdoms", "Kingdoms", "crown"], ["lives", "Lives", "family"], ["environment", "Planet", "planet"], ["society", "Society", "society"]]
}
const DESCRIPTIONS := {
	"society": "Follow cultures, clans, learning, beliefs, rulers, and discoveries.",
	"biome_1": "Paint temperate ecosystems; coasts and homes stay in place.",
	"biome_2": "Woodland renews timber over time. Biomes preserve elevation.",
	"biome_3": "Tundra brings cold and scarce food. Farm plots are removed.",
	"biome_4": "Arid land supports sparse forage. Farm plots are removed.",
	"biome_5": "Wetland has rich forage, renewing wood, and rare Rustfever exposure.",
	"biome_6": "Glimmergrove grows timber quickly; crops grow slowly.",
	"environment": "Follow climate, land conditions, and disease; choose weather and law presets.",
	"lightning": "Strike a small area, injure creatures, and ignite vegetation.",
	"quake": "Level homes and fields in a small area. Creatures can be hurt.",
	"volcano": "Raise a peak and release a finite eruption. Up to eight active vents.",
	"plague": "Seed Rustfever nearby. Immunity protects survivors; Disease law must be on.",
	"lives": "Discover traits, parents, children, and the stories of favorite lives",
	"politics": "Toggle political borders. Inspect claimed land to visit its kingdom.",
	"kingdoms": "Meet rulers, follow expansion, and influence diplomatic relations",
	"villages": "Follow village stores, jobs, housing, and population over time",
	"pan": "Drag to explore  ·  Pinch or scroll to zoom",
	"inspect": "Touch a creature, village, or tile to discover its story",
	"terrain_2": "Paint fertile meadows. Give new life a place to begin.",
	"terrain_3": "Grow a woodland. A shelter and food source for life.",
	"terrain_1": "Shape golden shores and quiet stretches of sand.",
	"terrain_0": "Carve a channel or return the land to the sea.",
	"terrain_4": "Raise stone peaks. Creatures must travel around them.",
	"terrain_5": "Dust the land in snow. Beautiful, but food is scarce.",
	"settler": "Place settlers on land. Four nearby settlers can found a village.",
	"rabbit": "Add rabbits to the meadow. Nearby pairs can reproduce.",
	"deer": "Bring deer to your world. They wander and forage.",
	"rain": "Restore forage and extinguish fire with a gentle rain.",
	"bless": "Restore health and satisfy hunger in the brush area.",
	"fire": "Ignite vegetation. Flames spread when the world law allows.",
	"meteor": "A falling star clears land and harms creatures in its path."
}
var selected_tool := "pan"
var political_visible := false
var category := "Shape"
var compact := false
var header: Panel
var brand: HBoxContainer
var top_actions: HBoxContainer
var time_controls: HBoxContainer
var title_group: VBoxContainer
var world_label: Label
var mobile_stats: Label
var year_label: Label
var dock: Panel
var dock_layout: VBoxContainer
var tabs: HBoxContainer
var tool_row: HBoxContainer
var tool_buttons := {}
var tab_buttons := {}
var brush_buttons: Array[Button] = []
var context_label: Label
var tool_hint: Label
var stats_panel: Panel
var population_label: Label
var animal_label: Label
var village_label: Label
var seed_label: Label
var chronicle_panel: Panel
var event_list: VBoxContainer
var inspector_panel: Panel
var inspector_title: Label
var inspector_text: Label
var camera_tools: HBoxContainer
var zoom_label: Label
var toast_label: Label
var toast_timer := 0.0
var pause_button: Button
var speed_buttons := {}
var active_speed := 1
var saved_label: Label
var sidebar_visible := false
var theme_font: Font = preload("res://assets/fonts/OpenSans-Regular.ttf")
var bold_font: Font = preload("res://assets/fonts/OpenSans-Semibold.ttf")

static func box(color: Color = PANEL, border: Color = BORDER, radius: int = 12) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 14
	b.content_margin_right = 14
	b.content_margin_top = 9
	b.content_margin_bottom = 9
	return b

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := Theme.new()
	t.default_font = theme_font
	t.default_font_size = 15
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_stylebox("normal", "Button", box(Color("193840")))
	t.set_stylebox("hover", "Button", box(Color("294b4e"), Color("688772")))
	t.set_stylebox("pressed", "Button", box(Color("38564a"), ACCENT))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT))
	t.set_stylebox("panel", "Panel", box())
	t.set_stylebox("normal", "LineEdit", box(Color("0c242c")))
	t.set_color("font_color", "LineEdit", INK)
	theme = t
	_build_header()
	_build_title()
	_build_dock()
	_build_sidebar()
	_build_camera()
	toast_label = label("", 15, ACCENT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", box(Color("254a42"), Color("55765a")))
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.hide()
	add_child(toast_label)
	resized.connect(_layout)
	_layout()
	_layout.call_deferred()

func label(text_value: String, font_size: int = 15, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text_value
	l.set_meta("base_font_size", font_size)
	l.set_meta("base_color", color)
	l.add_theme_font_size_override("font_size", roundi(font_size * text_scale))
	l.add_theme_color_override("font_color", Color("d8e5e1") if high_contrast and color == MUTED else color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func button(text_value: String, icon_name: String = "", callback: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text_value
	b.pressed.connect(func(): feedback_requested.emit())
	b.custom_minimum_size = Vector2(48, 48)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_ALL
	if not icon_name.is_empty():
		b.icon = load("res://assets/icons/%s.svg" % icon_name)
		b.add_theme_constant_override("icon_max_width", 21)
		b.add_theme_constant_override("h_separation", 9)
	if callback.is_valid(): b.pressed.connect(callback)
	return b

func _panel(parent: Node = self) -> Panel:
	var p := Panel.new()
	parent.add_child(p)
	return p

func _content(p: Control, padding: int = 20) -> VBoxContainer:
	var margin := MarginContainer.new()
	p.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, padding)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)
	return v

func _build_header() -> void:
	header = _panel()
	header.add_theme_stylebox_override("panel", box(Color("102830"), Color("345259"), 0))
	brand = HBoxContainer.new()
	brand.add_theme_constant_override("separation", 13)
	header.add_child(brand)
	var logo := TextureRect.new()
	logo.texture = preload("res://assets/icons/app.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.custom_minimum_size = Vector2(44, 44)
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand.add_child(logo)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	brand.add_child(words)
	var name_label := label("V E R D A N T", 23, ACCENT)
	name_label.add_theme_font_override("font", bold_font)
	words.add_child(name_label)
	words.add_child(label("P O C K E T   W O R L D S", 10, MUTED))
	time_controls = HBoxContainer.new()
	time_controls.add_theme_constant_override("separation", 6)
	header.add_child(time_controls)
	year_label = label("YEAR 01", 16, ACCENT)
	year_label.custom_minimum_size.x = 102
	time_controls.add_child(year_label)
	pause_button = button("", "pause", func(): speed_changed.emit(0 if active_speed > 0 else 1))
	pause_button.tooltip_text = "Pause / resume · Space"
	time_controls.add_child(pause_button)
	for speed in [1, 2, 5]:
		var b := button("%s×" % speed, "", func(): speed_changed.emit(speed))
		time_controls.add_child(b)
		speed_buttons[speed] = b
	top_actions = HBoxContainer.new()
	top_actions.add_theme_constant_override("separation", 7)
	header.add_child(top_actions)
	for item in [["new", "New world", "plus"], ["save", "", "save"], ["load", "", "load"], ["history", "", "history"], ["laws", "", "laws"], ["settings", "", "settings"], ["help", "", "help"]]:
		var b := button(item[1], item[2], func(): action_requested.emit(item[0]))
		b.tooltip_text = {"new": "Generate a new world", "save": "Save world · Ctrl+S", "load": "World shelf · named saves and recovery", "settings": "Audio, reading, motion, and performance settings", "history": "World population and chronicle", "laws": "World laws", "help": "Field guide & controls"}[item[0]]
		top_actions.add_child(b)
	set_speed(1)

func _build_title() -> void:
	title_group = VBoxContainer.new()
	title_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_group.add_theme_constant_override("separation", 4)
	add_child(title_group)
	title_group.add_child(label("A  W O R L D  O F  Y O U R  O W N", 10, Color("a0bcb7")))
	world_label = label("The Quiet Isles", 29, Color("edf0dc"))
	world_label.add_theme_font_override("font", bold_font)
	title_group.add_child(world_label)
	title_group.add_child(label("Shape the land. Let a story unfold.", 13, Color("a7c1bc")))
	mobile_stats = label("", 13, Color("baceb5"))
	title_group.add_child(mobile_stats)

func _build_dock() -> void:
	dock = _panel()
	dock_layout = _content(dock, 14)
	dock_layout.add_theme_constant_override("separation", 10)
	var tab_line := HBoxContainer.new()
	tab_line.add_theme_constant_override("separation", 8)
	dock_layout.add_child(tab_line)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tab_line.add_child(tabs)
	for key in CATEGORIES:
		var b := button(key, "", func(): _select_category(key))
		b.custom_minimum_size = Vector2(80, 38)
		tabs.add_child(b)
		tab_buttons[key] = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_line.add_child(spacer)
	var pan := button("", "pan", func(): choose_tool("pan"))
	pan.tooltip_text = "Move camera · V"
	tab_line.add_child(pan)
	var inspect := button("", "inspect", func(): choose_tool("inspect"))
	inspect.tooltip_text = "Inspect · I"
	tab_line.add_child(inspect)
	var brush_group := HBoxContainer.new()
	brush_group.add_theme_constant_override("separation", 4)
	tab_line.add_child(brush_group)
	var brush_text := label("  BRUSH  ", 10, MUTED)
	brush_group.add_child(brush_text)
	for radius in [1, 2, 4]:
		var b := button(["S", "M", "L"][[1, 2, 4].find(radius)], "", func(): set_brush(radius); brush_changed.emit(radius))
		b.custom_minimum_size = Vector2(40, 40)
		brush_group.add_child(b)
		brush_buttons.append(b)
	tool_row = HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 8)
	dock_layout.add_child(tool_row)
	context_label = label(DESCRIPTIONS.pan, 13, MUTED)
	context_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dock_layout.add_child(context_label)
	_select_category("Shape")
	set_brush(2)

func _select_category(key: String) -> void:
	category = key
	for child in tool_row.get_children(): child.free()
	tool_buttons.clear()
	for entry in CATEGORIES[key]:
		var b := button("", "", func(): choose_tool(entry[0]))
		b.custom_minimum_size = Vector2(0, 80)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = DESCRIPTIONS[entry[0]]
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_top = 11
		content.offset_bottom = -8
		content.add_theme_constant_override("separation", 5)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/%s.svg" % entry[2])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(30, 30)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)
		var text_label := label(entry[1], 13)
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(text_label)
		tool_row.add_child(b)
		tool_buttons[entry[0]] = b
	for tab in tab_buttons:
		_highlight(tab_buttons[tab], tab == category)
	for key_tool in tool_buttons: _highlight(tool_buttons[key_tool], political_visible if key_tool == "politics" else key_tool == selected_tool)

func choose_tool(value: String) -> void:
	if value in ["villages", "kingdoms", "politics", "lives", "environment", "society"]: action_requested.emit(value); return
	selected_tool = value
	context_label.text = DESCRIPTIONS.get(value, "")
	for key in tool_buttons: _highlight(tool_buttons[key], political_visible if key == "politics" else key == value)
	tool_selected.emit(value)

func set_brush(radius: int) -> void:
	for i in brush_buttons.size(): _highlight(brush_buttons[i], [1, 2, 4][i] == radius)

func _highlight(b: Button, active: bool) -> void:
	b.add_theme_stylebox_override("normal", box(Color("385044") if active else Color("193840"), Color("a6bf7c") if active else Color("2b4a4e"), 8))
	b.add_theme_color_override("font_color", ACCENT if active else INK)

func _build_sidebar() -> void:
	stats_panel = _panel()
	var content := _content(stats_panel)
	var heading := label("THE LIVING WORLD", 11, ACCENT)
	content.add_child(heading)
	population_label = label("12", 36)
	population_label.add_theme_font_override("font", bold_font)
	content.add_child(population_label)
	content.add_child(label("settlers finding their way", 12, MUTED))
	var line := HSeparator.new()
	line.modulate = Color("527172")
	content.add_child(line)
	animal_label = label("Wildlife                        22", 13)
	content.add_child(animal_label)
	village_label = label("Villages                         0", 13)
	content.add_child(village_label)
	seed_label = label("SEED 41827  ·  144 × 96", 10, MUTED)
	content.add_child(seed_label)
	chronicle_panel = _panel()
	var history := _content(chronicle_panel)
	history.add_child(label("WORLD CHRONICLE", 11, ACCENT))
	history.add_child(label("Small moments. Lasting stories.", 11, MUTED))
	event_list = VBoxContainer.new()
	event_list.add_theme_constant_override("separation", 17)
	history.add_child(event_list)
	inspector_panel = _panel()
	var info := _content(inspector_panel)
	inspector_title = label("A closer look", 17, ACCENT)
	info.add_child(inspector_title)
	inspector_text = label("Every little life has a story.\n\nChoose Inspect, then touch a creature, village, or patch of land.", 13, MUTED)
	inspector_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(inspector_text)
	saved_label = label("LOCAL WORLD  ·  AUTO-SAVES EVERY 60s", 10, MUTED)
	add_child(saved_label)

func _build_camera() -> void:
	camera_tools = HBoxContainer.new()
	camera_tools.add_theme_constant_override("separation", 5)
	add_child(camera_tools)
	camera_tools.add_child(button("", "minus", func(): action_requested.emit("zoom_out")))
	zoom_label = label("100%", 12)
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_label.custom_minimum_size.x = 50
	camera_tools.add_child(zoom_label)
	camera_tools.add_child(button("", "plus", func(): action_requested.emit("zoom_in")))
	camera_tools.add_child(button("", "fit", func(): action_requested.emit("fit")))
	tool_hint = label("✦  CREATION IS A QUIET KIND OF MAGIC", 10, Color("a3bcb6"))
	add_child(tool_hint)

func _layout() -> void:
	if header == null: return
	compact = size.x < 1150 or size.y < 700
	var inset := Vector2(20, 0)
	var right_inset := 20.0
	var bottom_inset := 20.0
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if screen.x > 0 and screen.y > 0:
			inset.x = maxf(16, safe.position.x * size.x / screen.x)
			inset.y = maxf(0, safe.position.y * size.y / screen.y)
			right_inset = maxf(16, (screen.x - safe.end.x) * size.x / screen.x)
			bottom_inset = maxf(20, (screen.y - safe.end.y) * size.y / screen.y)
	header.position = Vector2(0, inset.y)
	header.size = Vector2(size.x, 76 if not compact else 66)
	brand.position = Vector2(inset.x, 13)
	brand.get_child(0).custom_minimum_size = Vector2(36, 36) if compact else Vector2(44, 44)
	brand.get_child(1).get_child(0).add_theme_font_size_override("font_size", 18 if compact else 23)
	brand.get_child(1).get_child(1).add_theme_font_size_override("font_size", 9 if compact else 10)
	top_actions.get_child(0).text = "" if compact else "New world"
	top_actions.get_child(0).custom_minimum_size.x = 50 if compact else 148
	for i in range(1, top_actions.get_child_count()): top_actions.get_child(i).custom_minimum_size.x = 50
	top_actions.reset_size()
	top_actions.position = Vector2(size.x - (390 if compact else 488) - right_inset, 14 if not compact else 9)
	time_controls.position = Vector2(inset.x + (315 if not compact else 212), 14 if not compact else 9)
	for b in speed_buttons.values(): b.visible = not compact or b == speed_buttons[1] or b == speed_buttons[5]
	title_group.position = Vector2(inset.x + 10, inset.y + (105 if not compact else 80))
	world_label.add_theme_font_size_override("font_size", 22 if compact else 29)
	title_group.get_child(0).add_theme_font_size_override("font_size", 9 if compact else 10)
	mobile_stats.add_theme_font_size_override("font_size", 12)
	title_group.get_child(2).visible = not compact
	mobile_stats.visible = compact
	var dock_width: float = size.x - inset.x - (290 if not compact else right_inset)
	dock.position = Vector2(inset.x, size.y - (219 if not compact else 202) - (bottom_inset - 20))
	dock.size = Vector2(dock_width, 192 if not compact else 182)
	stats_panel.position = Vector2(size.x - 276, 103)
	stats_panel.size = Vector2(252, 251)
	chronicle_panel.position = Vector2(size.x - 276, 368)
	chronicle_panel.size = Vector2(252, 246)
	inspector_panel.position = Vector2(size.x - 276, 628)
	inspector_panel.size = Vector2(252, 212)
	stats_panel.visible = not compact
	chronicle_panel.visible = not compact
	inspector_panel.visible = not compact or sidebar_visible
	if compact:
		inspector_panel.position = Vector2(size.x - 282, 86)
		inspector_panel.size = Vector2(262, 214)
	saved_label.position = Vector2(size.x - 276, size.y - 35)
	saved_label.visible = not compact
	camera_tools.position = Vector2(dock.position.x + dock_width - 223, dock.position.y - 62)
	tool_hint.position = Vector2(inset.x + 10, dock.position.y - 46)
	tool_hint.visible = not compact
	toast_label.position = Vector2(size.x * 0.5 - 260, 84)
	toast_label.size = Vector2(520, 44)

func set_speed(value: int) -> void:
	active_speed = value
	if pause_button == null: return
	pause_button.icon = load("res://assets/icons/%s.svg" % ("play" if value == 0 else "pause"))
	_highlight(pause_button, value == 0)
	for key in speed_buttons: _highlight(speed_buttons[key], key == value)

func refresh(w: WorldState) -> void:
	world_label.text = w.world_name
	year_label.text = "YEAR %02d" % w.year()
	population_label.text = str(w.population("settler"))
	animal_label.text = "Wildlife                              %s" % (w.population() - w.population("settler"))
	var count := 0
	for v in w.villages:
		if v.alive: count += 1
	village_label.text = "Villages                              %s" % count
	mobile_stats.text = "%s settlers  ·  %s wildlife  ·  %s villages" % [w.population("settler"), w.population() - w.population("settler"), count]
	seed_label.text = "%s · %s\n%s" % [EnvironmentSimulation.SEASONS[EnvironmentSimulation.season(w)], EnvironmentSimulation.WEATHER[EnvironmentSimulation.weather(w)], EnvironmentSimulation.AGES[EnvironmentSimulation.age(w)]]
	for child in event_list.get_children(): child.free()
	for i in mini(3, w.events.size()):
		var e := w.events[i]
		var l := label("YEAR %s   /   %s" % [e.year, e.text], 12, INK if i == 0 else MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_list.add_child(l)

func inspect_text(title: String, body: String) -> void:
	inspector_title.text = title
	inspector_text.text = body
	sidebar_visible = true
	_layout()

func toast(message: String) -> void:
	toast_label.text = message
	toast_label.show()
	toast_timer = 3.0

func _process(delta: float) -> void:
	if toast_timer > 0:
		toast_timer -= delta
		if toast_timer <= 0: toast_label.hide()

func set_political_view(value: bool) -> void:
	political_visible = value
	if tool_buttons.has("politics"): _highlight(tool_buttons.politics, value)

func apply_preferences(values: Dictionary) -> void:
	text_scale = 1.15 if values.large_text else 1.0
	high_contrast = values.high_contrast
	theme.default_font_size = 16 if values.large_text else 15
	theme.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), Color.WHITE if high_contrast else ACCENT))
	for child in find_children("*", "Label", true, false):
		if child.has_meta("base_font_size"): child.add_theme_font_size_override("font_size", roundi(child.get_meta("base_font_size") * text_scale))
		if child.has_meta("base_color"):
			var color: Color = child.get_meta("base_color")
			child.add_theme_color_override("font_color", Color("d8e5e1") if high_contrast and color == MUTED else color)
	_layout()
