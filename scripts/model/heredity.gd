class_name Heredity
extends RefCounted
## Small diploid genome; traits/stats are derived, never independently mutable.
const MAX_RECORDS := 2048
const MAX_FAVORITES := 32
const MAX_EVENTS := 6
const GENES := ["metabolism", "vigor", "craft", "habitat", "coat"]
const TRAITS := {
	"thrifty": {"gene": "metabolism", "allele": -1, "text": "Uses 12.5% less food over time"},
	"hungry": {"gene": "metabolism", "allele": 1, "text": "Hunger rises 12.5% faster"},
	"frail": {"gene": "vigor", "allele": -1, "text": "Slower recovery, 10% shorter lifespan; equipped weapons deal 2 less damage"},
	"robust": {"gene": "vigor", "allele": 1, "text": "Faster recovery, 10% longer lifespan; equipped weapons deal 2 more damage"},
	"unhurried": {"gene": "craft", "allele": -1, "text": "Gathering and farming take four work ticks"},
	"industrious": {"gene": "craft", "allele": 1, "text": "Gathering and farming take two work ticks"},
	"meadow_adapted": {"gene": "habitat", "allele": 1, "text": "Hunger rises 12.5% slower on meadow"},
	"woodland_adapted": {"gene": "habitat", "allele": 2, "text": "Hunger rises 12.5% slower in woodland"},
	"cold_adapted": {"gene": "habitat", "allele": 3, "text": "Hunger rises 12.5% slower on snow"}
}
static func neutral() -> Dictionary:
	return {"metabolism": [0, 0], "vigor": [0, 0], "craft": [0, 0], "habitat": [0, 0], "coat": [0, 0]}
static func valid_genome(value: Variant) -> bool:
	if not value is Dictionary or value.size() != GENES.size(): return false
	for gene in GENES:
		var alleles: Variant = value.get(gene)
		if not alleles is Array or alleles.size() != 2: return false
		for a in alleles:
			if not PoliticsPersistence.integer(a, 0 if gene in ["habitat", "coat"] else -1, 3 if gene in ["habitat", "coat"] else 1): return false
	return true
static func value(u: Dictionary, gene: String) -> int:
	var g: Dictionary = u.get("genome", {})
	if g.is_empty(): return 0
	var alleles: Array = g[gene]
	if gene == "habitat": return int(alleles[0]) if alleles[0] == alleles[1] else 0
	if gene == "coat": return (int(alleles[0]) + int(alleles[1])) % 4
	return signi(int(alleles[0]) + int(alleles[1]))
