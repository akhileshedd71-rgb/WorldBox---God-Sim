extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: ", description)
	else: failures += 1; printerr("FAIL: ", description)
func scenario(gap: int = -1) -> Simulation:
	var w := WorldState.new()
	w.generate(892, 0, false)
	w.fill_material(WorldState.Terrain.MEADOW)
	for key in ["births", "hunger", "old_age", "expansion", "diplomacy"]: w.laws[key] = false
	if gap >= 0:
		for y in w.height:
			for x in range(60, 70): w.set_material(w.index(x, y), gap)
	for x in [50, 80]:
		var v := w.create_village(Vector2i(x, 48))
		for n in 20:
			w.spawn("settler", Vector2i(x, 48))
			w.units[-1].village = v.id
			w.units[-1].age = 20
			# These checks measure base weapons; trait modifiers have their own suite.
			Heredity.replace_traits(w, w.units[-1].id, [])
		v.population = 20
		v.wood = 80
		v.stone = 80
		v.food = 80
		v.muster_after = 100000
	var sim := Simulation.new(w)
	sim.politics.refresh()
	sim.navigation.begin_tick()
	sim.spatial.rebuild(w.units)
	return sim
func serialize(w: WorldState) -> String: return JSON.stringify(SaveStore.encode(w), "", true, true)
func continuation(sim: Simulation, ticks: int, name: String) -> void:
	var decoded := SaveStore.decode(JSON.parse_string(serialize(sim.world)))
	check(decoded.has("world"), name + " round-trips through real JSON")
	if not decoded.has("world"): return
	var other := Simulation.new(decoded.world)
	for n in ticks: sim.step(); other.step()
	check(serialize(sim.world) == serialize(other.world), name + " preserves every field over %s ticks" % ticks)
func run() -> void:
	var started := Time.get_ticks_msec()
	_recruitment()
	_combat()
	_capture_and_peace()
	_navigation_and_transport()
	_disruption()
	_migration()
	print("\nMILITARY RESULT: %s checks, %s passed, %s failed (%s ms)" % [checks, checks - failures, failures, Time.get_ticks_msec() - started])
	quit(0 if failures == 0 else 1)
func _recruitment() -> void:
	var sim := scenario()
	var w := sim.world
	var m := sim.military
	check(not m.recruit(0) and not m.declare_war(0, 0), "peaceful villages and self-war cannot raise a war company")
	sim.politics.influence(0, "discord", 1)
	check(not m.at_war(0, 1), "rivalry alone never causes military attacks")
	check(m.declare_war(0, 1) and m.at_war(1, 0) and not m.declare_war(0, 1), "declared war is symmetric and cannot be duplicated")
	var ids: Array = w.units.map(func(u: Dictionary) -> int: return u.id)
	check(m.recruit(0) and not m.recruit(0), "a village can raise exactly one active company")
	var a := w.armies[0]
	check(w.units.map(func(u: Dictionary) -> int: return u.id) == ids and a.members.size() == 8, "recruitment transfers eight existing adults without spawning anyone")
	check(w.villages[0].wood == 64 and w.villages[0].stone == 72 and w.villages[0].food == 64, "eight equipment sets and rations cost 16 wood, 8 stone, and 16 food")
	check(w.kingdoms[0].ruler not in a.members and m.people(a).all(func(u: Dictionary) -> bool: return u.army == 0 and u.job == "soldier" and u.expedition < 0), "the ruler stays home and military membership is reciprocal")
	check(m.people(a).filter(func(u: Dictionary) -> bool: return u.weapon == "bow").size() == 2, "a mixed company receives two bows and six stone spears")
	sim.economy._recount()
	check(w.villages[0].jobs.soldier == 8 and w.villages[0].population == 20, "recruitment removes workers but preserves their village population")
	w.villages[1].stone = 0
	check(not m.recruit(1) and w.armies.size() == 1, "missing equipment materials prevent recruitment")
	check(m.fortify(0) and not m.fortify(0) and w.villages[0].wood == 48 and w.villages[0].stone == 60, "watchtower construction is paid once and cannot be stacked")
	for n in 16: sim.step()
	check(w.villages[0].tower == 160 and w.villages[0].fort_progress == 0, "nearby adult workers complete a physical watchtower")
	continuation(sim, 120, "A marching company")
