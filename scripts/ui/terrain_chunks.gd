class_name TerrainChunks
extends RefCounted
## Scan compact visual signatures; rebuild only affected 16×16-cell textures.
const CELLS := 16
const TILE := 16
var world: WorldState
var tiles: Array[Image]
var biome_tiles: Array[Image]
var images: Dictionary
var textures := {}
var dirty := {}
var signatures := PackedInt32Array()
var seed := -1
var rebuilt := 0
var last_rebuilt := 0

func setup(state: WorldState, grounds: Array[Image], biomes: Array[Image], plants: Dictionary) -> void:
	world = state; tiles = grounds; biome_tiles = biomes; images = plants
	textures.clear(); dirty.clear(); signatures.clear(); seed = -1
func position(id: int) -> Vector2i:
	return Vector2i(id % columns(), id / columns()) * CELLS
func columns() -> int: return ceili(float(world.width) / CELLS)
func mark(p: Vector2i) -> void:
	if world.contains(p.x, p.y): dirty[(p.y / CELLS) * columns() + p.x / CELLS] = true
func scan() -> void:
	if signatures.size() != world.terrain.size() or seed != world.world_seed:
		signatures.resize(world.terrain.size()); signatures.fill(-1); seed = world.world_seed
	for i in world.terrain.size():
		var value := int(world.terrain[i]) | (int(world.elevation[i]) << 3) | (int(world.biomes[i]) << 5) | (int(world.trees[i] > 0) << 8) | (int(world.stone[i] > 0) << 9) | (int(world.snow[i] > 0) << 10)
		if value == signatures[i]: continue
		signatures[i] = value
		var p := Vector2i(i % world.width, i / world.width)
		mark(p)
		# Ocean coast accents depend on their four neighboring materials.
		for d in Simulation.DIRECTIONS: mark(p + d)
func flush(budget: int = 4) -> void:
	last_rebuilt = 0
	var ids: Array = dirty.keys(); ids.sort()
	for id in ids:
		if last_rebuilt >= budget: break
		var map := render_chunk(id)
		if textures.has(id): textures[id].update(map)
		else: textures[id] = ImageTexture.create_from_image(map)
		dirty.erase(id); last_rebuilt += 1; rebuilt += 1
func render_chunk(id: int) -> Image:
	var origin := position(id)
	var map := Image.create(CELLS * TILE, CELLS * TILE, false, Image.FORMAT_RGBA8)
	for y in range(origin.y, mini(world.height, origin.y + CELLS)):
		for x in range(origin.x, mini(world.width, origin.x + CELLS)):
			var i := world.index(x, y)
			var type: int = world.terrain[i]
			var variation := posmod(x * 7 + y * 13 + world.world_seed, 4)
			var p := (Vector2i(x, y) - origin) * TILE
			var ground: Image = tiles[type * 4 + variation] if world.elevation[i] != 1 else biome_tiles[world.biomes[i] * 4 + variation]
			if world.snow[i] > 0: ground = biome_tiles[3 * 4 + variation]
			map.blit_rect(ground, Rect2i(0, 0, TILE, TILE), p)
			var hash_value := posmod(hash(Vector3i(x, y, world.world_seed)), 101)
			if type == WorldState.Terrain.OCEAN:
				var coast := false
				for d in Simulation.DIRECTIONS:
					var n: Vector2i = Vector2i(x, y) + d
					if world.contains(n.x, n.y) and world.terrain[world.index(n.x, n.y)] != WorldState.Terrain.OCEAN:
						coast = true
				if coast:
					map.fill_rect(Rect2i(p, Vector2i(TILE, TILE)), Color("377b7c"))
					map.fill_rect(Rect2i(p + Vector2i(4, 6), Vector2i(8, 2)), Color("63a49a"))
				elif hash_value < 4:
					map.fill_rect(Rect2i(p + Vector2i(3, 8), Vector2i(7, 1)), Color("24596b"))
			elif world.trees[i] > 0:
				var plant: Image = images.glimmer_tree if world.biomes[i] == 6 else (images.reeds if world.biomes[i] == 5 else (images.tree if hash_value % 2 == 0 else images.pine))
				map.blend_rect(plant, Rect2i(0, 0, 16, 16), p)
			elif world.stone[i] > 0:
				map.blend_rect(images.stone, Rect2i(0, 0, 16, 16), p)
			elif type == WorldState.Terrain.MOUNTAIN and hash_value < 55:
				map.blend_rect(images.peak, Rect2i(0, 0, 16, 16), p)
	return map
