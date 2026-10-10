extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: ", description)
	else: failures += 1; printerr("FAIL: ", description)
func island(seed_value: int = 619) -> WorldState:
	var w := WorldState.new()
	w.generate(seed_value, 0, false)
	w.fill_material(WorldState.Terrain.OCEAN)
	for y in range(40, 61):
		for x in range(60, 81): w.set_material(w.index(x, y), WorldState.Terrain.MEADOW)
	w.laws.births = false
	w.laws.old_age = false
	w.laws.expansion = false
	w.laws.hunger = false
	w.laws.seasons = false
	w.laws.ages = false
	w.laws.weather = false
	w.laws.disease = false
	return w
func env_ticks(w: WorldState, count: int) -> void:
	var env := EnvironmentSimulation.new(w)
	for n in count: w.tick += 1; env.step()
func run() -> void:
	var started := Time.get_ticks_msec()
	_biomes()
	_climate()
	_disease()
	_disasters()
	_persistence()
	_food_stress()
	print("\nENVIRONMENT RESULT: %s checks, %s passed, %s failed (%s ms)" % [checks, checks - failures, failures, Time.get_ticks_msec() - started])
	quit(0 if failures == 0 else 1)
func _biomes() -> void:
	var a := WorldState.new()
	a.generate(41827, 2)
	var b := WorldState.new()
	b.generate(41827, 2)
	check(a.biomes == b.biomes and a.moisture == b.moisture and a.climate_rng.state == b.climate_rng.state, "climate geography and its independent random stream are seeded")
	check(4 in a.biomes and 5 in a.biomes and 6 in a.biomes, "generation includes arid, wetland, and original glimmer ecosystems")
	var w := island()
	var i := w.index(70, 50)
	var v := w.create_village(Vector2i(68, 50))
	v.sites = [i]; v.houses = 1
	w.spawn("settler", Vector2i(70, 50))
	var u := w.units[0]
	Heredity.replace_traits(w, u.id, ["woodland_adapted"])
	var elevation := w.elevation.duplicate()
	var navigation_revision := w.navigation_revision
	var ids := w.units.duplicate(true)
	w.paint_biome(Vector2i(70, 50), 2, 6)
	check(w.elevation == elevation and w.navigation_revision == navigation_revision and w.units == ids and v.houses == 1, "biome painting preserves navigation, identities, and buildings")
	check(w.biomes[i] == 6 and w.fertile(70, 50), "glimmergrove is an independently painted fertile ecosystem")
	check(Heredity.hunger_rate(w, u) == 0.4375, "existing woodland genes also help in glimmergrove")
	w.set_biome(i, 5)
	Heredity.replace_traits(w, u.id, ["meadow_adapted"])
	check(Heredity.hunger_rate(w, u) == 0.4375, "meadow adaptation applies to related wetland habitat")
	check(not w.set_biome(0, 5) and w.elevation[0] == 0 and w.biomes[0] == 0, "biome painting cannot turn ocean into walkable ground")
	check(not w.set_biome(i, 7) and not w.set_biome(-1, 2), "invalid biome edits are rejected before mutation")
	var plot := w.index(72, 52)
	v.farms = [plot]; w.farm_owner[plot] = v.id; w.crops[plot] = 32
	w.set_biome(plot, 4)
	check(w.crops[plot] == 0 and w.farm_owner[plot] == -1 and v.farms.is_empty() and v.houses == 1, "arid painting removes incompatible farms while preserving homes")
	w.set_biome(i, 2); w.trees[i] = 0; w.tree_growth[i] = 0; w.stone[i] = 0
	env_ticks(w, 192)
	check(w.trees[i] == 1, "woodland regrows a real finite wood unit over 192 ticks")
	w.set_biome(i, 6); w.trees[i] = 0; w.tree_growth[i] = 0
	env_ticks(w, 96)
	check(w.trees[i] == 1, "glimmergrove has a distinct faster wood regeneration rule")
	w.laws.weather = true
	check(EnvironmentSimulation.growth_interval(w, i) == 1 and EnvironmentSimulation.growth_interval(w, i, true) == 2, "glimmergrove slows crops while retaining fast timber and forage growth")
	w.laws.weather = false
	var neighbor := w.index(71, 50)
	w.trees[neighbor] = 0; w.stone[neighbor] = 0; w.tree_growth[neighbor] = 0
	env_ticks(w, 192)
	check(w.trees[neighbor] > 0, "vegetation can spread to an adjacent suitable tile")
	w.laws.vegetation = false
	var food := w.food.duplicate(); var trees := w.trees.duplicate(); var growth := w.tree_growth.duplicate()
	env_ticks(w, 48)
	check(w.food == food and w.trees == trees and w.tree_growth == growth, "plant-growth law freezes forage and vegetation clocks")
