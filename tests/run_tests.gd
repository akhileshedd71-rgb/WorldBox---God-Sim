extends SceneTree
## Dependency-free simulation and persistence tests. Failure exits nonzero.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)
	else:
		print("PASS: ", description)

func fresh(seed_value: int = 42) -> WorldState:
	var w := WorldState.new()
	w.generate(seed_value, 0, false)
	return w

func flat() -> WorldState:
	var w := fresh()
	w.fill_material(WorldState.Terrain.MEADOW)
	w.food.fill(15)
	return w

func run() -> void:
	var start := Time.get_ticks_msec()
	_generation()
	_brush_and_powers()
	_life()
	_settlements()
	_saves()
	_stress()
	print("\nRESULT: %s checks, %s passed, %s failed (%s ms)" % [checks, checks - failures, failures, Time.get_ticks_msec() - start])
	quit(0 if failures == 0 else 1)

func _generation() -> void:
	var a := fresh(41827)
	var b := fresh(41827)
	check(a.terrain == b.terrain and a.food == b.food, "same seed produces the same terrain and resources")
	check(a.terrain != fresh(99).terrain, "different seeds produce different terrain")
	check(a.terrain.size() == 144 * 96, "world dimensions match the bounded simulation grid")
	var land := 0
	for t in a.terrain:
		if t != WorldState.Terrain.OCEAN: land += 1
	check(land > 2000 and land < 11000, "starter world has usable land and surrounding ocean")
	var edge_ocean := true
	for x in a.width:
		if a.terrain[a.index(x, 0)] != 0 or a.terrain[a.index(x, a.height - 1)] != 0: edge_ocean = false
	check(edge_ocean, "north and south map edges stay ocean in the starter seed")
	b.generate(41827, 1, false)
	check(a.terrain != b.terrain, "archipelago preset changes the seeded world")
	b.generate(41827)
	check(b.population("settler") == 12 and b.population() == 34, "starter world is populated with settlers and wildlife")
	var valid := true
	for u in b.units:
		if not b.habitable(u.x, u.y): valid = false
	check(valid, "all starter creatures spawn on habitable terrain")

func _brush_and_powers() -> void:
	var w := fresh()
	w.fill_material(0)
	w.food.fill(0)
	w.paint(Vector2i(0, 0), 4, WorldState.Terrain.FOREST)
	check(w.terrain[0] == WorldState.Terrain.FOREST and w.terrain[w.index(143, 95)] == 0, "edge brush is clipped without wrapping into opposite edge")
	w.paint(Vector2i(20, 20), 2, WorldState.Terrain.MEADOW)
	check(w.food[w.index(20, 20)] == 10 and w.terrain[w.index(23, 20)] == 0, "circular terrain brush sets resources within its radius")
	w.power(Vector2i(20, 20), 1, "fire")
	check(w.fire[w.index(20, 20)] == 9, "fire ignites fertile land")
	w.power(Vector2i(20, 20), 2, "rain")
	check(w.fire[w.index(20, 20)] == 0 and w.food[w.index(20, 20)] == 17, "rain extinguishes flames and restores forage")
	w.spawn("settler", Vector2i(20, 20))
	w.units[0].health = 30
	w.units[0].hunger = 70
	w.power(Vector2i(20, 20), 2, "bless")
	check(w.units[0].health == 100 and w.units[0].hunger == 0, "blessing heals and feeds nearby creatures")
	w.power(Vector2i(20, 20), 2, "meteor")
	Simulation.new(w).step()
	check(w.terrain[w.index(20, 20)] == WorldState.Terrain.SAND and w.units.is_empty(), "meteor changes terrain and removes killed creatures on the next tick")
	w = flat()
	w.laws.fire_spread = false
	w.power(Vector2i(30, 30), 0, "fire")
	var sim := Simulation.new(w)
	for n in 10: sim.step()
	check(w.fire[w.index(30, 30)] == 0 and w.food[w.index(30, 30)] < 1 and w.food[w.index(31, 30)] > 9 and w.biomes[w.index(30, 30)] == WorldState.Biome.GRASSLAND, "disabled fire spread confines vegetation loss and preserves the underlying biome")

