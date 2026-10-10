extends SceneTree
## Phase 2: conservation, real routes, resource pressure, migration, generations.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: ", description)
	else: failures += 1; printerr("FAIL: ", description)

func island() -> WorldState:
	var w := WorldState.new()
	w.generate(812, 0, false)
	w.fill_material(WorldState.Terrain.OCEAN)
	for y in range(34, 67):
		for x in range(54, 87): w.set_material(w.index(x, y), WorldState.Terrain.MEADOW)
	return w

func settle(w: WorldState, count: int = 12) -> Dictionary:
	var v := w.create_village(Vector2i(70, 50))
	for i in count:
		w.spawn("settler", Vector2i(70 + i % 3, 50 + i / 3))
		w.units[-1].village = v.id
		w.units[-1].age = 20
		w.units[-1].cooldown = 0
	v.population = count
	return v

func run() -> void:
	var start := Time.get_ticks_msec()
	_routes()
	_conservation()
	_births()
	_migration()
	_century()
	_farm_loss()
	print("\nECONOMY RESULT: %s checks, %s passed, %s failed (%s ms)" % [checks, checks - failures, failures, Time.get_ticks_msec() - start])
	quit(0 if failures == 0 else 1)

func _routes() -> void:
	var w := island()
	var navigation := WorldNavigation.new(w)
	var from := Vector2i(65, 50)
	var to := Vector2i(75, 50)
	for y in range(34, 67): w.set_material(w.index(70, y), WorldState.Terrain.MOUNTAIN)
	navigation.begin_tick()
	check(not navigation.connected(from, to) and navigation.route(from, w.index(to.x, to.y)).is_empty(), "a solid mountain wall prevents cross-wall work")
	w.set_material(w.index(70, 60), WorldState.Terrain.SAND)
	navigation.begin_tick()
	var path := navigation.route(from, w.index(to.x, to.y))
	check(path.size() == 30 and w.index(70, 60) in path, "A* routes around a wall through its only gap")
	w.spawn("settler", from)
	var u := w.units[0]
	var reached := false
	for n in 35:
		navigation.begin_tick()
		reached = navigation.advance(u, w.index(to.x, to.y))
		if reached: break
	check(reached and u.x == to.x and u.y == to.y, "workers follow a route one adjacent cell at a time")
	w.set_material(w.index(70, 60), WorldState.Terrain.OCEAN)
	navigation.begin_tick()
	check(not navigation.connected(from, to), "painting a canal invalidates previously connected navigation")
	w.set_material(w.index(70, 50), WorldState.Terrain.MEADOW)
	check(navigation.connected(from, to), "painting a land bridge immediately reconnects the navigation grid")
	var spatial := SpatialIndex.new()
	w.spawn("deer", Vector2i(85, 65))
	spatial.rebuild(w.units)
	check(spatial.nearby(to, 3).size() == 1 and spatial.nearby(to, 3)[0].id == u.id, "spatial index returns nearby lives without including distant creatures")