func _combat() -> void:
	var sim := scenario()
	var w := sim.world
	var m := sim.military
	m.declare_war(0, 1)
	m.recruit(0)
	m.recruit(1, true)
	var a := w.armies[0]
	var b := w.armies[1]
	var attacker := m.people(a)[0]
	var defender := m.people(b)[0]
	attacker.x = 65
	defender.x = 66
	sim.spatial.rebuild(w.units)
	m.soldier_step(attacker)
	check(defender.health == 83 and attacker.attack_after == 4, "a stone spear deals damage in melee and has a cooldown")
	m.soldier_step(attacker)
	check(defender.health == 83, "cooldown prevents repeated damage within a tick")
	var archer := m.people(a)[2]
	archer.x = 62
	m.soldier_step(archer)
	check(defender.health == 72 and archer.attack_after == 6, "bows fire four tiles with their own damage and cooldown")
	w.set_material(w.index(64, 48), WorldState.Terrain.MOUNTAIN)
	check(not m.clear_shot(archer, defender), "ranged fire cannot pass through a mountain")
	w.set_material(w.index(64, 48), WorldState.Terrain.OCEAN)
	check(not m.clear_shot(archer, defender), "ranged fire cannot pass across impassable water")
	w.set_material(w.index(64, 48), WorldState.Terrain.MEADOW)
	var civilian := w.units[0]
	civilian.x = 66
	var civilian_health: float = civilian.health
	m.soldier_step(archer)
	check(civilian.health == civilian_health, "target selection leaves civilian workers and rulers unharmed")
	w.villages[1].tower = 160
	attacker.x = 76
	w.tick = 6
	sim.spatial.rebuild(w.units)
	m.finish_tick()
	check(attacker.health == 91, "a watchtower reacts to approaching enemy soldiers")
	for u in m.people(b).slice(0, 4): u.health = 0
	m.finish_tick()
	check(b.order == "return" and b.morale <= 30, "heavy losses break morale and trigger retreat")
	# Dead villagers are counted and removed by the regular life cycle.
	var before := w.units.size()
	sim.step()
	check(w.units.size() < before and w.villages[1].deaths >= 4 and w.villages[1].population < 20, "battle casualties affect real population and economic death counters")
	check(SaveStore.decode(SaveStore.encode(w)).has("world"), "casualties leave valid unit, army, and ruler references")
	check(w.battle_effects.size() <= 64 and not w.battle_effects.is_empty(), "combat emits bounded presentation cues without rendered nodes")
func _capture_and_peace() -> void:
	var sim := scenario()
	var w := sim.world
	var m := sim.military
	m.declare_war(0, 1)
	m.recruit(0)
	for n in 100: sim.step()
	check(w.villages[1].kingdom == 0 and w.villages[1].population == 20, "holding an undefended settlement captures its residents and stores intact")
	check(not w.kingdoms[1].alive and not m.at_war(0, 1), "capture of the last town collapses the realm and ends its war")
	check(w.armies[0].order == "return" and w.events.any(func(e: Dictionary) -> bool: return e.kind == "capture"), "capture orders survivors home and records the political change")
	check(SaveStore.decode(JSON.parse_string(serialize(w))).has("world"), "captured ownership passes the full v4 validator")
	sim = scenario()
	w = sim.world
	m = sim.military
	m.declare_war(0, 1)
	m.recruit(0)
	for n in 8: sim.step()
	check(m.make_peace(0, 1) and not m.at_war(0, 1) and w.armies[0].order == "return", "peace immediately ends hostilities and recalls the army")
	for n in 50: sim.step()
	check(not w.armies[0].active and w.units.all(func(u: Dictionary) -> bool: return u.army < 0 and u.weapon == ""), "surviving soldiers physically return and resume civilian jobs")
	check(w.units.size() == 40 and w.villages[1].kingdom == 1, "peace prevents subsequent fighting and capture")
	sim = scenario()
	w = sim.world
	m = sim.military
	m.declare_war(0, 1)
	m.recruit(0)
	w.villages[1].muster_after = 0
	for n in 24: sim.step()
	check(w.armies.size() == 2 and w.armies[1].order == "defend", "a threatened village automatically recruits a defending company")
	continuation(sim, 120, "A contested battle")
