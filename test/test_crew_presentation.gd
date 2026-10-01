extends SceneTree
## Presentation-only checks. Dynamic gameplay/config values remain authoritative.
class TrackedScene extends "res://scripts/main.gd":
	var writes: Array=[]
	var builds:=0
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property)!=value:writes.append(control)
		super.set_ui_value(control,property,value)
	func build_ui() -> void:
		builds+=1
		super.build_ui()
var checks:=0
var failures:=0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize() -> void:call_deferred("run")
func frames() -> void:
	await process_frame
	await process_frame
func run() -> void:
	var view:=SubViewport.new()
	view.size=Vector2i(2048,1280)
	root.add_child(view)
	var scene:=TrackedScene.new()
	scene.automation_args=["--capture"]
	view.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	for gate in scene.db.data.unlock.values():gate.level=0
	var level_gate: Dictionary=scene.db.data.unlock[scene.db.unlock_id("feature","crew_level")]
	level_gate.level=1
	level_gate.mode="cleared"
	scene.game.profile.cleared=[]
	scene.game.profile.grantedUnlocks=[]
	scene.game.rebuild_unlocks()
	scene.refresh_structure()
	scene.equipment_tabs.current_tab=5
	await frames()
	var panel=scene.crew_panel
	panel.select("navigator")
	check(panel.rows.size()==scene.db.data.crew.size(),"All and only unlocked configured crew have rows")
	check(not is_instance_valid(panel.experience) and not panel.title.text.contains("Lv"),"No level/XP controls before level unlock")
	check(panel.status.text==UIText.t("crew.free") and not panel.effect_section.visible and not panel.release_button.visible,"Idle has readable status and no effect/release gap")
	check(panel.portrait.texture==panel.IDLE_ICON,"Generic idle fallback uses accepted crew system badge")
	var enhancement_icon: Texture2D=load(panel.ENHANCEMENT_BADGE) if ResourceLoader.exists(panel.ENHANCEMENT_BADGE) else panel.JOB_ICONS.jewel
	check(panel.job_icon({"crewId":"navigator","assignmentType":"jewel_auto"})==enhancement_icon,"Legacy assignment identity uses coordinated enhancement badge when available")
	var custom_path: String="res://assets/ui/crew_locked.svg"
	scene.db.data.crew.navigator.icon=custom_path
	panel.invalidate()
	check(panel.portrait.texture==load(custom_path) and panel.row_fields.navigator.avatar.texture==load(custom_path),"Valid custom configured portrait wins in row and detail")
	scene.game.assign_crew("navigator","equipment_upgrade","equipment")
	check(panel.portrait.texture==load(custom_path) and panel.assignment_badge.texture==panel.JOB_ICONS.equipment,"Assignment badge never replaces custom portrait")
	scene.db.data.crew.navigator.icon=panel.GENERIC_PORTRAIT
	panel.invalidate()
	check(panel.portrait.texture==panel.JOB_ICONS.equipment,"Generic assigned fallback reflects actual targetType")
	check(panel.status.text==UIText.t("crew.assigned") and panel.effect_section.visible and panel.release_button.visible,"Assigned state remains readable and actionable")
	check(not panel.description.text.is_empty() and panel.effect_title.text==UIText.t("crew.core_title.equipment"),"Actual configured assignment effect remains visible")
	panel.select("engineer")
	check(panel.jobs.is_item_disabled(panel.job_ids.find("equipment_upgrade")),"Occupied target stays disabled for another crew")
	panel.select("navigator")
	check(not panel.jobs.is_item_disabled(panel.job_ids.find("equipment_upgrade")),"Current owner can retain its target")
	scene.game.profile.cleared.append(1)
	scene.game.rebuild_unlocks()
	panel.invalidate()
	await frames()
	check(is_instance_valid(panel.experience) and panel.level_section.visible and panel.title.text.contains("Lv"),"Existing level unlock reveals level/XP")
	var rows: Dictionary=panel.rows.duplicate()
	var builds: int=scene.builds
	panel.scroll.scroll_vertical=240
	panel.jobs.grab_focus()
	await frames()
	var offset: int=panel.scroll.scroll_vertical
	var draft: int=panel.jobs.selected
	var unrelated=panel.row_fields.engineer.name
	scene.writes.clear()
	scene.game.add_crew_exp("navigator",1)
	await frames()
	check(not scene.writes.has(unrelated) and panel.rows==rows and scene.builds==builds,"Growth does not write unrelated row or rebuild")
	check(panel.scroll.scroll_vertical==offset and panel.jobs.has_focus() and panel.jobs.selected==draft,"Growth retains scroll/focus/draft")
	scene.writes.clear()
	for i in 10:panel.refresh()
	await frames()
	check(scene.writes.is_empty(),"Stable paused page performs zero changed-property writes")
	scene.equipment_tabs.current_tab=0
	await frames()
	var old_text: String=panel.exp_label.text
	scene.writes.clear()
	scene.game.add_crew_exp("navigator",1)
	await frames()
	check(not scene.writes.has(panel.exp_label) and panel.exp_label.text==old_text,"Hidden page does not update XP controls")
	scene.equipment_tabs.current_tab=5
	await frames()
	check(panel.exp_label.text!=old_text and panel.rows==rows and panel.scroll.scroll_vertical==offset,"Reveal catches up with selection/rows/scroll intact")
	scene.game.assign_crew("navigator","","")
	check(panel.status.text==UIText.t("crew.free") and not panel.release_button.visible and panel.portrait.texture==panel.IDLE_ICON,"Release restores idle text and fallback badge")
	var full_name:=str(scene.db.data.crew.navigator.name)+"长名称边界测试长名称边界测试"
	scene.db.data.crew.navigator.name=full_name
	panel.invalidate()
	await frames()
	check(panel.row_fields.navigator.name.clip_text and panel.rows.navigator.tooltip_text.contains(full_name),"Long row name is bounded with full tooltip")
	check(panel.title.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART and panel.title.get_global_rect().end.x<=panel.detail_scroll.get_global_rect().end.x,"Detail identity wraps inside its viewport")
	scene.game.profile.cleared=[]
	scene.game.profile.grantedUnlocks=[]
	level_gate.level=1
	scene.game.rebuild_unlocks()
	panel.invalidate()
	check(not panel.level_section.visible and not panel.title.text.contains("Lv"),"Existing XP controls hide again when level feature is locked")
	for gate in scene.db.data.unlock.values():
		if gate.type=="crew":gate.level=10
	scene.game.profile.grantedUnlocks=[]
	scene.game.rebuild_unlocks()
	await frames()
	# The normal shell correctly hides the crew tab before its first unlock.
	# Explicitly expose only this empty-page presentation fixture.
	scene.equipment_tabs.set_tab_hidden(5,false)
	scene.equipment_tabs.current_tab=5
	panel.show()
	panel.invalidate()
	await frames()
	check(panel.rows.is_empty() and panel.empty_label.visible and not panel.detail_body.visible,"Empty roster hides identity/actions and shows readable empty state")
	check(panel.locked_preview.visible and panel.locked_preview.disabled and panel.locked_preview.text.contains("10"),"Next locked crew displays only existing ordinal/threshold")
	print("CREW PRESENTATION: %d checks, %d failures" % [checks,failures])
	view.queue_free()
	await frames()
	quit(1 if failures else 0)
