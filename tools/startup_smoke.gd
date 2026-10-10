extends SceneTree
## Start the configured game, then use its actual save-and-close lifecycle.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	game.autosave_path = "user://startup-smoke.json"
	root.add_child(game)
	for frame in 120: await process_frame
	game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	if not SaveStore.load_world(game.autosave_path).has("world"):
		printerr("FAIL: startup window-close did not preserve a valid world")
		quit(1)
		return
	print("STARTUP SMOKE: configured scene ran 120 frames and saved on window close")
