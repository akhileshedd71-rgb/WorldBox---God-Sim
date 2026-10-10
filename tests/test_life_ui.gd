extends SceneTree
var checks := 0
var failures := 0
var game: Control
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: ", description)
	else: failures += 1; printerr("FAIL: ", description)
func tap(control: Control, scroll: ScrollContainer = null) -> void:
	if scroll != null:
		scroll.ensure_control_visible(control)
		await process_frame
		await process_frame
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = root.get_screen_transform() * control.get_global_rect().get_center()
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await process_frame
func run() -> void:
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	Input.use_accumulated_input = false
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._set_speed(0)
	var w := WorldState.new()
	w.generate(741, 0, false)
	w.fill_material(WorldState.Terrain.MEADOW)
	w.laws.births = false
	var ids: Array = []
	for n in 2:
		w.spawn("settler", Vector2i(70, 50))
		ids.append(w.units[-1].id)
		w.units[-1].age = 25
	w.spawn("settler", Vector2i(74, 50), true, ids)
	var child_id: int = w.units[-1].id
	Heredity.replace_traits(w, child_id, ["robust", "woodland_adapted"])
	game.world = w
	game._bind_world()
	await process_frame
	await process_frame
	game.hud._select_category("Observe")
	game._inspect(Vector2i(74, 50))
	check(game.inspected_id == child_id and game.hud.inspector_text.text.contains("Generation 1"), "map inspection connects the selected creature to its lineage")
	await process_frame
	await tap(game.hud.tool_buttons.lives)
	check(game.life_panel != null and not game.modal_pauses, "native phone touch opens the live Lives inspector")
	if game.life_panel == null: quit(1); return
	var panel: LifePanel = game.life_panel
	var scroll: ScrollContainer = panel.get_parent()
	check(panel.selected == child_id and panel.overview.text.contains("Woodland folk") and panel.overview.text.contains("Generation 1"), "Lives starts at the inspected creature and shows its inherited subspecies and generation")
	check(panel.trait_label.text.contains("Robust") and panel.trait_label.text.contains("Weapon modifier: +2"), "trait inspection explains the actual derived combat effect")
	check(panel.portrait.texture != null and game.view.sprites.has("settler_3") and game.view.sprites.has("deer_3"), "portraits and the world canvas use original appearance variants")
	var shell: Control = game.modal.find_children("*", "PanelContainer", true, false)[0]
	check(shell.size.x <= 960 and shell.size.y <= 540 and panel.favorite_button.size.y >= 48, "life inspection fits the landscape phone with thumb-sized controls")
	await tap(panel.favorite_button, scroll)
	check(Heredity.record(w, child_id).favorite and panel.favorite_button.text == "Starred", "native Favorite touch persists the selected life in the model")
	await tap(panel.page_buttons.Family, scroll)
	check(panel.family_box.visible and not panel.trait_label.visible and panel.parent_buttons.size() == 2, "Family tab exposes both real parent links")
	await tap(panel.parent_buttons[0], scroll)
	check(panel.selected == ids[0] and panel.child_buttons.size() == 1 and panel.filter.selected == 3, "touching a parent navigates its record and reciprocal child link")
	await tap(panel.child_buttons[0], scroll)
	check(panel.selected == child_id and panel.parent_buttons.size() == 2, "touching a child returns to its own ancestry")
	await tap(panel.page_buttons.Memories, scroll)
	check(panel.memory_label.text.contains("Born to") and panel.memory_label.text.contains("Traits changed"), "Memories shows the actual recorded birth and trait events")
	panel.filter.select(1)
	panel.filter.item_selected.emit(1)
	check(panel.picker.item_count == 1 and panel.selected == child_id, "Favorites filter selects only starred records")
	await tap(panel.time_button, scroll)
	var tick: int = w.tick
	game._process(0.25)
	check(w.tick == tick + 1, "life inspector can resume the simulation")
	await tap(panel.time_button, scroll)
	check(game.speed == 0, "life inspector can pause without losing selection")
	# Archive a favorite parent while keeping the child's links intact.
	Heredity.set_favorite(w, ids[0], true)
	Heredity.unit(w, ids[0]).health = 0
	game.simulation.step()
	panel.filter.select(2)
	panel.filter.item_selected.emit(2)
	check(panel.selected == ids[0] and panel.focus_button.disabled and panel.overview.text.contains("Remembered"), "Remembered filter keeps a dead parent's identity and disables map focus")
	await tap(panel.page_buttons.Memories, scroll)
	check(panel.memory_label.text.contains("Life ended"), "a deceased favorite retains its final personal event")
	await tap(panel.page_buttons.Family, scroll)
	await tap(panel.child_buttons[0], scroll)
	check(panel.selected == child_id and panel.parent_buttons[0].text.contains("remembered"), "living descendants can still navigate to a dead parent")
	await tap(panel.page_buttons.Traits, scroll)
	scroll.scroll_vertical = 220
	await process_frame
	check(scroll.scroll_vertical > 0, "long trait explanations remain reachable by scrolling")
	await tap(panel.focus_button, scroll)
	check(game.modal == null and game.inspected_id == child_id and game.view.selected_id == child_id and game.view.zoom_level == 5, "Find on map focuses the actual living descendant")
	check(SaveStore.save_world(w, "user://life-ui.json") == OK, "UI favorites and family history can be written to a save")
	var restored := SaveStore.load_world("user://life-ui.json")
	check(restored.has("world") and Heredity.record(restored.world, ids[0]).favorite and Heredity.record(restored.world, child_id).parents == ids, "favorite memories and parent navigation survive disk reload")
	DirAccess.remove_absolute("user://life-ui.json")
	game._life_dialog(child_id)
	game.life_panel.filter.select(1)
	game.life_panel.filter.item_selected.emit(1)
	Heredity.set_favorite(w, child_id, false)
	Heredity.set_favorite(w, ids[0], false)
	game.life_panel.refresh()
	check(game.life_panel.selected == -1 and game.life_panel.favorite_button.disabled, "an empty favorites view has a safe disabled state")
	game._close_dialog()
	game.audio.shutdown()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("\nLIFE UI RESULT: %s checks, %s passed, %s failed" % [checks, checks - failures, failures])
	quit(0 if failures == 0 else 1)
