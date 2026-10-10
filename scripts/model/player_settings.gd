class_name PlayerSettings
extends RefCounted
const DEFAULTS := {"master": 0.6, "ambience": 0.35, "effects": 0.65, "large_text": false, "high_contrast": false, "reduced_motion": false, "pause_unfocused": true, "frame_limit": 60}
var path := "user://settings.json"
var values: Dictionary = DEFAULTS.duplicate()
var recovered := false
static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1 or not data.get("values") is Dictionary: return false
	if data.values.size() != DEFAULTS.size(): return false
	for key in ["master", "ambience", "effects"]:
		if not SaveStore._number(data.values.get(key), 0, 1): return false
	for key in ["large_text", "high_contrast", "reduced_motion", "pause_unfocused"]:
		if not data.values.get(key) is bool: return false
	return SaveStore._integer(data.values.get("frame_limit"), 30, 60) and int(data.values.frame_limit) in [30, 60]
func restore() -> void:
	values = DEFAULTS.duplicate()
	recovered = false
	var result := SafeFiles.read_json(path, valid, 16384)
	if not result.has("data"): return
	values = result.data.values.duplicate(true)
	values.frame_limit = int(values.frame_limit)
	recovered = result.recovered
func save(candidate: Dictionary) -> Error:
	var data := {"version": 1, "values": candidate}
	if not valid(data): return ERR_INVALID_DATA
	var result := SafeFiles.write_json(path, data, valid)
	if result == OK: values = candidate.duplicate(true); recovered = false
	return result
