class_name VillageEconomy
extends RefCounted
## Goods leave a tile, travel with a worker, then enter storage.
const JOBS := ["idle", "forage", "log", "mine", "farm", "build", "haul", "eat", "rest", "settle", "soldier"]
var world: WorldState
var navigation: WorldNavigation
var reserved := {}

func _init(state: WorldState, routes: WorldNavigation) -> void:
	world = state
	navigation = routes

func begin_tick(spatial: SpatialIndex) -> void:
	reserved.clear()
	for u in world.units:
		if u.health > 0 and u.target >= 0 and u.job in ["forage", "log", "mine", "farm", "build"]:
			reserved[u.target] = u.id
	_recount()
	if world.tick % 12 == 0:
		_settle(spatial)
		_recount()
		for v in world.villages:
			if v.alive: _plan_farms(v)

func finish_tick() -> void:
	_recount()
	if world.tick % 48 != 0: return
	for v in world.villages:
		if not v.alive: continue
		v.history.append({"year": world.year(), "population": v.population, "food": v.food, "housing": world.housing(v)})
		if v.history.size() > 120: v.history.pop_front()
		var shortage: bool = v.food < maxi(2, v.population / 2)
		if shortage and not v.shortage: world.add_event("%s's pantry is running low." % v.name, "shortage")
		if not shortage and v.shortage: world.add_event("Food is returning to %s's stores." % v.name, "village")
		v.shortage = shortage

func _recount() -> void:
	for v in world.villages:
		v.population = 0
		v.jobs = {}
	for u in world.units:
		if u.village < 0 or u.health <= 0: continue
		var v := world.villages[u.village]
		if not v.alive:
			u.village = -1
			reset_job(u)
			continue
		v.population += 1
		v.jobs[u.job] = v.jobs.get(u.job, 0) + 1
	for v in world.villages:
		if not v.alive: continue
		v.farms = v.farms.filter(func(i: int) -> bool: return world.farm_owner[i] == v.id and world.fertile(i % world.width, i / world.width))
		var surviving: Array = []
		for site in v.sites:
			if world.habitable(site % world.width, site / world.width) and world.fire[site] == 0: surviving.append(site)
		v.sites = surviving
		v.houses = v.sites.size()
		if v.population > 0 and world.habitable(v.x, v.y): continue
		v.alive = false
		v.tower = 0
		v.fort_progress = 0
		world.add_event("%s has fallen silent." % v.name, "disaster")
		for i in v.farms:
			world.farm_owner[i] = -1
			world.crops[i] = 0
		v.farms.clear()
		v.sites.clear()
		v.houses = 0
		v.build_site = -1
		v.build_progress = 0
		for u in world.units:
			if u.village == v.id:
				u.village = -1
				reset_job(u)

func _settle(spatial: SpatialIndex) -> void:
	for u in world.units:
		if u.health <= 0 or u.species != "settler" or u.expedition >= 0 or u.army >= 0 or u.village >= 0 or u.age < SpeciesCatalog.maturity("settler"): continue
		var p := Vector2i(u.x, u.y)
		for v in world.villages:
			if v.alive and p.distance_to(Vector2i(v.x, v.y)) < 16 and navigation.connected(p, Vector2i(v.x, v.y)):
				u.village = v.id
				break
		if u.village >= 0 or not world.fertile(u.x, u.y): continue
		var neighbors := 0
		for other in spatial.nearby(p, 9):
			if other.species == "settler" and other.village == -1 and other.health > 0 and other.age >= SpeciesCatalog.maturity(other.species) and navigation.connected(p, Vector2i(other.x, other.y)):
				neighbors += 1
		if neighbors >= 4 and world.villages.size() < 1000:
			var v := world.create_village(p)
			u.village = v.id

func _occupied(i: int) -> bool:
	for v in world.villages:
		if not v.alive: continue
		if i == world.index(v.x, v.y) or i in v.sites or i == v.build_site: return true
	return false