func _climate() -> void:
	var w := island()
	var i := w.index(70, 50)
	w.laws.weather = true
	w.laws.fire_spread = false
	w.fire[i] = 9; w.moisture[i] = 0; w.food[i] = 0
	check(EnvironmentSimulation.set_weather(w, 1), "the rain intervention sets an actual timed weather state")
	env_ticks(w, 8)
	check(w.fire[i] == 0 and w.moisture[i] > 0, "rain extinguishes burning land and replenishes moisture within one staggered pass")
	w.moisture[i] = 64; w.food[i] = 0
	env_ticks(w, 8)
	check(w.food[i] == 0.1875, "rain increases actual forage regeneration by half")
	var v := w.create_village(Vector2i(68, 50)); v.farms = [i]; w.farm_owner[i] = 0; w.crops[i] = 1
	env_ticks(w, 8)
	check(w.crops[i] == 17, "rain accelerates existing crops without directly creating stored food")
	EnvironmentSimulation.set_weather(w, 2)
	var crop := w.crops[i]
	var wetness := w.moisture[i]
	env_ticks(w, 16)
	check(w.crops[i] == crop and w.moisture[i] < wetness, "drought dries the soil and stops crop growth")
	EnvironmentSimulation.set_weather(w, 1); w.moisture[i] = 64
	env_ticks(w, 8)
	check(w.crops[i] > crop, "renewed rain lets stressed crops resume growing")
	w.laws.vegetation = false; crop = w.crops[i]
	env_ticks(w, 8)
	check(w.crops[i] == crop, "plant-growth law freezes actual planted crops even under rain")
	w.laws.vegetation = true
	w.laws.seasons = true; w.climate.season_clock = 300
	EnvironmentSimulation.set_weather(w, 3)
	env_ticks(w, 8)
	check(w.snow[i] > 0 and EnvironmentSimulation.temperature(w, i) < 0, "winter snowfall creates persistent visible snow cover")
	w.laws.seasons = false; EnvironmentSimulation.set_weather(w, 0)
	env_ticks(w, 24)
	check(w.snow[i] == 0, "snow cover melts when the weather warms")
	w.laws.weather = false
	var climate := w.climate.duplicate(true); var moisture := w.moisture.duplicate()
	env_ticks(w, 10)
	check(w.climate == climate and w.moisture == moisture and not EnvironmentSimulation.set_weather(w, 2), "weather law freezes forecasts and moisture and disables weather interventions")
	w.laws.seasons = true; w.climate.season_clock = 95
	env_ticks(w, 1)
	check(EnvironmentSimulation.season(w) == 1 and EnvironmentSimulation.temperature(w, i) == 28, "season boundaries change the temperature rule table")
	w.laws.seasons = false; w.laws.ages = true; w.climate.age_clock = 1535
	env_ticks(w, 1)
	check(EnvironmentSimulation.age(w) == 1 and EnvironmentSimulation.temperature(w, i) == 32, "world-age boundaries apply long-lived heat modifiers")
	w.spawn("settler", Vector2i(70, 50)); var u := w.units[0]
	Heredity.replace_traits(w, u.id, []); w.climate.age_clock = 3072; w.laws.seasons = true; w.climate.season_clock = 300
	check(EnvironmentSimulation.hunger_multiplier(w, u) == 1.25, "extreme cold raises the food requirement for unadapted creatures")
	Heredity.replace_traits(w, u.id, ["cold_adapted"])
	check(EnvironmentSimulation.hunger_multiplier(w, u) == 1.0, "cold-adapted creatures avoid the cold appetite penalty")
	w.laws.seasons = false; w.laws.ages = false
	var frozen := w.climate.duplicate(true)
	env_ticks(w, 8)
	check(w.climate == frozen, "disabling seasons and ages freezes both ecological clocks")
	check(EnvironmentSimulation.preset(w, "Peaceful") and not w.laws.hunger and not w.laws.disease and not w.laws.natural_disasters and not w.laws.fire_spread, "Peaceful preset applies explained survival and hazard laws")
	check(EnvironmentSimulation.preset(w, "Catastrophe") and w.laws.hunger and w.laws.disease and w.laws.natural_disasters and w.laws.fire_spread, "Catastrophe preset enables actual hazards and survival pressure")
	check(EnvironmentSimulation.preset(w, "Living planet") and not w.laws.natural_disasters and w.laws.disease, "Living planet returns to ecological rules without spontaneous disasters")
