class_name SpeciesDefinition
extends Resource
## Immutable project data; saves contain species IDs, never Resource instances.
@export var id := ""
@export var display_name := ""
@export var maturity := 16
@export var lifespan := 85
@export var birth_chance := 0.08
@export var birth_cooldown := 192
@export var forms_villages := false
@export var sprite := ""
@export var variants: PackedStringArray = []
