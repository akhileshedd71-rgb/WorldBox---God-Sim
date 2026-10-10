class_name SaveLibrary
extends RefCounted
## Fixed filenames keep user labels out of paths. No catalog can lose a slot.
const SLOT_COUNT := 6
var directory := "user://worlds"
func path(slot: int) -> String:
	return directory.path_join("slot-%02d.json" % (slot + 1)) if slot >= 0 and slot < SLOT_COUNT else ""
func save_slot(w: WorldState, slot: int, label: String) -> Error:
	if path(slot).is_empty() or label.strip_edges().is_empty() or label.length() > 48: return ERR_INVALID_PARAMETER
	var data := SaveStore.encode(w).duplicate(true)
	data.slot_label = label.strip_edges()
	data.saved_at = int(Time.get_unix_time_from_system())
	return SafeFiles.write_json(path(slot), data, valid)
static func valid(data: Variant) -> bool:
	if not data is Dictionary or not data.get("slot_label") is String or data.slot_label.strip_edges().is_empty() or data.slot_label.length() > 48: return false
	if not SaveStore._integer(data.get("saved_at"), 0, 99999999999): return false
	return SaveStore.decode(data).has("world")
func read_slot(slot: int, backup: bool = false) -> Dictionary:
	if path(slot).is_empty(): return {"error": "Choose one of the six world slots."}
	var result := SafeFiles.read_one(path(slot) + ".bak", valid) if backup else SafeFiles.read_json(path(slot), valid)
	if result.has("error"): return result
	var decoded := SaveStore.decode(result.data)
	decoded.label = result.data.slot_label
	decoded.source = result.source
	decoded.recovered = backup or result.recovered
	return decoded
func inspect_slot(slot: int) -> Dictionary:
	if path(slot).is_empty(): return {"slot": slot, "valid": false, "backup": false, "occupied": false, "label": "Invalid slot"}
	var result := SafeFiles.read_json(path(slot), valid)
	var info := {"slot": slot, "valid": result.has("data"), "backup": SafeFiles.read_one(path(slot) + ".bak", valid).has("data")}
	info.occupied = FileAccess.file_exists(path(slot)) or FileAccess.file_exists(path(slot) + ".bak") or FileAccess.file_exists(path(slot) + ".tmp")
	if not info.valid:
		info.label = "Unreadable world" if info.occupied else "Empty slot"
		return info
	info.label = result.data.slot_label
	info.year = 1 + int(result.data.tick) / 48
	info.population = result.data.units.size()
	info.seed = int(result.data.seed)
	info.saved_at = int(result.data.saved_at)
	info.recovered = result.recovered
	return info
