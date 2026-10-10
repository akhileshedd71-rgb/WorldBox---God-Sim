class_name SocietySimulation
extends RefCounted
## Learned affiliations are independent of genomes, village IDs, and crowns.
const MAX_CULTURES := 128
const MAX_CLANS := 256
const MAX_HISTORY := 192
const MAX_RULERS := 256
const FIELDS := ["culture", "clan", "language", "belief"]
const TABLES := ["cultures", "clans", "languages", "beliefs"]
const NAMES := ["Reed", "Lantern", "Juniper", "Tide", "Amber", "Willow"]
const LIMITS := {"harvest": 96, "building": 4}
const OBJECTIVES := {
	"roots": ["Many roots", "Let two cultures take root in living settlements."],
	"harvest": ["Learning by doing", "Let a culture learn crop rotation from real harvests or neighbors."],
	"neighbors": ["A shared home", "Bring members of two cultures into one inhabited village."],
	"generations": ["Living memory", "Raise a living settler with two generations of recorded ancestors."]}
var world: WorldState
var navigation: WorldNavigation
var care := {} # Derived each tick; never a saved source of truth.

func _init(w: WorldState, nav: WorldNavigation) -> void:
	world = w
	navigation = nav

static func initialize(w: WorldState, legacy: bool = false) -> void:
	for key in TABLES + ["society_history", "ruler_history", "discoveries", "society_samples"]: w.get(key).clear()
	w.laws.society = not legacy
	w.laws.cultural_exchange = not legacy
	w.society_ready = true
	if legacy:
		for r in w.lineage:
			for key in FIELDS: r[key] = -1
		for u in w.units: register(w, u)
		assign_homes(w)
		for k in w.kingdoms:
			if k.alive: ruler(w, k.id, k.ruler, "observed")

static func register(w: WorldState, u: Dictionary, parents: Array = []) -> void:
	for key in FIELDS: u[key] = -1
	u.residence = 0
	u.social_home = -1
	if u.species == "settler":
		# Household learning uses the oldest recorded parent ID, not an allele.
		var ordered := parents.duplicate()
		ordered.sort()
		for id in ordered:
			var parent := Heredity.record(w, id)
			if parent.get("culture", -1) < 0: continue
			for key in FIELDS: u[key] = parent[key]
			break
	archive(w, u)

static func archive(w: WorldState, u: Dictionary) -> void:
	var r := Heredity.record(w, u.id)
	if r.is_empty(): return
	for key in FIELDS: r[key] = u[key]

static func title(w: WorldState, field: String, id: int) -> String:
	var table: Array = w.get(TABLES[FIELDS.find(field)])
	return table[id].name if id >= 0 and id < table.size() else "Unaffiliated"

static func founding(w: WorldState) -> int:
	if w.cultures.size() >= MAX_CULTURES or w.clans.size() + 2 > MAX_CLANS or w.beliefs.size() >= MAX_CULTURES: return -1
	var id := w.cultures.size()
	var stem: String = NAMES[id % NAMES.size()] + (" %s" % (id / NAMES.size() + 1) if id >= NAMES.size() else "")
	w.cultures.append({"id": id, "name": stem + " folk", "founded": w.tick, "harvest": 0, "building": 0})
	# Languages are shared across some cultures, and remain independently held.
	if w.languages.size() < 2:
		w.languages.append({"id": w.languages.size(), "name": ["River speech", "Hill speech"][w.languages.size()], "founded": w.tick})
	w.beliefs.append({"id": id, "name": stem + " hearth", "founded": w.tick})
	for branch in 2:
		w.clans.append({"id": w.clans.size(), "name": stem + (" Weavers" if branch == 0 else " Keepers"), "founded": w.tick})
	log_event(w, "founding", id, -1, "%s begin a shared tradition." % w.cultures[id].name)
	return id

