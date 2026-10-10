extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: ", message)
	else: failures += 1; printerr("FAIL: ", message)
func flat() -> WorldState:
	var w := WorldState.new()
	w.generate(741, 0, false)
	w.fill_material(WorldState.Terrain.MEADOW)
	w.laws.old_age = false
	w.laws.expansion = false
	w.laws.diplomacy = false
	return w
func parents(w: WorldState, species: String = "settler") -> Array:
	var ids: Array = []
	for n in 2:
		w.spawn(species, Vector2i(70, 50))
		w.units[-1].age = SpeciesCatalog.maturity(species) + 5
		w.units[-1].cooldown = 0
		Heredity.replace_traits(w, w.units[-1].id, [])
		ids.append(w.units[-1].id)
	return ids
func encoded(w: WorldState) -> String: return JSON.stringify(SaveStore.encode(w), "", true, true)
func run() -> void:
	var start := Time.get_ticks_msec()
	_catalog_and_traits()
	_effects()
	_combat_effect()
	_families()
	_inheritance()
	_limits()
	_saves()
	print("\nHEREDITY RESULT: %s checks, %s passed, %s failed (%s ms)" % [checks, checks - failures, failures, Time.get_ticks_msec() - start])
	quit(0 if failures == 0 else 1)
func _catalog_and_traits() -> void:
	check(SpeciesCatalog.DEFINITIONS.size() == 3 and SpeciesCatalog.maturity("settler") == 16 and SpeciesCatalog.lifespan("rabbit") == 16, "resource species catalog supplies distinct maturity and lifespan rules")
	check(SpeciesCatalog.get_species("settler").forms_villages and not SpeciesCatalog.get_species("deer").forms_villages and SpeciesCatalog.get_species("deer").birth_cooldown == 120, "civilization and birth timing come from species resources")
	var w := flat()
	var ids := parents(w)
	var u := w.units[0]
	check(w.lineage.size() == 2 and Heredity.record(w, ids[0]).parents.is_empty(), "introduced adults gain distinct persistent records with unknown ancestors")
	check(Heredity.replace_traits(w, u.id, ["thrifty", "robust", "industrious", "cold_adapted"]), "compatible trait edits commit atomically through the model")
	check(Heredity.traits(u).size() == 4 and Heredity.variant(u) == "Frostfolk", "expressed adaptation gives the settler a named subspecies")
	var before := encoded(w)
	for traits_list in [["thrifty", "hungry"], ["robust", "frail"], ["industrious", "unhurried"], ["cold_adapted", "meadow_adapted"], ["thrifty", "thrifty"], ["invincible"]]:
		check(not Heredity.replace_traits(w, u.id, traits_list) and encoded(w) == before, "invalid trait edit is rejected without partial changes: " + str(traits_list))
	var invalid := Heredity.neutral()
	invalid.vigor = [500, -500]
	check(not Heredity.valid_genome(invalid), "out-of-range alleles cannot inject unbounded statistics")
	invalid = Heredity.neutral()
	invalid.extra = [0, 0]
	check(not Heredity.valid_genome(invalid), "unknown genes are rejected")
	var a := WorldState.new()
	var b := WorldState.new()
	a.generate(41827, 2)
	b.generate(41827, 2)
	check(encoded(a) == encoded(b), "seeded founders have identical genomes, appearance, records, and RNG state")
	check(a.units.any(func(person: Dictionary) -> bool: return Heredity.value(person, "coat") != 0), "original appearance variants occur in an ordinary generated world")
func _effects() -> void:
	var w := flat()
	parents(w)
	var u := w.units[0]
	Heredity.replace_traits(w, u.id, ["thrifty", "industrious", "robust", "woodland_adapted"])
	var fast := Heredity.hunger_rate(w, u)
	w.set_material(w.index(u.x, u.y), WorldState.Terrain.FOREST)
	check(Heredity.hunger_rate(w, u) < fast, "woodland adaptation reduces hunger only in its matching habitat")
	var lifespan := Heredity.lifespan(u)
	var recovery := Heredity.recovery(u)
	var damage := Heredity.damage(u, 17)
	Heredity.replace_traits(w, u.id, ["hungry", "unhurried", "frail"])
	check(Heredity.hunger_rate(w, u) > fast and Heredity.lifespan(u) < lifespan and Heredity.recovery(u) < recovery, "metabolism and vigor produce bounded survival differences")
	check(damage == 19 and Heredity.damage(u, 17) == 15, "vigor modifies base spear damage by two in either direction")
	var sim := Simulation.new(w)
	w.laws.births = false
	w.laws.hunger = false
	u.health = 50.0
	w.units[1].health = 50.0
	Heredity.replace_traits(w, w.units[1].id, ["robust"])
	sim.step()
	check(w.units[1].health > u.health, "trait recovery rates affect actual simulation health")
	# Two workers stand at independent equal deposits; no walking or hauling confound.
	var v := w.create_village(Vector2i(70, 50))
	for person in w.units: person.village = v.id
	v.food = 80
	var quick := w.units[1]
	Heredity.replace_traits(w, quick.id, ["industrious"])
	Heredity.replace_traits(w, u.id, ["unhurried"])
	for person in [u, quick]:
		person.health = 100
		person.x = 72 + int(person == quick)
		person.y = 50
		var tile := w.index(person.x, person.y)
		w.trees[tile] = 6
		sim.economy._assign(person, "log", tile)
	for n in 2: sim.economy.worker_step(u); sim.economy.worker_step(quick)
	check(quick.cargo == 6 and u.cargo == 0 and u.work == 2, "industry changes time to gather physical goods")
	for n in 2: sim.economy.worker_step(u)
	check(u.cargo == 6, "unhurried workers gather the same finite quantity after four work ticks")
