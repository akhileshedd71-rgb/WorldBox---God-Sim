class_name WorldNavigation
extends RefCounted
## Shared A* grid and connected components; edited barriers invalidate both.
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const MAX_REQUESTS := 16
var world: WorldState
var grid := AStarGrid2D.new()
var components := PackedInt32Array()
var revision := -1
var requests := 0

func _init(state: WorldState) -> void:
	world = state
	grid.region = Rect2i(0, 0, world.width, world.height)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.update()

func begin_tick() -> void:
	requests = 0
	ensure_current()

func ensure_current() -> void:
	if revision == world.navigation_revision: return
	components.resize(world.width * world.height)
	components.fill(-1)
	for i in components.size(): grid.set_point_solid(Vector2i(i % world.width, i / world.width), world.elevation[i] != WorldState.Elevation.LOWLAND)
	var component := 0
	for start in components.size():
		if components[start] >= 0 or world.elevation[start] != WorldState.Elevation.LOWLAND: continue
		var queue := PackedInt32Array([start])
		components[start] = component
		var head := 0
		while head < queue.size():
			var i := queue[head]
			head += 1
			var p := Vector2i(i % world.width, i / world.width)
			for d in DIRECTIONS:
				var n: Vector2i = p + d
				if not world.habitable(n.x, n.y): continue
				var j := world.index(n.x, n.y)
				if components[j] >= 0: continue
				components[j] = component
				queue.append(j)
		component += 1
	revision = world.navigation_revision

func connected(a: Vector2i, b: Vector2i) -> bool:
	ensure_current()
	if not world.habitable(a.x, a.y) or not world.habitable(b.x, b.y): return false
	return components[world.index(a.x, a.y)] == components[world.index(b.x, b.y)]

func route(start: Vector2i, target: int) -> Array:
	if requests >= MAX_REQUESTS or target < 0 or target >= world.terrain.size(): return []
	var destination := Vector2i(target % world.width, target / world.width)
	if not connected(start, destination): return []
	requests += 1
	var points := grid.get_id_path(start, destination)
	var result: Array = []
	for i in range(1, mini(points.size(), 513)):
		result.append(world.index(points[i].x, points[i].y))
	return result

func nearest(start: Vector2i, eligible: Callable, radius: int = 24) -> int:
	ensure_current()
	if not world.habitable(start.x, start.y): return -1
	var component := components[world.index(start.x, start.y)]
	for r in range(radius + 1):
		for dy in range(-r, r + 1):
			var dx := r - absi(dy)
			for offset in ([0] if dx == 0 else [-dx, dx]):
				var p := start + Vector2i(offset, dy)
				if not world.contains(p.x, p.y): continue
				var i := world.index(p.x, p.y)
				if components[i] == component and eligible.call(i): return i
	return -1

func advance(u: Dictionary, target: int) -> bool:
	var p := Vector2i(u.x, u.y)
	if world.index(u.x, u.y) == target: return true
	if u.target != target or u.route_revision != world.navigation_revision:
		u.route = []
		u.target = target
	if u.route.is_empty():
		u.route = route(p, target)
		u.route_revision = world.navigation_revision
	if u.route.is_empty(): return false
	var next: int = u.route[0]
	var destination := Vector2i(next % world.width, next / world.width)
	if not world.habitable(destination.x, destination.y) or absi(destination.x - u.x) + absi(destination.y - u.y) != 1:
		u.route = []
		return false
	if world.fire[next] > 0: u.route = []; return false
	u.route.pop_front()
	u.x = destination.x
	u.y = destination.y
	return next == target
