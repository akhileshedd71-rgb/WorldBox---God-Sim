class_name SaveStore
extends RefCounted
## Versioned JSON, validated completely before replacing the current world.
const VERSION := 7
const MANUAL_PATH := "user://world.json"
const AUTO_PATH := "user://autosave.json"
const MAX_BYTES := 8000000

static func encode(w: WorldState) -> Dictionary:
	var data := {"version": VERSION, "width": w.width, "height": w.height, "seed": w.world_seed, "name": w.world_name, "tick": w.tick, "next_id": w.next_id, "rng_state": str(w.rng.state), "terrain": Array(w.terrain), "food": Array(w.food), "fire": Array(w.fire), "units": w.units, "villages": w.villages, "events": w.events, "laws": w.laws}

	for key in ["elevation", "biomes", "trees", "tree_growth", "stone", "crops", "farm_owner"]: data[key] = Array(w.get(key))
	data.navigation_revision = w.navigation_revision
	data.climate = w.climate
	data.climate_rng_state = str(w.climate_rng.state)
	data.moisture = Array(w.moisture)
	data.snow = Array(w.snow)
	data.hazards = w.hazards
	for key in ["kingdoms", "relations", "expeditions", "armies", "lineage"]: data[key] = w.get(key)
	for key in SocietyPersistence.ARRAYS: data[key] = w.get(key)
	return data

static func _valid_file(data: Variant) -> bool:
	return decode(data).has("world")

static func save_world(w: WorldState, path: String = MANUAL_PATH) -> Error:
	return SafeFiles.write_json(path, encode(w), _valid_file)

static func load_world(path: String = MANUAL_PATH) -> Dictionary:
	var result := SafeFiles.read_json(path, _valid_file, MAX_BYTES)
	if result.has("error"): return result
	var decoded := decode(result.data)
	decoded.recovered = result.recovered
	decoded.source = result.source
	return decoded

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func _integer(value: Variant, low: float, high: float) -> bool:
	return _number(value, low, high) and float(value) == floorf(float(value))

