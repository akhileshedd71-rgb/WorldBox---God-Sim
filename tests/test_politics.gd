extends SceneTree
## Phase 3 acceptance: real expansion, durable ownership, diplomacy, old saves.
var checks := 0
var failures := 0
var expanded: WorldState
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: ", description)
	else: failures += 1; printerr("FAIL: ", description)

func flat() -> WorldState:
	var w := WorldState.new()
	w.generate(731, 0, false)
	w.fill_material(WorldState.Terrain.MEADOW)
	w.laws.births = false
	w.laws.old_age = false
	return w

func town(w: WorldState, p: Vector2i) -> Dictionary:
	var v := w.create_village(p)
	for i in 40:
		w.spawn("settler", p)
		w.units[-1].village = v.id
		w.units[-1].age = 20 + i % 5
	v.population = 40
	v.food = 160
	v.wood = 24
	v.stone = 12
	for i in 8:
		var cell := w.index(p.x - 4 + i, p.y + 2)
		v.sites.append(cell)
		w.trees[cell] = 0
		w.stone[cell] = 0
	v.houses = 8
	v.expansion_after = 0
	return v

func clone(w: WorldState) -> WorldState:
	var result := SaveStore.decode(SaveStore.encode(w))
	check(result.has("world"), "political scenario passes full save validation")
	return result.get("world")

func run() -> void:
	var started := Time.get_ticks_msec()
	_frontier()
	_supply_and_saves()
	_shared_world()
	_barriers()
	_succession()
	_diplomacy()
	_migration()
	print("\nPOLITICS RESULT: %s checks, %s passed, %s failed (%s ms)" % [checks, checks - failures, failures, Time.get_ticks_msec() - started])
	quit(0 if failures == 0 else 1)

func _frontier() -> void:
	var w := WorldState.new()
	w.generate(41827, 2)
	check(w.population("settler") == 36 and w.world_name == "The Three Frontiers", "Frontier preset begins with three separated groups of twelve settlers")
	var sim := Simulation.new(w)
	for n in 48: sim.step()
	check(w.kingdoms.size() == 3 and w.kingdoms.all(func(k: Dictionary) -> bool: return k.alive and k.ruler > 0), "three frontier peoples autonomously form distinct ruled kingdoms")
	check(SaveStore.decode(SaveStore.encode(w)).has("world"), "the populated Frontier preset is saveable")
	for n in 1152: sim.step()
	check(w.relations.size() >= 2, "the playable Frontier preset reaches natural diplomatic contact within 25 years")

func _supply_and_saves() -> void:
	var w := flat()
	var v := town(w, Vector2i(32, 50))
	var sim := Simulation.new(w)
	sim.politics.refresh()
	sim.navigation.begin_tick()
	var next_id := w.next_id
	sim.society.begin_tick()
	var social_identity := {}
	for u in w.units: social_identity[u.id] = SocietySimulation.FIELDS.map(func(key: String): return u[key])
	check(sim.politics.launch(v, w.index(32, 22)), "a crowded, supplied village can launch a reachable expedition")
	check(v.food == 136 and v.wood == 12 and v.stone == 8 and w.expeditions[0].members.size() == 4, "expedition supplies are deducted and four existing adults are assigned")
	check(w.next_id == next_id and w.villages.size() == 1, "departure creates neither extra people nor an instant colony")
	var member_ids: Array = w.expeditions[0].members.duplicate()
	for n in 7: sim.step()
	check(w.expeditions[0].active and w.villages.size() == 1 and w.units[0].y >= 43, "settlers travel across adjacent cells before a destination can be founded")
	SaveStore.save_world(w, "user://politics-continuation.json")
	var result := SaveStore.load_world("user://politics-continuation.json")
	check(result.has("world"), "a v3 JSON file reloads an expedition in flight")
	if result.has("world"):
		var copy: WorldState = result.world
		var other := Simulation.new(copy)
		for n in 120: sim.step(); other.step()
		check(JSON.stringify(SaveStore.encode(w), "", true, true) == JSON.stringify(SaveStore.encode(copy), "", true, true), "politics, routes, supplies, economy, and RNG continue identically for 120 ticks")
	check(w.villages.size() == 2 and not w.expeditions[0].active and w.villages[1].kingdom == v.kingdom, "arrival founds a second settlement in the parent's kingdom")
	var transferred := true
	for id in member_ids:
		var u := sim.politics.unit_by_id(id)
		if u.is_empty() or u.village != 1 or u.expedition != -1: transferred = false
	check(transferred and w.next_id == next_id, "the same four travellers become the colony's residents")
	var carried_identity := true
	for id in member_ids:
		var u := sim.politics.unit_by_id(id)
		if u.is_empty() or SocietySimulation.FIELDS.map(func(key: String): return u[key]) != social_identity[id]: carried_identity = false
	check(carried_identity and w.cultures.size() == 1, "real colony travel preserves all four social identities without inventing a new culture")
	check(w.expeditions[0].members.is_empty() and w.expeditions[0].food == 0, "finished expedition records cannot retain or duplicate supplies or member references")
	DirAccess.remove_absolute("user://politics-continuation.json")