static func assign_homes(w: WorldState) -> void:
	if not w.society_ready: return
	var groups := {}
	for u in w.units:
		if u.species == "settler" and u.health > 0 and u.village >= 0:
			if not groups.has(u.village): groups[u.village] = []
			groups[u.village].append(u)
	for home in groups:
		if not w.villages[home].alive: continue
		var people: Array = groups[home]
		var exemplar: Dictionary = {}
		for u in people:
			if u.culture >= 0: exemplar = u; break
		var newcomers: Array = people.filter(func(u: Dictionary) -> bool: return u.culture < 0)
		if newcomers.is_empty(): continue
		var new_house := exemplar.is_empty()
		if new_house:
			var id := founding(w)
			if id < 0: continue
			exemplar = {"culture": id, "clan": w.clans.size() - 2, "language": id % w.languages.size(), "belief": w.beliefs.size() - 1}
		for u in newcomers:
			for key in FIELDS: u[key] = exemplar[key]
			# Introduced people join a social house; this invents no ancestry.
			if new_house: u.clan += u.id % 2
			archive(w, u)

func begin_tick() -> void:
	assign_homes(world)
	care.clear()
	for u in world.units:
		var is_local := local(u)
		if world.laws.society and world.laws.cultural_exchange:
			if not is_local: u.residence = 0; u.social_home = -1
			else:
				if u.social_home != u.village: u.residence = 0; u.social_home = u.village
				u.residence = mini(192, u.residence + 1)
		if not is_local or u.belief < 0: continue
		var key := "%s:%s" % [u.village, u.belief]
		care[key] = care.get(key, 0) + 1

func local(u: Dictionary) -> bool:
	if u.species != "settler" or u.health <= 0 or u.village < 0 or u.army >= 0 or u.expedition >= 0: return false
	var v := world.villages[u.village]
	return v.alive and Vector2(u.x - v.x, u.y - v.y).length() <= 16 and navigation.connected(Vector2i(u.x, u.y), Vector2i(v.x, v.y))

func recovery(u: Dictionary) -> float:
	if not world.laws.society or not local(u) or u.belief < 0: return 0.0
	return 0.125 if care.get("%s:%s" % [u.village, u.belief], 0) >= 2 else 0.0

static func clan_support(w: WorldState, village: int) -> bool:
	if not w.laws.get("society", false): return false
	var counts := {}
	for u in w.units:
		if u.health <= 0 or u.village != village or u.get("clan", -1) < 0 or u.army >= 0 or u.expedition >= 0: continue
		counts[u.clan] = counts.get(u.clan, 0) + 1
		if counts[u.clan] >= 2: return true
	return false

static func work_ticks(w: WorldState, u: Dictionary) -> int:
	var base := 6 if u.job == "build" else Heredity.work_ticks(u)
	if not w.laws.get("society", false) or u.get("culture", -1) < 0: return base
	var c := w.cultures[u.culture]
	if u.job == "build" and c.building >= LIMITS.building: return 4
	if u.job == "farm" and c.harvest >= LIMITS.harvest: return maxi(1, base - 1)
	return base

static func learn(w: WorldState, culture: int, topic: String, amount: int) -> void:
	if not w.laws.get("society", false) or culture < 0 or culture >= w.cultures.size() or amount <= 0: return
	var c := w.cultures[culture]
	var before: int = c[topic]
	c[topic] = mini(LIMITS[topic], before + amount)
	if before < LIMITS[topic] and c[topic] == LIMITS[topic]:
		log_event(w, "knowledge", culture, -1, "%s learned %s." % [c.name, "crop rotation" if topic == "harvest" else "masonry"])

static func log_event(w: WorldState, kind: String, culture: int, person: int, message: String) -> void:
	w.society_history.push_front({"tick": w.tick, "kind": kind, "culture": culture, "person": person, "text": message})
	if w.society_history.size() > MAX_HISTORY: w.society_history.resize(MAX_HISTORY)
	w.add_event(message, "society")

