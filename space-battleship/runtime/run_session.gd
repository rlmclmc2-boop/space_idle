extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var options := {}
	var args := OS.get_cmdline_user_args()
	for i in range(0, args.size() - 1, 2): options[args[i]] = args[i + 1]
	for required in ["--fixture", "--compiler", "--python", "--output"]:
		if not options.has(required):
			printerr("missing ", required)
			quit(2)
			return
	var output := []
	if OS.execute(options["--python"], [options["--compiler"], "--manifest", options["--fixture"], "--output", options["--output"]], output, true) != 0:
		printerr(output)
		quit(2)
		return
	var status := GDExtensionManager.load_extension("res://space_native.gdextension")
	if status != GDExtensionManager.LOAD_STATUS_OK and status != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		quit(2)
		return
	var bundle_script = load("res://runtime/config_bundle.gd")
	var opened: Dictionary = bundle_script.open_active(options["--output"])
	if not opened.ok:
		printerr(opened)
		quit(2)
		return
	var session_script = load("res://runtime/game_session.gd")
	if session_script == null or not session_script.can_instantiate():
		quit(2)
		return
	var created: Dictionary = session_script.create(opened.bundle)
	if not created.ok:
		printerr(created)
		quit(2)
		return
	var session = created.session
	session.settings.skip_guides = options.get("--skip-guides", "false") == "true"
	var departed: Dictionary = session.depart()
	var duration: float = str(options.get("--duration", "20")).to_float()
	for i in range(ceili(duration * 60)):
		session.frame(1.0 / 60.0)
		if not session.stopped_error.is_empty(): break
	var report := {"ok": departed.ok and session.stopped_error.is_empty(), "entry": "GameSession", "state": session.view()}
	var file := FileAccess.open(options["--output"].path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	print(JSON.stringify(report))
	quit(0 if report.ok else 1)