func _conservation() -> void:
	var w := island()
	# Isolate base work costs/timing from Phase 6 climate. The century scenario
	# below keeps live climate, and environmental yield effects have their own suite.
	for law in ["weather", "seasons", "ages", "disease"]: w.laws[law] = false
	w.laws.hunger = false
	w.laws.births = false
	var v := settle(w, 1)
	var u := w.units[0]
	var sim := Simulation.new(w)
	var tile := w.index(74, 50)
	w.trees.fill(0)
	w.trees[tile] = 6
	v.food = 30
	v.stone = 16
	sim.navigation.begin_tick()
	sim.economy._assign(u, "log", tile)
	for n in 6: sim.economy.worker_step(u)
	check(w.trees[tile] == 0 and u.cargo == 6 and v.wood == 0, "logging removes finite wood and puts it in cargo, not village storage")
	for n in 4: sim.economy.worker_step(u)
	check(u.cargo == 0 and v.wood == 6 and u.x == v.x and u.y == v.y, "wood enters storage only after the worker returns to the depot")
	w.stone.fill(0)
	w.stone[tile] = 6
	sim.economy._assign(u, "mine", tile)
	for n in 10: sim.economy.worker_step(u)
	check(w.stone[tile] == 0 and v.stone == 22 and v.gathered_stone == 6, "mining conserves a finite stone deposit through hauling")
	# Paid work can resume when another worker takes the building job.
	v.population = 12
	v.wood = 12
	v.stone = 4
	sim.economy._choose_job(u, v)
	check(u.job == "build" and v.wood == 0 and v.stone == 0 and v.houses == 0, "a house reserves and consumes twelve wood and four stone before construction")
	for n in 12: sim.economy.worker_step(u)
	check(v.houses == 1 and w.housing(v) == 16, "completed construction creates a real house and four housing places")
	var plot := w.index(72, 53)
	v.farms = [plot]
	w.farm_owner[plot] = v.id
	w.trees[plot] = 0
	sim.economy._assign(u, "farm", plot)
	for n in 12: sim.economy.worker_step(u)
	check(w.crops[plot] == 1 and v.harvested == 0, "sowing creates a growing crop without adding food")
	for n in 63: sim._environment()
	check(w.crops[plot] == WorldState.CROP_MATURE, "crops mature over simulation ticks")
	sim.economy._assign(u, "farm", plot)
	for n in 12: sim.economy.worker_step(u)
	check(v.harvested == 6 and w.crops[plot] == 0 and v.food == 36, "harvested crops pass through worker cargo into the pantry")
	u.hunger = 60
	w.laws.hunger = true
	u.x = v.x
	u.y = v.y
	sim.economy.worker_step(u)
	check(v.food == 35 and u.hunger == 20 and v.consumed == 1, "eating removes pantry food and satisfies hunger")
	w.set_material(v.sites[0], WorldState.Terrain.OCEAN)
	check(v.houses == 0 and w.housing(v) == 12, "destroying a physical house immediately removes its housing capacity")
	w.set_material(plot, WorldState.Terrain.SAND)
	check(w.farm_owner[plot] == -1 and w.crops[plot] == 0 and v.farms.is_empty(), "terrain destruction removes crops and farm ownership together")
	w.set_material(tile, WorldState.Terrain.FOREST)
	w.trees[tile] = 0
	w.tree_growth[tile] = 0
	for n in 192:
		w.tick += 1
		sim._environment()
	check(w.trees[tile] == 1, "depleted woodland regenerates one wood per four years")
	u.x = v.x
	u.y = v.y
	u.cargo = 6
	u.cargo_type = "wood"
	v.wood = w.storage(v)
	v.food = 10
	u.hunger = 60
	sim.economy.worker_step(u)
	check(v.food == 9 and u.hunger == 20 and u.cargo == 6, "a full wood store does not prevent a carrier from eating at the pantry")
	# Cut off cargo from its depot: no teleporting goods across water.
	u.x = 74
	u.y = 50
	u.cargo_type = "wood"
	u.cargo = 6
	v.wood = 0
	for y in range(34, 67): w.set_material(w.index(72, y), WorldState.Terrain.OCEAN)
	sim.navigation.begin_tick()
	for n in 8: sim.economy.worker_step(u)
	check(v.wood == 0 and u.cargo == 6 and u.x == 74, "a worker isolated by ocean cannot deliver carried goods")

func _births() -> void:
	var w := island()
	var v := settle(w, 12)
	var sim := Simulation.new(w)
	v.food = 80
	for n in 100:
		sim.spatial.rebuild(w.units)
		sim._reproduce()
	check(v.births == 0, "full housing prevents births even with full food stores")
	v.sites = [w.index(68, 50)]
	v.houses = 1
	v.food = 0
	for n in 100: sim._reproduce()
	check(v.births == 0, "empty pantry prevents births even with spare housing")
	v.food = 80
	for u in w.units: u.age = 15
	for n in 100: sim._reproduce()
	check(v.births == 0, "settlers below sixteen cannot reproduce")
	for u in w.units: u.age = 16
	for n in 200:
		sim.spatial.rebuild(w.units)
		sim._reproduce()
	check(v.births == 4 and v.population == 16 and v.food == 72, "eligible adults fill exactly the available housing and consume food for births")
	var child := w.units[-1]
	sim.economy.worker_step(child)
	check(child.job == "rest" and child.cargo == 0 and child.age == 0, "newborn children do not perform adult gathering jobs")

