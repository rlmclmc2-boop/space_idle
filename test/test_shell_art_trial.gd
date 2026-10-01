extends SceneTree
## Bounded shell checks; capture mode prevents persistence in this fixture.
class TrialScene extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist: bool) -> BattleGame:
		return super.create_battle_game(false)

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene := TrialScene.new()
	scene.automation_args=[]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=true
	await process_frame
	var tabs: TabContainer=scene.equipment_tabs
	var nav_identity: Array=scene.system_nav_buttons.duplicate()
	var frame_rect: Rect2=scene.workspace_frame.get_global_rect()
	var content_position: Vector2=tabs.position
	var content_scale: Vector2=tabs.scale
	for index in scene.system_nav_buttons.size():
		var nav: Button=scene.system_nav_buttons[index]
		check(nav.visible==not tabs.is_tab_hidden(index),"Starting nav visibility follows existing tab rules: %d" % index)
		if not nav.visible:
			scene.select_system(index)
			check(tabs.current_tab!=index,"Hidden system cannot be selected: %d" % index)
	scene.game.profile.cleared=range(1,201)
	scene.game.profile.highestLevel=201
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	scene.refresh_structure()
	await process_frame
	for index in scene.system_nav_buttons.size():
		var nav: Button=scene.system_nav_buttons[index]
		check(nav.visible==not tabs.is_tab_hidden(index),"Late nav visibility follows tab rules: %d" % index)
		if not nav.visible:continue
		nav.pressed.emit()
		check(tabs.current_tab==index and bool(nav.get_meta("selected")),"Original callback selects system: %d" % index)
		check(nav.text==UIText.t(scene.SYSTEM_TITLES[index]),"Full localized system caption retained: %d" % index)
		check(Rect2(Vector2.ZERO,nav.size).encloses(nav.get_node("SystemIcon").get_rect()),"Icon fits navigation bounds: %d" % index)
		check(nav.get_node("SystemIcon").mouse_filter==Control.MOUSE_FILTER_IGNORE,"Icon does not intercept navigation: %d" % index)
		check(nav.get_theme_font("font").get_string_size(nav.text,HORIZONTAL_ALIGNMENT_LEFT,-1,nav.get_theme_font_size("font_size")).x<=nav.size.x-14,"Caption fits button: %d" % index)
		var page=tabs.get_child(index)
		nav.pressed.emit()
		check(tabs.get_child(index)==page,"Repeated selection retains page: %d" % index)
	check(scene.system_nav_buttons==nav_identity and tabs.position==content_position and tabs.scale==content_scale and scene.workspace_frame.get_global_rect()==frame_rect,"Navigation retains identities and layout area")
	scene.help_button.pressed.emit()
	check(scene.help_open and scene.help_close_button.visible,"Header help opens existing close path")
	scene.help_close_button.pressed.emit()
	check(not scene.help_open and scene.system_nav.visible,"Close returns to existing shell")
	root.size=Vector2i(960,617)
	await process_frame
	check(scene.workspace_frame.get_global_rect()==frame_rect and scene.system_nav.visible,"Narrow width retains logical shell bounds")
	scene.queue_free()
	await process_frame
	print("Shell art trial: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
