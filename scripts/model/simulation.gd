class_name Simulation
extends RefCounted
## Fixed-step survival and population; physical work is in VillageEconomy.
const STEP_SECONDS := 0.25
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
var world: WorldState
var navigation: WorldNavigation
var spatial := SpatialIndex.new()
var economy: VillageEconomy
var politics: KingdomPolitics
var military: MilitarySimulation
var environment: EnvironmentSimulation
var society: SocietySimulation

func _init(state: WorldState) -> void:
	world = state
	environment = EnvironmentSimulation.new(world)
	navigation = WorldNavigation.new(world)
	economy = VillageEconomy.new(world, navigation)
	society = SocietySimulation.new(world, navigation)
	politics = KingdomPolitics.new(world, navigation, economy)
	military = MilitarySimulation.new(world, navigation, economy, politics, spatial)

func step() -> void:
	world.tick += 1
	_environment()
	navigation.begin_tick()
	spatial.rebuild(world.units)
	environment.diseases(spatial, navigation)
	economy.begin_tick(spatial)
	society.begin_tick()
	politics.refresh()
	military.begin_tick()
	for u in world.units:
		if u.health <= 0: continue
		if world.tick % 48 == 0:
			u.age += 1
			if u.age == SpeciesCatalog.maturity(u.species): Heredity.event(world, u.id, "Reached adulthood.", "maturity")
		u.cooldown = maxi(0, u.cooldown - 1)
		var i := world.index(u.x, u.y)
		var embarked := military.embarked(u)
		if not embarked and not world.habitable(u.x, u.y): u.health -= 8.0; u.state = "Stranded"
		if world.fire[i] > 0: u.health -= 16.0; u.state = "Fleeing fire"
		if world.laws.hunger:
			u.hunger = minf(100.0, u.hunger + Heredity.hunger_rate(world, u) * EnvironmentSimulation.hunger_multiplier(world, u))
			# Members prefer their pantry; hungry nomads/wildlife use local forage.
			var can_forage: bool = u.village < 0 or world.villages[u.village].food == 0
			if can_forage and u.hunger > 18 and world.food[i] >= 1:
				world.food[i] -= 1
				u.hunger = maxf(0, u.hunger - 20)
				u.state = "Foraging"
			if u.hunger > 85: u.health -= 2.5; u.state = "Starving"
		if u.health <= 0: continue
		if u.hunger < 30 and (not world.laws.disease or u.sickness == 0): u.health = minf(100.0, u.health + Heredity.recovery(u) + society.recovery(u))
		if world.laws.old_age and u.age > Heredity.lifespan(u): u.health -= 1.0
		if embarked: military.feed(u)
		elif world.fire[i] > 0 or not world.habitable(u.x, u.y):
			economy.reset_job(u)
			_wander(u)
		elif military.soldier_step(u): pass
		elif politics.expedition_step(u): pass
		elif not economy.worker_step(u): _wander(u)
	military.finish_tick()
	for u in world.units:
		if u.health <= 0:
			Heredity.remember_death(world, u)
			if u.village >= 0: world.villages[u.village].deaths += 1
	world.units = world.units.filter(func(u: Dictionary) -> bool: return u.health > 0)
	economy.finish_tick()
	politics.finish_tick()
	military.reconcile()
	spatial.rebuild(world.units)
	_reproduce()
	society.finish_tick()

func _reproduce() -> void:
	if not world.laws.births: return
	var babies: Array[Dictionary] = []
	for u in world.units:
		if u.army >= 0 or u.expedition >= 0 or u.cooldown > 0 or u.hunger >= 35 or u.health <= 65 or u.age < SpeciesCatalog.maturity(u.species): continue
		if world.units.size() + babies.size() >= WorldState.MAX_UNITS or world.lineage.size() + babies.size() >= Heredity.MAX_RECORDS: break
		var v: Dictionary = {}
		if SpeciesCatalog.get_species(u.species).forms_villages:
			if u.village < 0: continue
			v = world.villages[u.village]
			if not v.alive or v.population >= world.housing(v) or v.food < maxi(8, v.population * 2): continue
		elif world.food[world.index(u.x, u.y)] < 3: continue
		if world.rng.randf() >= SpeciesCatalog.get_species(u.species).birth_chance: continue
		for other in spatial.nearby(Vector2i(u.x, u.y), 6):
			if other.army >= 0 or other.expedition >= 0 or other.id == u.id or other.species != u.species or other.age < SpeciesCatalog.maturity(other.species) or other.cooldown > 0 or other.health <= 65 or other.hunger >= 35: continue
			if SpeciesCatalog.get_species(u.species).forms_villages and u.village != other.village: continue
			if Heredity.related(world, u.id, other.id): continue
			if not navigation.connected(Vector2i(u.x, u.y), Vector2i(other.x, other.y)): continue
			babies.append({"species": u.species, "p": Vector2i(u.x, u.y), "village": u.village, "parents": [u.id, other.id]})
			u.cooldown = SpeciesCatalog.get_species(u.species).birth_cooldown
			other.cooldown = u.cooldown
			if not v.is_empty():
				v.food -= 2
				v.consumed += 2
				v.population += 1
				v.births += 1
			break
	for baby in babies:
		if world.spawn(baby.species, baby.p, true, baby.parents): world.units[-1].village = baby.village

func _wander(u: Dictionary) -> void:
	var best := Vector2i(u.x, u.y)
	var score := -1000.0
	for d in DIRECTIONS:
		var p: Vector2i = Vector2i(u.x, u.y) + d
		if not world.habitable(p.x, p.y): continue
		var i := world.index(p.x, p.y)
		var value := world.rng.randf_range(0, 4) - float(world.fire[i]) * 10
		if u.hunger > 18: value += world.food[i] * 0.6
		if u.village >= 0:
			var v := world.villages[u.village]
			value -= Vector2(p.x - v.x, p.y - v.y).length() * 0.5
		if value > score: score = value; best = p
	u.x = best.x
	u.y = best.y
	if u.village < 0 and u.hunger < 18: u.state = "Exploring"

func _environment() -> void:
	environment.step()
