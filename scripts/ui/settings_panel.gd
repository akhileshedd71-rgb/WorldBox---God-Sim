class_name SettingsPanel
extends VBoxContainer
var game: Control
var sliders := {}
var toggles := {}
var limit: OptionButton
var apply_button: Button
var status: Label
func setup(controller: Control) -> void:
	game = controller
	add_theme_constant_override("separation", 10)
	for entry in [["master", "Master volume"], ["ambience", "Ambient music"], ["effects", "Interaction sounds"]]:
		var row := HBoxContainer.new(); add_child(row)
		var label: Label = game.hud.label(entry[1], 13); label.custom_minimum_size.x = 165; row.add_child(label)
		var slider := HSlider.new(); slider.min_value = 0; slider.max_value = 100; slider.step = 5
		slider.custom_minimum_size = Vector2(100, 48); slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value = game.preferences.values[entry[0]] * 100; row.add_child(slider)
		var value: Label = game.hud.label("%s%%" % int(slider.value), 13); value.custom_minimum_size.x = 48; row.add_child(value)
		slider.value_changed.connect(func(n: float): value.text = "%s%%" % int(n))
		sliders[entry[0]] = slider
	for entry in [["large_text", "Larger reading text"], ["high_contrast", "Higher-contrast interface"], ["reduced_motion", "Reduce weather and movement animation"], ["pause_unfocused", "Pause when the game loses focus"]]:
		var b := CheckButton.new(); b.text = entry[1]; b.custom_minimum_size.y = 48
		b.button_pressed = game.preferences.values[entry[0]]; add_child(b); toggles[entry[0]] = b
	var row := HBoxContainer.new(); add_child(row)
	row.add_child(game.hud.label("Frame limit", 13))
	limit = OptionButton.new(); limit.custom_minimum_size.y = 48; limit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	limit.add_item("60 FPS target", 60); limit.add_item("30 FPS target", 30)
	limit.select(0 if game.preferences.values.frame_limit == 60 else 1); row.add_child(limit)
	var note: Label = game.hud.label("Choose smoother motion or a lower frame limit to reduce power use. Changes apply when you save these settings. Escape closes panels; Tab and arrow keys navigate controls.", 13, GameHUD.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(note)
	status = game.hud.label("", 13, GameHUD.ACCENT); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	apply_button = game.hud.button("Apply & save settings", "settings", _apply); add_child(apply_button)
func _apply() -> void:
	var candidate := PlayerSettings.DEFAULTS.duplicate()
	for key in sliders: candidate[key] = sliders[key].value / 100.0
	for key in toggles: candidate[key] = toggles[key].button_pressed
	candidate.frame_limit = limit.get_selected_id()
	if game.preferences.save(candidate) != OK: status.text = "Settings could not be saved. Check device storage and try again."; return
	game._apply_preferences(); game._close_dialog(); game.hud.toast("Settings saved.")
