class_name WorldState
extends RefCounted
## Serializable simulation data. No scene nodes and no rendering dependencies.

enum Terrain { OCEAN, SAND, MEADOW, FOREST, MOUNTAIN, SNOW }
enum Elevation { WATER, LOWLAND, PEAK }
enum Biome { BARREN, GRASSLAND, WOODLAND, TUNDRA, ARID, WETLAND, GLIMMERGROVE }
const WIDTH := 144
const HEIGHT := 96
const MAX_UNITS := 350
const TERRAIN_NAMES := ["Ocean", "Sand", "Meadow", "Forest", "Mountain", "Snow"]
const PALETTE := [Color("164b60"), Color("d9c28b"), Color("7b9d52"), Color("48744b"), Color("7a8990"), Color("d7e6df")]
const WORLD_NAMES := ["The Quiet Isles", "Aurelian Reach", "The Emerald Drift", "Larkspur Atoll", "The Sleeping Coast", "Mosslight Haven"]
var width: int = WIDTH
var height: int = HEIGHT
var world_seed: int = 41827
var world_name: String = WORLD_NAMES[0]
var terrain := PackedByteArray()
var food := PackedFloat32Array()
var fire := PackedByteArray()
# Terrain remains the six-brush presentation cache. These independent layers
# drive navigation, vegetation, harvesting, and agriculture.
var elevation := PackedByteArray()
var biomes := PackedByteArray()
var trees := PackedByteArray()
var tree_growth := PackedInt32Array()
var stone := PackedByteArray()
var crops := PackedByteArray()
var farm_owner := PackedInt32Array()
var moisture := PackedByteArray()
var snow := PackedByteArray()
var climate := {}
var climate_rng := RandomNumberGenerator.new()
var hazards: Array[Dictionary] = []
var units: Array[Dictionary] = []
var villages: Array[Dictionary] = []
var events: Array[Dictionary] = []
var kingdoms: Array[Dictionary] = []
var relations: Array[Dictionary] = []
var expeditions: Array[Dictionary] = []
var armies: Array[Dictionary] = []
var lineage: Array[Dictionary] = []
var cultures: Array[Dictionary] = []
var clans: Array[Dictionary] = []
var languages: Array[Dictionary] = []
var beliefs: Array[Dictionary] = []
var society_history: Array[Dictionary] = []
var ruler_history: Array[Dictionary] = []
var discoveries: Array[Dictionary] = []
var society_samples: Array[Dictionary] = []
var society_ready := false
var lineage_index := {} # Derived lookup, not a second saved family tree.
# Transient, bounded combat cues; gameplay never reads these.
var battle_effects: Array[Dictionary] = []
var territory := PackedInt32Array()
var politics_revision := 0
var tick: int = 0
var next_id: int = 1
var rng := RandomNumberGenerator.new()
var laws := {"hunger": true, "births": true, "fire_spread": true, "old_age": true, "expansion": true, "diplomacy": true}
var terrain_revision: int = 0
var navigation_revision: int = 0

const CROP_MATURE := 64
const HOUSE_WOOD := 12
const HOUSE_STONE := 4
const MAX_HOUSES := 8
const CAMP_CAPACITY := 12

func housing(village: Dictionary) -> int:
	return CAMP_CAPACITY + village.houses * 4

func storage(village: Dictionary) -> int:
	return 80 + village.houses * 16

func index(x: int, y: int) -> int:
	return y * width + x