static func ruler(w: WorldState, kingdom: int, person: int, kind: String = "succession") -> void:
	if not w.society_ready: return
	w.ruler_history.push_front({"tick": w.tick, "kingdom": kingdom, "person": person, "kind": kind})
	if w.ruler_history.size() > MAX_RULERS: w.ruler_history.resize(MAX_RULERS)

static func majority(people: Array, field: String) -> int:
	var counts := {}
	for u in people:
		if u[field] >= 0: counts[u[field]] = counts.get(u[field], 0) + 1
	for id in counts:
		if counts[id] * 2 > people.size(): return id
	return -1

func finish_tick() -> void:
	if world.tick % 48 != 0: return
	var sample := {"year": world.year(), "population": world.population("settler"), "food": 0, "wood": 0, "stone": 0}
	for v in world.villages:
		if v.alive:
			for key in ["food", "wood", "stone"]: sample[key] += v[key]
	world.society_samples.append(sample)
	if world.society_samples.size() > 120: world.society_samples.pop_front()
	if not world.laws.society: return
	var groups := {}
	for u in world.units:
		if local(u):
			if not groups.has(u.village): groups[u.village] = []
			groups[u.village].append(u)
	if world.laws.cultural_exchange:
		_exchange(groups)
		for id in groups: _residence(id, groups[id])
	_discover(groups)

func _residence(home: int, people: Array) -> void:
	# Take a snapshot: adoption order cannot change another person's target.
	var targets := {}
	for field in ["culture", "language", "belief"]: targets[field] = majority(people, field)
	for u in people:
		for field in ["culture", "belief", "language"]:
			var threshold: int = {"culture": 96, "belief": 144, "language": 192}[field]
			if u.residence < threshold or targets[field] < 0 or u[field] == targets[field]: continue
			u[field] = targets[field]
			archive(world, u)
			var message := "%s joined %s after living together." % [u.name, title(world, field, u[field])]
			log_event(world, "exchange", u.culture, u.id, message)
			Heredity.event(world, u.id, message, "society")

func _exchange(groups: Dictionary) -> void:
	var snapshot := world.cultures.duplicate(true)
	var towns: Array = groups.keys()
	for a in towns:
		for b in towns:
			if a == b: continue
			var va := world.villages[a]
			var vb := world.villages[b]
			if Vector2(va.x - vb.x, va.y - vb.y).length() > 32: continue
			if not navigation.connected(Vector2i(va.x, va.y), Vector2i(vb.x, vb.y)): continue
			var war := false
			for r in world.relations:
				if r.war and ((r.a == va.kingdom and r.b == vb.kingdom) or (r.b == va.kingdom and r.a == vb.kingdom)): war = true; break
			if war: continue
			var ca := majority(groups[a], "culture")
			var cb := majority(groups[b], "culture")
			if ca < 0 or cb < 0 or ca == cb: continue
			var language := majority(groups[a], "language")
			var amount := 4 if language >= 0 and language == majority(groups[b], "language") else 1
			for topic in LIMITS:
				# One teacher can never teach more than it knew at the year's start.
				learn(world, ca, topic, mini(amount, int(snapshot[cb][topic]) - int(world.cultures[ca][topic])))

func _discover(groups: Dictionary) -> void:
	var cultures := {}
	var mixed := false
	for id in groups:
		var local_cultures := {}
		for u in groups[id]:
			if u.culture >= 0: cultures[u.culture] = true; local_cultures[u.culture] = true
		mixed = mixed or local_cultures.size() >= 2
	var met := {"roots": cultures.size() >= 2, "harvest": world.cultures.any(func(c: Dictionary) -> bool: return c.harvest >= LIMITS.harvest), "neighbors": mixed, "generations": world.units.any(func(u: Dictionary) -> bool: return u.species == "settler" and Heredity.record(world, u.id).generation >= 2)}
	for key in met:
		if not met[key] or world.discoveries.any(func(d: Dictionary) -> bool: return d.key == key): continue
		world.discoveries.append({"key": key, "tick": world.tick})
		log_event(world, "discovery", -1, -1, "Discovery: %s." % OBJECTIVES[key][0])
