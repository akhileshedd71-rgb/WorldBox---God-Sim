class_name EnvironmentPersistence
extends RefCounted
## v6 owns explicit climate, wetness, snow, disease timers, and finite eruptions.
static func validate(d: Dictionary) -> bool:
	for law in EnvironmentSimulation.LAWS:
		if not d.laws.get(law) is bool: return false
	if not d.get("climate") is Dictionary: return false
	for pair in [["weather", 4], ["weather_left", 192], ["season_clock", 383], ["age_clock", 4607], ["disaster_clock", 191]]:
		if not PoliticsPersistence.integer(d.climate.get(pair[0]), 1 if pair[0] == "weather_left" else 0, pair[1]): return false
	if not d.get("climate_rng_state") is String or not d.climate_rng_state.is_valid_int(): return false
	for key in ["moisture", "snow"]:
		if not d.get(key) is Array or d[key].size() != d.terrain.size(): return false
		for i in d[key].size():
			if not PoliticsPersistence.integer(d[key][i], 0, 100 if key == "moisture" else 8): return false
			if d.elevation[i] != 1 and d[key][i] != 0: return false
	for u in d.units:
		if not PoliticsPersistence.integer(u.get("sickness"), 0, 64) or not PoliticsPersistence.integer(u.get("immunity"), 0, 192): return false
		if u.sickness > 0 and u.immunity > 0: return false
	if not d.get("hazards") is Array or d.hazards.size() > EnvironmentSimulation.MAX_HAZARDS: return false
	var cells := {}
	for vent in d.hazards:
		if not vent is Dictionary or not PoliticsPersistence.integer(vent.get("cell"), 0, d.terrain.size() - 1) or not PoliticsPersistence.integer(vent.get("remaining"), 1, 24): return false
		if cells.has(vent.cell): return false
		cells[vent.cell] = true
	return true
static func restore(w: WorldState, d: Dictionary) -> void:
	w.climate = d.climate.duplicate(true)
	for key in w.climate: w.climate[key] = int(w.climate[key])
	w.climate_rng.seed = w.world_seed + 610031
	w.climate_rng.state = d.climate_rng_state.to_int()
	w.moisture = PackedByteArray(d.moisture)
	w.snow = PackedByteArray(d.snow)
	for vent in d.hazards: w.hazards.append({"cell": int(vent.cell), "remaining": int(vent.remaining)})
	for u in w.units:
		u.sickness = int(u.sickness)
		u.immunity = int(u.immunity)
