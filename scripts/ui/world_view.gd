class_name WorldView
extends Control
## A single canvas for terrain, villages, and units. Touch-safe editing and camera.
signal applied(tool: String, cell: Vector2i)
signal inspected(cell: Vector2i)
signal camera_changed(value: float)

const TILE := 16
var world: WorldState
var tool := "pan"
var brush := 2
var zoom_level := 1.0
var camera_center := Vector2(1152, 768)
var show_villages := true
var show_politics := false
var political_texture: ImageTexture
var political_revision := -1
var hover_cell := Vector2i(-1, -1)
var selected_id := -1
var terrain_cache := TerrainChunks.new()
var reduced_motion := false
var baked_revision := -1
var rebuild_cooldown := 0.0
var tiles: Array[Image] = []
var biome_tiles: Array[Image] = []
var sprites := {}
var images := {}
var display_positions := {}
var fx: Array[Dictionary] = []
var mouse_down := false
var dragging_camera := false
var last_paint := Vector2i(-999, -999)
var fingers := {}
var touch_origin := Vector2.ZERO
var multi_touch := false
var previous_pinch := 0.0
var previous_mid := Vector2.ZERO
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for type in 6:
		for variation in 4:
			tiles.append(load("res://assets/sprites/tile_%s_%s.png" % [type, variation]).get_image())
	for biome in BiomeCatalog.NAMES.size():
		for variant in 4: biome_tiles.append(load("res://assets/sprites/biome_%s_%s.png" % [biome, variant]).get_image())
	for key in ["glimmer_tree", "reeds", "tree", "pine", "peak", "settler", "rabbit", "deer", "house", "fire", "stone", "depot", "soldier", "archer", "tower", "boat"]:
		sprites[key] = load("res://assets/sprites/%s.png" % key)
		images[key] = sprites[key].get_image()
	for species in SpeciesCatalog.DEFINITIONS:
		for variant in 4:
			var key := "%s_%s" % [species, variant]
			sprites[key] = load("res://assets/sprites/%s.png" % key)

func bind_world(state: WorldState) -> void:
	world = state
	terrain_cache.setup(state, tiles, biome_tiles, images)
	baked_revision = -1
	political_revision = -1
	political_texture = null
	display_positions.clear()
	selected_id = -1
	fit()

func fit() -> void:
	if world == null: return
	camera_center = Vector2(world.width, world.height) * TILE * 0.5
	zoom_level = 1.0
	camera_changed.emit(zoom_level)
	queue_redraw()

func map_area() -> Rect2:
	var is_compact := size.x < 1150 or size.y < 700
	var right_space := 285.0 if not is_compact else 18.0
	return Rect2(18, 100 if not is_compact else 70, maxf(400, size.x - right_space - 18), maxf(180, size.y - (325 if not is_compact else 272)))

func scale_factor() -> float:
	if world == null: return 1.0
	var a := map_area()
	return minf(a.size.x / (world.width * TILE), a.size.y / (world.height * TILE)) * zoom_level

func origin() -> Vector2:
	return map_area().get_center() - camera_center * scale_factor()

func screen_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(((p - origin()) / (scale_factor() * TILE)).floor())

func zoom_at(factor: float, point: Vector2) -> void:
	var before := (point - origin()) / scale_factor()
	zoom_level = clampf(zoom_level * factor, 0.65, 5.0)
	var after := (point - origin()) / scale_factor()
	camera_center += before - after
	_clamp_camera()
	camera_changed.emit(zoom_level)
	queue_redraw()

func _clamp_camera() -> void:
	camera_center.x = clampf(camera_center.x, 0, world.width * TILE)
	camera_center.y = clampf(camera_center.y, 0, world.height * TILE)

func _process(delta: float) -> void:
	if world == null: return
	if not reduced_motion: elapsed += delta
	if show_politics and political_revision != world.politics_revision: _bake_politics()
	rebuild_cooldown -= delta
	if baked_revision != world.terrain_revision and rebuild_cooldown <= 0:
		if baked_revision < 0: _bake()
		else:
			terrain_cache.scan()
			baked_revision = world.terrain_revision
		rebuild_cooldown = 0.12
	terrain_cache.flush(4)
	for u in world.units:
		var target := Vector2(u.x, u.y) * TILE
		var old: Vector2 = display_positions.get(u.id, target)
		display_positions[u.id] = target if reduced_motion else old.lerp(target, minf(1, delta * 12))
	# Keep rendering state bounded as entities are born and die.
	if display_positions.size() > world.units.size() + 32:
		var alive := {}
		for u in world.units: alive[u.id] = true
		for id in display_positions.keys():
			if not alive.has(id): display_positions.erase(id)
	for effect in fx: effect.life -= delta
	fx = fx.filter(func(e: Dictionary) -> bool: return e.life > 0)
	queue_redraw()