func _life() -> void:
	var w := flat()
	check(not w.spawn("rabbit", Vector2i(-1, 0)), "spawn rejects out-of-bounds cells")
	w.set_material(0, WorldState.Terrain.OCEAN)
	check(not w.spawn("settler", Vector2i.ZERO), "land species cannot spawn in the ocean")
	for i in WorldState.MAX_UNITS: w.spawn("rabbit", Vector2i(30, 30))
	check(not w.spawn("rabbit", Vector2i(30, 30)) and w.units.size() == 350, "spawn enforces the mobile population budget")
	w = flat()
	w.fill_material(WorldState.Terrain.MOUNTAIN)
	w.set_material(w.index(30, 30), WorldState.Terrain.MEADOW)
	w.spawn("rabbit", Vector2i(30, 30))
	var sim := Simulation.new(w)
	for n in 50: sim.step()
	check(w.units[0].x == 30 and w.units[0].y == 30, "creatures respect impassable neighboring mountains")
	w = flat()
	w.fill_material(WorldState.Terrain.SAND)
	w.food.fill(0)
	w.laws.births = false
	w.laws.old_age = false
	w.spawn("settler", Vector2i(20, 20))
	w.units[0].hunger = 100
	sim = Simulation.new(w)
	for n in 60: sim.step()
	check(w.units.is_empty(), "starvation kills creatures when forage is unavailable")
	w.spawn("settler", Vector2i(20, 20))
	w.units[0].hunger = 100
	w.laws.hunger = false
	for n in 80: sim.step()
	check(w.units.size() == 1 and w.units[0].health == 100, "hunger law disables starvation damage")
	w.units[0].age = 100
	w.laws.old_age = true
	for n in 110: sim.step()
	check(w.units.is_empty(), "old-age law produces mortality")
	w = flat()
	for i in 24:
		w.spawn("rabbit", Vector2i(30 + i % 4, 30 + i / 4))
		w.units[-1].cooldown = 0
	w.laws.old_age = false
	sim = Simulation.new(w)
	for n in 300: sim.step()
	check(w.next_id > 25, "nearby well-fed adults create offspring")
	w = flat()
	w.laws.births = false
	w.laws.old_age = false
	for i in 8: w.spawn("rabbit", Vector2i(20, 20))
	sim = Simulation.new(w)
	for n in 250: sim.step()
	check(w.next_id == 9, "birth law prevents reproduction")

func _settlements() -> void:
	var w := flat()
	for i in 12: w.spawn("settler", Vector2i(50 + i % 3, 50 + i / 3))
	var sim := Simulation.new(w)
	for n in 600: sim.step()
	check(w.villages.size() >= 1, "settlers autonomously found a village")
	check(w.villages[0].houses >= 1 and w.villages[0].population >= 4, "a village gathers wood and builds housing")
	check(w.events.any(func(e: Dictionary) -> bool: return e.kind == "village"), "village founding is recorded in the chronicle")
	var v := w.villages[0]
	w.paint(Vector2i(v.x, v.y), 1, WorldState.Terrain.OCEAN)
	for n in 12: sim.step()
	check(not w.villages[0].alive, "terrain destruction abandons a village on uninhabitable land")

func _saves() -> void:
	var w := WorldState.new()
	w.generate(41827)
	var sim := Simulation.new(w)
	for n in 60: sim.step()
	var path := "user://test-roundtrip.json"
	check(SaveStore.save_world(w, path) == OK, "save writes a complete world to disk")
	var result := SaveStore.load_world(path)
	check(result.has("world"), "save reloads after strict schema validation")
	if result.has("world"):
		var restored: WorldState = result.world
		check(restored.terrain == w.terrain and restored.units == w.units and restored.tick == w.tick, "save/load preserves terrain, units, and simulation time")
		check(restored.rng.state == w.rng.state, "save preserves the full 64-bit random state")
		var sim2 := Simulation.new(restored)
		for n in 120: sim.step(); sim2.step()
		check(restored.units == w.units and restored.food == w.food and restored.villages == w.villages, "restored simulation continues deterministically")
		check(SaveStore.save_world(restored, path) == OK, "atomic save can replace an existing slot")
	var d := SaveStore.encode(w).duplicate(true)
	d.version = 999
	check(SaveStore.decode(d).has("error"), "future save versions are rejected")
	d = SaveStore.encode(w).duplicate(true)
	d.terrain[0] = 255
	check(SaveStore.decode(d).has("error"), "invalid terrain values are rejected")
	d = SaveStore.encode(w).duplicate(true)
	d.units[0].x = -1
	check(SaveStore.decode(d).has("error"), "invalid creature coordinates are rejected")
	d = SaveStore.encode(w).duplicate(true)
	d.units[0].health = "broken"
	check(SaveStore.decode(d).has("error"), "invalid creature stat types are rejected")
	d = SaveStore.encode(w).duplicate(true)
	d.laws.erase("hunger")
	check(SaveStore.decode(d).has("error"), "incomplete world laws are rejected")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(SafeFiles.read_one(path, SaveStore._valid_file).has("error") and SaveStore.load_world(path).get("recovered", false), "truncated primary is rejected and its valid backup recovers the world")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")
	check(SaveStore.load_world(path).has("error"), "missing saves without recovery copies return a player-facing error")

func _stress() -> void:
	var w := flat()
	w.laws.old_age = false
	for i in WorldState.MAX_UNITS:
		w.spawn("settler" if i % 3 == 0 else "rabbit", Vector2i(10 + (i * 3) % 120, 10 + (i * 7) % 70))
	var sim := Simulation.new(w)
	var start := Time.get_ticks_usec()
	for n in 500: sim.step()
	var valid := w.units.size() <= WorldState.MAX_UNITS
	for u in w.units:
		valid = valid and w.contains(u.x, u.y) and u.health > 0 and u.hunger >= 0 and u.hunger <= 100
	check(valid, "500-tick population-budget run preserves simulation invariants")
	print("BENCHMARK: 350 starting creatures, 500 ticks: %.2f ms/tick (host CPU only)" % ((Time.get_ticks_usec() - start) / 500000.0))
