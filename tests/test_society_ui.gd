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
		await process_frame
		scroll.ensure_control_visible(control)
		await process_frame; await process_frame
	var e := InputEventScreenTouch.new()
	e.index = 0; e.position = root.get_screen_transform() * control.get_global_rect().get_center(); e.pressed = true
	Input.parse_input_event(e); await process_frame
	e = e.duplicate(); e.pressed = false; Input.parse_input_event(e); await process_frame
func run() -> void:
	root.size = Vector2i(960, 540); root.content_scale_size = Vector2i(960, 540)
	Input.use_accumulated_input = false
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; game._set_speed(0)
	game.world.generate(41827, 2); game._bind_world()
	for n in 192: game.simulation.step()
	game.hud._select_category("Observe"); await process_frame
	await tap(game.hud.tool_buttons.society)
	check(game.society_panel != null and not game.modal_pauses, "native phone touch opens a live Society inspector")
	if game.society_panel == null: quit(1); return
	var panel: SocietyPanel = game.society_panel
	var scroll: ScrollContainer = panel.get_parent()
	var shell: Control = game.modal.find_children("*", "PanelContainer", true, false)[0]
	check(shell.size.x <= 960 and shell.size.y <= 540 and panel.page_buttons.Discoveries.size.y >= 48, "society fits the landscape phone with thumb-sized tabs")
	check(game.hud.tool_buttons.society.get_global_rect().end.x <= 940, "all eight Observe tools fit the phone toolbar")
	check(panel.picker.item_count == 3 and panel.status.text.contains("3 cultures"), "culture selection reflects the three actual frontier communities")
	check(panel.overview.text.contains("speech") and panel.overview.text.contains("hearth"), "People explains independently held language and belief membership")
	await tap(panel.time_button, scroll)
	var tick: int = game.world.tick; game._process(0.25)
	check(game.world.tick == tick + 1, "Society can resume the live simulation")
	await tap(panel.time_button, scroll)
	check(game.speed == 0, "Society can pause while retaining its selected culture")
	await tap(panel.page_buttons.Knowledge, scroll)
	check(panel.knowledge.is_visible_in_tree() and panel.knowledge.text.contains("/ 96") and panel.knowledge.text.contains("/ 4"), "Knowledge exposes both real learning thresholds")
	panel.metric_picker.select(1); panel.metric_picker.item_selected.emit(1)
	check(panel.chart.metric == "food" and panel.chart.history == game.world.society_samples, "resource graph reads the persisted annual food series")
	panel.picker.select(1); panel.picker.item_selected.emit(1)
	check(panel.selected == 1 and panel.member_picker.get_selected_id() > 0, "switching cultures updates the actual member roster")
	await tap(panel.page_buttons.History, scroll)
	check(panel.history_label.text.contains("begin a shared tradition"), "History displays real founding events")
	panel.scope_filter.select(1); panel.scope_filter.item_selected.emit(1)
	check(panel.history_label.text.contains(game.world.cultures[1].name) and not panel.history_label.text.contains(game.world.cultures[0].name), "culture filter narrows history without changing the world")
	panel.history_filter.select(3); panel.history_filter.item_selected.emit(3)
	check(panel.history_label.text.contains("No recorded events"), "empty filtered history explains the absence of matching events")
	panel.history_filter.select(5); panel.history_filter.item_selected.emit(5)
	check(panel.ruler_picker.is_visible_in_tree() and panel.history_label.text.contains("Succession"), "Rulers opens a persistent timeline with person links")
	panel.kingdom_filter.select(1); panel.kingdom_filter.item_selected.emit(1)
	check(panel.history_label.text.contains(game.world.kingdoms[0].name) and not panel.history_label.text.contains(game.world.kingdoms[1].name), "kingdom filter narrows the ruler timeline")
	var ruler: int = panel.ruler_picker.get_selected_id()
	await tap(panel.ruler_button, scroll)
	check(game.life_panel != null and game.life_panel.selected == ruler, "native ruler link opens that person's family browser")
	if game.life_panel == null: quit(1); return
	var life: LifePanel = game.life_panel
	check(life.trait_label.text.contains("Learned identity"), "Lives displays social affiliations alongside inherited traits")
	await tap(life.society_button, life.get_parent())
	check(game.society_panel != null and game.society_panel.selected == Heredity.record(game.world, ruler).culture, "native community link returns to the person's culture")
	panel = game.society_panel; scroll = panel.get_parent()
	await tap(panel.page_buttons.Discoveries, scroll)
	check(panel.discovery_label.text.contains("Many roots · Year") and panel.discovery_label.text.contains("Raise a living settler"), "Discoveries shows earned emblems and unfinished experiment goals")
	game.world.laws.society = false; panel.refresh()
	check(panel.status.text.contains("Society paused") and panel.status.text.contains("Exchange paused"), "the panel explains dormant social effects")
	await tap(panel.page_buttons.People, scroll)
	var member: int = panel.member_picker.get_selected_id()
	await tap(panel.life_button, scroll)
	check(game.life_panel != null and game.life_panel.selected == member, "native member link follows the exact selected person")
	check(SaveStore.save_world(game.world, "user://society-ui.json") == OK and SaveStore.load_world("user://society-ui.json").has("world"), "world changes made while inspecting society survive disk validation")
	DirAccess.remove_absolute("user://society-ui.json")
	game._close_dialog(); game.world.generate(91, 0, false); game._bind_world(); game._society_dialog()
	panel = game.society_panel
	check(panel.picker.disabled and panel.life_button.disabled and panel.overview.text.contains("Give settlers"), "empty worlds offer a clear path to begin social simulation")
	game.audio.shutdown()
	await create_timer(0.15).timeout
	game.queue_free(); await process_frame
	await create_timer(0.15).timeout
	print("\nSOCIETY UI RESULT: %s checks, %s passed, %s failed" % [checks, checks - failures, failures])
	quit(0 if failures == 0 else 1)