func _shared_world() -> void:
	var w := flat()
	for x in [32, 68, 104]: town(w, Vector2i(x, 50))
	var sim := Simulation.new(w)
	for n in 220: sim.step()
	expanded = w
	var all_expanded := w.kingdoms.size() == 3
	for k in w.kingdoms: all_expanded = all_expanded and sim.politics.villages(k.id).size() >= 2
	print("FRONTIERS: %s kingdoms, %s settlements, %s diplomatic pairs" % [w.kingdoms.size(), w.villages.size(), w.relations.size()])
	check(all_expanded, "three kingdoms each autonomously expand on a shared map")
	check(sim.politics.contacts.size() >= 2 and w.relations.size() >= 2, "expanding kingdoms encounter shared borders and establish diplomatic ties")
	check(w.relations.all(func(r: Dictionary) -> bool: return not r.reason.is_empty()) and w.relations.any(func(r: Dictionary) -> bool: return r.score > 0), "border decisions have visible causes and prosperous neighbors build trust")
	var valid := true
	for i in w.territory.size():
		var owner := w.territory[i]
		if owner >= 0 and (not w.kingdoms[owner].alive or not w.habitable(i % w.width, i / w.width)): valid = false
	check(valid, "every claimed cell belongs to a living realm on walkable land")
	check(w.units.size() == 120 and w.units.size() <= WorldState.MAX_UNITS, "political expansion preserves the shared creature budget")

func _barriers() -> void:
	var w := flat()
	var v := town(w, Vector2i(32, 50))
	var sim := Simulation.new(w)
	sim.politics.refresh()
	sim.navigation.begin_tick()
	sim.politics.launch(v, w.index(32, 22))
	for n in 5: sim.step()
	for x in w.width: w.set_material(w.index(x, 35), WorldState.Terrain.OCEAN)
	sim.step()
	check(not w.expeditions[0].active and w.villages.size() == 1, "a canal cut across an expedition's route cancels settlement rather than teleporting it")
	check(w.expeditions[0].outcome.contains("unreachable") and w.expeditions[0].wood == 0, "an aborted expedition records why it failed and loses stranded supplies")
	check(w.units.all(func(u: Dictionary) -> bool: return u.y > 35 and u.expedition == -1), "all stranded travellers remain on their side of the water with cleared assignments")
	check(not sim.politics.launch(v, w.index(32, 22)), "a landlocked kingdom cannot launch across the ocean")
	# A surviving alternate land passage is a valid detour, not a crossing.
	w.set_material(w.index(48, 35), WorldState.Terrain.MEADOW)
	sim.politics.refresh()
	check(sim.navigation.connected(Vector2i(32, 50), Vector2i(32, 22)), "restoring an overland passage reconnects settlement routes")

func _succession() -> void:
	var w := clone(expanded)
	if w == null: return
	var sim := Simulation.new(w)
	sim.politics.refresh()
	var k := w.kingdoms[0]
	var ruler: int = k.ruler
	sim.politics.unit_by_id(ruler).health = 0
	sim.step()
	check(k.ruler != ruler and k.ruler > 0 and not sim.politics.unit_by_id(k.ruler).is_empty(), "a dead ruler is replaced by a living adult of the same kingdom")
	check(k.history.any(func(e: Dictionary) -> bool: return e.kind == "succession"), "succession is recorded in the realm's history")
	var capital := w.villages[k.capital]
	var old_capital: int = capital.id
	w.set_material(w.index(capital.x, capital.y), WorldState.Terrain.OCEAN)
	sim.step()
	check(k.alive and k.capital != old_capital and w.villages[k.capital].kingdom == k.id, "destroying a capital transfers the seat to a surviving settlement")
	capital = w.villages[k.capital]
	w.set_material(w.index(capital.x, capital.y), WorldState.Terrain.OCEAN)
	sim.step()
	check(not k.alive and k.capital == -1 and k.ruler == -1 and not k.id in Array(w.territory), "loss of the final town collapses a kingdom and clears its ruler and claims")
	check(SaveStore.decode(SaveStore.encode(w)).has("world"), "succession, capital loss, and collapse preserve a valid save graph")

