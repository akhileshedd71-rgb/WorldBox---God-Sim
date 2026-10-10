extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: ", description)
	else: failures += 1; printerr("FAIL: ", description)
func flat() -> WorldState:
	var w := WorldState.new(); w.generate(731, 0, false)
	w.fill_material(WorldState.Terrain.MEADOW)
	for law in ["births", "old_age", "hunger", "weather", "seasons", "ages", "disease", "expansion"]: w.laws[law] = false
	return w
func town(w: WorldState, p: Vector2i, count: int = 6) -> Dictionary:
	var v := w.create_village(p)
	for n in count:
		w.spawn("settler", p); w.units[-1].village = v.id; w.units[-1].age = 22
	v.population = count; v.food = 40
	return v
func run() -> void:
	var start := Time.get_ticks_msec()
	_identity()
	_work()
	_effects()
	_exchange()
	_residence()
	_persistence()
	_bounds()
	print("\nSOCIETY RESULT: %s checks, %s passed, %s failed (%s ms)" % [checks, checks - failures, failures, Time.get_ticks_msec() - start])
	quit(0 if failures == 0 else 1)
func _identity() -> void:
	var w := flat(); town(w, Vector2i(40, 48)); town(w, Vector2i(60, 48))
	var rng_before := w.rng.state
	SocietySimulation.assign_homes(w)
	check(w.cultures.size() == 2 and w.clans.size() == 4 and w.languages.size() == 2 and w.beliefs.size() == 2, "settlements establish four distinct stable social registries")
	check(w.rng.state == rng_before, "social founding consumes no ecological or genetic random draws")
	var u := w.units[0]; var identities: Array = SocietySimulation.FIELDS.map(func(key: String): return u[key])
	u.village = 1; SocietySimulation.assign_homes(w)
	check(SocietySimulation.FIELDS.map(func(key: String): return u[key]) == identities, "a migrant carries culture, clan, language, and belief into a new village")
	check(w.spawn("settler", Vector2i(60, 48), true, [w.units[6].id, u.id]), "a mixed-culture household can have a recorded child")
	check(w.units[-1].culture == u.culture and w.units[-1].clan == u.clan and Heredity.record(w, w.units[-1].id).parents.size() == 2, "newborn household identity is learned separately from its two biological parents")
	w.spawn("rabbit", Vector2i(60, 48))
	check(w.units[-1].culture == -1 and Heredity.record(w, w.units[-1].id).belief == -1, "wildlife remains socially unaffiliated")
	u.health = 0; Heredity.remember_death(w, u); w.units.erase(u)
	check(Heredity.record(w, u.id).culture == identities[0], "remembered lives retain their last social identity")
	check(SaveStore.decode(SaveStore.encode(w)).has("world"), "mixed families and a remembered migrant form a valid v7 save")
func _work() -> void:
	var w := flat(); var v := town(w, Vector2i(50, 48), 10)
	var sim := Simulation.new(w); sim.society.begin_tick()
	var u := w.units[0]; var c := w.cultures[u.culture]
	var i := w.index(53, 48); v.farms = [i]; w.farm_owner[i] = v.id; w.crops[i] = 64
	c.harvest = 90; u.x = 53; u.y = 48
	sim.economy._assign(u, "farm", i)
	var base := Heredity.work_ticks(u)
	for n in base - 1: sim.economy.worker_step(u)
	check(c.harvest == 90 and w.crops[i] == 64, "unfinished farm work awards no knowledge")
	sim.economy.worker_step(u)
	check(c.harvest == 96 and u.cargo == 6 and v.harvested == 6 and w.crops[i] == 0, "a real six-food harvest crosses the crop-rotation threshold")
	u.cargo = 0; u.cargo_type = ""; u.job = "farm"
	check(SocietySimulation.work_ticks(w, u) == maxi(1, base - 1), "learned crop rotation reduces actual farm work by one tick")
	w.laws.society = false
	check(SocietySimulation.work_ticks(w, u) == base, "pausing Society restores the inherited base work time")
	w.laws.society = true; c.building = 3; v.food = 80; v.wood = 12; v.stone = 4
	sim.economy.reset_job(u); sim.economy._choose_job(u, v)
	check(u.job == "build" and v.wood == 0 and v.stone == 0, "learning preserves the real twelve-wood/four-stone house payment")
	u.x = u.target % w.width; u.y = u.target / w.width
	for n in 6: sim.economy.worker_step(u)
	check(c.building == 4 and v.houses == 1, "a completed paid house unlocks masonry after four recorded constructions")
	u.job = "build"
	check(SocietySimulation.work_ticks(w, u) == 4, "masonry changes construction work from six ticks to four")
	var count := w.society_history.size(); SocietySimulation.learn(w, u.culture, "building", 100)
	check(c.building == 4 and w.society_history.size() == count, "knowledge is capped and unlock announcements are not duplicated")
