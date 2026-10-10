class_name SafeFiles
extends RefCounted
## Recoverable local JSON replacement. No existing good copy is truncated.
static func read_one(path: String, validate: Callable, limit: int = 8000000) -> Dictionary:
	if not FileAccess.file_exists(path): return {"error": "No saved file here yet."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"error": "This file could not be opened."}
	if file.get_length() > limit: return {"error": "This file is too large."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not validate.call(parser.data): return {"error": "This file is damaged or unsupported."}
	return {"data": parser.data, "source": path, "recovered": false}

static func read_json(path: String, validate: Callable, limit: int = 8000000) -> Dictionary:
	var result := read_one(path, validate, limit)
	if result.has("data"): return result
	for suffix in [".bak", ".tmp"]:
		var fallback := read_one(path + suffix, validate, limit)
		if fallback.has("data"):
			fallback.recovered = true
			return fallback
	return {"error": "No valid save or recovery copy was found. Your current world is unchanged."}

static func write_json(path: String, data: Dictionary, validate: Callable) -> Error:
	if not validate.call(data): return ERR_INVALID_DATA
	var result := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if result != OK: return result
	# If an interrupted temporary is the only good copy, protect it before reuse.
	if not read_one(path, validate).has("data") and not read_one(path + ".bak", validate).has("data") and read_one(path + ".tmp", validate).has("data"):
		result = DirAccess.rename_absolute(path + ".tmp", path + ".bak")
		if result != OK: return result
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "", true, true))
	file.flush(); result = file.get_error(); file.close()
	if result != OK: return result
	if not read_one(path + ".tmp", validate).has("data"): return ERR_FILE_CORRUPT
	if read_one(path, validate).has("data"):
		result = DirAccess.copy_absolute(path, path + ".bak.tmp")
		if result != OK: return result
		if not read_one(path + ".bak.tmp", validate).has("data"): return ERR_FILE_CORRUPT
		result = DirAccess.rename_absolute(path + ".bak.tmp", path + ".bak")
		if result != OK: return result
	return DirAccess.rename_absolute(path + ".tmp", path)
