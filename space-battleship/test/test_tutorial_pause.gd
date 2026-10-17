extends SceneTree

const MAIN = preload("res://scripts/main.gd")
const DB = preload("res://scripts/database.gd")
const GAME = preload("res://scripts/game.gd")
const GUIDE = preload("res://scripts/beginner_guide.gd")

func _initialize() -> void:
	var host = MAIN.new()
	host.game = GAME.new(DB.new(),false)
	var initial_resources: Dictionary = host.game.profile.resources.duplicate(true)
	host.game.paused = false
	host.set_intro_pause(true)
	host.set_intro_pause(true)
	var ok: bool = host.game.paused and host.guidance_pause_owned
	host.game.pending_unlocks.append("reactor")
	host.sync_unlock_pause()
	host.set_intro_pause(false)
	ok = ok and host.game.paused and host.unlock_pause_owned
	host.game.pending_unlocks.clear()
	host.sync_unlock_pause()
	ok = ok and not host.game.paused and not host.guidance_pause_owned
	host.game.paused = true
	host.set_intro_pause(true)
	host.set_intro_pause(false)
	ok = ok and host.game.paused
	host.game.paused = false
	host.tutorial_auto_skip = true
	host.game.pending_unlocks.append("reactor")
	host.sync_unlock_pause()
	ok = ok and not host.unlock_pause_owned and not host.game.paused
	host.set_intro_pause(true)
	ok = ok and host.game.paused
	host.set_intro_pause(false)
	ok = ok and not host.game.paused and host.game.profile.resources == initial_resources
	var guide = GUIDE.new()
	guide.host = host
	host.game.state = GAME.State.TRAVEL
	ok = ok and guide.intro_pending()
	host.game.profile.onboarding.intro = true
	ok = ok and not guide.intro_pending()
	host.game.profile.onboarding.intro = false
	host.game.profile.onboarding.dismissed = true
	ok = ok and not guide.intro_pending()
	guide.manually_opened = true
	ok = ok and guide.intro_pending()
	host.game.profile.onboarding.completed = true
	ok = ok and not guide.intro_pending()
	guide.free()
	host.free()
	if not ok:
		printerr("TUTORIAL_PAUSE_FAIL")
		quit(1)
		return
	print("TUTORIAL_PAUSE_OK repeated intro, overlapping unlock, preexisting pause, auto-skip separation, resources stable")
	quit()