func _effects() -> void:
	var w := flat(); var v := town(w, Vector2i(50, 48))
	var sim := Simulation.new(w); sim.society.begin_tick(); sim.politics.refresh()
	v.food = 40; v.loyalty = 50; sim.politics._loyalty()
	check(v.loyalty == 54 and v.loyalty_reason.contains("clan solidarity"), "resident clan solidarity adds one explained loyalty point to the yearly rule")
	w.laws.society = false; v.loyalty = 50; sim.politics._loyalty()
	check(v.loyalty == 53, "Society law removes the clan contribution while ordinary politics continues")
	w.laws.society = true; var u := w.units[0]; u.health = 50
	var base := Heredity.recovery(u); sim.step()
	check(u.health == 50 + base + 0.125, "shared hearth belief adds a measurable healing increment through the full simulation")
	u.expedition = 0
	check(sim.society.recovery(u) == 0, "communal care cannot follow a traveler away from home")
	u.expedition = -1; u.x = 90
	check(sim.society.recovery(u) == 0, "remote village affiliation does not grant local communal care")
	u.x = 50; w.laws.society = false
	check(sim.society.recovery(u) == 0, "Society law removes the belief effect")
	w.laws.society = true; sim.politics.refresh()
	var old: int = w.kingdoms[0].ruler
	var dead := Heredity.unit(w, old); dead.health = 0; Heredity.remember_death(w, dead); w.units.erase(dead)
	sim.politics.refresh()
	check(w.ruler_history.size() == 2 and w.ruler_history[0].person != old and w.ruler_history[1].person == old, "succession retains the actual past ruler ID after death")
	sim.politics.refresh()
	check(w.ruler_history.size() == 2, "read-only political refresh does not duplicate ruler transitions")
func _exchange() -> void:
	var w := flat(); town(w, Vector2i(40, 48)); town(w, Vector2i(60, 48))
	var sim := Simulation.new(w); sim.society.begin_tick(); sim.politics.refresh()
	w.cultures[1].harvest = 96
	w.tick = 48; sim.society.finish_tick()
	check(w.cultures[0].harvest == 1, "neighboring cultures with different languages share one real knowledge progress per year")
	for u in w.units:
		u.language = 0; SocietySimulation.archive(w, u)
	w.tick = 96; sim.society.finish_tick()
	check(w.cultures[0].harvest == 5, "a shared language increases teaching to four progress")
	var r := sim.politics.relation(0, 1, true); r.war = true
	w.tick = 144; sim.society.finish_tick()
	check(w.cultures[0].harvest == 5, "war blocks knowledge exchange across the same connected border")
	r.war = false; w.laws.cultural_exchange = false
	w.tick = 192; sim.society.finish_tick()
	check(w.cultures[0].harvest == 5, "the exchange law freezes shared learning")
	w.laws.cultural_exchange = true
	for y in w.height: w.set_material(w.index(50, y), WorldState.Terrain.OCEAN)
	w.tick = 240; sim.society.finish_tick()
	check(w.cultures[0].harvest == 5, "a canal prevents knowledge from crossing disconnected land")
	check(w.discoveries.any(func(d: Dictionary) -> bool: return d.key == "roots") and w.discoveries.any(func(d: Dictionary) -> bool: return d.key == "harvest"), "discovery emblems follow observed living cultures and learned knowledge")
	check(w.society_samples.size() == 5 and w.society_samples[-1].food == 80 and w.society_samples[-1].population == 12, "annual graphs sample real settler population and village resources")
func _residence() -> void:
	var w := flat(); town(w, Vector2i(40, 48)); town(w, Vector2i(60, 48))
	var sim := Simulation.new(w); sim.society.begin_tick()
	var u := w.units[0]; var genome: Dictionary = u.genome.duplicate(true); var clan: int = u.clan
	u.village = 1; u.x = 60; u.social_home = -1; u.residence = 0
	for n in 95: w.tick += 1; sim.society.begin_tick()
	check(u.culture == 0 and u.residence == 95, "visiting a majority community does not immediately replace culture")
	SaveStore.save_world(w, "user://pending-residence.json")
	var pending := SaveStore.load_world("user://pending-residence.json")
	check(pending.has("world"), "a pending adoption one tick before its threshold survives actual JSON validation")
	w.tick += 1; sim.society.begin_tick(); sim.society.finish_tick()
	check(u.culture == 1 and u.belief == 0 and u.language == 0, "two full years of residence adopts culture independently of belief and language")
	for n in 48: w.tick += 1; sim.society.begin_tick()
	sim.society.finish_tick()
	check(u.belief == 1 and u.language == 0, "three full years of residence can adopt the majority hearth faith")
	for n in 48: w.tick += 1; sim.society.begin_tick()
	sim.society.finish_tick()
	check(u.language == 1 and u.clan == clan and u.genome == genome, "four years teaches a language while clan and genome remain independent")
	check(Heredity.record(w, u.id).culture == 1 and Heredity.record(w, u.id).events[0].kind == "society", "adoption updates the archive and personal memory")
	if pending.has("world"):
		var copy: WorldState = pending.world
		var society := SocietySimulation.new(copy, WorldNavigation.new(copy))
		while copy.tick < w.tick:
			copy.tick += 1; society.begin_tick(); society.finish_tick()
		check(JSON.stringify(SaveStore.encode(copy), "", true, true) == JSON.stringify(SaveStore.encode(w), "", true, true), "pending residence reload reproduces culture, belief, language, archive memories, and discoveries exactly")
	DirAccess.remove_absolute("user://pending-residence.json")
	u.residence = 37; w.laws.cultural_exchange = false
	for n in 48: w.tick += 1; sim.society.begin_tick()
	sim.society.finish_tick()
	check(u.residence == 37, "exchange pause preserves unfinished residence timers exactly")
	w.laws.cultural_exchange = true; u.x = 100; sim.society.begin_tick()
	check(u.residence == 0 and u.social_home == -1, "leaving the community resets continuous residence")
