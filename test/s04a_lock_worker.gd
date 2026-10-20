extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var lock = ClassDB.instantiate("SpaceSaveLock")
	var acquired: bool = lock != null and lock.acquire(args[0] + ".writer-lock")
	print("S04A_ACQUIRE:", acquired)
	if acquired and args.size() > 1 and args[1] == "hold":
		await create_timer(60.0).timeout
	quit(0)
