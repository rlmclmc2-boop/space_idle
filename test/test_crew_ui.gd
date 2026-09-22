extends SceneTree
class TrackedUI extends "res://scripts/main.gd":
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
var view: SubViewport
var scene
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(message)
func _initialize() -> void:
	call_deferred("run")
func frames() -> void:
	await process_frame
	await process_frame
func click_at(pos: Vector2) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.position=pos
	motion.global_position=pos
	view.push_input(motion,true)
	await frames()
	for down in [true,false]:
		var input:=InputEventMouseButton.new()
		input.position=pos
		input.global_position=pos
		input.button_index=MOUSE_BUTTON_LEFT
		input.pressed=down
		view.push_input(input,true)
		await frames()
func click(control: Control) -> void:
	await click_at(control.get_global_rect().get_center())
func run() -> void:
	view=SubViewport.new()
	view.size=Vector2i(1440,810)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	view.notify_mouse_entered()
	scene=TrackedUI.new()
	scene.automation_args=["--capture"]
	view.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=range(1,60)
	scene.game.rebuild_unlocks()
	for key in scene.db.data.hightech:scene.game.profile.hightechLevels[key]=1
	scene.refresh_structure()
	await frames()
	var tabs: TabBar=scene.equipment_tabs.get_tab_bar()
	await click_at(tabs.get_global_transform()*tabs.get_tab_rect(5).get_center())
	var panel=scene.crew_panel
	check(scene.equipment_tabs.current_tab==5 and panel.is_visible_in_tree(),"Real crew tab click opens page")
	check(panel.rows.size()==6 and panel.jobs.item_count==4,"Excel creates crew rows and job choices")
	check(panel.size.y>600,"Crew full-height layout")
	var first: Button=panel.rows.navigator
	var other: Button=panel.rows.engineer
	var equipment=scene.equipment_panel.cards.duplicate()
	var builds: int=scene.builds
	await click(first)
	check(panel.selected=="navigator","Real crew row selection")
	panel.jobs.select(panel.job_ids.find("equipment_upgrade"))
	panel.jobs.item_selected.emit(panel.jobs.selected)
	panel.target_picker.select(panel.target_ids.find("equipment"))
	panel.target_picker.item_selected.emit(panel.target_picker.selected)
	await click(panel.assign_button)
	check(scene.game.crew.entry(scene.game,"navigator").targetId=="equipment","Real assignment button commits selected target")
	check(first.text.contains("1.0") and not panel.release_button.disabled,"Current actual interval and release feedback")
	var draft: int=panel.jobs.selected
	var focus: Control=view.gui_get_focus_owner()
	var draws: Dictionary={"other":0,"background":0,"resources":0}
	other.draw.connect(func():draws.other+=1)
	scene.background_layer.draw.connect(func():draws.background+=1)
	scene.resource_layer.draw.connect(func():draws.resources+=1)
	scene.writes.clear()
	scene.game.add_crew_exp("navigator",100)
	await frames()
	check(first.text.contains("Lv.2") and first.text.contains("1.0"),"XP updates level while equipment interval stays one second")
	check(not scene.writes.has(other) and panel.rows.navigator==first and panel.rows.engineer==other,"Unrelated row receives zero writes and instances survive")
	check(panel.jobs.selected==draft and view.gui_get_focus_owner()==focus,"Draft and focus preserved")
	check(scene.builds==builds and scene.equipment_panel.cards==equipment,"No ancestor or equipment rebuild")
	check(draws.other==0 and draws.background==0 and draws.resources==0,"Crew growth causes zero unrelated CanvasItem redraws")
	scene.writes.clear()
	for i in 20:panel.refresh()
	await frames()
	check(scene.writes.is_empty(),"Stable paused page zero property writes")
	check(draws.other==0 and draws.background==0 and draws.resources==0,"Stable paused page zero unrelated redraws")
	check(panel.upgrade_picker.visible and not panel.target_picker.visible,"Equipment system shows amount selector instead of individual targets")
	check(panel.mode_ids==["1","10","max"],"Three amount choices come from Excel")
	await click(panel.upgrade_picker)
	var popup: PopupMenu=panel.upgrade_picker.get_popup()
	check(popup.visible,"Real click opens upgrade amount choices")
	# Mouse-opened popup starts with no focused item; first Down focuses the first row.
	for code in [KEY_DOWN,KEY_DOWN,KEY_ENTER]:
		for down in [true,false]:
			var key:=InputEventKey.new()
			key.keycode=code
			key.pressed=down
			Input.parse_input_event(key)
			await frames()
	check(scene.game.crew.entry(scene.game,"navigator").upgradeMode=="10","Keyboard choice saves ten-level mode")
	check(first.text.contains("10") and panel.rows.engineer==other,"Selected batch updates own effect without recreating other crew")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://.runtime/crew-page.png")
	await click(panel.release_button)
	check(scene.game.crew.entry(scene.game,"navigator").assignmentType=="" and panel.release_button.disabled,"Real release button clears assignment")
	scene.game.assign_crew("navigator","equipment_upgrade","equipment")
	scene.equipment_tabs.current_tab=0
	await frames()
	scene.refresh_visible_cards()
	check(scene.equipment_panel.cards.weapons_0.fields.crew.text.contains("1"),"Equipment compact badge")
	check(scene.equipment_panel.cards.weapons_0.fields.crew.tooltip_text.contains("Lv.2"),"Badge shows crew level and effect")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://.runtime/crew-equipment-badge.png")
	var hidden_text: String=first.text
	scene.writes.clear()
	scene.game.add_crew_exp("navigator",200)
	check(first.text==hidden_text and not scene.writes.has(first),"Hidden crew page does not write")
	scene.equipment_tabs.current_tab=5
	await frames()
	check(first.text.contains("Lv.3") and panel.rows.navigator==first,"Show catches up without recreation")
	check(panel.upgrade_picker.selected==panel.mode_ids.find("10"),"Upgrade choice survives hidden page and growth")
	var tech: String=scene.game.hightech_slots()[0]
	scene.game.assign_crew("navigator","hightech_efficiency",tech)
	scene.equipment_tabs.current_tab=1
	await frames()
	scene.refresh_visible_cards()
	check(scene.hightech_progress[tech].crew.text.contains("1"),"Hightech compact badge")
	scene.game.assign_crew("navigator","production_output",scene.game.FURNACE)
	scene.refresh_visible_cards()
	check(scene.hightech_progress[scene.game.FURNACE].crew.text.contains("1"),"Production badge on existing furnace card")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://.runtime/crew-production-badge.png")
	# Structural config additions touch only the new row and option list.
	scene.equipment_tabs.current_tab=5
	var job: Dictionary=scene.db.data.crew_assignment.production_output.duplicate()
	job.id="extra_output"
	scene.db.data.crew_assignment[job.id]=job
	panel.invalidate()
	check(panel.job_ids.has("extra_output") and panel.rows.navigator==first,"Excel job addition without crew row rebuild")
	for i in 8:
		var id: String="extra_"+str(i)
		var row: Dictionary=scene.db.data.crew.navigator.duplicate()
		row.id=id
		scene.db.data.crew[id]=row
	scene.game.crew.load_state(scene.game,scene.game.profile.crew.duplicate(true))
	panel.invalidate()
	await frames()
	panel.scroll.scroll_vertical=200
	panel.jobs.grab_focus()
	await frames()
	var offset: int=panel.scroll.scroll_vertical
	scene.game.add_crew_exp("engineer",1)
	await frames()
	check(offset>0 and panel.scroll.scroll_vertical==offset and view.gui_get_focus_owner()==panel.jobs,"Growth preserves real scroll offset and picker focus")
	check(panel.rows.size()==14 and panel.rows.navigator==first,"Configured crew additions only add new rows")
	await click(scene.battle_return_button)
	check(scene.equipment_tabs.current_tab==0,"Real return-to-battle button leaves crew page")
	print("CREW UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