func _combat_effect() -> void:
	var w := flat()
	for x in [50, 80]:
		var v := w.create_village(Vector2i(x, 50))
		v.food = 80
		v.wood = 80
		v.stone = 80
		v.population = 8
		for n in 8:
			w.spawn("settler", Vector2i(x, 50))
			w.units[-1].village = v.id
			w.units[-1].age = 25
	var sim := Simulation.new(w)
	sim.politics.refresh()
	sim.military.declare_war(0, 1)
	sim.military.recruit(0)
	sim.military.recruit(1, true)
	var attacker: Dictionary = sim.military.people(w.armies[0])[0]
	var defender: Dictionary = sim.military.people(w.armies[1])[0]
	attacker.x = 79
	Heredity.replace_traits(w, attacker.id, ["robust"])
	sim.spatial.rebuild(w.units)
	sim.military.soldier_step(attacker)
	check(defender.health == 81, "a robust soldier's actual melee strike deals 19 damage")
	attacker.attack_after = 0
	defender.health = 100.0
	Heredity.replace_traits(w, attacker.id, ["frail"])
	sim.military.soldier_step(attacker)
	check(defender.health == 85, "the same soldier with frailty deals 15 damage through combat")

func _families() -> void:
	var w := flat()
	var ids := parents(w)
	check(w.spawn("settler", Vector2i(70, 50), true, ids), "two eligible existing adults produce a recorded newborn")
	var child := w.units[-1]
	var child_id: int = child.id
	var r := Heredity.record(w, child_id)
	check(r.parents == ids and r.generation == 1 and r.origin == "born" and child.age == 0, "newborn ancestry uses the two real parent IDs and a derived generation")
	check(Heredity.related(w, ids[0], child_id) and Heredity.record(w, ids[0]).events[0].kind == "child", "parent-child relationship and personal birth memories are recorded")
	var before := encoded(w)
	check(not w.spawn("rabbit", Vector2i(70, 50), true, ids) and encoded(w) == before, "cross-species parent links cannot create a child or consume RNG")
	check(not w.spawn("settler", Vector2i(70, 50), true, [ids[0], ids[0]]), "self-parenting is rejected")
	check(w.spawn("settler", Vector2i(70, 50), true, ids) and Heredity.related(w, child_id, w.units[-1].id), "siblings share recorded parents")
	Heredity.set_favorite(w, ids[0], true)
	w.units[0].health = 0
	w.laws.births = false
	Simulation.new(w).step()
	check(Heredity.unit(w, ids[0]).is_empty() and Heredity.record(w, ids[0]).death_tick == w.tick, "death removes the live entity and preserves its historical identity")
	check(Heredity.record(w, child_id).parents == ids and Heredity.record(w, ids[0]).favorite and w.events.any(func(e: Dictionary) -> bool: return e.kind == "memory"), "a dead favorite remains linked to children and announces a remembered death")
	check(SaveStore.decode(JSON.parse_string(encoded(w))).has("world"), "a family with a dead parent passes full JSON validation")
	check(not w.spawn("settler", Vector2i(70, 50), true, ids), "a deceased creature cannot parent a new birth")
	w.tick = 768
	child.age = 16
	w.spawn("settler", Vector2i(70, 50))
	var outsider: int = w.units[-1].id
	check(w.spawn("settler", Vector2i(70, 50), true, [child_id, outsider]) and Heredity.record(w, w.units[-1].id).generation == 2, "an adult descendant and unrelated founder produce a second-generation child")
	check(Heredity.record(w, child_id).parents == ids and Heredity.record(w, ids[0]).death_tick >= 0 and SaveStore.decode(JSON.parse_string(encoded(w))).has("world"), "a three-generation family retains valid ancestry through a dead grandparent")
	for n in 20: Heredity.event(w, child_id, "A bounded memory %s" % n, "traits")
	check(r.events.size() == Heredity.MAX_EVENTS and r.events[0].text.ends_with("19"), "personal history retains only its newest six moments")