func _persistence() -> void:
	for version in range(1, 7):
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v%s_world.json" % version))
		var original := JSON.stringify(source)
		var result := SaveStore.decode(source)
		check(result.has("world"), "genuine v%s fixture migrates into the v7 social schema" % version)
		if not result.has("world"): continue
		var w: WorldState = result.world
		check(w.tick == source.tick and w.next_id == source.next_id and str(w.rng.state) == source.rng_state and w.units.size() == source.units.size(), "v%s migration preserves lives, IDs, time, and simulation RNG" % version)
		check(not w.laws.society and not w.laws.cultural_exchange and w.cultures.all(func(c: Dictionary) -> bool: return c.harvest == 0 and c.building == 0), "v%s migration leaves new rule effects dormant without inventing past learning" % version)
		check(JSON.stringify(source) == original and SaveStore.decode(SaveStore.encode(w)).has("world"), "v%s migration leaves input untouched and revalidates as v7" % version)
		if version == 6:
			check(JSON.parse_string(JSON.stringify(w.climate)) == source.climate and str(w.climate_rng.state) == source.climate_rng_state and w.hazards.size() == source.hazards.size(), "v6 climate state, independent RNG, and active eruption survive social migration")
			var same := true
			for n in w.lineage.size():
				var old: Dictionary = w.lineage[n].duplicate(true)
				for key in SocietySimulation.FIELDS: old.erase(key)
				if JSON.parse_string(JSON.stringify(old, "", true, true)) != source.lineage[n]: same = false
			check(same, "v6 ancestry, favorite flags, genomes, and earlier memories remain untouched")
			var old_units: Array = w.units.duplicate(true)
			for u in old_units:
				for key in SocietySimulation.FIELDS + ["residence", "social_home"]: u.erase(key)
			check(JSON.parse_string(JSON.stringify(old_units, "", true, true)) == source.units and w.moisture == PackedByteArray(source.moisture) and w.snow == PackedByteArray(source.snow), "v6 live health, illness, work, cargo, genes, moisture, and snow remain unchanged")
	var w := WorldState.new(); w.generate(41827, 2); var sim := Simulation.new(w)
	for n in 240: sim.step()
	check(SaveStore.save_world(w, "user://society-test.json") == OK, "social state writes to a real v7 JSON save")
	var result := SaveStore.load_world("user://society-test.json")
	check(result.has("world"), "JSON reload validates every social ID, progress counter, event, and ruler reference")
	if result.has("world"):
		var other := Simulation.new(result.world)
		for n in 144: sim.step(); other.step()
		check(JSON.stringify(SaveStore.encode(w), "", true, true) == JSON.stringify(SaveStore.encode(other.world), "", true, true), "144 ticks after JSON reload preserve every field including social effects and timers")
	DirAccess.remove_absolute("user://society-test.json")
	var valid := SaveStore.encode(w).duplicate(true)
	for key in ["culture", "clan", "language", "belief", "archive", "progress", "timer", "law", "person", "ruler", "sample", "discovery", "wildlife", "table", "duplicate"]:
		var bad: Dictionary = valid.duplicate(true)
		match key:
			"culture", "clan", "language", "belief": bad.units[0][key] = 99999
			"archive": bad.lineage[0].culture = -1
			"progress": bad.cultures[0].harvest = 97
			"timer": bad.units[0].residence = 193
			"law": bad.laws.society = "true"
			"person": bad.society_history[0].person = 99999
			"ruler": bad.ruler_history[0].kingdom = 99999
			"sample": bad.society_samples[0].year = 99999
			"discovery": bad.discoveries.append({"key": "invented", "tick": 0})
			"wildlife":
				for u in bad.units:
					if u.species != "settler": u.culture = 0; break
			"table": bad.cultures[0].id = 1
			"duplicate": bad.ruler_history.resize(257)
		check(SaveStore.decode(bad).has("error"), "v7 rejects corrupt %s without replacing the active world" % key)
func _bounds() -> void:
	var w := flat()
	for n in SocietySimulation.MAX_CULTURES: SocietySimulation.founding(w)
	check(SocietySimulation.founding(w) == -1 and w.clans.size() == 256, "social IDs stop allocating at their explicit caps")
	for n in 300:
		w.tick += 1; SocietySimulation.log_event(w, "knowledge", 0, -1, "A bounded memory.")
	check(w.society_history.size() == 192 and w.society_history[0].tick == 300, "social history retains the latest 192 events")
	check(SaveStore.decode(SaveStore.encode(w)).has("world"), "a capped social registry and trimmed history remain saveable")