func _plan_farms(v: Dictionary) -> void:
	if v.farms.size() >= clampi(ceili(float(v.population) / 3), 3, 14): return
	var center := Vector2i(v.x, v.y)
	var tile := navigation.nearest(center, func(i: int) -> bool:
		return world.fertile(i % world.width, i / world.width) and world.farm_owner[i] == -1 and world.trees[i] == 0 and world.stone[i] == 0 and not _occupied(i) and Vector2i(i % world.width, i / world.width).distance_to(center) >= 3, 10)
	if tile < 0: return
	world.farm_owner[tile] = v.id
	world.food[tile] = 0
	v.farms.append(tile)

func reset_job(u: Dictionary) -> void:
	if reserved.get(u.target, -1) == u.id: reserved.erase(u.target)
	u.job = "idle"
	u.target = -1
	u.work = 0
	u.route = []
	u.route_revision = -1

func _assign(u: Dictionary, job: String, target: int) -> bool:
	if target < 0: return false
	reset_job(u)
	u.job = job
	u.target = target
	if job in ["farm", "log", "mine", "forage", "build"]: reserved[target] = u.id
	return true

func worker_step(u: Dictionary) -> bool:
	if u.species != "settler" or u.village < 0: return false
	var v := world.villages[u.village]
	if not v.alive: return false
	var home := world.index(v.x, v.y)
	var p := Vector2i(u.x, u.y)
	if not navigation.connected(p, Vector2i(v.x, v.y)):
		reset_job(u)
		u.state = "Cut off from village"
		return false
	if world.laws.hunger and u.hunger > 30 and v.food > 0:
		if u.job != "eat": _assign(u, "eat", home)
		u.state = "Going to the pantry"
		if navigation.advance(u, home):
			v.food -= 1
			v.consumed += 1
			u.hunger = maxf(0, u.hunger - 40)
			u.state = "Eating"
			reset_job(u)
		return true
	if u.cargo > 0:
		if u.cargo_type == "food" and u.hunger > 40 and world.laws.hunger:
			u.cargo -= 1
			u.hunger = maxf(0, u.hunger - 40)
			v.consumed += 1
			if u.cargo == 0: u.cargo_type = ""; reset_job(u)
		if u.cargo > 0:
			if u.job != "haul": _assign(u, "haul", home)
			u.state = "Hauling %s" % u.cargo_type
			if navigation.advance(u, home):
				var deposited := mini(u.cargo, maxi(0, world.storage(v) - int(v[u.cargo_type])))
				v[u.cargo_type] += deposited
				u.cargo -= deposited
				if u.cargo == 0: u.cargo_type = ""; reset_job(u)
			return true
	if u.age < SpeciesCatalog.maturity("settler"):
		reset_job(u)
		u.job = "rest"
		u.state = "Growing up"
		if p.distance_to(Vector2i(v.x, v.y)) > 3: navigation.advance(u, home)
		return true
	if u.health < 40 and u.hunger < 30:
		reset_job(u)
		u.job = "rest"
		u.state = "Resting"
		return true
	if u.job in ["eat", "rest", "haul"]: reset_job(u)
	if u.target >= 0 and not _target_valid(u, v): reset_job(u)
	if u.job == "idle":
		if world.tick < u.think_after: return false
		if not _choose_job(u, v):
			u.think_after = world.tick + 12
			u.state = "No reachable work"
			return false
	u.state = {"forage": "Gathering food", "log": "Cutting timber", "mine": "Gathering stone", "farm": "Tending crops", "build": "Building a house"}.get(u.job, "Working")
	if not navigation.advance(u, u.target): return true
	u.work += 1
	if u.job == "build":
		v.build_progress += 1
		u.work = v.build_progress
	if u.work < SocietySimulation.work_ticks(world, u): return true
	var i: int = u.target
	match u.job:
		"forage":
			var amount := mini(6, floori(world.food[i]))
			world.food[i] -= amount
			u.cargo_type = "food"
			u.cargo = amount
		"log":
			u.cargo = mini(6, world.trees[i])
			u.cargo_type = "wood"
			world.trees[i] -= u.cargo
			world.tree_growth[i] = 0
			v.gathered_wood += u.cargo
			world.terrain_revision += 1
		"mine":
			u.cargo = mini(6, world.stone[i])
			u.cargo_type = "stone"
			world.stone[i] -= u.cargo
			v.gathered_stone += u.cargo
			world.terrain_revision += 1
		"farm":
			if world.crops[i] == WorldState.CROP_MATURE:
				u.cargo = 6
				u.cargo_type = "food"
				v.harvested += 6
				SocietySimulation.learn(world, u.culture, "harvest", 6)
				world.crops[i] = 0
			else: world.crops[i] = 1
		"build":
			v.sites.append(i)
			SocietySimulation.learn(world, u.culture, "building", 1)
			v.houses = v.sites.size()
			v.build_site = -1
			v.build_progress = 0
			world.add_event("A new house in %s makes room for four." % v.name, "village")
	reset_job(u)
	return true