func contains(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

func habitable(x: int, y: int) -> bool:
	return contains(x, y) and elevation[index(x, y)] == Elevation.LOWLAND

func fertile(x: int, y: int) -> bool:
	return habitable(x, y) and biomes[index(x, y)] in BiomeCatalog.FERTILE

func year() -> int:
	return 1 + tick / 48

func add_event(message: String, kind: String = "world") -> void:
	events.push_front({"year": year(), "text": message, "kind": kind})
	if events.size() > 60:
		events.resize(60)

func generate(seed_value: int, style: int = 0, populate: bool = true) -> void:
	world_seed = seed_value
	world_name = WORLD_NAMES[posmod(seed_value, WORLD_NAMES.size())]
	rng.seed = seed_value
	tick = 0
	next_id = 1
	units.clear()
	lineage.clear()
	lineage_index.clear()
	villages.clear()
	kingdoms.clear()
	relations.clear()
	expeditions.clear()
	armies.clear()
	battle_effects.clear()
	territory.resize(width * height)
	territory.fill(-1)
	politics_revision += 1
	events.clear()
	terrain.resize(width * height)
	food.resize(width * height)
	fire.resize(width * height)
	fire.fill(0)
	_resize_layers()
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.037 if style == 0 else 0.058
	noise.fractal_octaves = 4
	var climate := FastNoiseLite.new()
	climate.seed = seed_value + 109
	climate.frequency = 0.057
	for y in height:
		for x in width:
			var p := Vector2(float(x) / width, float(y) / height)
			# A smooth island mask leaves ocean around the playable world.
			var a := 1.0 - (p - Vector2(0.34, 0.49)).length() / 0.37
			var b := 1.0 - (p - Vector2(0.69, 0.43)).length() / 0.29
			var c := 1.0 - (p - Vector2(0.66, 0.77)).length() / 0.16
			var shape := maxf(maxf(a, b), c)
			var h := noise.get_noise_2d(x, y) * 0.80 + shape * 0.73
			if style == 2:
				h = 0.56 + noise.get_noise_2d(x, y) * 0.20 - maxf(0, absf(p.x - 0.5) - 0.36) * 4 - maxf(0, absf(p.y - 0.5) - 0.28) * 4
			if style == 1:
				h -= 0.13
			var biome := climate.get_noise_2d(x, y)
			var tile := Terrain.OCEAN
			if h > 0.20: tile = Terrain.SAND
			if h > 0.27: tile = Terrain.MEADOW
			if h > 0.32 and biome > -0.05: tile = Terrain.FOREST
			if h > 0.62 and biome < 0.18: tile = Terrain.MOUNTAIN
			if h > 0.77: tile = Terrain.SNOW
			var i := index(x, y)
			terrain[i] = tile
			food[i] = rng.randf_range(5.0, 13.0) if tile in [Terrain.MEADOW, Terrain.FOREST] else 0.0
	initialize_layers()
	# Climate geography is a separate layer: it never turns water into walkable land.
	for i in terrain.size():
		if elevation[i] != Elevation.LOWLAND or biomes[i] == Biome.TUNDRA: continue
		var value := climate.get_noise_2d(i % width + 231, i / width - 119)
		if value > 0.32: biomes[i] = Biome.ARID
		elif value < -0.32: biomes[i] = Biome.GLIMMERGROVE
		elif value < -0.19: biomes[i] = Biome.WETLAND
		food[i] = minf(food[i], BiomeCatalog.FOOD_CAP[biomes[i]])
		_seed_resources(i)
	EnvironmentSimulation.initialize(self)
	SocietySimulation.initialize(self)
	if style == 2: world_name = "The Three Frontiers"
	add_event("A new world stirs beneath your fingertips.")
	if populate:
		var centers := [Vector2i(40, 48), Vector2i(68, 48), Vector2i(96, 48)] if style == 2 else [Vector2i(width * 0.35, height * 0.48)]
		for center in centers:
			var home := find_land(center, true)
			for n in 12:
				var scatter := 2 if style == 2 else 5
				spawn("settler", find_land(home + Vector2i(rng.randi_range(-scatter, scatter), rng.randi_range(-scatter, scatter))))
		for n in 22:
			spawn("deer" if n % 3 == 0 else "rabbit", find_land(Vector2i(rng.randi_range(12, width - 12), rng.randi_range(12, height - 12))))
	terrain_revision += 1
	navigation_revision += 1

func _resize_layers() -> void:
	var count := width * height
	elevation.resize(count)
	biomes.resize(count)
	trees.resize(count)
	tree_growth.resize(count)
	stone.resize(count)
	crops.resize(count)
	farm_owner.resize(count)
	trees.fill(0)
	tree_growth.fill(0)
	stone.fill(0)
	crops.fill(0)
	farm_owner.fill(-1)

func initialize_layers() -> void:
	_resize_layers()
	for i in terrain.size():
		_material_layers(i)
		_seed_resources(i)

func _material_layers(i: int) -> void:
	elevation[i] = Elevation.WATER if terrain[i] == Terrain.OCEAN else (Elevation.PEAK if terrain[i] == Terrain.MOUNTAIN else Elevation.LOWLAND)
	biomes[i] = {Terrain.MEADOW: Biome.GRASSLAND, Terrain.FOREST: Biome.WOODLAND, Terrain.SNOW: Biome.TUNDRA}.get(terrain[i], Biome.BARREN)

func _seed_resources(i: int) -> void:
	var x := i % width
	var y := i / width
	var variation := posmod(hash(Vector3i(x, y, world_seed)), 101)
	trees[i] = BiomeCatalog.TREE_CAP[biomes[i]] if (biomes[i] in [Biome.WOODLAND, Biome.WETLAND, Biome.GLIMMERGROVE] and variation < 52) or (biomes[i] == Biome.GRASSLAND and variation < 6) else 0
	stone[i] = 24 if elevation[i] == Elevation.LOWLAND and variation > 95 else 0

func set_material(i: int, material: int, renew: bool = true) -> void:
	var old_elevation := elevation[i]
	terrain[i] = material
	_material_layers(i)
	trees[i] = 0
	tree_growth[i] = 0
	stone[i] = 0
	crops[i] = 0
	farm_owner[i] = -1
	fire[i] = 0
	for v in villages:
		if i in v.farms: v.farms.erase(i)
		if i in v.sites: v.sites.erase(i); v.houses = v.sites.size()
		if v.build_site == i: v.build_site = -1; v.build_progress = 0
	food[i] = 10.0 if material in [Terrain.MEADOW, Terrain.FOREST] and renew else 0.0
	if moisture.size() == terrain.size(): moisture[i] = BiomeCatalog.MOISTURE[biomes[i]] if elevation[i] == 1 else 0; snow[i] = 0
	if renew: _seed_resources(i)
	if elevation[i] != old_elevation: navigation_revision += 1
	terrain_revision += 1

func fill_material(material: int) -> void:
	for i in terrain.size(): set_material(i, material)

static func initialize_work(u: Dictionary) -> void:
	u.merge({"job": "idle", "target": -1, "route": [], "route_revision": -1, "cargo_type": "", "cargo": 0, "work": 0, "think_after": 0, "expedition": -1, "army": -1, "weapon": "", "attack_after": 0}, false)

func create_village(p: Vector2i) -> Dictionary:
	var names := ["Willowmere", "Dawnrest", "Fernhaven", "Starfall", "Oak & Ember", "Mossbridge"]
	var id := villages.size()
	var v := {"id": id, "name": names[id % names.size()] + (" %s" % (id / names.size() + 1) if id >= names.size() else ""), "x": p.x, "y": p.y, "wood": 0, "stone": 0, "food": 0, "houses": 0, "population": 0, "alive": true, "sites": [], "farms": [], "build_site": -1, "build_progress": 0, "shortage": false, "history": [], "jobs": {}, "births": 0, "deaths": 0, "gathered_wood": 0, "gathered_stone": 0, "harvested": 0, "consumed": 0}
	v.merge({"kingdom": -1, "loyalty": 75, "loyalty_reason": "A new beginning", "expansion_after": tick + 240, "expansion_reason": "Establishing the village"})
	v.merge({"tower": 0, "fort_progress": 0, "muster_after": 0})
	villages.append(v)
	add_event("%s was founded. A small beginning." % v.name, "village")
	return v

func find_land(near: Vector2i, needs_food: bool = false) -> Vector2i:
	for radius in range(0, maxi(width, height)):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if radius > 0 and absi(dx) != radius and absi(dy) != radius: continue
				var p := near + Vector2i(dx, dy)
				if fertile(p.x, p.y) if needs_food else habitable(p.x, p.y):
					return p
	return Vector2i(-1, -1)

func spawn(species: String, p: Vector2i, newborn: bool = false, parents: Array = []) -> bool:
	if not species in SpeciesCatalog.DEFINITIONS or not habitable(p.x, p.y) or units.size() >= MAX_UNITS or lineage.size() >= Heredity.MAX_RECORDS: return false
	if not parents.is_empty() and (not newborn or not Heredity.can_parent(self, parents, species)): return false
	var names := ["Ari", "Fern", "Rowan", "Nell", "Ember", "Sage", "Lumi", "Ash", "Wren", "Milo", "Clover", "Iris"]
	units.append({"id": next_id, "species": species, "name": names[rng.randi_range(0, names.size() - 1)], "x": p.x, "y": p.y, "age": 0 if newborn else rng.randi_range(SpeciesCatalog.maturity(species) + 2, SpeciesCatalog.maturity(species) + 12), "health": 100.0, "hunger": 10.0, "cooldown": rng.randi_range(10, 30), "village": -1, "state": "Exploring"})
	initialize_work(units[-1])
	EnvironmentSimulation.initialize_health(units[-1])
	Heredity.register(self, units[-1], parents)
	SocietySimulation.register(self, units[-1], parents)
	next_id += 1
	return true

func paint(center: Vector2i, radius: int, tile: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not contains(x, y) or Vector2(x - center.x, y - center.y).length() > radius + 0.3: continue
			var i := index(x, y)
			set_material(i, tile)
	terrain_revision += 1

func set_biome(i: int, biome: int) -> bool:
	if i < 0 or i >= terrain.size() or biome < 0 or biome >= BiomeCatalog.NAMES.size() or elevation[i] == Elevation.WATER: return false
	biomes[i] = biome
	food[i] = minf(food[i], BiomeCatalog.FOOD_CAP[biome])
	trees[i] = mini(trees[i], BiomeCatalog.TREE_CAP[biome]) if elevation[i] == Elevation.LOWLAND else 0
	tree_growth[i] = 0
	if biome not in BiomeCatalog.FERTILE:
		crops[i] = 0
		farm_owner[i] = -1
		for v in villages: v.farms.erase(i)
	terrain_revision += 1
	return true

func paint_biome(center: Vector2i, radius: int, biome: int) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if contains(x, y) and Vector2(x - center.x, y - center.y).length() <= radius + 0.3: set_biome(index(x, y), biome)

func power(center: Vector2i, radius: int, kind: String) -> void:
	if kind in ["lightning", "quake", "volcano"]:
		EnvironmentSimulation.disaster(self, center, kind)
		return
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if not contains(x, y) or Vector2(x - center.x, y - center.y).length() > radius + 0.3: continue
			var i := index(x, y)
			if kind == "rain":
				fire[i] = 0
				moisture[i] = mini(100, moisture[i] + 32) if elevation[i] == 1 else 0
				snow[i] = 0
				if fertile(x, y): food[i] = minf(food[i] + 7.0, 20.0)
				if crops[i] > 0: crops[i] = mini(CROP_MATURE, crops[i] + 8)
			elif kind == "fire" and fertile(x, y): fire[i] = 9
			elif kind == "meteor":
				set_material(i, Terrain.SAND, false)
	for unit in units:
		if Vector2(unit.x - center.x, unit.y - center.y).length() <= radius + 1:
			if kind == "bless": unit.health = 100.0; unit.hunger = 0.0
			if kind == "meteor": unit.health = 0.0
			if kind == "plague": EnvironmentSimulation.infect(self, unit)
	if kind == "meteor":
		add_event("A falling star reshaped the coast.", "disaster")
	terrain_revision += 1

func population(species: String = "") -> int:
	if species.is_empty(): return units.size()
	var count := 0
	for u in units:
		if u.species == species: count += 1
	return count
