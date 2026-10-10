class_name KingdomPolitics
extends RefCounted
## Political ownership is derived from living settlements; IDs are never reused.
const COLORS := [Color("d6be73"), Color("70b9c5"), Color("d99492"), Color("aaa0d7"), Color("84be8a"), Color("df9f68")]
const NAMES := ["Aurelian Crown", "Tideglass Union", "Rosevale Realm", "Amethyst Reach", "Verdant Accord", "Ember Coast"]
const MAX_KINGDOMS := 128
const MAX_EXPEDITIONS := 256
const EXPEDITION_FOOD := 24
var world: WorldState
var navigation: WorldNavigation
var economy: VillageEconomy
var contacts := {}
var claim_signature: Array = []

func _init(state: WorldState, routes: WorldNavigation, work: VillageEconomy) -> void:
	world = state
	navigation = routes
	economy = work

func members(village_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for u in world.units:
		if u.health > 0 and u.species == "settler" and u.village == village_id: result.append(u)
	return result

func villages(kingdom_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for v in world.villages:
		if v.alive and v.kingdom == kingdom_id and world.habitable(v.x, v.y): result.append(v)
	return result

func unit_by_id(id: int) -> Dictionary:
	for u in world.units:
		if u.id == id and u.health > 0: return u
	return {}

func record(k: Dictionary, message: String, kind: String = "politics", global_event: bool = true) -> void:
	k.history.push_front({"year": world.year(), "text": message, "kind": kind})
	if k.history.size() > 32: k.history.resize(32)
	if global_event: world.add_event(message, kind)

func create_kingdom(v: Dictionary, announce: bool = true) -> int:
	if world.kingdoms.size() >= MAX_KINGDOMS: return -1
	var id := world.kingdoms.size()
	var suffix := "" if id < NAMES.size() else " %s" % (id / NAMES.size() + 1)
	var k := {"id": id, "name": NAMES[id % NAMES.size()] + suffix, "capital": v.id, "ruler": -1, "alive": true, "founded": world.year(), "favor_until": 0, "outlook": [2, 0, -2][id % 3], "history": []}
	world.kingdoms.append(k)
	v.kingdom = id
	v.loyalty = 75
	record(k, "%s rose around %s." % [k.name, v.name], "kingdom", announce)
	return id

func refresh(announce: bool = true) -> void:
	for v in world.villages:
		if not v.alive or not world.habitable(v.x, v.y) or members(v.id).is_empty():
			v.kingdom = -1
		elif v.kingdom < 0:
			create_kingdom(v, announce)
	for k in world.kingdoms:
		if not k.alive: continue
		var towns := villages(k.id)
		if towns.is_empty():
			k.alive = false
			k.capital = -1
			k.ruler = -1
			SocietySimulation.ruler(world, k.id, -1, "collapse")
			record(k, "%s has lost its last settlement." % k.name, "collapse", announce)
			continue
		if not towns.any(func(v: Dictionary) -> bool: return v.id == k.capital):
			k.capital = towns[0].id
			record(k, "%s became the capital of %s." % [towns[0].name, k.name], "succession", announce)
		var ruler := unit_by_id(k.ruler)
		if not ruler.is_empty() and ruler.age >= SpeciesCatalog.maturity(ruler.species) and ruler.village >= 0 and world.villages[ruler.village].kingdom == k.id: continue
		var candidates: Array[Dictionary] = []
		for v in towns:
			for u in members(v.id):
				if u.age >= SpeciesCatalog.maturity(u.species): candidates.append(u)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.age > b.age if a.age != b.age else a.id < b.id)
		var successor: int = candidates[0].id if not candidates.is_empty() else -1
		if successor != k.ruler:
			k.ruler = successor
			SocietySimulation.ruler(world, k.id, successor)
			if successor >= 0: Heredity.event(world, successor, "Became ruler of %s." % k.name, "ruler")
			record(k, "%s now leads %s." % [candidates[0].name, k.name] if successor >= 0 else "%s awaits an adult ruler." % k.name, "succession", announce)
	refresh_claims()

func refresh_claims() -> void:
	var signature: Array = [world.navigation_revision]
	for v in world.villages: signature.append([v.id, v.kingdom, v.alive, v.x, v.y, v.houses])
	if signature == claim_signature: return
	claim_signature = signature
	var count := world.terrain.size()
	world.territory.resize(count)
	world.territory.fill(-1)
	var distance := PackedInt32Array()
	distance.resize(count)
	distance.fill(999)
	for v in world.villages:
		if not v.alive or v.kingdom < 0 or not world.habitable(v.x, v.y): continue
		var start := world.index(v.x, v.y)
		var queue := PackedInt32Array([start])
		var steps := PackedInt32Array([0])
		var visited := {start: true}
		var head := 0
		while head < queue.size():
			var i := queue[head]
			var depth := steps[head]
			head += 1
			if depth < distance[i]:
				distance[i] = depth
				world.territory[i] = v.kingdom
			if depth >= 12 + v.houses: continue
			var p := Vector2i(i % world.width, i / world.width)
			for d in WorldNavigation.DIRECTIONS:
				var n: Vector2i = p + d
				if not world.habitable(n.x, n.y): continue
				var j := world.index(n.x, n.y)
				if visited.has(j): continue
				visited[j] = true
				queue.append(j)
				steps.append(depth + 1)
	contacts.clear()
	for i in count:
		var owner := world.territory[i]
		if owner < 0: continue
		for offset in [1, world.width]:
			var j: int = i + offset
			if j >= count or (offset == 1 and i % world.width == world.width - 1): continue
			var other := world.territory[j]
			if other >= 0 and other != owner: contacts[pair_key(owner, other)] = true
	world.politics_revision += 1

static func pair_key(a: int, b: int) -> String:
	return "%s:%s" % [mini(a, b), maxi(a, b)]

func relation(a: int, b: int, create: bool = false) -> Dictionary:
	for r in world.relations:
		if r.a == mini(a, b) and r.b == maxi(a, b): return r
	if not create or a == b: return {}
	var r := {"a": mini(a, b), "b": maxi(a, b), "score": 0, "status": "peace", "reason": "A shared frontier", "changed": world.tick, "war": false}
	world.relations.append(r)
	return r

func _set_relation(r: Dictionary, score: int, reason: String, announce: bool = true) -> void:
	var old: String = r.status
	r.score = clampi(score, -100, 100)
	r.status = "alliance" if r.score >= 50 else ("rivalry" if r.score <= -40 else "peace")
	r.reason = reason
	r.changed = world.tick
	if r.status != old:
		var a := world.kingdoms[r.a]
		var b := world.kingdoms[r.b]
		var message := "%s and %s: %s. %s" % [a.name, b.name, r.status, reason]
		record(a, message, "diplomacy", announce)
		record(b, message, "diplomacy", false)

func influence(a: int, power: String, b: int = -1) -> bool:
	if a < 0 or a >= world.kingdoms.size() or not world.kingdoms[a].alive: return false
	var k := world.kingdoms[a]
	if power == "favor":
		k.favor_until = world.tick + 240
		for v in villages(a): v.loyalty = mini(100, v.loyalty + 12); v.loyalty_reason = "Divine favor"
		record(k, "Divine favor steadies %s for five years." % k.name, "favor")
		return true
	if b < 0 or b >= world.kingdoms.size() or b == a or not world.kingdoms[b].alive or power not in ["peace", "discord"]: return false
	var r := relation(a, b, true)
	if power == "peace" and r.get("war", false):
		r.war = false
		record(k, "%s and %s agreed to peace." % [k.name, world.kingdoms[b].name], "peace")
	_set_relation(r, r.score + (45 if power == "peace" else -45), "A divine call for peace" if power == "peace" else "Divine discord strains the frontier")
	return true

func _diplomacy() -> void:
	for key in contacts:
		var ids: PackedStringArray = key.split(":")
		var a := world.kingdoms[ids[0].to_int()]
		var b := world.kingdoms[ids[1].to_int()]
		if not a.alive or not b.alive: continue
		var r := relation(a.id, b.id, true)
		if r.get("war", false): continue
		var shortage := false
		for v in villages(a.id) + villages(b.id):
			if v.food < maxi(2, v.population / 2): shortage = true
		var change: int = 2 + a.outlook + b.outlook - (8 if shortage else 0)
		_set_relation(r, r.score + change, "Scarcity at a shared border" if shortage else ("Prosperous neighbors build trust" if change > 0 else "Cautious rulers keep their distance"))

func _loyalty() -> void:
	for v in world.villages:
		if not v.alive or v.kingdom < 0: continue
		var k := world.kingdoms[v.kingdom]
		var capital := world.villages[k.capital]
		var change := 1
		var reasons: Array[String] = []
		if SocietySimulation.clan_support(world, v.id): change += 1; reasons.append("clan solidarity")
		if v.food < maxi(2, v.population / 2): change -= 8; reasons.append("food shortage")
		elif v.food >= v.population * 2: change += 2; reasons.append("well supplied")
		if v.id != capital.id:
			if not navigation.connected(Vector2i(v.x, v.y), Vector2i(capital.x, capital.y)): change -= 10; reasons.append("isolated from capital")
			elif Vector2(v.x - capital.x, v.y - capital.y).length() > 40: change -= 4; reasons.append("distant capital")
		if k.ruler < 0: change -= 2; reasons.append("awaiting a ruler")
		if k.favor_until > world.tick: change += 8; reasons.append("divine favor")
		for r in world.relations:
			if r.status == "alliance" and (r.a == k.id or r.b == k.id) and world.kingdoms[r.a].alive and world.kingdoms[r.b].alive:
				change += 2
				reasons.append("allied support")
				break
		v.loyalty = clampi(v.loyalty + change, 0, 100)
		v.loyalty_reason = ", ".join(reasons) if not reasons.is_empty() else "Stable local life"
		if v.id != capital.id and v.loyalty <= 20 and world.kingdoms.size() < MAX_KINGDOMS:
			var old: int = k.id
			var new_id := create_kingdom(v)
			record(k, "%s declared independence from %s." % [v.name, k.name], "independence")
			v.loyalty_reason = "New independence"
			for e in world.expeditions:
				if e.active and e.origin == v.id: _end_expedition(e, "Independence dispersed the expedition; supplies were lost")
			_set_relation(relation(old, new_id, true), -55, "A settlement declared independence")

func _permitted(kingdom_id: int, tile: int) -> bool:
	var owner := world.territory[tile]
	if owner < 0 or owner == kingdom_id: return true
	var r := relation(kingdom_id, owner)
	return r.is_empty() or (r.status != "rivalry" and not r.get("war", false))

func suitable_site(origin: Dictionary, tile: int, ignore_expedition: int = -1) -> bool:
	var p := Vector2i(tile % world.width, tile / world.width)
	if not world.fertile(p.x, p.y) or world.fire[tile] > 0: return false
	if world.territory[tile] >= 0 and world.territory[tile] != origin.kingdom: return false
	for v in world.villages:
		if v.alive and p.distance_squared_to(Vector2i(v.x, v.y)) < 576: return false
	for e in world.expeditions:
		if e.active and e.id != ignore_expedition and p.distance_squared_to(Vector2i(e.target % world.width, e.target / world.width)) < 576: return false
	if not navigation.connected(Vector2i(origin.x, origin.y), p): return false
	var fertile_count := 0
	for y in range(p.y - 2, p.y + 3):
		for x in range(p.x - 2, p.x + 3):
			if world.fertile(x, y): fertile_count += 1
	return fertile_count >= 18

func expansion_ready(v: Dictionary) -> bool:
	if not v.alive or v.kingdom < 0 or world.villages.size() >= 1000 or world.expeditions.size() >= MAX_EXPEDITIONS: return false
	for e in world.expeditions:
		if e.active and e.origin == v.id: return false
	if v.population < 20 or v.population < world.housing(v) - 4:
		v.expansion_reason = "Waiting for housing pressure (20+ settlers)"
		return false
	if v.food < maxi(48, v.population * 2 + EXPEDITION_FOOD) or v.wood < 12 or v.stone < 4:
		v.expansion_reason = "Needs food surplus, 12 wood, and 4 stone"
		return false
	return true

func launch(v: Dictionary, target: int) -> bool:
	if not expansion_ready(v) or not suitable_site(v, target): return false
	var adults: Array[Dictionary] = []
	for u in members(v.id):
		if u.age >= SpeciesCatalog.maturity(u.species) and u.health > 65 and u.hunger < 35 and u.cargo == 0 and u.expedition < 0 and u.army < 0 and u.id != world.kingdoms[v.kingdom].ruler and navigation.connected(Vector2i(u.x, u.y), Vector2i(v.x, v.y)): adults.append(u)
	if adults.size() < 8: v.expansion_reason = "Waiting for eight available adults"; return false
	var route := navigation.route(Vector2i(v.x, v.y), target)
	if route.is_empty() or route.any(func(i: int) -> bool: return not _permitted(v.kingdom, i)):
		v.expansion_reason = "No safe route beyond the frontier"
		return false
	var e := {"id": world.expeditions.size(), "kingdom": v.kingdom, "origin": v.id, "target": target, "members": [], "food": EXPEDITION_FOOD, "wood": 12, "stone": 4, "active": true, "started": world.tick, "outcome": "Travelling"}
	world.expeditions.append(e)
	v.food -= EXPEDITION_FOOD
	v.wood -= 12
	v.stone -= 4
	v.expansion_after = world.tick + 480
	v.expansion_reason = "Four adults are founding a new settlement"
	for n in 4:
		var u := adults[n]
		economy.reset_job(u)
		u.expedition = e.id
		u.job = "settle"
		u.state = "Joining an expedition"
		e.members.append(u.id)
	record(world.kingdoms[v.kingdom], "Four settlers left %s to seek a new home." % v.name, "expansion")
	return true

func _expand() -> void:
	for v in world.villages:
		if world.tick < v.expansion_after or not expansion_ready(v): continue
		v.expansion_after = world.tick + 96
		var target := navigation.nearest(Vector2i(v.x, v.y), func(i: int) -> bool: return suitable_site(v, i), 40)
		if target < 0: v.expansion_reason = "No reachable fertile site beyond nearby villages"; continue
		launch(v, target)

func expedition_step(u: Dictionary) -> bool:
	if u.expedition < 0: return false
	var e := world.expeditions[u.expedition]
	if not e.active: u.expedition = -1; economy.reset_job(u); return false
	if world.laws.hunger and u.hunger > 30 and e.food > 0:
		e.food -= 1
		u.hunger = maxf(0, u.hunger - 40)
		world.villages[e.origin].consumed += 1
	u.job = "settle"
	u.state = "Travelling to new land"
	# Validate the next route before moving, including newly hostile borders.
	if u.route_revision != world.navigation_revision or u.route.is_empty():
		u.route = navigation.route(Vector2i(u.x, u.y), e.target)
		u.route_revision = world.navigation_revision
		u.target = e.target
	if not u.route.is_empty() and not _permitted(e.kingdom, u.route[0]):
		_end_expedition(e, "Rival borders closed the route; supplies were left behind")
		return false
	if navigation.advance(u, e.target): u.state = "Waiting at the new home"
	return true

func _end_expedition(e: Dictionary, outcome: String) -> void:
	e.active = false
	e.outcome = outcome
	for id in e.members:
		var u := unit_by_id(id)
		if not u.is_empty(): u.expedition = -1; economy.reset_job(u)
	e.members.clear()
	e.food = 0
	e.wood = 0
	e.stone = 0
	record(world.kingdoms[e.kingdom], "%s: %s." % [world.villages[e.origin].name, outcome], "expansion")

func _finish_expeditions() -> void:
	for e in world.expeditions:
		if not e.active: continue
		var origin := world.villages[e.origin]
		var living: Array[Dictionary] = []
		for id in e.members:
			var u := unit_by_id(id)
			if not u.is_empty(): living.append(u)
		var p := Vector2i(e.target % world.width, e.target / world.width)
		if living.size() != 4 or not origin.alive or origin.kingdom != e.kingdom or not world.kingdoms[e.kingdom].alive:
			_end_expedition(e, "The expedition dispersed; supplies were lost")
			continue
		if world.tick - e.started > 384 or not suitable_site(origin, e.target, e.id):
			_end_expedition(e, "The destination became unreachable; supplies were left behind")
			continue
		var arrived := true
		for u in living:
			if Vector2i(u.x, u.y) != p: arrived = false
		if not arrived: continue
		if world.villages.size() >= 1000:
			_end_expedition(e, "The world has no room for another settlement")
			continue
		var town := world.create_village(p)
		town.kingdom = e.kingdom
		town.food = e.food
		town.wood = e.wood
		town.stone = e.stone
		town.population = living.size()
		origin.population = maxi(0, origin.population - living.size())
		for u in living: u.village = town.id
		world.trees[e.target] = 0
		world.stone[e.target] = 0
		world.terrain_revision += 1
		_end_expedition(e, "Founded %s with the supplies that arrived" % town.name)

func finish_tick() -> void:
	_finish_expeditions()
	refresh()
	if world.tick % 48 == 0:
		if world.laws.diplomacy: _diplomacy(); _loyalty()
		refresh()
		if world.laws.expansion: _expand()