func _navigation_and_transport() -> void:
	var sim := scenario(WorldState.Terrain.MOUNTAIN)
	var w := sim.world
	var m := sim.military
	m.declare_war(0, 1)
	m.recruit(0)
	for n in 60: sim.step()
	check(m.people(w.armies[0]).all(func(u: Dictionary) -> bool: return u.x < 60), "soldiers cannot cross a mountain wall")
	check(not w.armies[0].boat.paid, "no boat is charged when no water crossing exists")
	sim = scenario(WorldState.Terrain.OCEAN)
	w = sim.world
	m = sim.military
	m.declare_war(0, 1)
	m.recruit(0)
	var a := w.armies[0]
	var sailing := false
	for n in 80:
		sim.step()
		if a.boat.state == "sailing": sailing = true; break
	check(sailing and a.boat.paid, "island invasion boards a paid transport before crossing water")
	check(m.people(a).all(func(u: Dictionary) -> bool: return m.embarked(u) and u.x == a.boat.x and u.y == a.boat.y), "all passengers share the actual boat position")
	check(a.boat.route.all(func(i: int) -> bool: return w.elevation[i] == WorldState.Elevation.WATER), "the transport route contains only water tiles")
	continuation(sim, 120, "An embarked invasion")
	check(w.villages[1].kingdom == 0, "a real landing permits capture on the far island")
	check(w.units.size() == 40, "embarked soldiers take no artificial drowning damage")
	for n in 160: sim.step()
	check(not a.active, "a returning company reuses its transport and demobilizes at home")
	sim = scenario(WorldState.Terrain.OCEAN)
	w = sim.world
	m = sim.military
	m.declare_war(0, 1)
	m.recruit(0)
	a = w.armies[0]
	for n in 80:
		sim.step()
		if a.boat.state == "sailing" and a.boat.x > 60: break
	m.make_peace(0, 1)
	var next: int = a.boat.route[0]
	w.set_material(next, WorldState.Terrain.MOUNTAIN)
	continuation(sim, 24, "A peace order aboard a rerouting ship")
	for n in 200: sim.step()
	check(not a.active and w.villages[1].kingdom == 1 and w.units.size() == 40, "peace at sea finishes a safe crossing, reroutes around edits, and brings everyone home")
