class_name MilitarySimulation
extends RefCounted
## Bounded data-only armies: villagers leave work, carry rations, fight and return.
const MAX_ARMIES := 256
const CAPTURE_TICKS := 24
var world: WorldState
var navigation: WorldNavigation
var economy: VillageEconomy
var politics: KingdomPolitics
var spatial: SpatialIndex
var transport: SeaTransport
var transport_tried := {}

func _init(w: WorldState, nav: WorldNavigation, work: VillageEconomy, realms: KingdomPolitics, index: SpatialIndex) -> void:
	world = w
	navigation = nav
	economy = work
	politics = realms
	spatial = index
	transport = SeaTransport.new(w, nav)

func at_war(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a == b: return false
	return politics.relation(a, b).get("war", false)

func declare_war(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a == b or a >= world.kingdoms.size() or b >= world.kingdoms.size(): return false
	if not world.kingdoms[a].alive or not world.kingdoms[b].alive or at_war(a, b): return false
	var r := politics.relation(a, b, true)
	r.war = true
	politics._set_relation(r, -75, "War declared by divine intervention", false)
	var message := "%s declared war on %s." % [world.kingdoms[a].name, world.kingdoms[b].name]
	politics.record(world.kingdoms[a], message, "war")
	politics.record(world.kingdoms[b], message, "war", false)
	return true

func make_peace(a: int, b: int) -> bool:
	if not politics.influence(a, "peace", b): return false
	reconcile()
	return true

func people(a: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in a.members:
		var u := politics.unit_by_id(id)
		if not u.is_empty(): result.append(u)
	return result

func army_for(village_id: int) -> Dictionary:
	for a in world.armies:
		if a.active and a.origin == village_id: return a
	return {}

func enemy_town(v: Dictionary) -> int:
	var target := -1
	var best := INF
	for town in world.villages:
		if not town.alive or not at_war(v.kingdom, town.kingdom): continue
		var distance := Vector2(v.x - town.x, v.y - town.y).length_squared()
		if distance < best: best = distance; target = town.id
	return target

func recruit(village_id: int, defend: bool = false) -> bool:
	if village_id < 0 or village_id >= world.villages.size() or world.armies.size() >= MAX_ARMIES: return false
	var v := world.villages[village_id]
	if not v.alive or v.kingdom < 0 or not army_for(village_id).is_empty(): return false
	var target := enemy_town(v)
	if target < 0: return false
	var available: Array[Dictionary] = []
	var members := politics.members(v.id)
	for u in members:
		if u.age >= SpeciesCatalog.maturity(u.species) and u.health > 65 and u.hunger < 50 and u.army < 0 and u.expedition < 0 and u.cargo == 0 and u.id != world.kingdoms[v.kingdom].ruler and navigation.connected(Vector2i(u.x, u.y), Vector2i(v.x, v.y)):
			available.append(u)
	var count := mini(8, mini(available.size(), members.size() / 2))
	count = mini(count, mini(v.wood / 2, mini(v.stone, v.food / 2)))
	if count < 4: return false
	var a := {"id": world.armies.size(), "kingdom": v.kingdom, "origin": v.id, "target": target, "members": [], "active": true, "order": "defend" if defend else "attack", "morale": 100, "food": count * 2, "initial": count, "capture": 0, "started": world.tick, "last_progress": world.tick, "outcome": "Mustered in defense" if defend else "Marching to %s" % world.villages[target].name, "boat": SeaTransport.empty_boat()}
	v.wood -= count * 2
	v.stone -= count
	v.food -= count * 2
	v.muster_after = world.tick + 240
	world.armies.append(a)
	for n in count:
		var u := available[n]
		economy.reset_job(u)
		u.army = a.id
		u.weapon = "bow" if n % 3 == 2 else "stone_spear"
		u.job = "soldier"
		u.state = "Mustered for war"
		a.members.append(u.id)
		Heredity.event(world, u.id, "Joined the company of %s with a %s." % [v.name, u.weapon.replace("_", " ")], "muster")
	politics.record(world.kingdoms[v.kingdom], "%s equipped %s villagers for war." % [v.name, count], "muster")
	return true

func fortify(village_id: int) -> bool:
	if village_id < 0 or village_id >= world.villages.size(): return false
	var v := world.villages[village_id]
	if not v.alive or v.tower > 0 or v.fort_progress > 0 or v.wood < 16 or v.stone < 12: return false
	v.wood -= 16
	v.stone -= 12
	v.fort_progress = 1
	return true

func recall(a: Dictionary, reason: String = "Ordered home") -> void:
	if not a.active or a.order == "return": return
	a.order = "return"
	a.capture = 0
	a.last_progress = world.tick
	a.outcome = reason
	# Boats finish their current crossing; nobody is dropped into the sea.
	if a.boat.state == "boarding": a.boat.state = "landed"
	politics.record(world.kingdoms[a.kingdom], "%s's soldiers retreat: %s." % [world.villages[a.origin].name, reason], "retreat")

func _disband(a: Dictionary, reason: String) -> void:
	for u in world.units:
		if u.army != a.id: continue
		u.army = -1
		u.weapon = ""
		economy.reset_job(u)
		u.state = reason
		Heredity.event(world, u.id, reason + ".", "service")
	a.members = []
	a.active = false
	a.capture = 0
	a.food = 0
	a.outcome = reason
	a.boat = SeaTransport.empty_boat()

func reconcile() -> void:
	for a in world.armies:
		if not a.active: continue
		var home := world.villages[a.origin]
		if not home.alive or home.kingdom != a.kingdom or not world.kingdoms[a.kingdom].alive:
			# An occupied hometown changes allegiance only after any boat lands.
			if a.boat.state == "sailing": recall(a, "The home realm was lost")
			else: _disband(a, "Returned to civilian life")
			continue
		var target := world.villages[a.target]
		if not target.alive or not at_war(a.kingdom, target.kingdom): recall(a, "Hostilities ended")
	for r in world.relations:
		if r.war and (not world.kingdoms[r.a].alive or not world.kingdoms[r.b].alive):
			r.war = false
			r.reason = "War ended with the loss of a realm"
			r.changed = world.tick

func begin_tick() -> void:
	transport_tried.clear()
	world.battle_effects = world.battle_effects.filter(func(e: Dictionary) -> bool: return world.tick - e.tick < 3)
	reconcile()
	for v in world.villages:
		if not v.alive: continue
		if world.fire[world.index(v.x, v.y)] > 0: v.tower = maxi(0, v.tower - 20); v.fort_progress = 0
		if v.fort_progress > 0:
			for u in politics.members(v.id):
				if u.age >= SpeciesCatalog.maturity(u.species) and u.army < 0 and u.expedition < 0 and _distance(u, v) <= 2:
					v.fort_progress += 1
					if v.fort_progress >= 16:
						v.tower = 160
						v.fort_progress = 0
						world.add_event("%s completed a watchtower." % v.name, "defense")
					break
		if world.tick % 24 == 0 and world.tick >= v.muster_after and enemy_town(v) >= 0:
			var threatened := world.armies.any(func(a: Dictionary) -> bool: return a.active and a.order == "attack" and a.target == v.id)
			if recruit(v.id, threatened) and threatened: fortify(v.id)
	for a in world.armies:
		if not a.active: continue
		transport.step(a, people(a))

func embarked(u: Dictionary) -> bool:
	return u.army >= 0 and world.armies[u.army].active and world.armies[u.army].boat.state == "sailing"

func feed(u: Dictionary) -> void:
	if u.army < 0: return
	var a := world.armies[u.army]
	var v := world.villages[a.origin]
	if not embarked(u) and _distance(u, v) <= 1 and v.kingdom == a.kingdom and v.food > 0 and a.food < 48:
		var ration := mini(48 - a.food, mini(v.food, a.members.size() * 2))
		v.food -= ration
		a.food += ration
	if world.laws.hunger and u.hunger > 30 and a.food > 0:
		a.food -= 1
		u.hunger = maxf(0, u.hunger - 40)
		v.consumed += 1

static func _distance(a: Dictionary, b: Dictionary) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _kingdom(u: Dictionary) -> int:
	return world.villages[u.village].kingdom if u.village >= 0 else -1

func clear_shot(a: Dictionary, b: Dictionary) -> bool:
	# Supercover sampling rejects shots through a corner, mountain, or water.
	var delta := Vector2(b.x - a.x, b.y - a.y)
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y)) * 2
	for n in range(steps + 1):
		var p := Vector2(a.x, a.y) + delta * float(n) / maxi(1, steps)
		for cell in [Vector2i(p.floor()), Vector2i(p.ceil()), Vector2i(floori(p.x), ceili(p.y)), Vector2i(ceili(p.x), floori(p.y))]:
			if not world.habitable(cell.x, cell.y): return false
	return true

func _enemy(u: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var distance := 7
	for other in spatial.nearby(Vector2i(u.x, u.y), 6):
		if other.health <= 0 or other.army < 0 or embarked(other) or not at_war(_kingdom(u), _kingdom(other)): continue
		var d := _distance(u, other)
		if d < distance and navigation.connected(Vector2i(u.x, u.y), Vector2i(other.x, other.y)):
			best = other
			distance = d
	return best

func _effect(a: Dictionary, b: Dictionary, kind: String) -> void:
	world.battle_effects.append({"x": a.x, "y": a.y, "tx": b.x, "ty": b.y, "kind": kind, "tick": world.tick})
	if world.battle_effects.size() > 64: world.battle_effects.pop_front()

func soldier_step(u: Dictionary) -> bool:
	if u.army < 0: return false
	var a := world.armies[u.army]
	if not a.active: return false
	u.job = "soldier"
	feed(u)
	if a.boat.state == "boarding":
		navigation.advance(u, a.boat.embark)
		u.state = "Boarding a transport"
		return true
	var home := world.villages[a.origin]
	var target := world.villages[a.target]
	if u.health < 25 or u.hunger > 80: a.morale = maxi(0, a.morale - 2)
	if a.morale <= 30: recall(a, "Morale broke")
	if a.order != "return":
		var enemy := _enemy(u)
		if not enemy.is_empty():
			var reach := 4 if u.weapon == "bow" else 1
			if _distance(u, enemy) <= reach and clear_shot(u, enemy):
				if world.tick >= u.attack_after:
					enemy.health -= Heredity.damage(u, 11.0 if u.weapon == "bow" else 17.0)
					u.attack_after = world.tick + (6 if u.weapon == "bow" else 4)
					world.armies[enemy.army].morale = maxi(0, world.armies[enemy.army].morale - 1)
					_effect(u, enemy, "arrow" if u.weapon == "bow" else "hit")
					u.state = "Firing a bow" if u.weapon == "bow" else "Fighting with a stone spear"
			else: navigation.advance(u, world.index(enemy.x, enemy.y)); u.state = "Engaging enemy soldiers"
			a.last_progress = world.tick
			return true
		if a.order == "attack" and target.tower > 0 and _distance(u, target) <= 1:
			if world.tick >= u.attack_after:
				target.tower = maxi(0, target.tower - 12)
				u.attack_after = world.tick + 4
				_effect(u, target, "hit")
			u.state = "Attacking the watchtower"
			a.last_progress = world.tick
			return true
	var destination: Dictionary = home if a.order in ["defend", "return"] else target
	var end := Vector2i(destination.x, destination.y)
	if navigation.connected(Vector2i(u.x, u.y), end):
		var before := Vector2i(u.x, u.y)
		navigation.advance(u, world.index(end.x, end.y))
		if before != Vector2i(u.x, u.y): a.last_progress = world.tick
	else:
		if world.tick % 24 == 0 and a.boat.state not in ["boarding", "sailing"] and not transport_tried.has(a.id) and transport_tried.size() < 2:
			transport_tried[a.id] = true
			transport.prepare(a, people(a), end)
	u.state = "Returning home" if a.order == "return" else ("Defending home" if a.order == "defend" else "Marching to " + target.name)
	return true

func finish_tick() -> void:
	for v in world.villages:
		if not v.alive or v.tower <= 0 or world.tick % 6 != 0: continue
		for u in spatial.nearby(Vector2i(v.x, v.y), 5):
			if u.health > 0 and u.army >= 0 and not embarked(u) and at_war(v.kingdom, _kingdom(u)) and _distance(v, u) <= 5 and clear_shot(v, u):
				u.health -= 9.0
				_effect(v, u, "arrow")
				break
	for a in world.armies:
		if not a.active: continue
		var living := people(a)
		var lost: int = a.members.size() - living.size()
		if lost > 0: a.morale = maxi(0, a.morale - lost * 18)
		a.members = living.map(func(u: Dictionary) -> int: return u.id)
		if living.is_empty(): _disband(a, "The company was lost"); continue
		if a.boat.state in ["sailing", "boarding"]: continue
		var home := world.villages[a.origin]
		if a.order == "return":
			if living.all(func(u: Dictionary) -> bool: return _distance(u, home) <= 1):
				home.food = mini(world.storage(home), home.food + a.food)
				_disband(a, "Home from war")
			elif world.tick - a.last_progress > 192: _disband(a, "Cut off; resumed civilian life")
			continue
		if a.morale <= 30 or (a.order == "attack" and world.tick - a.last_progress > 192):
			recall(a, "Morale broke" if a.morale <= 30 else "The route was cut off")
			continue
		if a.order != "attack": continue
		var target := world.villages[a.target]
		var occupied := living.any(func(u: Dictionary) -> bool: return _distance(u, target) <= 1)
		var contested := false
		for u in world.units:
			if u.health > 0 and u.army >= 0 and not embarked(u) and at_war(a.kingdom, _kingdom(u)) and _distance(u, target) <= 5: contested = true; break
		if occupied and not contested and target.tower == 0 and at_war(a.kingdom, target.kingdom):
			a.capture += 1
			a.last_progress = world.tick
			a.outcome = "Capturing %s · %s/%s" % [target.name, a.capture, CAPTURE_TICKS]
			if a.capture >= CAPTURE_TICKS: _capture(a, target)
		else: a.capture = 0

func _capture(a: Dictionary, v: Dictionary) -> void:
	var previous: int = v.kingdom
	v.kingdom = a.kingdom
	v.loyalty = 45
	v.loyalty_reason = "Recently captured"
	v.fort_progress = 0
	v.muster_after = world.tick + 240
	v.expansion_after = world.tick + 240
	for e in world.expeditions:
		if e.active and e.origin == v.id: politics._end_expedition(e, "The home settlement was captured")
	for other in world.armies:
		if other.active and other.origin == v.id and other.boat.state != "sailing": _disband(other, "Laid down arms after capture")
	var message := "%s captured %s from %s." % [world.kingdoms[a.kingdom].name, v.name, world.kingdoms[previous].name]
	politics.record(world.kingdoms[a.kingdom], message, "capture")
	politics.record(world.kingdoms[previous], message, "capture", false)
	politics.refresh()
	recall(a, "The settlement was captured")
	reconcile()