func _inheritance() -> void:
	var w := flat()
	var ids := parents(w, "rabbit")
	Heredity.replace_traits(w, ids[0], ["thrifty", "robust", "cold_adapted"])
	Heredity.replace_traits(w, ids[1], ["hungry", "robust", "cold_adapted"])
	var robust := 0
	var balanced := 0
	var mutations := 0
	var all_valid := true
	for n in 128:
		var genome := Heredity.inherit(w, ids, 3)
		var sample := {"genome": genome, "species": "rabbit"}
		all_valid = all_valid and Heredity.valid_genome(genome)
		if Heredity.value(sample, "vigor") == 1: robust += 1
		if Heredity.value(sample, "metabolism") == 0: balanced += 1
		if genome.craft != [0, 0]: mutations += 1
	check(all_valid and robust > 115 and balanced > 110, "offspring usually inherit both parents' vigor while opposite metabolism alleles balance")
	check(mutations > 0 and mutations < 32, "seeded births introduce rare valid variations beyond parental craft alleles")
	# Exercise autonomous pairing, food costs, and generation links together.
	w = flat()
	ids = parents(w)
	var v := w.create_village(Vector2i(70, 50))
	v.food = 80
	v.population = 2
	for u in w.units: u.village = v.id
	var sim := Simulation.new(w)
	for n in 100:
		sim.spatial.rebuild(w.units)
		sim._reproduce()
	check(v.births == 1 and w.units.size() == 3 and v.food == 78 and Heredity.record(w, w.units[-1].id).parents == ids, "autonomous reproduction charges real food and attaches both actual parents")
	var copy := SaveStore.decode(JSON.parse_string(encoded(w)))
	check(copy.has("world"), "a young family can reload")
	if copy.has("world"):
		var other := Simulation.new(copy.world)
		for n in 240: sim.step(); other.step()
		check(encoded(w) == encoded(copy.world), "a growing family continues identically after full JSON round trip")
func _limits() -> void:
	var w := flat()
	for n in 33: w.spawn("rabbit", Vector2i(70, 50))
	for u in w.units.slice(0, 32): Heredity.set_favorite(w, u.id, true)
	check(not Heredity.set_favorite(w, w.units[-1].id, true), "favorites are capped without removing existing favorites")
	Heredity.set_favorite(w, w.units[0].id, false)
	check(Heredity.set_favorite(w, w.units[-1].id, true), "removing a favorite makes room for another")
	# Fill the archive through the same creation/death lifecycle, keeping parents.
	w = flat()
	w.laws.births = false
	var sim := Simulation.new(w)
	for n in Heredity.MAX_RECORDS:
		w.spawn("rabbit", Vector2i(70, 50))
		w.units[-1].health = 0
		Heredity.remember_death(w, w.units[-1])
		w.units.pop_back()
	var first: Dictionary = w.lineage[0].duplicate(true)
	check(not w.spawn("rabbit", Vector2i(70, 50)) and w.lineage.size() == Heredity.MAX_RECORDS and w.lineage[0] == first, "a full archive stops new lives without silently deleting ancestors")
	check(encoded(w).length() < SaveStore.MAX_BYTES and SaveStore.decode(JSON.parse_string(encoded(w))).has("world"), "a full historical archive fits the bounded save format and reloads")
func _saves() -> void:
	for version in [1, 2, 3, 4]:
		var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v%s_world.json" % version))
		var before := JSON.stringify(old)
		var result := SaveStore.decode(old)
		check(result.has("world"), "genuine v%s fixture migrates to v5" % version)
		if not result.has("world"): continue
		var w: WorldState = result.world
		check(w.tick == int(old.tick) and w.next_id == int(old.next_id) and w.rng.state == old.rng_state.to_int() and w.units.size() == old.units.size(), "v%s migration preserves time, IDs, random state, and living population" % version)
		check(w.lineage.size() == w.units.size() and w.lineage.all(func(r: Dictionary) -> bool: return r.origin == "legacy" and r.parents.is_empty()) and w.units.all(func(u: Dictionary) -> bool: return Heredity.traits(u).is_empty()), "v%s gains neutral traits and explicitly unknown ancestry" % version)
		check(JSON.stringify(old) == before and SaveStore.decode(SaveStore.encode(w)).has("world"), "v%s migration is non-mutating and revalidates as v5" % version)
	var w := flat()
	var ids := parents(w)
	w.spawn("settler", Vector2i(70, 50), true, ids)
	var good: Dictionary = JSON.parse_string(encoded(w))
	for field in ["genes", "range", "contradiction", "duplicate", "parent", "cycle", "species", "generation", "living_death", "orphan", "favorites", "history", "birth"]:
		var bad := good.duplicate(true)
		match field:
			"genes": bad.units[0].genome.erase("vigor")
			"range": bad.lineage[0].genome.vigor = [8, 8]
			"contradiction": bad.units[0].genome.craft = [1, 1]
			"duplicate": bad.lineage.append(bad.lineage[-1])
			"parent": bad.lineage[-1].parents = [999, 1]
			"cycle": bad.lineage[-1].parents = [3, 1]
			"species": bad.lineage[0].species = "rabbit"
			"generation": bad.lineage[-1].generation = 999
			"living_death": bad.lineage[0].death_tick = 0
			"orphan": bad.lineage.pop_back()
			"favorites": bad.lineage[0].favorite = "yes"
			"history": bad.lineage[0].events = [{"tick": 999, "text": "Future", "kind": "arrival"}]
			"birth": bad.lineage[-1].birth_tick = 999
		check(SaveStore.decode(bad).has("error"), "v5 rejects malformed " + field)