func _migration() -> void:
	var legacy: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v1_world.json"))
	var before := JSON.stringify(legacy)
	var result := SaveStore.decode(legacy)
	check(result.has("world"), "a real Phase 1 fixture migrates to Phase 2")
	if result.has("world"):
		var w: WorldState = result.world
		check(w.tick == 60 and w.next_id == legacy.next_id and w.units.size() == legacy.units.size() and w.rng.state == legacy.rng_state.to_int(), "migration preserves time, entity IDs, lives, and random state")
		check(w.villages[0].houses == w.villages[0].sites.size() and w.units[0].job == "idle", "legacy abstract houses become sites and creatures gain empty work state")
		check(SaveStore.decode(SaveStore.encode(w)).has("world") and JSON.stringify(legacy) == before, "migrated data revalidates as v2 without mutating the input fixture")
		var sim := Simulation.new(w)
		for n in 120: sim.step()
		var encoded := SaveStore.encode(w).duplicate(true)
		check(SaveStore.decode(encoded).has("world"), "a migrated world remains saveable after work and reproduction")
		for mutation in ["trees", "route", "farm_owner", "farms", "jobs", "cargo", "history"]:
			var corrupt := encoded.duplicate(true)
			match mutation:
				"trees": corrupt.trees[0] = 99
				"route": corrupt.units[0].route = [-1]
				"farm_owner": corrupt.farm_owner[0] = 999
				"farms": corrupt.villages[0].farms = 10
				"jobs": corrupt.units[0].job = "teleport"
				"cargo": corrupt.units[0].cargo = 99
				"history": corrupt.villages[0].history = [{"year": "bad"}]
			check(SaveStore.decode(corrupt).has("error"), "v2 validation rejects malformed " + mutation)

	var abandoned: Dictionary = legacy.duplicate(true)
	abandoned.villages[0].alive = false
	var remnant := SaveStore.decode(abandoned)
	if remnant.has("world"):
		var old_world: WorldState = remnant.world
		Simulation.new(old_world).step()
		var detached := true
		for u in old_world.units:
			if u.village == 0: detached = false
		check(detached and old_world.villages[0].sites.is_empty() and SaveStore.decode(SaveStore.encode(old_world)).has("world"), "legacy abandoned villages release members and building sites without invalidating future saves")
	else: check(false, "legacy abandoned village migrates")

func _century() -> void:
	var w := island()
	var v := settle(w)
	var sim := Simulation.new(w)
	for n in 4800: sim.step()
	print("CENTURY: population=%s, births=%s, deaths=%s, houses=%s, food=%s, harvested=%s" % [v.population, v.births, v.deaths, v.houses, v.food, v.harvested])
	check(v.alive and v.population >= 12 and v.births > 12 and v.deaths >= 12, "an isolated resource-rich village survives a hundred years and replaces its founders")
	check(v.houses > 0 and v.harvested > 0 and v.consumed > 0 and v.population <= w.housing(v), "century economy uses construction, crops, consumption, and bounded housing")
	check(v.history.size() == 100 and v.history[0].year == 2 and v.history[-1].year == 101, "village history records one population sample per simulated year")
	SaveStore.save_world(w, "user://economy-continuation.json")
	var result := SaveStore.load_world("user://economy-continuation.json")
	check(result.has("world"), "a century-old village and its in-flight work can reload")
	if result.has("world"):
		var copy: WorldState = result.world
		var other := Simulation.new(copy)
		for n in 120: sim.step(); other.step()
		check(JSON.stringify(SaveStore.encode(w), "", true, true) == JSON.stringify(SaveStore.encode(copy), "", true, true), "JSON round trip reproduces every persisted field for the next 120 ticks")
	DirAccess.remove_absolute("user://economy-continuation.json")

func _farm_loss() -> void:
	# A small agricultural island: no outside forage, wood, or food imports.
	var w := island()
	for i in w.terrain.size():
		if w.elevation[i] == WorldState.Elevation.LOWLAND: w.set_material(i, WorldState.Terrain.SAND, false)
	var v := settle(w)
	v.food = 24
	for x in range(66, 72):
		var i := w.index(x, 47)
		w.set_material(i, WorldState.Terrain.MEADOW, false)
		w.farm_owner[i] = v.id
		w.crops[i] = WorldState.CROP_MATURE
		v.farms.append(i)
	w.laws.births = false
	w.laws.old_age = false
	var copied := SaveStore.decode(SaveStore.encode(w))
	if not copied.has("world"):
		check(false, "farm-loss scenario can be copied")
		return
	var damaged: WorldState = copied.world
	for i in v.farms: damaged.set_material(i, WorldState.Terrain.SAND, false)
	var control := Simulation.new(w)
	var disaster := Simulation.new(damaged)
	for n in 600: control.step(); disaster.step()
	print("FARM LOSS: intact=%s, destroyed=%s" % [w.units.size(), damaged.units.size()])
	check(w.units.size() == 12 and v.harvested > 0, "maintained farms sustain an island with no wild forage")
	check(damaged.units.size() < w.units.size() and damaged.villages[0].deaths > 0, "destroying those farms causes starvation and population decline")
	check(damaged.events.any(func(e: Dictionary) -> bool: return e.kind == "shortage"), "food shortages are explained in the world chronicle")
