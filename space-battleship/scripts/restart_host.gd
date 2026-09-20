extends SceneTree
## Separate process waits for the old game to exit before importing and starting.
var old_pid := -1
var elapsed := 0.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_valid_int():
		quit(1)
		return
	old_pid = int(args[0])

func _process(delta: float) -> bool:
	elapsed += delta
	if old_pid < 0: return false
	if OS.is_process_running(old_pid):
		if elapsed > 60:
			printerr(UIText.t("debug._process.text_17"))
			quit(1)
		return false
	old_pid = -1
	var project := ProjectSettings.globalize_path("res://")
	var output: Array = []
	var result := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--editor", "--import", "--quit", "--path", project, "--log-file", project.path_join(".runtime/full-restart-import.log")]), output, true, false)
	if result != 0:
		printerr(UIText.t("debug._process.text_18"), "".join(output))
		quit(1)
		return false
	var pid := OS.create_process(OS.get_executable_path(), PackedStringArray(["--path", project]))
	if pid == -1: printerr(UIText.t("debug._process.text_19"))
	quit(1 if pid == -1 else 0)
	return false
