extends SceneTree
## Render an actual game frame for documentation; requires a graphics display.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Capture needs a graphical display. Use the headless tests for logic checks.")
		quit(1)
		return
	var phone := "--phone" in OS.get_cmdline_user_args()
	if phone:
		root.content_scale_size = Vector2i(960, 540)
		root.size = Vector2i(960, 540)
	var game: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._set_speed(0)
	var war := "--war" in OS.get_cmdline_user_args() or "--military" in OS.get_cmdline_user_args()
	var political := war or "--politics" in OS.get_cmdline_user_args() or "--kingdoms" in OS.get_cmdline_user_args()
	if political:
		game.world.generate(41827, 2)
		game._bind_world()
	for n in (1200 if war else (2400 if political else 960)): game.simulation.step()
	if war:
		game.simulation.military.declare_war(0, 1)
		for n in 62: game.simulation.step()
		var v: Dictionary = game.world.villages[1]
		game.view.zoom_level = 5
		game.view.camera_center = Vector2(v.x - 4, v.y) * 16
		game.view.camera_changed.emit(5.0)
	game.hud.refresh(game.world)
	game.hud.choose_tool("terrain_2")
	game.hud.toast_label.hide()
	if political:
		game.simulation.politics.refresh()
		game.view.show_politics = true
		game.hud.set_political_view(true)
		game.hud._select_category("Observe")
		game.hud.choose_tool("inspect")
	if "--kingdoms" in OS.get_cmdline_user_args():
		game._kingdom_dialog()
		if "--diplomacy" in OS.get_cmdline_user_args(): game.kingdom_panel.set_page("Diplomacy")
	if "--military" in OS.get_cmdline_user_args():
		game._kingdom_dialog(0)
		game.kingdom_panel.set_page("War")
	if "--villages" in OS.get_cmdline_user_args(): game._village_dialog()
	if "--settlement" in OS.get_cmdline_user_args() and not game.world.villages.is_empty():
		var v: Dictionary = game.world.villages[0]
		game.view.zoom_level = 5
		game.view.camera_changed.emit(5.0)
		game.view.camera_center = Vector2(v.x, v.y) * 16
	if "--lives" in OS.get_cmdline_user_args():
		var descendants: Array = game.world.lineage.filter(func(r: Dictionary) -> bool: return r.species == "settler" and r.generation > 0 and r.death_tick < 0)
		var chosen: Dictionary = descendants[-1] if not descendants.is_empty() else game.world.lineage[0]
		Heredity.set_favorite(game.world, chosen.id, true)
		game.hud._select_category("Observe")
		game._life_dialog(chosen.id)
		if "--family" in OS.get_cmdline_user_args(): game.life_panel.set_page("Family")
		if "--memories" in OS.get_cmdline_user_args(): game.life_panel.set_page("Memories")
	if "--environment" in OS.get_cmdline_user_args() or "--biomes" in OS.get_cmdline_user_args():
		EnvironmentSimulation.set_weather(game.world, 1)
		game.hud._select_category("Biomes")
		game.hud.choose_tool("biome_6")
		game.hud.refresh(game.world)
		game.view.zoom_level = 1.6
		game.view.camera_changed.emit(1.6)
		game.view.camera_center = Vector2(70, 48) * 16
		if not game.world.villages.is_empty(): game.inspected_cell = Vector2i(game.world.villages[0].x, game.world.villages[0].y)
		if "--environment" in OS.get_cmdline_user_args():
			game._environment_dialog()
			if "--land" in OS.get_cmdline_user_args(): game.environment_panel.set_page("Land")
			if "--health" in OS.get_cmdline_user_args(): game.environment_panel.set_page("Health")
	if "--society" in OS.get_cmdline_user_args():
		game.hud._select_category("Observe")
		game._society_dialog()
		if "--knowledge" in OS.get_cmdline_user_args(): game.society_panel.set_page("Knowledge")
		if "--chronicle" in OS.get_cmdline_user_args(): game.society_panel.set_page("History")
	if "--readable" in OS.get_cmdline_user_args():
		game.preferences.values.large_text = true
		game.preferences.values.high_contrast = true
		game._apply_preferences()
	if "--settings" in OS.get_cmdline_user_args(): game._settings_dialog()
	if "--shelf" in OS.get_cmdline_user_args():
		game.library.directory = "user://capture-shelf"
		game.library.save_slot(game.world, 0, "My first island")
		for n in 48: game.simulation.step()
		game.library.save_slot(game.world, 0, "My first island")
		game._load_dialog()
	if "--guide" in OS.get_cmdline_user_args(): game._help_dialog()
	for n in 8: await process_frame
	await RenderingServer.frame_post_draw
	var suffix := "-kingdoms" if "--kingdoms" in OS.get_cmdline_user_args() else ("-politics" if political else ("-guide" if "--guide" in OS.get_cmdline_user_args() else ("-villages" if "--villages" in OS.get_cmdline_user_args() else ("-settlement" if "--settlement" in OS.get_cmdline_user_args() else ""))))
	if "--diplomacy" in OS.get_cmdline_user_args(): suffix += "-diplomacy"
	if war: suffix = "-military" if "--military" in OS.get_cmdline_user_args() else "-war"
	if "--lives" in OS.get_cmdline_user_args(): suffix = "-lives" + ("-family" if "--family" in OS.get_cmdline_user_args() else ("-memories" if "--memories" in OS.get_cmdline_user_args() else ""))
	if "--environment" in OS.get_cmdline_user_args(): suffix = "-environment" + ("-land" if "--land" in OS.get_cmdline_user_args() else ("-health" if "--health" in OS.get_cmdline_user_args() else ""))
	if "--biomes" in OS.get_cmdline_user_args(): suffix = "-biomes"
	if "--society" in OS.get_cmdline_user_args(): suffix = "-society" + ("-knowledge" if "--knowledge" in OS.get_cmdline_user_args() else ("-history" if "--chronicle" in OS.get_cmdline_user_args() else ""))
	if "--settings" in OS.get_cmdline_user_args(): suffix = "-settings"
	if "--shelf" in OS.get_cmdline_user_args(): suffix = "-shelf"
	var path := "res://docs/screenshots/" + ("phone" if phone else "first-world") + suffix + ".png"
	var result := root.get_texture().get_image().save_png(path)
	print("Captured ", path, ": ", result)
	game.audio.shutdown()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if result == OK else 1)
