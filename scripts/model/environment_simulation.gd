class_name EnvironmentSimulation
extends RefCounted
## Bounded climate/vegetation/disease; all gameplay randomness belongs to the world.
const LAWS := ["weather", "seasons", "ages", "vegetation", "disease", "natural_disasters"]
const WEATHER := ["Clear", "Rain", "Drought", "Snow", "Storm"]
const SEASONS := ["Spring", "Summer", "Autumn", "Winter"]
const AGES := ["Age of Balance", "Age of Embers", "Age of Frost"]
const SEASON_TEMPERATURE := [0, 8, -2, -12]
const AGE_TEMPERATURE := [0, 12, -12]
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const MAX_HAZARDS := 8
var world: WorldState
func _init(w: WorldState) -> void: world = w
static func initialize(w: WorldState, legacy: bool = false) -> void:
	w.climate = {"weather": 0, "weather_left": 96, "season_clock": 0, "age_clock": 0, "disaster_clock": 0}
	w.climate_rng.seed = w.world_seed + 610031
	w.moisture.resize(w.width * w.height)
	w.snow.resize(w.width * w.height)
	w.snow.fill(0)
	w.hazards.clear()
	for i in w.moisture.size(): w.moisture[i] = BiomeCatalog.MOISTURE[w.biomes[i]] if w.elevation[i] == 1 else 0
	for law in LAWS: w.laws[law] = not legacy and law != "natural_disasters"
	# Vegetation was already active in old worlds; retain its base behavior.
	w.laws.vegetation = true
	for u in w.units: initialize_health(u)
static func initialize_health(u: Dictionary) -> void:
	u.sickness = 0
	u.immunity = 0
static func season(w: WorldState) -> int: return int(w.climate.season_clock) / 96 if w.laws.seasons else 0
static func age(w: WorldState) -> int: return int(w.climate.age_clock) / 1536 if w.laws.ages else 0
static func weather(w: WorldState) -> int: return int(w.climate.weather) if w.laws.weather else 0
static func temperature(w: WorldState, i: int) -> int:
	return BiomeCatalog.TEMPERATURE[w.biomes[i]] + SEASON_TEMPERATURE[season(w)] + AGE_TEMPERATURE[age(w)] + [0, -3, 10, -14, -5][weather(w)]
static func growth_interval(w: WorldState, i: int, crop: bool = false) -> int:
	if not w.laws.vegetation: return 0
	if not w.laws.weather and not w.laws.seasons and not w.laws.ages: return 2 if crop and w.biomes[i] == 6 else 1
	var temp := temperature(w, i)
	if temp < -4 or temp > 40 or (w.laws.weather and (w.moisture[i] < 16 or weather(w) == 2)): return 0
	return 2 if temp < 8 or temp > 30 or (crop and w.biomes[i] == 6) else 1
static func hunger_multiplier(w: WorldState, u: Dictionary) -> float:
	if not w.laws.weather and not w.laws.seasons and not w.laws.ages: return 1.0
	var temp := temperature(w, w.index(u.x, u.y))
	if temp < 0: return 1.0 if Heredity.value(u, "habitat") == 3 else 1.25
	return 1.125 if temp > 32 else 1.0
static func health_text(w: WorldState, u: Dictionary) -> String:
	if not w.laws.disease: return "Disease paused" + (" · Rustfever %s ticks left" % u.sickness if u.sickness > 0 else "")
	if u.sickness > 0: return "Rustfever · %s ticks to recovery" % u.sickness
	if u.immunity > 0: return "Rustfever immunity · %s ticks left" % u.immunity
	return "No active illness"
static func set_weather(w: WorldState, kind: int) -> bool:
	if kind < 0 or kind >= WEATHER.size() or not w.laws.weather: return false
	w.climate.weather = kind
	w.climate.weather_left = 144
	w.add_event("%s arrives. Watch the land and its harvests." % WEATHER[kind], "climate")
	return true
static func preset(w: WorldState, name: String) -> bool:
	if name not in ["Living planet", "Peaceful", "Catastrophe"]: return false
	for law in LAWS: w.laws[law] = true
	w.laws.natural_disasters = name == "Catastrophe"
	w.laws.disease = name != "Peaceful"
	w.laws.fire_spread = name != "Peaceful"
	w.laws.hunger = name != "Peaceful"
	w.laws.old_age = name != "Peaceful"
	w.add_event("World laws changed: %s." % name, "climate")
	return true
func step() -> void:
	_climate()
	_land()
	_hazards()
