class_name SeaTransport
extends RefCounted
## A paid eight-person boat follows water-only routes between reachable shores.
var world: WorldState
var navigation: WorldNavigation
func _init(w: WorldState, nav: WorldNavigation) -> void:
	world = w
	navigation = nav

static func empty_boat() -> Dictionary:
	return {"paid": false, "state": "none", "embark": -1, "landing": -1, "x": 0, "y": 0, "route": [], "revision": -1}

func _neighbors(i: int) -> Array[int]:
	var result: Array[int] = []
	for d in WorldNavigation.DIRECTIONS:
		var p: Vector2i = Vector2i(i % world.width, i / world.width) + d
		if world.contains(p.x, p.y): result.append(world.index(p.x, p.y))
	return result

func _shores(p: Vector2i) -> Dictionary:
	var shores := {}
	navigation.ensure_current()
	if not world.habitable(p.x, p.y): return shores
	var component := navigation.components[world.index(p.x, p.y)]
	for i in world.elevation.size():
		if navigation.components[i] != component: continue
		if Vector2i(i % world.width, i / world.width).distance_squared_to(p) > 1024: continue
		for n in _neighbors(i):
			if world.elevation[n] == WorldState.Elevation.WATER and not shores.has(n): shores[n] = i
	return shores

func _crossing(starts: Dictionary, goals: Dictionary) -> Dictionary:
	var queue: Array = starts.keys()
	var parent := {}
	var source := {}
	for i in queue: parent[i] = -1; source[i] = starts[i]
	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		if goals.has(i):
			var route: Array = [i]
			var previous: int = parent[i]
			while previous >= 0: route.push_front(previous); previous = parent[previous]
			if route.size() > 512: return {}
			return {"embark": source[i], "landing": goals[i], "route": route}
		for n in _neighbors(i):
			if world.elevation[n] != WorldState.Elevation.WATER or parent.has(n): continue
			parent[n] = i
			source[n] = source[i]
			queue.append(n)
	return {}

func plan(start: Vector2i, destination: Vector2i) -> Dictionary:
	return _crossing(_shores(start), _shores(destination))

func prepare(army: Dictionary, people: Array[Dictionary], destination: Vector2i) -> bool:
	if people.is_empty(): return false
	var start := Vector2i(people[0].x, people[0].y)
	var route := plan(start, destination)
	if route.is_empty(): army.outcome = "No reachable crossing within 32 tiles of shore"; return false
	for u in people:
		if not navigation.connected(Vector2i(u.x, u.y), start): return false
	var boat: Dictionary = army.boat
	var v := world.villages[army.origin]
	if not boat.paid:
		if v.wood < 20 or v.food < 8: army.outcome = "Transport needs 20 wood and 8 food"; return false
		v.wood -= 20
		v.food -= 8
		army.food = mini(48, army.food + 8)
		boat.paid = true
	boat.merge(route, true)
	boat.state = "boarding"
	boat.x = int(boat.embark) % world.width
	boat.y = int(boat.embark) / world.width
	boat.revision = world.navigation_revision
	army.outcome = "Boarding an eight-seat transport"
	return true

func step(army: Dictionary, people: Array[Dictionary]) -> void:
	var boat: Dictionary = army.boat
	if boat.state not in ["boarding", "sailing"] or people.is_empty(): return
	if boat.state == "boarding":
		if boat.revision != world.navigation_revision: boat.state = "landed"; return
		for u in people:
			if world.index(u.x, u.y) != boat.embark: return
		boat.state = "sailing"
		army.outcome = "Sailing to the far shore"
	# Only the boat moves embarked people, one adjacent water tile per two ticks.
	if world.tick % 2 != 0: return
	var current := world.index(boat.x, boat.y)
	if boat.revision != world.navigation_revision:
		if world.habitable(boat.x, boat.y):
			_land(boat, people, current)
			return
		var shore := int(boat.landing)
		var goals := {}
		if world.habitable(shore % world.width, shore / world.width):
			for n in _neighbors(shore):
				if world.elevation[n] == WorldState.Elevation.WATER: goals[n] = shore
		var revised := _crossing({current: current}, goals) if world.elevation[current] == WorldState.Elevation.WATER else {}
		boat.route = revised.get("route", [])
		if not boat.route.is_empty(): boat.route.pop_front()
		boat.revision = world.navigation_revision
	if not boat.route.is_empty():
		var next: int = boat.route[0]
		if next not in _neighbors(current) or world.elevation[next] != WorldState.Elevation.WATER: return
		boat.route.pop_front()
		boat.x = next % world.width
		boat.y = next / world.width
		for u in people: u.x = boat.x; u.y = boat.y; u.state = "Aboard a transport"
	elif int(boat.landing) in _neighbors(current) and world.habitable(int(boat.landing) % world.width, int(boat.landing) / world.width):
		_land(boat, people, boat.landing)
		army.outcome = "Landed on the far shore"
	else:
		army.outcome = "Transport stranded; restore the water route or a nearby shore"
		# A new adjacent shore can rescue a trapped boat without teleporting.
		for n in _neighbors(current):
			if world.habitable(n % world.width, n / world.width): _land(boat, people, n); break

func _land(boat: Dictionary, people: Array[Dictionary], tile: int) -> void:
	boat.state = "landed"
	boat.route = []
	boat.x = tile % world.width
	boat.y = tile / world.width
	for u in people:
		u.x = boat.x
		u.y = boat.y
		u.route = []
		u.route_revision = -1
