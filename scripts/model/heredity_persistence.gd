class_name HeredityPersistence
extends RefCounted
## v4 -> v5 migration preserves live identities; unknown ancestors stay unknown.
static func migrate(w: WorldState) -> void:
	for u in w.units: Heredity.register(w, u, [], true)
static func restore(w: WorldState, d: Dictionary) -> void:
	for entry in d.lineage:
		var r: Dictionary = entry.duplicate(true)
		for key in ["id", "generation", "birth_tick", "death_tick", "last_age"]: r[key] = int(r[key])
		r.parents = r.parents.map(func(i: Variant) -> int: return int(i))
		for gene in Heredity.GENES: r.genome[gene] = r.genome[gene].map(func(i: Variant) -> int: return int(i))
		for e in r.events: e.tick = int(e.tick)
		w.lineage.append(r)
		w.lineage_index[r.id] = r
	for u in w.units: u.genome = w.lineage_index[u.id].genome
static func validate(d: Dictionary) -> bool:
	if not d.get("lineage") is Array or d.lineage.size() > Heredity.MAX_RECORDS: return false
	var records := {}
	var previous := 0
	var favorites := 0
	for r in d.lineage:
		if not r is Dictionary or not PoliticsPersistence.integer(r.get("id"), previous + 1, int(d.next_id) - 1): return false
		previous = int(r.id)
		if not PoliticsPersistence.words(r.get("name"), 80) or r.get("species") not in SpeciesCatalog.DEFINITIONS: return false
		if not Heredity.valid_genome(r.get("genome")): return false
		if not PoliticsPersistence.integer(r.get("birth_tick"), -480000000, int(d.tick)) or not PoliticsPersistence.integer(r.get("death_tick"), -1, int(d.tick)): return false
		if r.death_tick >= 0 and r.death_tick < r.birth_tick: return false
		if not PoliticsPersistence.integer(r.get("last_age"), 0, 10000000) or not PoliticsPersistence.integer(r.get("generation"), 0, Heredity.MAX_RECORDS): return false
		if not r.get("favorite") is bool or r.get("origin") not in ["legacy", "introduced", "born"]: return false
		if r.favorite: favorites += 1
		if favorites > Heredity.MAX_FAVORITES: return false
		if not r.get("parents") is Array: return false
		if r.origin == "born":
			if r.parents.size() != 2 or r.parents[0] == r.parents[1] or r.birth_tick < 0: return false
			var generation := 0
			for id in r.parents:
				if not PoliticsPersistence.integer(id, 1, int(r.id) - 1) or not records.has(int(id)): return false
				var parent: Dictionary = records[int(id)]
				if parent.species != r.species or parent.birth_tick > r.birth_tick: return false
				if parent.death_tick >= 0 and parent.death_tick < r.birth_tick: return false
				generation = maxi(generation, int(parent.generation) + 1)
			if r.generation != generation: return false
		else:
			if not r.parents.is_empty() or r.generation != 0: return false
		if not r.get("events") is Array or r.events.size() > Heredity.MAX_EVENTS: return false
		var last_tick := int(d.tick)
		for e in r.events:
			if not e is Dictionary or not PoliticsPersistence.integer(e.get("tick"), 0, last_tick) or not PoliticsPersistence.words(e.get("text"), 160): return false
			if e.get("kind") not in ["birth", "arrival", "mutation", "child", "maturity", "traits", "death", "muster", "service", "ruler", "illness", "recovery", "society"]: return false
			last_tick = int(e.tick)
		records[int(r.id)] = r
	var living := {}
	for u in d.units:
		if not records.has(int(u.id)) or not Heredity.valid_genome(u.get("genome")): return false
		var r: Dictionary = records[int(u.id)]
		if r.death_tick != -1 or r.species != u.species or r.name != u.name or r.genome != u.genome: return false
		living[int(u.id)] = true
	for r in d.lineage:
		if not living.has(int(r.id)) and r.death_tick < 0: return false
	return true