func _disease() -> void:
	var w := island(48)
	w.laws.disease = true
	for n in 12: w.spawn("settler", Vector2i(70, 50))
	w.spawn("rabbit", Vector2i(70, 50))
	var source := w.units[0]
	var rabbit := w.units[-1]
	check(EnvironmentSimulation.infect(w, source) and source.sickness == 64, "Rustfever seeds one bounded illness timer")
	check(not EnvironmentSimulation.infect(w, source), "reinfection cannot restart an active illness")
	var sim := Simulation.new(w)
	for n in 8:
		w.tick += 8; sim.spatial.rebuild(w.units); sim.environment.diseases(sim.spatial, sim.navigation)
	check(w.units.filter(func(u: Dictionary) -> bool: return u.sickness > 0).size() > 1, "Rustfever spreads through real nearby same-species contacts")
	check(rabbit.sickness == 0, "different species do not share Rustfever contact transmission")
	check(source.health < 100, "infection causes real health loss")
	w.laws.disease = false
	var before := w.units.duplicate(true)
	for n in 8: sim.environment.diseases(sim.spatial, sim.navigation)
	check(w.units == before and not EnvironmentSimulation.infect(w, rabbit), "disabling Disease pauses transmission, damage, recovery, and immunity clocks")
	w.laws.disease = true
	for n in 64: w.tick += 1; sim.environment.diseases(sim.spatial, sim.navigation)
	check(source.sickness == 0 and source.immunity > 0 and not EnvironmentSimulation.infect(w, source), "recovered creatures acquire effective temporary immunity")
	source.immunity = 1
	sim.environment.diseases(sim.spatial, sim.navigation)
	check(source.immunity == 0 and EnvironmentSimulation.infect(w, source), "temporary immunity expires and permits a later infection")
	check(Heredity.record(w, source.id).events.any(func(e: Dictionary) -> bool: return e.kind == "recovery"), "recovery becomes a persistent personal memory")
	w = island(); w.laws.disease = true
	w.spawn("settler", Vector2i(69, 50)); w.spawn("settler", Vector2i(71, 50))
	for y in range(40, 61): w.set_material(w.index(70, y), WorldState.Terrain.OCEAN)
	sim = Simulation.new(w); EnvironmentSimulation.infect(w, w.units[0]); sim.spatial.rebuild(w.units)
	for n in 20: w.tick += 8; sim.environment.diseases(sim.spatial, sim.navigation)
	check(w.units[1].sickness == 0, "nearby creatures separated by ocean cannot transmit illness across the barrier")
	w = island(); w.laws.disease = true
	w.spawn("settler", Vector2i(70, 50)); source = w.units[0]; Heredity.replace_traits(w, source.id, [])
	EnvironmentSimulation.infect(w, source); sim = Simulation.new(w)
	sim.step()
	check(source.health == 99.75 and source.sickness == 63, "normal simulation suppresses healing while applying illness damage")
	for n in 63: sim.step()
	check(source.sickness == 0 and source.immunity == 192 and source.health > 80, "an otherwise healthy creature survives and recovers through the full simulation")
func _disasters() -> void:
	var w := island()
	w.laws.fire_spread = false
	var center := Vector2i(70, 50); var i := w.index(70, 50)
	w.spawn("settler", center)
	check(EnvironmentSimulation.disaster(w, center, "lightning") and w.fire[i] == 9 and w.units[0].health == 65, "lightning ignites vegetation and injures actual creatures")
	var v := w.create_village(Vector2i(68, 50))
	v.sites = [i]; v.houses = 1; var plot := w.index(71, 50); v.farms = [plot]; w.farm_owner[plot] = 0; w.crops[plot] = 32
	EnvironmentSimulation.disaster(w, center, "quake")
	check(v.houses == 0 and v.farms.is_empty() and w.crops[plot] == 0 and w.units[0].health == 10, "earthquake destruction reduces housing, farms, and health together")
	w.set_material(i, WorldState.Terrain.MEADOW)
	var revision := w.navigation_revision
	check(EnvironmentSimulation.disaster(w, center, "volcano") and w.elevation[i] == 2 and w.navigation_revision > revision and w.hazards.size() == 1, "volcano raises a real navigation obstacle and starts a finite eruption")
	env_ticks(w, 24)
	check(w.hazards.is_empty(), "a volcano expires after exactly six bounded eruption pulses")
	w.hazards.clear()
	for x in 8: EnvironmentSimulation.disaster(w, Vector2i(61 + x * 2, 44), "volcano")
	check(w.hazards.size() == 8 and not EnvironmentSimulation.disaster(w, Vector2i(65, 58), "volcano"), "active eruptions have a strict eight-vent budget")
	w.hazards.clear(); w.laws.natural_disasters = false; var terrain := w.terrain.duplicate(); var clock: int = w.climate.disaster_clock
	env_ticks(w, 192)
	check(w.climate.disaster_clock == clock and w.terrain == terrain and w.hazards.is_empty(), "natural-disaster law freezes spontaneous hazard scheduling")
	w.laws.natural_disasters = true
	w.events.clear()
	var env := EnvironmentSimulation.new(w)
	for n in 24:
		w.tick += 192; w.climate.disaster_clock = 191; env._climate()
	check(w.events.any(func(e: Dictionary) -> bool: return e.kind == "disaster") and w.hazards.size() <= 8, "enabled spontaneous hazards run through the bounded natural scheduler")
	for n in 40: EnvironmentSimulation.disaster(w, center, "lightning")
	check(w.units[0].health >= 0, "repeated destructive interventions keep creature health bounded")
	var sim := Simulation.new(w)
	sim.step()
	check(SaveStore.decode(SaveStore.encode(w)).has("world"), "disaster aftermath remains a valid world after deaths and ownership reconcile")