static func traits(u: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in TRAITS:
		if TRAITS[key].gene == "craft" and not SpeciesCatalog.get_species(u.species).forms_villages: continue
		if value(u, TRAITS[key].gene) == TRAITS[key].allele: result.append(key)
	return result
static func variant(u: Dictionary) -> String:
	return SpeciesCatalog.get_species(u.species).variants[value(u, "habitat")]
static func hunger_rate(w: WorldState, u: Dictionary) -> float:
	var habitat := value(u, "habitat")
	var matching := habitat > 0 and habitat == BiomeCatalog.habitat(w.biomes[w.index(u.x, u.y)])
	return 0.5 * (1.0 + 0.125 * value(u, "metabolism")) * (0.875 if matching else 1.0)
static func recovery(u: Dictionary) -> float: return 0.25 + 0.125 * value(u, "vigor")
static func lifespan(u: Dictionary) -> int: return roundi(SpeciesCatalog.lifespan(u.species) * (1.0 + 0.1 * value(u, "vigor")))
static func work_ticks(u: Dictionary) -> int: return 3 - value(u, "craft")
static func damage(u: Dictionary, base: float) -> float: return clampf(base + value(u, "vigor") * 2, 1, 25)
static func unit(w: WorldState, id: int) -> Dictionary:
	for u in w.units:
		if u.id == id: return u
	return {}
static func record(w: WorldState, id: int) -> Dictionary: return w.lineage_index.get(id, {})
static func event(w: WorldState, id: int, message: String, kind: String) -> void:
	var r := record(w, id)
	if r.is_empty(): return
	r.events.push_front({"tick": w.tick, "text": message.left(160), "kind": kind})
	if r.events.size() > MAX_EVENTS: r.events.resize(MAX_EVENTS)
static func set_favorite(w: WorldState, id: int, enabled: bool) -> bool:
	var r := record(w, id)
	if r.is_empty(): return false
	if enabled and not r.favorite and w.lineage.filter(func(entry: Dictionary) -> bool: return entry.favorite).size() >= MAX_FAVORITES: return false
	r.favorite = enabled
	return true
static func replace_traits(w: WorldState, id: int, requested: Array) -> bool:
	var u := unit(w, id)
	if u.is_empty() or u.health <= 0: return false
	var genome := neutral()
	genome.coat = u.genome.coat.duplicate()
	var seen := {}
	for key in requested:
		if not key is String or not TRAITS.has(key): return false
		var rule: Dictionary = TRAITS[key]
		if seen.has(rule.gene): return false
		seen[rule.gene] = true
		genome[rule.gene] = [rule.allele, rule.allele]
	u.genome = genome
	record(w, id).genome = genome
	event(w, id, "Traits changed by the worldmaker.", "traits")
	return true
static func related(w: WorldState, a: int, b: int) -> bool:
	if a == b: return true
	var ra := record(w, a)
	var rb := record(w, b)
	if ra.is_empty() or rb.is_empty(): return false
	if a in rb.parents or b in ra.parents: return true
	for parent in ra.parents:
		if parent in rb.parents: return true
	return false
static func can_parent(w: WorldState, parents: Array, species: String) -> bool:
	if parents.size() != 2 or related(w, int(parents[0]), int(parents[1])): return false
	for id in parents:
		var u := unit(w, int(id))
		if u.is_empty() or u.health <= 0 or u.species != species or u.age < SpeciesCatalog.maturity(species): return false
	return true
static func inherit(w: WorldState, parents: Array, biome: int) -> Dictionary:
	var a := record(w, int(parents[0]))
	var b := record(w, int(parents[1]))
	var result := neutral()
	for gene in GENES:
		var pair: Array = [a.genome[gene][w.rng.randi_range(0, 1)], b.genome[gene][w.rng.randi_range(0, 1)]]
		for n in 2:
			# Rare mutations change one allele; habitat mutations favor the birth biome.
			if w.rng.randi_range(0, 31) != 0: continue
			var low := 0 if gene in ["habitat", "coat"] else -1
			var high := 3 if low == 0 else 1
			var altered := low + posmod(int(pair[n]) - low + w.rng.randi_range(1, high - low), high - low + 1)
			if gene == "habitat" and biome > 0 and biome != pair[n]: altered = biome
			pair[n] = altered
		result[gene] = pair
	return result
static func register(w: WorldState, u: Dictionary, parents: Array = [], legacy: bool = false) -> void:
	var genome := neutral()
	var generation := 0
	if not parents.is_empty():
		genome = inherit(w, parents, BiomeCatalog.habitat(w.biomes[w.index(u.x, u.y)]))
		generation = maxi(record(w, int(parents[0])).generation, record(w, int(parents[1])).generation) + 1
	elif not legacy:
		# Founder variation consumes no simulation RNG, preserving seeded geography.
		var initial := RandomNumberGenerator.new()
		initial.seed = w.world_seed * 65537 + u.id * 257
		for gene in ["metabolism", "vigor", "craft"]:
			genome[gene] = [initial.randi_range(-1, 1), initial.randi_range(-1, 1)]
		var habitat: int = BiomeCatalog.habitat(w.biomes[w.index(u.x, u.y)])
		genome.habitat = [habitat, habitat] if initial.randf() < 0.5 else [0, 0]
		genome.coat = [initial.randi_range(0, 3), initial.randi_range(0, 3)]
	u.genome = genome
	var r := {"id": u.id, "name": u.name, "species": u.species, "parents": parents.duplicate(), "generation": generation, "genome": genome, "birth_tick": w.tick - u.age * 48, "death_tick": -1, "last_age": u.age, "origin": "legacy" if legacy else ("born" if not parents.is_empty() else "introduced"), "favorite": false, "events": []}
	w.lineage.append(r)
	w.lineage_index[u.id] = r
	event(w, u.id, "Earlier ancestry is unknown." if legacy else ("Born to %s and %s." % [record(w, int(parents[0])).name, record(w, int(parents[1])).name] if not parents.is_empty() else "Arrived in this world."), "arrival" if parents.is_empty() else "birth")
	for id in parents: event(w, int(id), "%s (#%s) was born." % [u.name, u.id], "child")
	if not parents.is_empty():
		var mutated := false
		for gene in GENES:
			for allele in genome[gene]:
				if allele not in record(w, int(parents[0])).genome[gene] and allele not in record(w, int(parents[1])).genome[gene]: mutated = true
		if mutated: event(w, u.id, "A new inherited variation appeared at birth.", "mutation")
static func remember_death(w: WorldState, u: Dictionary) -> void:
	var r := record(w, u.id)
	if r.is_empty() or r.death_tick >= 0: return
	r.death_tick = w.tick
	r.last_age = u.age
	event(w, u.id, "Life ended at age %s. Last seen: %s." % [u.age, u.state], "death")
	if r.favorite: w.add_event("%s (#%s), a favorite, has died at age %s." % [u.name, u.id, u.age], "memory")
