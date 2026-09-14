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
			printerr("大重启失败：旧游戏进程未退出。")
			quit(1)
		return false
	old_pid = -1
	var project := ProjectSettings.globalize_path("res://")
	var output: Array = []
	var result := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--editor", "--import", "--quit", "--path", project, "--log-file", project.path_join(".runtime/full-restart-import.log")]), output, true, false)
	if result != 0:
		printerr("大重启资源导入失败，请检查 .runtime/full-restart-import.log\n", "".join(output))
		quit(1)
		return false
	var pid := OS.create_process(OS.get_executable_path(), PackedStringArray(["--path", project]))
	if pid == -1: printerr("大重启失败：无法启动游戏进程。")
	quit(1 if pid == -1 else 0)
	return false