func _bake() -> void:
	terrain_cache.scan()
	terrain_cache.flush(54)
	baked_revision = world.terrain_revision

func _bake_politics() -> void:
	if world.territory.size() != world.terrain.size(): return
	var overlay := Image.create(world.width * 3, world.height * 3, false, Image.FORMAT_RGBA8)
	for i in world.territory.size():
		var owner := world.territory[i]
		if owner < 0: continue
		var color: Color = KingdomPolitics.COLORS[owner % KingdomPolitics.COLORS.size()]
		color.a = 0.32
		var p := Vector2i(i % world.width, i / world.width)
		overlay.fill_rect(Rect2i(p * 3, Vector2i(3, 3)), color)
		color.a = 0.9
		for d in WorldNavigation.DIRECTIONS:
			var n: Vector2i = p + d
			if world.contains(n.x, n.y) and world.territory[world.index(n.x, n.y)] == owner: continue
			var edge := Rect2i(p * 3, Vector2i(3, 1))
			if d.y > 0: edge.position.y += 2
			if d.x != 0: edge.size = Vector2i(1, 3); edge.position.x += 2 if d.x > 0 else 0
			overlay.fill_rect(edge, color)
	if political_texture == null: political_texture = ImageTexture.create_from_image(overlay)
	else: political_texture.update(overlay)
	political_revision = world.politics_revision

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("164b60"))
	for y in range(90, int(size.y), 45):
		for x in range(20, int(size.x), 68):
			draw_line(Vector2(x + posmod(y, 47), y), Vector2(x + posmod(y, 47) + 6, y), Color("21576a"), 1)
	if world == null or terrain_cache.textures.is_empty(): return
	var s := scale_factor()
	draw_set_transform(origin(), 0, Vector2.ONE * s)
	for id in terrain_cache.textures:
		var p := Vector2(terrain_cache.position(id) * TILE)
		if Rect2(origin() + p * s, Vector2.ONE * TerrainChunks.CELLS * TILE * s).intersects(Rect2(Vector2.ZERO, size)):
			draw_texture(terrain_cache.textures[id], p)
	if show_politics and political_texture != null: draw_texture_rect(political_texture, Rect2(Vector2.ZERO, Vector2(world.width, world.height) * TILE), false)
	for v in world.villages:
		if not v.alive: continue
		var p := Vector2(v.x, v.y) * TILE
		if show_villages and not show_politics:
			draw_circle(p + Vector2(8, 8), 106, Color(0.87, 0.81, 0.47, 0.10))
			draw_arc(p + Vector2(8, 8), 106, 0, TAU, 48, Color(0.89, 0.83, 0.55, 0.4), 1.5 / s)
		draw_texture(sprites.depot, p)
		if v.tower > 0: draw_texture(sprites.tower, p - Vector2(8, 24))
		elif v.fort_progress > 0: draw_rect(Rect2(p - Vector2(6, 10), Vector2(28, 24)), Color("d6c694"), false, 2)
		if v.kingdom >= 0:
			var flag: Color = KingdomPolitics.COLORS[v.kingdom % KingdomPolitics.COLORS.size()]
			draw_rect(Rect2(p + Vector2(8, 0), Vector2(7, 4)), flag)
		for i in v.sites:
			draw_texture(sprites.house, Vector2(i % world.width, i / world.width) * TILE - Vector2(8, 16))
		for i in v.farms:
			var plot := Vector2(i % world.width, i / world.width) * TILE
			draw_rect(Rect2(plot + Vector2(1, 1), Vector2(14, 14)), Color("6f5438"))
			for row in 3:
				var col := Color("bcd082") if world.crops[i] < 40 else Color("e9c96f")
				if world.crops[i] == 0: col = Color("98714b")
				draw_rect(Rect2(plot + Vector2(3 + row * 4, 3), Vector2(2, 3 + world.crops[i] / 8)), col)
		if v.build_site >= 0:
			var site := Vector2(v.build_site % world.width, v.build_site / world.width) * TILE
			draw_rect(Rect2(site, Vector2(16, 16)), Color("d6c694"), false, 2)
			draw_line(site, site + Vector2(16, 16), Color("a48660"), 2)
	for u in world.units:
		if u.army >= 0 and world.armies[u.army].boat.state == "sailing": continue
		var p: Vector2 = display_positions.get(u.id, Vector2(u.x, u.y) * TILE)
		if u.id == selected_id:
			draw_arc(p + Vector2(8, 9), 14, 0, TAU, 20, Color("e6d798"), 2 / s)
		if u.id == selected_id and not u.route.is_empty():
			var points := PackedVector2Array([p + Vector2(8, 8)])
			for cell in u.route: points.append(Vector2(cell % world.width, cell / world.width) * TILE + Vector2(8, 8))
			draw_polyline(points, Color(0.92, 0.84, 0.57, 0.5), 1 / s)
		draw_texture(sprites[("archer" if u.weapon == "bow" else "soldier") if u.army >= 0 else "%s_%s" % [u.species, Heredity.value(u, "coat")]], p)
		if u.army >= 0:
			var color: Color = KingdomPolitics.COLORS[world.armies[u.army].kingdom % KingdomPolitics.COLORS.size()]
			draw_circle(p + Vector2(8, 12), 3 / s, color)
			if u.health < 99: draw_line(p + Vector2(0, -2), p + Vector2(u.health * 0.16, -2), Color("ed9f7c"), 2 / s)
		if u.sickness > 0: draw_circle(p + Vector2(13, 1), 2.5 / s, Color("d6ad72"))
		if Heredity.record(world, u.id).get("favorite", false):
			draw_arc(p + Vector2(8, 8), 12, 0, TAU, 16, Color("f4db86"), 1.5 / s)
		if u.cargo > 0:
			var color: Color = {"wood": Color("aa7b4f"), "stone": Color("b7c9c7"), "food": Color("edcb73")}[u.cargo_type]
			draw_rect(Rect2(p + Vector2(11, 8), Vector2(5, 5)), color)
	for a in world.armies:
		if a.active and a.boat.state in ["boarding", "sailing"]:
			var p := Vector2(a.boat.x, a.boat.y) * TILE
			draw_texture(sprites.boat, p - Vector2(8, 16))
			draw_rect(Rect2(p + Vector2(0, -10), Vector2(6, 4)), KingdomPolitics.COLORS[a.kingdom % KingdomPolitics.COLORS.size()])
	for effect in world.battle_effects:
		var from := Vector2(effect.x, effect.y) * TILE + Vector2(8, 8)
		var to := Vector2(effect.tx, effect.ty) * TILE + Vector2(8, 8)
		if effect.kind == "arrow": draw_line(from, to, Color("f1d98c"), 1.5 / s)
		else:
			draw_line(to - Vector2(5, 5), to + Vector2(5, 5), Color("f2b58b"), 2 / s)
			draw_line(to + Vector2(-5, 5), to + Vector2(5, -5), Color("f2b58b"), 2 / s)
	for i in world.fire.size():
		if world.fire[i] > 0:
			var p := Vector2(i % world.width, i / world.width) * TILE
			draw_texture(sprites.fire, p + Vector2(0, sin(elapsed * 12 + i) * 2))
	for effect in fx:
		var col: Color = effect.color
		col.a = effect.life / 0.7
		draw_arc(Vector2(effect.cell) * TILE + Vector2(8, 8), (1 - effect.life / 0.7) * 60 + 6, 0, TAU, 32, col, 2 / s)
	if world.contains(hover_cell.x, hover_cell.y) and tool != "pan":
		var p := Vector2(hover_cell) * TILE + Vector2(8, 8)
		draw_circle(p, (brush + 0.5) * TILE, Color(0.95, 0.93, 0.73, 0.10))
		draw_arc(p, (brush + 0.5) * TILE, 0, TAU, 40, Color(0.94, 0.92, 0.75, 0.8), 1.4 / s)
	for vent in world.hazards:
		var p := Vector2(vent.cell % world.width, vent.cell / world.width) * TILE
		draw_circle(p + Vector2(8, 8), 9, Color("e8a160"))
		draw_circle(p + Vector2(8, 8), 4, Color("fff0a2"))
	draw_set_transform(Vector2.ZERO)
	var sky := EnvironmentSimulation.weather(world)
	if not reduced_motion and sky in [1, 3, 4]:
		var area := map_area()
		for n in 70:
			var p := area.position + Vector2(fposmod(n * 71.0 + elapsed * 18, area.size.x), fposmod(n * 47.0 + elapsed * (45 if sky == 3 else 150), area.size.y))
			if sky == 3: draw_circle(p, 1.5, Color(0.9, 0.95, 1, 0.65))
			else: draw_line(p, p + Vector2(-2, 7), Color(0.65, 0.84, 0.91, 0.4), 1)
	var name_rects: Array[Rect2] = []
	if show_villages:
		var font := ThemeDB.fallback_font
		for v in world.villages:
			if not v.alive: continue
			var p := origin() + Vector2(v.x * TILE, (v.y - 4) * TILE) * s
			var label: String = v.name
			if show_politics and v.kingdom >= 0 and world.kingdoms[v.kingdom].capital == v.id: label = world.kingdoms[v.kingdom].name
			var extent := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
			var plate := Rect2(p - Vector2(extent.x * 0.5 + 10, 16), extent + Vector2(20, 8))
			name_rects.append(plate)
			draw_style_box(_name_plate(), plate)
			draw_string(font, p - Vector2(extent.x * 0.5, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e4ddae"))

	# Screen-space banners remain legible at the world zoom level.
	for a in world.armies:
		if not a.active: continue
		var leader: Dictionary = {}
		for u in world.units:
			if u.army == a.id: leader = u; break
		if leader.is_empty(): continue
		var p := origin() + Vector2(leader.x * TILE, (leader.y - 2) * TILE) * s
		var label := "%s troops · %s%%" % [a.members.size(), a.morale]
		if a.capture > 0: label = "Capture %s%%" % (a.capture * 100 / MilitarySimulation.CAPTURE_TICKS)
		elif a.order == "return": label += " ↩"
		var font := ThemeDB.fallback_font
		var extent := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var anchor := p
		var plate := Rect2(p - Vector2(6, 15), extent + Vector2(12, 5))
		for attempt in 8:
			if not name_rects.any(func(other: Rect2) -> bool: return plate.intersects(other)): break
			p.y -= 24
			plate.position.y -= 24
		name_rects.append(plate)
		if p != anchor: draw_line(anchor, p, Color(0.8, 0.8, 0.6, 0.5), 1)
		draw_style_box(_name_plate(), plate)
		draw_string(font, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, KingdomPolitics.COLORS[a.kingdom % KingdomPolitics.COLORS.size()])

func _name_plate() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.17, 0.18, 0.87)
	style.set_corner_radius_all(4)
	return style

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION: return
	# Release even when the pointer finishes over UI, so drawing never sticks.
	if event is InputEventMouseButton and not event.pressed:
		mouse_down = false
		dragging_camera = false
	if event is InputEventScreenTouch and not event.pressed and fingers.has(event.index):
		# GUI input handles tap before its release is cleared on the next frame.
		call_deferred("_release_touch", event.index)

func _release_touch(index_value: int) -> void:
	fingers.erase(index_value)
	if fingers.is_empty(): multi_touch = false

func _gui_input(event: InputEvent) -> void:
	if world == null: return
	# Native Controls use emulated mouse clicks; the map owns raw touch gestures.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom_at(1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom_at(1 / 1.15, event.position)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			mouse_down = true
			dragging_camera = tool == "pan" or event.button_index != MOUSE_BUTTON_LEFT
			last_paint = Vector2i(-999, -999)
			if not dragging_camera: _apply(event.position)
	elif event is InputEventMouseMotion:
		hover_cell = screen_to_cell(event.position)
		if mouse_down:
			if dragging_camera:
				camera_center -= event.relative / scale_factor()
				_clamp_camera()
			else: _apply(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			fingers[event.index] = event.position
			if fingers.size() == 1:
				touch_origin = event.position
				last_paint = Vector2i(-999, -999)
			if fingers.size() == 2:
				multi_touch = true
				var points := fingers.values()
				previous_pinch = points[0].distance_to(points[1])
				previous_mid = (points[0] + points[1]) * 0.5
		elif fingers.has(event.index):
			if not multi_touch and tool != "pan": _apply(event.position)
			_release_touch(event.index)
	elif event is InputEventScreenDrag and fingers.has(event.index):
		fingers[event.index] = event.position
		if fingers.size() >= 2:
			var points := fingers.values()
			var distance: float = points[0].distance_to(points[1])
			var midpoint: Vector2 = (points[0] + points[1]) * 0.5
			camera_center -= (midpoint - previous_mid) / scale_factor()
			if previous_pinch > 8: zoom_at(distance / previous_pinch, midpoint)
			previous_pinch = distance
			previous_mid = midpoint
		elif not multi_touch:
			if tool == "pan":
				camera_center -= event.relative / scale_factor()
				_clamp_camera()
			elif event.position.distance_to(touch_origin) > 8: _apply(event.position)
	elif event is InputEventMagnifyGesture:
		zoom_at(event.factor, event.position)
	accept_event()

func _apply(point: Vector2) -> void:
	var cell := screen_to_cell(point)
	if not world.contains(cell.x, cell.y) or cell == last_paint: return
	if tool == "inspect":
		inspected.emit(cell)
	else:
		# Interpolate terrain strokes so fast gestures do not leave gaps.
		if tool.begins_with("terrain_") and last_paint.x != -999:
			var steps := maxi(absi(cell.x - last_paint.x), absi(cell.y - last_paint.y))
			for n in range(1, steps):
				applied.emit(tool, Vector2i(Vector2(last_paint).lerp(Vector2(cell), float(n) / steps).round()))
		applied.emit(tool, cell)
		if not tool.begins_with("terrain_"):
			if fx.size() >= 64: fx.pop_front()
			if not reduced_motion: fx.append({"cell": cell, "life": 0.7, "color": Color("a7d997") if tool != "meteor" else Color("edb47b")})
	last_paint = cell
	hover_cell = cell
