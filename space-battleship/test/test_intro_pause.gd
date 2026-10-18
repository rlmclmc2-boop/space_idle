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
	host.beginner_guide.dismiss()
	if game.profile.onboarding.dismissed or not game.paused:
		printerr("INTRO_PAUSE_FAIL opening dismissal bypass")
		quit(1)
		return
	await create_timer(4.0).timeout
	var held: bool = game.paused and not game.profile.onboarding.intro and game.stage == 1
	held = held and game.distance == initial_distance and game.group_index == initial_group and game.drops.is_empty()
	held = held and host.beginner_guide.phase == "intro" and not host.beginner_guide.dismiss_button.visible
	if not held:
		printerr("INTRO_PAUSE_FAIL held stage=",game.stage," distance=",game.distance," group=",game.group_index," paused=",game.paused," intro=",game.profile.onboarding.intro)
		quit(1)
		return
	for expected_phase in ["equip","defence","upgrade","progress"]:
		host.beginner_guide.action.pressed.emit()
		await process_frame
		if not game.paused or game.profile.onboarding.intro or host.beginner_guide.phase != expected_phase or host.beginner_guide.dismiss_button.visible:
			printerr("INTRO_PAUSE_FAIL opening phase=",expected_phase," actual=",host.beginner_guide.phase," paused=",game.paused)
			quit(1)
			return
	await create_timer(2.0).timeout
	if game.distance != initial_distance or game.group_index != initial_group or not game.drops.is_empty():
		printerr("INTRO_PAUSE_FAIL opening moved before final confirmation")
		quit(1)
		return
	if host.beginner_guide.action.text != UIText.t("onboarding.finish"):
		printerr("INTRO_PAUSE_FAIL final button")
		quit(1)
		return
	host.beginner_guide.action.pressed.emit()
	var guide = host.beginner_guide
	if not game.profile.onboarding.intro or game.profile.onboarding.upgraded or guide.panel.visible or guide.decide().phase != "waiting":
		printerr("INTRO_PAUSE_FAIL opening immediately repeated passive hint")
		quit(1)
		return
	game.profile.resources = {"1":1e12,"2":1e12}
	guide.refresh()
	if guide.decide().phase != "upgrade" or not guide.panel.visible or game.profile.onboarding.upgraded:
		printerr("INTRO_PAUSE_FAIL affordable upgrade hint missing")
		quit(1)
		return
	game.profile.resources = {"1":0.0,"2":0.0}
	guide.refresh()
	if guide.panel.visible:
		printerr("INTRO_PAUSE_FAIL passive hint reopened")
		quit(1)
		return
	guide.open_guide()
	if not guide.panel.visible or guide.phase != "waiting" or game.profile.onboarding.upgraded:
		printerr("INTRO_PAUSE_FAIL manual review unavailable")
		quit(1)
		return
	guide.dismiss()
	await create_timer(4.0).timeout
	var released: bool = game.profile.onboarding.intro and not game.paused and game.distance > initial_distance
	if not released:
		printerr("INTRO_PAUSE_FAIL released stage=",game.stage," distance=",game.distance," paused=",game.paused," intro=",game.profile.onboarding.intro)
		quit(1)
		return
	print("INTRO_PAUSE_OK five_confirmations held=6s passive_hidden=1 affordable_hint=1 manual_review=1 upgraded=",game.profile.onboarding.upgraded," released_distance=",game.distance)
	quit()