static func decode(value: Variant) -> Dictionary:
	var bad := {"error": "Unsupported or damaged save. Your current world is unchanged."}
	if not value is Dictionary: return bad
	var d: Dictionary = value.duplicate(true)
	if not _integer(d.get("version"), 1, VERSION) or d.get("width") != WorldState.WIDTH or d.get("height") != WorldState.HEIGHT: return bad
	if not d.get("name") is String or d.name.length() > 100: return bad
	if not _integer(d.get("seed"), 0, 2147483647) or not _integer(d.get("tick"), 0, 2147483647) or not _integer(d.get("next_id"), 1, 2147483647): return bad
	if not d.get("rng_state") is String or not d.rng_state.is_valid_int(): return bad
	var count := WorldState.WIDTH * WorldState.HEIGHT
	for key in ["terrain", "food", "fire"]:
		if not d.get(key) is Array or d[key].size() != count: return bad
	for i in count:
		if not _integer(d.terrain[i], 0, 5) or not _number(d.food[i], 0, 20) or not _integer(d.fire[i], 0, 9): return bad
	if not d.get("units") is Array or d.units.size() > WorldState.MAX_UNITS: return bad
	if not d.get("villages") is Array or d.villages.size() > 1000: return bad
	var ids := {}
	for u in d.units:
		if not u is Dictionary: return bad
		if not _integer(u.get("id"), 1, d.next_id - 1) or ids.has(u.id): return bad
		ids[u.id] = true
		if not u.get("species") in SpeciesCatalog.DEFINITIONS: return bad
		if not u.get("name") is String or not u.get("state") is String: return bad
		if u.name.length() > 80 or u.state.length() > 80: return bad
		if not _integer(u.get("x"), 0, WorldState.WIDTH - 1) or not _integer(u.get("y"), 0, WorldState.HEIGHT - 1): return bad
		if not _number(u.get("health"), -1000, 100) or not _number(u.get("hunger"), 0, 100): return bad
		if not _integer(u.get("age"), 0, 10000000) or not _integer(u.get("cooldown"), 0, 10000): return bad
		if not _integer(u.get("village"), -1, d.villages.size() - 1): return bad
	for n in d.villages.size():
		var v: Variant = d.villages[n]
		if not v is Dictionary or v.get("id") != n: return bad
		if not v.get("name") is String or v.name.length() > 100 or not v.get("alive") is bool: return bad
		if not _integer(v.get("x"), 0, WorldState.WIDTH - 1) or not _integer(v.get("y"), 0, WorldState.HEIGHT - 1): return bad
		for key in ["wood", "food", "houses", "population"]:
			if not _number(v.get(key), 0, 100000000): return bad
	if not d.get("events") is Array or d.events.size() > 60: return bad
	for e in d.events:
		if not e is Dictionary or not e.get("text") is String or not e.get("kind") is String or not _integer(e.get("year"), 1, 100000000): return bad
		if e.text.length() > 300: return bad
	if not d.get("laws") is Dictionary: return bad
	for key in ["hunger", "births", "fire_spread", "old_age"]:
		if not d.laws.get(key) is bool: return bad
	if d.version >= 2 and not _validate_v2(d): return bad
	if d.version >= 3 and not PoliticsPersistence.validate(d): return bad
	if d.version >= 4 and not MilitaryPersistence.validate(d): return bad
	if d.version >= 5 and not HeredityPersistence.validate(d): return bad
	if d.version >= 6 and not EnvironmentPersistence.validate(d): return bad
	if d.version >= 7 and not SocietyPersistence.validate(d): return bad
	var w := WorldState.new()
	w.world_seed = int(d.seed)
	w.world_name = d.name
	w.tick = int(d.tick)
	w.next_id = int(d.next_id)
	w.terrain = PackedByteArray(d.terrain)
	w.food = PackedFloat32Array(d.food)
	w.fire = PackedByteArray(d.fire)
	w.laws = d.laws.duplicate(true)
	for u in d.units:
		for key in ["id", "x", "y", "age", "cooldown", "village"]: u[key] = int(u[key])
		w.units.append(u.duplicate(true))
	for v in d.villages:
		for key in ["id", "x", "y", "houses", "population"]: v[key] = int(v[key])
		w.villages.append(v.duplicate(true))
	for e in d.events:
		e.year = int(e.year)
		w.events.append(e.duplicate(true))
	if d.version == 1:
		_migrate_v1(w)
	else:
		for key in ["elevation", "biomes", "trees", "stone", "crops"]: w.set(key, PackedByteArray(d[key]))
		w.tree_growth = PackedInt32Array(d.tree_growth)
		w.farm_owner = PackedInt32Array(d.farm_owner)
		w.navigation_revision = int(d.navigation_revision)
		for u in w.units:
			for key in ["target", "route_revision", "cargo", "work", "think_after"]: u[key] = int(u[key])
			u.route = u.route.map(func(i: Variant) -> int: return int(i))
		for v in w.villages:
			for key in ["wood", "stone", "food", "build_site", "build_progress", "births", "deaths", "gathered_wood", "gathered_stone", "harvested", "consumed"]: v[key] = int(v[key])
			for key in ["sites", "farms"]: v[key] = v[key].map(func(i: Variant) -> int: return int(i))
			for key in v.jobs: v.jobs[key] = int(v.jobs[key])
			for sample in v.history:
				for key in ["year", "population", "food", "housing"]: sample[key] = int(sample[key])
	if d.version < 3: PoliticsPersistence.migrate(w)
	else: PoliticsPersistence.restore(w, d)
	if d.version < 4: MilitaryPersistence.migrate(w)
	else: MilitaryPersistence.restore(w, d)
	if d.version < 5: HeredityPersistence.migrate(w)
	else: HeredityPersistence.restore(w, d)
	if d.version < 6: EnvironmentSimulation.initialize(w, true)
	else: EnvironmentPersistence.restore(w, d)
	if d.version < 7: SocietySimulation.initialize(w, true)
	else: SocietyPersistence.restore(w, d)
	w.rng.seed = w.world_seed
	w.rng.state = d.rng_state.to_int()
	w.terrain_revision += 1
	return {"world": w}

static func _indices(value: Variant, limit: int, unique: bool = false) -> bool:
	if not value is Array or value.size() > limit: return false
	var seen := {}
	for i in value:
		if not _integer(i, 0, WorldState.WIDTH * WorldState.HEIGHT - 1) or (unique and seen.has(i)): return false
		seen[i] = true
	return true