func _climate() -> void:
	if world.laws.seasons:
		world.climate.season_clock = (world.climate.season_clock + 1) % 384
		if world.climate.season_clock % 96 == 0: world.add_event("%s returns to the world." % SEASONS[season(world)], "climate")
	if world.laws.ages:
		world.climate.age_clock = (world.climate.age_clock + 1) % 4608
		if world.climate.age_clock % 1536 == 0: world.add_event("The %s begins." % AGES[age(world)], "climate")
	if world.laws.weather:
		world.climate.weather_left -= 1
		if world.climate.weather_left <= 0:
			var roll := world.climate_rng.randi_range(0, 99)
			var kind := 0
			if roll < 35: kind = 1
			elif roll < 50: kind = 2
			elif roll < 58: kind = 4
			if season(world) == 3 and kind == 1: kind = 3
			if age(world) == 1 and roll < 30: kind = 2
			if age(world) == 2 and roll < 40: kind = 3
			set_weather(world, kind)
			world.climate.weather_left = world.climate_rng.randi_range(96, 192)
	if world.laws.natural_disasters:
		world.climate.disaster_clock = (world.climate.disaster_clock + 1) % 192
		if world.climate.disaster_clock == 0 and world.climate_rng.randi_range(0, 3) == 0:
			var p := world.find_land(Vector2i(world.climate_rng.randi_range(12, world.width - 12), world.climate_rng.randi_range(12, world.height - 12)))
			if world.contains(p.x, p.y): disaster(world, p, ["lightning", "quake", "volcano"][world.climate_rng.randi_range(0, 2)])
		elif weather(world) == 4 and world.tick % 24 == 0:
			var p := Vector2i(world.climate_rng.randi_range(0, world.width - 1), world.climate_rng.randi_range(0, world.height - 1))
			if world.habitable(p.x, p.y): disaster(world, p, "lightning")
func _land() -> void:
	var sky := weather(world)
	for i in range(world.tick % 8, world.terrain.size(), 8):
		if world.elevation[i] != 1: continue
		var biome := world.biomes[i]
		if world.laws.weather:
			var delta := 10 if sky in [1, 4] else (-8 if sky == 2 else (-1 if biome not in [5, 6] else 1))
			world.moisture[i] = clampi(world.moisture[i] + delta, 0, 100)
			if sky in [1, 4]: world.fire[i] = 0
			var before := world.snow[i]
			if sky == 3 and temperature(world, i) < 3: world.snow[i] = mini(8, before + 2); world.fire[i] = 0
			elif before > 0 and temperature(world, i) > 0:
				world.snow[i] -= 1
				world.moisture[i] = mini(100, world.moisture[i] + 3)
			if (before == 0) != (world.snow[i] == 0): world.terrain_revision += 1
		var interval := growth_interval(world, i)
		if interval == 0 or world.fire[i] > 0: continue
		if world.farm_owner[i] < 0:
			var amount: float = BiomeCatalog.FORAGE[biome] / interval
			if sky in [1, 4]: amount *= 1.5
			world.food[i] = minf(BiomeCatalog.FOOD_CAP[biome], world.food[i] + amount)
			if world.trees[i] < BiomeCatalog.TREE_CAP[biome] and world.stone[i] == 0:
				# A tree spreads into adjacent empty tiles; woods can also regenerate locally.
				var source := biome in [2, 5, 6] or world.trees[i] > 0
				if not source:
					for d in DIRECTIONS:
						var p: Vector2i = Vector2i(i % world.width, i / world.width) + d
						if world.contains(p.x, p.y) and world.trees[world.index(p.x, p.y)] > 0: source = true; break
				if source:
					world.tree_growth[i] += 8 / interval
					if world.tree_growth[i] >= BiomeCatalog.TREE_PERIOD[biome]:
						world.tree_growth[i] = 0
						world.trees[i] += 1
						if world.trees[i] == 1: world.terrain_revision += 1
	var spread: Array[int] = []
	for i in world.fire.size():
		if world.crops[i] > 0 and world.crops[i] < WorldState.CROP_MATURE and world.fire[i] == 0:
			var interval := growth_interval(world, i, true)
			if interval > 0 and world.tick % interval == 0: world.crops[i] = mini(WorldState.CROP_MATURE, world.crops[i] + (2 if sky == 1 else 1))
		if world.fire[i] == 0: continue
		world.fire[i] -= 1
		world.food[i] = 0
		world.trees[i] = 0
		world.crops[i] = 0
		if world.fire[i] == 0:
			# Burn vegetation without changing the coastline, biome, buildings, or ownership.
			world.tree_growth[i] = 0
		elif world.laws.fire_spread and world.rng.randf() < (0.4 if sky == 2 or age(world) == 1 else 0.27):
			var d: Vector2i = DIRECTIONS[world.rng.randi_range(0, 3)]
			var p := Vector2i(i % world.width, i / world.width) + d
			if world.fertile(p.x, p.y) and world.fire[world.index(p.x, p.y)] == 0: spread.append(world.index(p.x, p.y))
		world.terrain_revision += 1
	for i in spread: world.fire[i] = 9
