class_name SocietyPersistence
extends RefCounted
## Validate every social reference before constructing a replacement world.
const ARRAYS := ["cultures", "clans", "languages", "beliefs", "society_history", "ruler_history", "discoveries", "society_samples"]
static func validate(d: Dictionary) -> bool:
	for key in ["society", "cultural_exchange"]:
		if not d.laws.get(key) is bool: return false
	var limits := [128, 256, 2, 128, 192, 256, 4, 120]
	for n in ARRAYS.size():
		if not d.get(ARRAYS[n]) is Array or d[ARRAYS[n]].size() > limits[n]: return false
	for table in SocietySimulation.TABLES:
		for n in d[table].size():
			var entry: Variant = d[table][n]
			if not entry is Dictionary or not PoliticsPersistence.integer(entry.get("id"), n, n) or not PoliticsPersistence.words(entry.get("name"), 80): return false
			if not PoliticsPersistence.integer(entry.get("founded"), 0, d.tick): return false
			if table == "cultures":
				for topic in SocietySimulation.LIMITS:
					if not PoliticsPersistence.integer(entry.get(topic), 0, SocietySimulation.LIMITS[topic]): return false
	var records := {}
	for r in d.lineage:
		if not _identity(r, d): return false
		records[int(r.id)] = r
	for u in d.units:
		if not _identity(u, d): return false
		for key in SocietySimulation.FIELDS:
			if u[key] != records[int(u.id)][key]: return false
		if not PoliticsPersistence.integer(u.get("residence"), 0, 192): return false
		if not PoliticsPersistence.integer(u.get("social_home"), -1, d.villages.size() - 1): return false
		if u.social_home < 0 and u.residence != 0: return false
		if u.species != "settler" and (u.social_home != -1 or u.residence != 0): return false
	var last := int(d.tick)
	for e in d.society_history:
		if not e is Dictionary or not PoliticsPersistence.integer(e.get("tick"), 0, last): return false
		last = int(e.tick)
		if e.get("kind") not in ["founding", "knowledge", "exchange", "discovery"] or not PoliticsPersistence.words(e.get("text"), 300): return false
		if not PoliticsPersistence.integer(e.get("culture"), -1, d.cultures.size() - 1) or not _person(e.get("person"), records): return false
	last = int(d.tick)
	for e in d.ruler_history:
		if not e is Dictionary or not PoliticsPersistence.integer(e.get("tick"), 0, last): return false
		last = int(e.tick)
		if not PoliticsPersistence.integer(e.get("kingdom"), 0, d.kingdoms.size() - 1) or not _person(e.get("person"), records): return false
		if e.person >= 0 and records[int(e.person)].species != "settler": return false
		if e.get("kind") not in ["succession", "observed", "collapse"]: return false
	var seen := {}
	last = 0
	for e in d.discoveries:
		if not e is Dictionary or not e.get("key") is String or not SocietySimulation.OBJECTIVES.has(e.key) or seen.has(e.key): return false
		if not PoliticsPersistence.integer(e.get("tick"), last, d.tick): return false
		last = int(e.tick)
		seen[e.key] = true
	last = 0
	for e in d.society_samples:
		if not e is Dictionary or not PoliticsPersistence.integer(e.get("year"), last + 1, 1 + int(d.tick) / 48): return false
		last = int(e.year)
		if not PoliticsPersistence.integer(e.get("population"), 0, WorldState.MAX_UNITS): return false
		for key in ["food", "wood", "stone"]:
			if not PoliticsPersistence.integer(e.get(key), 0, 208 * d.villages.size()): return false
	return true

static func _identity(r: Dictionary, d: Dictionary) -> bool:
	for n in SocietySimulation.FIELDS.size():
		var key: String = SocietySimulation.FIELDS[n]
		if not PoliticsPersistence.integer(r.get(key), -1, d[SocietySimulation.TABLES[n]].size() - 1): return false
		if r.species != "settler" and r[key] != -1: return false
	# An identity can be absent, or contain four valid independent memberships.
	for key in SocietySimulation.FIELDS:
		if (r[key] < 0) != (r.culture < 0): return false
	return true

static func _person(value: Variant, records: Dictionary) -> bool:
	return PoliticsPersistence.integer(value, -1, 2147483647) and (value == -1 or records.has(int(value)))

static func restore(w: WorldState, d: Dictionary) -> void:
	for key in ARRAYS:
		for source in d[key]:
			var entry: Dictionary = source.duplicate(true)
			for field in entry:
				if entry[field] is float: entry[field] = int(entry[field])
			w.get(key).append(entry)
	for r in w.lineage:
		for field in SocietySimulation.FIELDS: r[field] = int(r[field])
	for u in w.units:
		for field in SocietySimulation.FIELDS + ["residence", "social_home"]: u[field] = int(u[field])
	w.society_ready = true
