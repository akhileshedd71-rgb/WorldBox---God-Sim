class_name PoliticsPersistence
extends RefCounted
## Additive v2 -> v3 migration; political references are checked before loading.
static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high and float(value) == floorf(float(value))

static func words(value: Variant, length: int = 160) -> bool:
	return value is String and value.length() <= length

static func validate(d: Dictionary) -> bool:
	if not d.get("kingdoms") is Array or d.kingdoms.size() > KingdomPolitics.MAX_KINGDOMS: return false
	if not d.get("relations") is Array or d.relations.size() > 8128: return false
	if not d.get("expeditions") is Array or d.expeditions.size() > KingdomPolitics.MAX_EXPEDITIONS: return false
	for law in ["expansion", "diplomacy"]:
		if not d.laws.get(law) is bool: return false
	var units := {}
	for u in d.units:
		units[int(u.id)] = u
		if not integer(u.get("expedition"), -1, d.expeditions.size() - 1): return false
	for v in d.villages:
		if not integer(v.get("kingdom"), -1, d.kingdoms.size() - 1) or not integer(v.get("loyalty"), 0, 100): return false
		if not integer(v.get("expansion_after"), 0, 2147483647): return false
		if not words(v.get("loyalty_reason")) or not words(v.get("expansion_reason")): return false
	for n in d.kingdoms.size():
		var k: Variant = d.kingdoms[n]
		if not k is Dictionary or k.get("id") != n or not words(k.get("name"), 80) or not k.get("alive") is bool: return false
		if not integer(k.get("capital"), -1, d.villages.size() - 1) or not integer(k.get("ruler"), -1, d.next_id - 1): return false
		if k.alive:
			if k.capital < 0 or not d.villages[int(k.capital)].alive or d.villages[int(k.capital)].kingdom != k.id: return false
		elif k.capital != -1 or k.ruler != -1: return false
		if k.ruler >= 0:
			if not units.has(int(k.ruler)): return false
			var u: Dictionary = units[int(k.ruler)]
			if u.species != "settler" or u.age < SpeciesCatalog.maturity(u.species) or u.village < 0 or d.villages[int(u.village)].kingdom != k.id: return false
		if not integer(k.get("founded"), 1, 1 + int(d.tick) / 48) or not integer(k.get("favor_until"), 0, 2147483647) or not integer(k.get("outlook"), -2, 2): return false
		if not k.get("history") is Array or k.history.size() > 32: return false
		var previous: int = 1 + int(d.tick) / 48
		for e in k.history:
			if not e is Dictionary or not integer(e.get("year"), 1, previous) or not words(e.get("text"), 300) or not words(e.get("kind"), 24): return false
			previous = int(e.year)
	for v in d.villages:
		if v.kingdom >= 0 and (not d.kingdoms[int(v.kingdom)].alive or not v.alive): return false
	var pairs := {}
	for r in d.relations:
		if not r is Dictionary or not integer(r.get("a"), 0, d.kingdoms.size() - 1) or not integer(r.get("b"), 0, d.kingdoms.size() - 1) or r.a >= r.b: return false
		var key := KingdomPolitics.pair_key(int(r.a), int(r.b))
		if pairs.has(key): return false
		pairs[key] = true
		if not integer(r.get("score"), -100, 100) or not words(r.get("reason")) or not integer(r.get("changed"), 0, d.tick): return false
		var expected := "alliance" if r.score >= 50 else ("rivalry" if r.score <= -40 else "peace")
		if r.get("status") != expected: return false
	var assigned := {}
	var origins := {}
	for n in d.expeditions.size():
		var e: Variant = d.expeditions[n]
		if not e is Dictionary or e.get("id") != n or not e.get("active") is bool: return false
		if not integer(e.get("kingdom"), 0, d.kingdoms.size() - 1) or not integer(e.get("origin"), 0, d.villages.size() - 1) or not integer(e.get("target"), 0, WorldState.WIDTH * WorldState.HEIGHT - 1): return false
		if not integer(e.get("started"), 0, d.tick) or not words(e.get("outcome")): return false
		for key in ["food", "wood", "stone"]:
			if not integer(e.get(key), 0, {"food": 24, "wood": 12, "stone": 4}[key]): return false
		if not e.get("members") is Array: return false
		if not e.active:
			if not e.members.is_empty() or e.food != 0 or e.wood != 0 or e.stone != 0: return false
			continue
		if e.members.size() != 4 or origins.has(int(e.origin)): return false
		origins[int(e.origin)] = true
		for id in e.members:
			if not integer(id, 1, d.next_id - 1) or not units.has(int(id)) or assigned.has(int(id)): return false
			var u: Dictionary = units[int(id)]
			if u.expedition != n or u.species != "settler" or u.village != e.origin: return false
			assigned[int(id)] = true
	for u in d.units:
		if u.expedition >= 0 and not assigned.has(int(u.id)): return false
	return true

static func restore(w: WorldState, d: Dictionary) -> void:
	for key in ["kingdoms", "relations", "expeditions"]:
		for entry in d[key]:
			var copy: Dictionary = entry.duplicate(true)
			for field in copy:
				if copy[field] is float: copy[field] = int(copy[field])
			if key == "kingdoms":
				for e in copy.history: e.year = int(e.year)
			if key == "expeditions": copy.members = copy.members.map(func(i: Variant) -> int: return int(i))
			w.get(key).append(copy)
	for u in w.units: u.expedition = int(u.expedition)
	for v in w.villages:
		for key in ["kingdom", "loyalty", "expansion_after"]: v[key] = int(v[key])
	var nav := WorldNavigation.new(w)
	KingdomPolitics.new(w, nav, VillageEconomy.new(w, nav)).refresh_claims()

static func migrate(w: WorldState) -> void:
	w.laws.merge({"expansion": true, "diplomacy": true}, true)
	for u in w.units: u.expedition = -1
	for v in w.villages:
		v.merge({"kingdom": -1, "loyalty": 75, "loyalty_reason": "A new beginning", "expansion_after": w.tick + 240, "expansion_reason": "Establishing the village"}, true)
	var nav := WorldNavigation.new(w)
	KingdomPolitics.new(w, nav, VillageEconomy.new(w, nav)).refresh(false)
