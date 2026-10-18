extends SceneTree

const TECH = preload("res://scripts/ai_tech_tree.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if change_scene_to_file("res://main.tscn") != OK:
		printerr("AI_TECH_CONTINUOUS_UI_FAIL scene")
		quit(1)
		return
	await scene_changed
	var host = current_scene
	var game = host.game
	game.profile.onboarding.intro = true
	host.set_intro_pause(false)
	game.profile.cleared = [1,2,3,4]
	game.rebuild_unlocks()
	host.build_ui()
	if not game.ai_tech_factory_unlocked() or not game.select_tech("resource_refining"):
		printerr("AI_TECH_CONTINUOUS_UI_FAIL factory gate")
		quit(1)
		return
	var dot = host.system_nav_buttons[1].get_node("ActivationBadge")
	TECH.advance(game,TECH.required(game,"resource_refining"))
	var first: bool = game.hightech_level("resource_refining") == 1 and game.profile.aiTechActive == "resource_refining"
	first = first and game.profile.aiTechCompletionUnread and dot.visible
	host.select_system(1)
	var opened: bool = host.hightech_page.is_visible_in_tree() and not game.profile.aiTechCompletionUnread and not dot.visible
	host.select_system(0)
	TECH.advance(game,TECH.required(game,"resource_refining"))
	var second: bool = game.hightech_level("resource_refining") == 2 and game.profile.aiTechActive == "resource_refining"
	second = second and game.profile.aiTechCompletionUnread and dot.visible
	host.select_system(1)
	var reopened: bool = not game.profile.aiTechCompletionUnread and not dot.visible
	TECH.advance(game,TECH.required(game,"resource_refining"))
	var watched: bool = game.hightech_level("resource_refining") == 3 and game.profile.aiTechActive == "resource_refining"
	watched = watched and not game.profile.aiTechCompletionUnread and not dot.visible
	if not (first and opened and second and reopened and watched):
		printerr("AI_TECH_CONTINUOUS_UI_FAIL first=",first," opened=",opened," second=",second," reopened=",reopened," watched=",watched," level=",game.hightech_level("resource_refining")," active=",game.profile.aiTechActive," unread=",game.profile.aiTechCompletionUnread," dot=",dot.visible)
		quit(1)
		return
	print("AI_TECH_CONTINUOUS_UI_OK first=unread open=cleared second=unread reopen=cleared third=read_while_watching level=3 active=resource_refining")
	quit()