func _persistence() -> void:
	for version in range(1, 6):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v%s_world.json" % version))
		var result := SaveStore.decode(data)
		check(result.has("world") and result.world.tick == data.tick and result.world.rng.state == data.rng_state.to_int() and not result.world.laws.weather and not result.world.laws.disease, "genuine v%s migration preserves time/RNG and introduces dormant new climate systems" % version)
		if version == 5 and result.has("world"):
			# Compare every original field; Phase 7 adds separate memberships.
			var prior: Array = result.world.lineage.duplicate(true)
			for record in prior:
				for key in SocietySimulation.FIELDS: record.erase(key)
			check(JSON.parse_string(JSON.stringify(prior, "", true, true)) == data.lineage and result.world.units.size() == data.units.size(), "v5 migration preserves ancestry, favorites, and living identities")
	var w := island(671)
	w.spawn("settler", Vector2i(70, 50)); w.laws.disease = true; w.laws.weather = true; w.laws.seasons = true; w.laws.ages = true
	EnvironmentSimulation.infect(w, w.units[0]); EnvironmentSimulation.set_weather(w, 1)
	EnvironmentSimulation.disaster(w, Vector2i(74, 54), "volcano")
	var sim := Simulation.new(w); sim.step()
	check(SaveStore.save_world(w, "user://environment-test.json") == OK, "v6 saves active weather, illness, and an eruption to disk")
	var loaded := SaveStore.load_world("user://environment-test.json")
	check(loaded.has("world"), "the active environmental save passes strict load validation")
	if loaded.has("world"):
		var restored: WorldState = loaded.world
		check(JSON.stringify(SaveStore.encode(w), "", true, true) == JSON.stringify(SaveStore.encode(restored), "", true, true), "JSON preserves every environmental field exactly")
		var other := Simulation.new(restored)
		for n in 240: sim.step(); other.step()
		check(JSON.stringify(SaveStore.encode(w), "", true, true) == JSON.stringify(SaveStore.encode(restored), "", true, true), "weather transitions, illness, eruptions, and simulation continue identically for 240 ticks")
	DirAccess.remove_absolute("user://environment-test.json")
	var base := SaveStore.encode(w).duplicate(true)
	for bad in ["moisture", "snow", "weather", "clock", "rng", "illness", "immunity", "both", "law", "hazards", "vent", "ocean_biome"]:
		var d: Dictionary = base.duplicate(true)
		match bad:
			"moisture": d.moisture[0] = 101
			"snow": d.snow[0] = 1
			"weather": d.climate.weather = 5
			"clock": d.climate.age_clock = 4608
			"rng": d.climate_rng_state = "invalid"
			"illness": d.units[0].sickness = 65
			"immunity": d.units[0].immunity = -1
			"both": d.units[0].sickness = 1; d.units[0].immunity = 1
			"law": d.laws.erase("weather")
			"hazards": d.hazards = "volcano"
			"vent": d.hazards = [{"cell": 0, "remaining": 25}]
			"ocean_biome": d.biomes[0] = 6
		check(SaveStore.decode(d).has("error"), "malformed v6 %s state is rejected" % bad)
func _food_stress() -> void:
	var yields := []
	for dry in [false, true]:
		var w := island(391)
		w.laws.weather = true
		w.trees.fill(0); w.stone.fill(0)
		var v := w.create_village(Vector2i(70, 50))
		for n in 8:
			w.spawn("settler", Vector2i(70, 50)); w.units[-1].village = 0; w.units[-1].age = 25
		v.population = 8
		var sim := Simulation.new(w)
		for n in 300:
			if n % 100 == 0: EnvironmentSimulation.set_weather(w, 2 if dry else 1)
			sim.step()
		yields.append(v.harvested)
	print("ENVIRONMENT HARVEST: rain=%s drought=%s" % yields)
	check(yields[0] > 0 and yields[1] < yields[0], "sustained drought reduces actual worker harvests compared with rain")