func diseases(spatial: SpatialIndex, navigation: WorldNavigation) -> void:
	if not world.laws.disease: return
	var exposed := {}
	for u in world.units:
		if u.health <= 0: continue
		if u.immunity > 0: u.immunity -= 1
		if u.sickness <= 0: continue
		u.sickness -= 1
		u.health -= 0.5 if u.hunger > 60 else 0.25
		if u.sickness == 0:
			u.immunity = 192
			Heredity.event(world, u.id, "Recovered from Rustfever; immunity will last four years.", "recovery")
		elif world.tick % 8 == 0:
			for other in spatial.nearby(Vector2i(u.x, u.y), 2):
				if other.id == u.id or other.health <= 0 or other.sickness > 0 or other.immunity > 0 or other.species != u.species: continue
				if navigation.connected(Vector2i(u.x, u.y), Vector2i(other.x, other.y)) and world.climate_rng.randi_range(0, 3) == 0: exposed[other.id] = other
	if world.tick % 96 == 0:
		for u in world.units:
			if world.biomes[world.index(u.x, u.y)] == 5 and world.climate_rng.randi_range(0, 127) == 0: exposed[u.id] = u
	for u in exposed.values(): infect(world, u)
static func infect(w: WorldState, u: Dictionary) -> bool:
	if not w.laws.disease or u.health <= 0 or u.sickness > 0 or u.immunity > 0: return false
	u.sickness = 64
	Heredity.event(w, u.id, "Contracted Rustfever. Nearby creatures of the same species may catch it.", "illness")
	return true
static func disaster(w: WorldState, center: Vector2i, kind: String) -> bool:
	if not w.contains(center.x, center.y) or kind not in ["lightning", "quake", "volcano"]: return false
	if kind == "volcano" and w.hazards.any(func(vent: Dictionary) -> bool: return vent.cell == w.index(center.x, center.y)): return false
	if kind == "volcano" and (w.hazards.size() >= MAX_HAZARDS or not w.habitable(center.x, center.y)): return false
	var radius := 1 if kind == "lightning" else 3
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not w.habitable(x, y) or Vector2i(x, y).distance_squared_to(center) > radius * radius: continue
			var i := w.index(x, y)
			if kind == "quake":
				w.set_material(i, WorldState.Terrain.SAND, false)
			elif w.fertile(x, y): w.fire[i] = 9
	for u in w.units:
		if Vector2i(u.x, u.y).distance_squared_to(center) <= radius * radius: u.health = maxf(0, u.health - (35 if kind == "lightning" else 55))
	if kind == "volcano":
		w.set_material(w.index(center.x, center.y), WorldState.Terrain.MOUNTAIN, false)
		w.hazards.append({"cell": w.index(center.x, center.y), "remaining": 24})
	w.add_event({"lightning": "Lightning strikes the land.", "quake": "An earthquake levels fields and homes.", "volcano": "A volcano rises; six pulses of embers will follow."}[kind], "disaster")
	w.terrain_revision += 1
	return true
func _hazards() -> void:
	# Active eruptions are finite consequences of interventions, independent of spontaneous-disaster law.
	for vent in world.hazards:
		vent.remaining -= 1
		if vent.remaining % 4 != 0: continue
		var center := Vector2i(vent.cell % world.width, vent.cell / world.width)
		var p := center + Vector2i(world.climate_rng.randi_range(-3, 3), world.climate_rng.randi_range(-3, 3))
		if not world.habitable(p.x, p.y): continue
		var i := world.index(p.x, p.y)
		if world.fertile(p.x, p.y): world.fire[i] = 9
		for u in world.units:
			if Vector2i(u.x, u.y).distance_squared_to(p) <= 1: u.health = maxf(0, u.health - 12)
		world.terrain_revision += 1
	world.hazards = world.hazards.filter(func(vent: Dictionary) -> bool: return vent.remaining > 0)
