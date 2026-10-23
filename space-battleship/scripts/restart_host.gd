extends SceneTree
## Separate process waits for the old game to exit before importing and starting.
var old_pid := -1
var elapsed := 0.0
var child_pid := -1
var restart_id := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not args[0].is_valid_int() or args[1].length()!=32 or not args[1].is_valid_hex_number(false):
		quit(1)
		return
	old_pid = int(args[0])
	restart_id=args[1]

func _process(delta: float) -> bool:
	elapsed += delta
	if child_pid>0:
		var path:="user://restart-"+restart_id+".json"
		if FileAccess.file_exists(path):
			var acknowledgement=JSON.parse_string(FileAccess.get_file_as_string(path))
			if acknowledgement is Dictionary and acknowledgement.get("id")==restart_id and int(acknowledgement.get("pid",-1))==child_pid and acknowledgement.get("state")=="ready" and acknowledgement.get("owns_progress")==true:
				print("RESTART_READY ",child_pid);quit(0);return false
		if elapsed>60 or not OS.is_process_running(child_pid):
			printerr("RESTART_RECOVERY_REQUIRED: child did not confirm installed ownership")
			quit(1)
		return false
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
	var pid := OS.create_process(OS.get_executable_path(), PackedStringArray(["--path", project,"--","--restart-id",restart_id]))
	if pid == -1: printerr(UIText.t("debug._process.text_19"))
	if pid == -1:quit(1)
	else:child_pid=pid;elapsed=0.0
	return false