func _target_valid(u: Dictionary, v: Dictionary) -> bool:
	var i: int = u.target
	if not world.habitable(i % world.width, i / world.width) or world.fire[i] > 0: return false
	if not navigation.connected(Vector2i(u.x, u.y), Vector2i(i % world.width, i / world.width)): return false
	match u.job:
		"forage": return world.food[i] >= 1 and world.farm_owner[i] == -1
		"log": return world.trees[i] > 0
		"mine": return world.stone[i] > 0
		"farm": return world.farm_owner[i] == v.id and world.crops[i] in [0, WorldState.CROP_MATURE]
		"build": return v.build_site == i
	return true

func _choose_job(u: Dictionary, v: Dictionary) -> bool:
	var p := Vector2i(u.x, u.y)
	var home := Vector2i(v.x, v.y)
	if v.food < world.storage(v) - 6:
		for stage in [WorldState.CROP_MATURE, 0]:
			for i in v.farms:
				if world.crops[i] == stage and not reserved.has(i) and world.fire[i] == 0 and navigation.connected(p, Vector2i(i % world.width, i / world.width)):
					return _assign(u, "farm", i)
	if v.food < maxi(12, v.population * 2):
		var target := navigation.nearest(p, func(i: int) -> bool: return world.food[i] >= 4 and world.farm_owner[i] == -1 and not reserved.has(i) and world.fire[i] == 0 and Vector2i(i % world.width, i / world.width).distance_to(home) <= 24)
		if _assign(u, "forage", target): return true
	if v.build_site >= 0 and not reserved.has(v.build_site): return _assign(u, "build", v.build_site)
	if v.build_site < 0 and world.housing(v) < v.population + 4 and v.houses < WorldState.MAX_HOUSES and v.wood >= WorldState.HOUSE_WOOD and v.stone >= WorldState.HOUSE_STONE:
		var site := navigation.nearest(home, func(i: int) -> bool: return world.fertile(i % world.width, i / world.width) and world.farm_owner[i] < 0 and world.trees[i] == 0 and world.stone[i] == 0 and not _occupied(i) and Vector2i(i % world.width, i / world.width).distance_to(home) >= 2, 8)
		if site >= 0:
			v.wood -= WorldState.HOUSE_WOOD
			v.stone -= WorldState.HOUSE_STONE
			v.build_site = site
			return _assign(u, "build", site)
	if v.wood < 36:
		var target := navigation.nearest(p, func(i: int) -> bool: return world.trees[i] > 0 and not reserved.has(i) and world.fire[i] == 0 and Vector2i(i % world.width, i / world.width).distance_to(home) <= 24)
		if _assign(u, "log", target): return true
	if v.stone < 16:
		var target := navigation.nearest(p, func(i: int) -> bool: return world.stone[i] > 0 and not reserved.has(i) and world.fire[i] == 0 and Vector2i(i % world.width, i / world.width).distance_to(home) <= 24)
		if _assign(u, "mine", target): return true
	return false
