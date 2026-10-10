class_name SpatialIndex
extends RefCounted
## Stable bucket iteration for local neighbors; rebuilt at simulation boundaries.
const CELL_SIZE := 8
var buckets := {}

func rebuild(units: Array[Dictionary]) -> void:
	buckets.clear()
	for u in units:
		if u.health <= 0: continue
		var key := Vector2i(u.x / CELL_SIZE, u.y / CELL_SIZE)
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(u)

func nearby(p: Vector2i, radius: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var from := Vector2i(maxi(0, p.x - radius) / CELL_SIZE, maxi(0, p.y - radius) / CELL_SIZE)
	var to := Vector2i((p.x + radius) / CELL_SIZE, (p.y + radius) / CELL_SIZE)
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			for u in buckets.get(Vector2i(x, y), []):
				if Vector2i(u.x, u.y).distance_squared_to(p) <= radius * radius: result.append(u)
	return result
