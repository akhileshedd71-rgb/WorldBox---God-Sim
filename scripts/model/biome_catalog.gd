class_name BiomeCatalog
extends RefCounted
## IDs 0–3 preserve Phase 2–5 habitat genes and save compatibility.
const NAMES := ["Barren", "Temperate", "Woodland", "Tundra", "Arid", "Wetland", "Glimmergrove"]
const COLORS := [Color("d9c28b"), Color("7b9d52"), Color("48744b"), Color("d7e6df"), Color("c99a62"), Color("518c83"), Color("7476a7")]
const TEMPERATURE := [24, 20, 16, -4, 32, 22, 12]
const MOISTURE := [32, 64, 72, 48, 24, 88, 72]
const FORAGE := [0.0, 0.125, 0.125, 0.03125, 0.03125, 0.25, 0.1875]
const FOOD_CAP := [0.0, 20.0, 20.0, 4.0, 4.0, 20.0, 16.0]
const TREE_CAP := [0, 4, 12, 4, 0, 8, 12]
const TREE_PERIOD := [192, 192, 192, 192, 192, 128, 96]
const FERTILE := [1, 2, 5, 6]
static func habitat(biome: int) -> int:
	return {1: 1, 2: 2, 3: 3, 5: 1, 6: 2}.get(biome, 0)
