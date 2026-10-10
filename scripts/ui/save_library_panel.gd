class_name SaveLibraryPanel
extends VBoxContainer
var game: Control
var picker: OptionButton
var name_input: LineEdit
var info: Label
var message: Label
var save_button: Button
var load_button: Button
var backup_button: Button
var selected := 0
var entries: Array[Dictionary] = []
func setup(controller: Control) -> void:
	game = controller
	add_theme_constant_override("separation", 10)
	var legacy := HBoxContainer.new(); add_child(legacy)
	for entry in [["Saved world", game.manual_save_path], ["Last autosave", game.autosave_path]]:
		var b: Button = game.hud.button(entry[0], "load", func(): game._restore_world(SaveStore.load_world(entry[1])))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not ["", ".bak", ".tmp"].any(func(suffix: String) -> bool: return FileAccess.file_exists(entry[1] + suffix))
		legacy.add_child(b)
	add_child(game.hud.label("YOUR WORLD SHELF · SIX NAMED SLOTS", 11, GameHUD.ACCENT))
	picker = OptionButton.new(); picker.custom_minimum_size.y = 48
	picker.fit_to_longest_item = false
	picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(picker)
	picker.item_selected.connect(func(n: int): selected = n; refresh(false))
	info = game.hud.label("", 13); info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(info)
	name_input = LineEdit.new(); name_input.max_length = 48; name_input.custom_minimum_size.y = 48
	name_input.placeholder_text = "A name for this saved world"; add_child(name_input)
	var actions := HBoxContainer.new(); add_child(actions)
	save_button = game.hud.button("Save here", "save", _save)
	load_button = game.hud.button("Load world", "load", func(): game._restore_world(game.library.read_slot(selected), selected))
	for b in [save_button, load_button]: b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; actions.add_child(b)
	backup_button = game.hud.button("Load previous version", "history", func(): game._restore_world(game.library.read_slot(selected, true), selected))
	add_child(backup_button)
	message = game.hud.label("", 13, GameHUD.ACCENT); message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(message)
	var note: Label = game.hud.label("Saving here keeps one previous valid version. Loading first preserves your current world in autosave. A recovered copy is kept in memory until you save again. Ctrl+S updates the last named slot you saved or loaded; new worlds return to quick save.", 13, GameHUD.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(note)
	selected = maxi(0, game.active_slot)
	refresh()
func refresh(rescan: bool = true) -> void:
	if rescan:
		entries.clear(); picker.clear()
		for n in SaveLibrary.SLOT_COUNT:
			var entry: Dictionary = game.library.inspect_slot(n); entries.append(entry)
			picker.add_item("%s · %s" % [n + 1, entry.label], n)
	picker.select(selected)
	var entry := entries[selected]
	name_input.text = entry.label if entry.valid else game.world.world_name
	info.text = "This slot is empty. Save the world on screen here."
	if entry.valid:
		info.text = "Year %s · %s creatures · Seed %s\n%s%s" % [entry.year, entry.population, entry.seed, Time.get_datetime_string_from_unix_time(entry.saved_at, true) + " UTC", " · Recovery copy available" if entry.recovered else ""]
	elif entry.occupied: info.text = "This slot has no readable world. The world on screen is safe."
	save_button.text = "Replace slot %s" % (selected + 1) if entry.occupied else "Save in slot %s" % (selected + 1)
	load_button.disabled = not entry.valid
	backup_button.disabled = not entry.backup
	message.text = ""
func _save() -> void:
	var label := name_input.text.strip_edges()
	if label.is_empty(): message.text = "Give this world a name first."; return
	var result: Error = game.library.save_slot(game.world, selected, label)
	if result != OK: message.text = "Save failed. Check storage; the previous valid version is kept."; return
	game.active_slot = selected; game.active_label = label
	refresh(); message.text = "Saved “%s” in slot %s." % [label, selected + 1]
	game.audio.play_cue("save")