func _disruption() -> void:
	var sim := scenario()
	var w := sim.world
	var m := sim.military
	m.declare_war(0, 1)
	m.recruit(0)
	m.recruit(1, true)
	var attacker := m.people(w.armies[0])[2]
	var friend := m.people(w.armies[0])[0]
	attacker.x = 65
	friend.x = 66
	sim.spatial.rebuild(w.units)
	var health: float = friend.health
	m.soldier_step(attacker)
	check(friend.health == health, "armed soldiers never damage a friendly company member")
	w.set_material(w.index(60, 47), WorldState.Terrain.MOUNTAIN)
	check(not m.clear_shot({"x": 59, "y": 47}, {"x": 61, "y": 49}), "supercover line of sight prevents shooting diagonally through a blocked corner")
	# Destroy the mustering home while paused, before death cleanup runs.
	w.power(Vector2i(50, 48), 4, "meteor")
	w.set_material(w.index(50, 48), WorldState.Terrain.OCEAN)
	sim.politics.refresh()
	m.reconcile()
	check(not w.armies[0].active and w.units.filter(func(u: Dictionary) -> bool: return u.village == 0).all(func(u: Dictionary) -> bool: return u.army == -1), "loss of the home realm clears even pending-death military assignments")
	check(SaveStore.decode(JSON.parse_string(serialize(w))).has("world"), "a paused disaster during war can be saved immediately")
	sim = scenario()
	w = sim.world
	m = sim.military
	m.declare_war(0, 1)
	m.recruit(0)
	var a := w.armies[0]
	for n in 6: sim.step()
	for y in w.height: w.set_material(w.index(59, y), WorldState.Terrain.MOUNTAIN)
	continuation(sim, 48, "A land route interrupted during invasion")
	check(m.people(a).all(func(u: Dictionary) -> bool: return u.x < 59) and w.villages[1].kingdom == 1, "a terrain edit interrupts a marching army without moving it through the barrier")
	sim = scenario(WorldState.Terrain.OCEAN)
	w = sim.world
	m = sim.military
	m.declare_war(0, 1)
	m.recruit(0)
	a = w.armies[0]
	for n in 80:
		sim.step()
		if a.boat.state == "sailing" and a.boat.x > 60: break
	var old_position := Vector2i(a.boat.x, a.boat.y)
	for d in WorldNavigation.DIRECTIONS: w.set_material(w.index(old_position.x + d.x, old_position.y + d.y), WorldState.Terrain.MOUNTAIN)
	for n in 6: sim.step()
	check(a.boat.state == "sailing" and Vector2i(a.boat.x, a.boat.y) == old_position, "a fully blocked boat remains at its actual position without teleporting")
	check(SaveStore.decode(JSON.parse_string(serialize(w))).has("world"), "a stranded transport remains saveable")
	w.set_material(w.index(old_position.x, old_position.y), WorldState.Terrain.MEADOW)
	for n in 2: sim.step()
	check(a.boat.state == "landed" and m.people(a).all(func(u: Dictionary) -> bool: return Vector2i(u.x, u.y) == old_position), "creating land under a stranded boat safely disembarks its passengers")
	# Active state itself is bounded, including record history.
	check(w.units.size() <= WorldState.MAX_UNITS and w.armies.size() <= MilitarySimulation.MAX_ARMIES, "war and transport preserve the existing world budgets")

func _migration() -> void:
	for version in [1, 2, 3]:
		var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v%s_world.json" % version))
		var before := JSON.stringify(old)
		var result := SaveStore.decode(old)
		check(result.has("world"), "genuine v%s save migrates to v4" % version)
		if not result.has("world"): continue
		var w: WorldState = result.world
		check(w.tick == int(old.tick) and w.rng.state == old.rng_state.to_int() and w.units.size() == old.units.size() and w.next_id == int(old.next_id), "v%s migration preserves time, RNG, IDs, and lives" % version)
		check(w.armies.is_empty() and w.relations.all(func(r: Dictionary) -> bool: return not r.war) and w.units.all(func(u: Dictionary) -> bool: return u.army < 0), "v%s migration invents no wars or soldiers" % version)
		check(JSON.stringify(old) == before and SaveStore.decode(SaveStore.encode(w)).has("world"), "v%s migration leaves input intact and revalidates" % version)
	var sim := scenario()
	sim.military.declare_war(0, 1)
	sim.military.recruit(0)
	var good: Dictionary = JSON.parse_string(serialize(sim.world))
	for field in ["army", "duplicate", "morale", "equipment", "child", "expedition", "tower", "war", "boat", "origin", "target", "cooldown"]:
		var bad := good.duplicate(true)
		match field:
			"army": bad.units[1].army = 999
			"duplicate": bad.armies[0].members.append(bad.armies[0].members[0])
			"morale": bad.armies[0].morale = -1
			"equipment": bad.units[1].weapon = "dragon"
			"child": bad.units[1].age = 3
			"expedition": bad.units[1].expedition = 0
			"tower": bad.villages[0].tower = 161
			"war": bad.relations[0].erase("war")
			"boat": bad.armies[0].boat.route = [1, 100]
			"origin": bad.armies[0].origin = 1
			"target": bad.armies[0].target = 500
			"cooldown": bad.units[1].attack_after = 50000
		check(SaveStore.decode(bad).has("error"), "v4 rejects malformed " + field)
