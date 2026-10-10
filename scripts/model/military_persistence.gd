class_name MilitaryPersistence
extends RefCounted
## Schema v4; old worlds gain no soldiers, wars, stores, or random draws.
static func migrate(w: WorldState) -> void:
	for u in w.units: u.merge({"army": -1, "weapon": "", "attack_after": 0}, true)
	for v in w.villages: v.merge({"tower": 0, "fort_progress": 0, "muster_after": 0}, true)
	for r in w.relations: r.war = false

static func restore(w: WorldState, d: Dictionary) -> void:
	for u in w.units:
		for key in ["army", "attack_after"]: u[key] = int(u[key])
	for v in w.villages:
		for key in ["tower", "fort_progress", "muster_after"]: v[key] = int(v[key])
	for entry in d.armies:
		var a: Dictionary = entry.duplicate(true)
		for key in ["id", "kingdom", "origin", "target", "morale", "food", "initial", "capture", "started", "last_progress"]: a[key] = int(a[key])
		a.members = a.members.map(func(i: Variant) -> int: return int(i))
		for key in ["embark", "landing", "x", "y", "revision"]: a.boat[key] = int(a.boat[key])
		a.boat.route = a.boat.route.map(func(i: Variant) -> int: return int(i))
		w.armies.append(a)

static func integer(value: Variant, low: int, high: int) -> bool:
	return PoliticsPersistence.integer(value, low, high)

static func validate(d: Dictionary) -> bool:
	if not d.get("armies") is Array or d.armies.size() > MilitarySimulation.MAX_ARMIES: return false
	for r in d.relations:
		if not r.get("war") is bool: return false
		if r.war and (not d.kingdoms[int(r.a)].alive or not d.kingdoms[int(r.b)].alive): return false
	for v in d.villages:
		if not integer(v.get("tower"), 0, 160) or not integer(v.get("fort_progress"), 0, 15) or not integer(v.get("muster_after"), 0, 2147483647): return false
		if v.tower > 0 and v.fort_progress > 0: return false
	var units := {}
	for u in d.units:
		if not integer(u.get("army"), -1, d.armies.size() - 1) or not integer(u.get("attack_after"), 0, int(d.tick) + 6): return false
		if not u.get("weapon") in ["", "stone_spear", "bow"]: return false
		if (u.army < 0) != (u.weapon == ""): return false
		if u.army >= 0 and (u.species != "settler" or u.age < SpeciesCatalog.maturity(u.species) or u.expedition >= 0): return false
		units[int(u.id)] = u
	var assigned := {}
	var origins := {}
	for n in d.armies.size():
		var a: Variant = d.armies[n]
		if not a is Dictionary or a.get("id") != n or not a.get("active") is bool: return false
		if not integer(a.get("kingdom"), 0, d.kingdoms.size() - 1) or not integer(a.get("origin"), 0, d.villages.size() - 1) or not integer(a.get("target"), 0, d.villages.size() - 1): return false
		if not a.get("order") in ["attack", "defend", "return"] or not PoliticsPersistence.words(a.get("outcome")): return false
		for key in ["started", "last_progress"]:
			if not integer(a.get(key), 0, int(d.tick)): return false
		for key in ["morale", "food", "initial", "capture"]:
			if not integer(a.get(key), 4 if key == "initial" else 0, {"morale": 100, "food": 48, "initial": 8, "capture": 23}[key]): return false
		if not a.get("members") is Array or a.members.size() > 8: return false
		if not _boat(a.get("boat"), d): return false
		if not a.active:
			if not a.members.is_empty() or a.food != 0 or a.capture != 0 or a.boat.state != "none": return false
			continue
		if a.members.is_empty() or a.members.size() > a.initial or origins.has(int(a.origin)): return false
		origins[int(a.origin)] = true
		var home: Dictionary = d.villages[int(a.origin)]
		if a.boat.state != "sailing" and (not home.alive or home.kingdom != a.kingdom): return false
		for id in a.members:
			if not integer(id, 1, int(d.next_id) - 1) or not units.has(int(id)) or assigned.has(int(id)): return false
			var u: Dictionary = units[int(id)]
			if u.army != n or (u.village != a.origin and a.boat.state != "sailing"): return false
			if a.boat.state == "sailing" and (u.x != a.boat.x or u.y != a.boat.y): return false
			assigned[int(id)] = true
	for u in d.units:
		if u.army >= 0 and not assigned.has(int(u.id)): return false
	return true

static func _boat(b: Variant, d: Dictionary) -> bool:
	if not b is Dictionary or not b.get("paid") is bool or b.get("state") not in ["none", "boarding", "sailing", "landed"]: return false
	var count := WorldState.WIDTH * WorldState.HEIGHT
	if not integer(b.get("embark"), -1, count - 1) or not integer(b.get("landing"), -1, count - 1): return false
	if not integer(b.get("x"), 0, WorldState.WIDTH - 1) or not integer(b.get("y"), 0, WorldState.HEIGHT - 1): return false
	if not integer(b.get("revision"), -1, int(d.navigation_revision)) or not SaveStore._indices(b.get("route"), 512, true): return false
	if b.state == "none": return not b.paid and b.route.is_empty() and b.embark == -1 and b.landing == -1
	if not b.paid or b.embark < 0 or b.landing < 0: return false
	# Old routes are intentionally allowed after terrain edits; the next tick repairs them.
	var previous := int(b.embark) if b.state == "boarding" else int(b.y) * WorldState.WIDTH + int(b.x)
	for tile in b.route:
		var next := int(tile)
		if absi(previous % WorldState.WIDTH - next % WorldState.WIDTH) + absi(previous / WorldState.WIDTH - next / WorldState.WIDTH) != 1: return false
		previous = next
	return true
