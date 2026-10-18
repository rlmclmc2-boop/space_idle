extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if change_scene_to_file("res://main.tscn") != OK:
		printerr("INTRO_PAUSE_FAIL scene")
		quit(1)
		return
	await scene_changed
	var host = current_scene
	var game = host.game
	var initial_distance: float = game.distance
	var initial_group: int = game.group_index
	await create_timer(4.0).timeout
	var held: bool = game.paused and not game.profile.onboarding.intro and game.stage == 1
	held = held and game.distance == initial_distance and game.group_index == initial_group and game.drops.is_empty()
	if not held:
		printerr("INTRO_PAUSE_FAIL held stage=",game.stage," distance=",game.distance," group=",game.group_index," paused=",game.paused," intro=",game.profile.onboarding.intro)
		quit(1)
		return
	host.beginner_guide.action.pressed.emit()
	await create_timer(4.0).timeout
	var released: bool = game.profile.onboarding.intro and not game.paused and game.distance > initial_distance
	if not released:
		printerr("INTRO_PAUSE_FAIL released stage=",game.stage," distance=",game.distance," paused=",game.paused," intro=",game.profile.onboarding.intro)
		quit(1)
		return
	print("INTRO_PAUSE_OK held=4s stage=1 group=",initial_group," distance=",initial_distance," released_distance=",game.distance)
	quit()
