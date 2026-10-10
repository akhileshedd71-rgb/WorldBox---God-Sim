class_name SpeciesCatalog
extends RefCounted
const DEFINITIONS := {
	"settler": preload("res://data/species/settler.tres"),
	"rabbit": preload("res://data/species/rabbit.tres"),
	"deer": preload("res://data/species/deer.tres")
}
static func get_species(id: String) -> SpeciesDefinition:
	return DEFINITIONS.get(id)
static func maturity(id: String) -> int: return get_species(id).maturity
static func lifespan(id: String) -> int: return get_species(id).lifespan