static func _validate_v2(d: Dictionary) -> bool:
	var count := WorldState.WIDTH * WorldState.HEIGHT
	if not _integer(d.get("navigation_revision"), 0, 2147483647): return false
	for v in d.villages:
		if not _indices(v.get("farms"), 14, true): return false
		v.farms = v.farms.map(func(i: Variant) -> int: return int(i))
	var bounds := {"elevation": 2, "biomes": 6 if d.version >= 6 else 3, "trees": 12, "tree_growth": 191, "stone": 24, "crops": 64, "farm_owner": d.villages.size() - 1}
	for key in bounds:
		if not d.get(key) is Array or d[key].size() != count: return false
		for i in d[key]:
			if not _integer(i, -1 if key == "farm_owner" else 0, bounds[key]): return false
	for i in count:
		var material: int = int(d.terrain[i])
		var expected_elevation := 0 if material == 0 else (2 if material == 4 else 1)
		var expected_biome: int = {2: 1, 3: 2, 5: 3}.get(material, 0)
		if d.elevation[i] != expected_elevation: return false
		if d.version < 6 and d.biomes[i] != expected_biome: return false
		if d.version >= 6 and expected_elevation == 0 and d.biomes[i] != 0: return false
		if d.crops[i] > 0 and d.farm_owner[i] < 0: return false
		if d.farm_owner[i] >= 0 and (int(d.biomes[i]) not in BiomeCatalog.FERTILE or expected_elevation != 1 or not i in d.villages[int(d.farm_owner[i])].get("farms", [])): return false
	for u in d.units:
		if not u.get("job") in VillageEconomy.JOBS: return false
		if not _integer(u.get("target"), -1, count - 1) or not _integer(u.get("route_revision"), -1, d.navigation_revision): return false
		if not _indices(u.get("route"), 512): return false
		if not u.get("cargo_type") in ["", "food", "wood", "stone"] or not _integer(u.get("cargo"), 0, 6): return false
		if (u.cargo == 0) != (u.cargo_type == ""): return false
		if not _integer(u.get("work"), 0, 6) or not _integer(u.get("think_after"), 0, 2147483647): return false
	var occupied := {}
	for v in d.villages:
		if not _indices(v.get("sites"), WorldState.MAX_HOUSES, true) or not _indices(v.get("farms"), 14, true): return false
		if not _integer(v.houses, 0, WorldState.MAX_HOUSES) or v.houses != v.sites.size(): return false
		if not _integer(v.population, 0, WorldState.MAX_UNITS): return false
		for key in ["food", "wood", "stone"]:
			# Destroyed housing can leave stored goods over the new capacity;
			# they remain accessible, but no more can be deposited until used.
			if not _integer(v.get(key), 0, 80 + WorldState.MAX_HOUSES * 16): return false
		for key in ["births", "deaths", "gathered_wood", "gathered_stone", "harvested", "consumed"]:
			if not _integer(v.get(key), 0, 2147483647): return false
		if not _integer(v.get("build_site"), -1, count - 1) or not _integer(v.get("build_progress"), 0, 5): return false
		if not v.get("shortage") is bool or not v.get("jobs") is Dictionary: return false
		for key in v.jobs:
			if not key in VillageEconomy.JOBS or not _integer(v.jobs[key], 0, WorldState.MAX_UNITS): return false
		for i in v.farms:
			if d.farm_owner[int(i)] != v.id: return false
		for i in v.sites + v.farms + ([v.build_site] if v.build_site >= 0 else []):
			if occupied.has(i): return false
			occupied[i] = true
		if not v.get("history") is Array or v.history.size() > 120: return false
		var last_year := 0
		for sample in v.history:
			if not sample is Dictionary: return false
			if not _integer(sample.get("year"), last_year + 1, 100000000): return false
			if not _integer(sample.get("population"), 0, WorldState.MAX_UNITS) or not _integer(sample.get("food"), 0, 208) or not _integer(sample.get("housing"), 12, 44): return false
			last_year = int(sample.year)
	return true

static func _migrate_v1(w: WorldState) -> void:
	w.initialize_layers()
	w.navigation_revision = 1
	for u in w.units:
		for key in ["job", "target", "route", "route_revision", "cargo_type", "cargo", "work", "think_after"]: u.erase(key)
		WorldState.initialize_work(u)
	var occupied := {}
	for v in w.villages: occupied[w.index(v.x, v.y)] = true
	for v in w.villages:
		var legacy_houses := clampi(int(v.houses), 0, WorldState.MAX_HOUSES) if v.alive else 0
		v.merge({"stone": 0, "sites": [], "farms": [], "build_site": -1, "build_progress": 0, "shortage": false, "history": [], "jobs": {}, "births": 0, "deaths": 0, "gathered_wood": 0, "gathered_stone": 0, "harvested": 0, "consumed": 0}, true)
		# Materialize legacy abstract housing without consuming RNG or duplicating
		# stores. Only connected, free lowland within eight tiles is eligible.
		var nav := WorldNavigation.new(w)
		for n in legacy_houses:
			var i := nav.nearest(Vector2i(v.x, v.y), func(tile: int) -> bool: return not occupied.has(tile), 8)
			if i < 0: break
			v.sites.append(i)
			occupied[i] = true
			w.trees[i] = 0
			w.stone[i] = 0
		v.houses = v.sites.size()
		v.population = 0
		for u in w.units:
			if u.village == v.id and u.health > 0: v.population += 1
		v.wood = clampi(floori(v.wood), 0, w.storage(v))
		v.food = clampi(floori(v.food), 0, w.storage(v))