func _diplomacy() -> void:
	var w := clone(expanded)
	if w == null: return
	# Isolate the alliance delta; Phase 7 tests clan loyalty separately.
	w.laws.society = false
	var sim := Simulation.new(w)
	sim.politics.refresh()
	var p := sim.politics
	check(not p.influence(0, "peace", 0) and not p.influence(999, "favor"), "political powers reject missing realms and self-relations")
	p.influence(0, "peace", 1)
	p.influence(0, "peace", 1)
	var r := p.relation(0, 1)
	check(r.status == "alliance" and p.relation(1, 0) == r, "peace can establish one symmetric alliance between two realms")
	var home := w.villages[w.kingdoms[0].capital]
	home.loyalty = 50
	home.food = 120
	p._loyalty()
	check(home.loyalty == 55 and home.loyalty_reason.contains("allied support"), "an alliance provides a measurable loyalty benefit")
	for n in 4: p.influence(0, "discord", 1)
	check(r.status == "rivalry" and r.score >= -100, "discord can establish bounded rivalry")
	var enemy := w.villages[w.kingdoms[1].capital]
	check(not p._permitted(0, w.index(enemy.x, enemy.y)), "rival territory closes expedition transit")
	var old_loyalty: int = home.loyalty
	p.influence(0, "favor")
	check(home.loyalty == old_loyalty + 12 and w.kingdoms[0].favor_until == w.tick + 240, "favor immediately increases loyalty and lasts five years")
	w.kingdoms[0].favor_until = 0
	var frontier: Dictionary = p.villages(0)[1]
	frontier.loyalty = 23
	frontier.food = 0
	p._loyalty()
	p.refresh()
	check(frontier.kingdom != 0 and w.kingdoms[frontier.kingdom].capital == frontier.id, "a disloyal, food-starved outlying settlement declares independence")
	check(p.relation(0, frontier.kingdom).status == "rivalry" and w.kingdoms[0].history.any(func(e: Dictionary) -> bool: return e.kind == "independence"), "independence establishes new ownership and an explained diplomatic consequence")
	check(SaveStore.decode(SaveStore.encode(w)).has("world"), "independent realm references remain valid")
	w.laws.diplomacy = false
	w.laws.expansion = false
	var score: int = r.score
	var loyalty: int = home.loyalty
	for n in 48: sim.step()
	check(r.score == score and home.loyalty == loyalty, "the politics law freezes automatic diplomacy and loyalty changes")

func _migration() -> void:
	for version in [1, 2]:
		var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v%s_world.json" % version))
		var before := JSON.stringify(old)
		var result := SaveStore.decode(old)
		check(result.has("world"), "genuine v%s fixture migrates to v3" % version)
		if result.has("world"):
			var w: WorldState = result.world
			check(w.tick == int(old.tick) and w.next_id == int(old.next_id) and w.rng.state == old.rng_state.to_int() and w.units.size() == old.units.size(), "v%s migration preserves time, IDs, RNG, and lives" % version)
			check(not w.kingdoms.is_empty() and w.villages[0].kingdom >= 0 and w.expeditions.is_empty(), "v%s villages gain realms without inventing expeditions" % version)
			check(JSON.stringify(old) == before and SaveStore.decode(SaveStore.encode(w)).has("world"), "v%s migration leaves its input intact and revalidates as v3" % version)
	var encoded := SaveStore.encode(expanded).duplicate(true)
	for field in ["ruler", "capital", "kingdom", "score", "status", "duplicate_pair", "loyalty", "expedition", "laws"]:
		var bad := encoded.duplicate(true)
		match field:
			"ruler": bad.kingdoms[0].ruler = 999999
			"capital": bad.kingdoms[0].capital = 999
			"kingdom": bad.villages[0].kingdom = 999
			"score": bad.relations[0].score = 101
			"status": bad.relations[0].status = "alliance" if bad.relations[0].status != "alliance" else "peace"
			"duplicate_pair": bad.relations.append(bad.relations[0].duplicate())
			"loyalty": bad.villages[0].loyalty = -5
			"expedition": bad.units[0].expedition = 0
			"laws": bad.laws.erase("diplomacy")
		check(SaveStore.decode(bad).has("error"), "v3 validation rejects corrupt " + field)
