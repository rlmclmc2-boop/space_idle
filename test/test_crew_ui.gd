extends SceneTree
class TrackedUI extends "res://scripts/main.gd":
	var writes: Array=[]
	var builds:=0
	var refreshed_slots: Array=[]
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property)!=value:writes.append(control)
		super.set_ui_value(control,property,value)
	func build_ui() -> void:
		builds+=1
		super.build_ui()
	func refresh_equipment_cards(only_slot := "") -> void:
		refreshed_slots.append(only_slot)
		super.refresh_equipment_cards(only_slot)
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
	view.size=Vector2i(2048,1280)
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
	await click(scene.system_nav_buttons[5])
	var panel=scene.crew_panel
	check(scene.equipment_tabs.current_tab==5 and panel.is_visible_in_tree(),"Real crew tab click opens page")
	check(not scene.equipment_tabs.get_tab_title(0).contains("👤") and not scene.equipment_tabs.get_tab_title(1).contains("👤"),"Idle systems have no crew tab markers")
	check(panel.rows.size()==6 and panel.jobs.item_count==4 and not panel.job_ids.has("production_output") and not panel.job_ids.has("hightech_efficiency"),"Excel creates crew rows without removed efficiency job")
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
	check(scene.equipment_tabs.get_tab_title(0).ends_with("👤") and not scene.equipment_tabs.get_tab_title(1).contains("👤"),"Equipment assignment marks only equipment tab without count")
	check(tabs.get_tab_tooltip(0).contains("船员01") and tabs.get_tab_tooltip(0).contains("Lv0"),"Equipment tab tooltip keeps crew identity and effect")
	check(panel.description.text.contains("1.0") and not panel.release_button.disabled,"Current actual interval and release feedback")
	panel.select("engineer")
	var occupied_index: int=panel.job_ids.find("equipment_upgrade")
	check(panel.jobs.is_item_disabled(occupied_index) and panel.jobs.selected!=occupied_index,"Other crew cannot select occupied equipment in dropdown")
	panel.select("navigator")
	check(not panel.jobs.is_item_disabled(occupied_index),"Current owner can keep its own system")
	await frames()

	var draft: int=panel.jobs.selected
	var focus: Control=view.gui_get_focus_owner()
	var draws: Dictionary={"other":0,"background":0,"resources":0}
	other.draw.connect(func():draws.other+=1)
	scene.background_layer.draw.connect(func():draws.background+=1)
	scene.resource_layer.draw.connect(func():draws.resources+=1)
	scene.writes.clear()
	scene.game.add_crew_exp("navigator",100)
	await frames()
	check(panel.row_fields.navigator.name.text.contains("Lv1") and panel.description.text.contains("1.0"),"XP updates level while equipment interval stays one second")
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
	check(panel.description.text.contains("+10") and panel.rows.engineer==other,"Selected batch updates own effect without recreating other crew")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://.runtime/crew-page.png")
	await click(panel.release_button)
	check(scene.game.crew.entry(scene.game,"navigator").assignmentType=="" and not panel.release_button.visible,"Real release button clears assignment")
	check(not scene.equipment_tabs.get_tab_title(0).contains("👤") and tabs.get_tab_tooltip(0).is_empty(),"Release clears equipment tab marker and tooltip")
	scene.game.assign_crew("navigator","equipment_upgrade","equipment")
	scene.equipment_tabs.current_tab=0
	await frames()
	scene.refresh_visible_cards()
	check(scene.equipment_tabs.get_tab_title(0).ends_with("👤") and tabs.get_tab_tooltip(0).contains("Lv1"),"Equipment tab badge shows crew level and effect without count")
	check(scene.equipment_panel.cards.values().all(func(card):return not card.fields.has("crew")),"Equipment module cards have no crew marker")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://.runtime/crew-equipment-tab-badge.png")
	var hidden_text: String=panel.row_fields.navigator.name.text
	scene.writes.clear()
	scene.game.add_crew_exp("navigator",200)
	check(panel.row_fields.navigator.name.text==hidden_text and not scene.writes.has(first),"Hidden crew page does not write")
	scene.equipment_tabs.current_tab=5
	await frames()
	check(panel.row_fields.navigator.name.text.contains("Lv2") and panel.rows.navigator==first,"Show catches up without recreation")
	check(panel.upgrade_picker.selected==panel.mode_ids.find("10"),"Upgrade choice survives hidden page and growth")
	var tech: String=scene.game.hightech_slots()[0]
	panel.jobs.select(panel.job_ids.find("hightech_scientists"))
	panel.jobs.item_selected.emit(panel.jobs.selected)
	check(panel.jobs.get_item_text(panel.jobs.selected)=="高科技","Automatic scientist job is titled hightech")
	check(panel.target_ids==["hightech"] and panel.upgrade_picker.visible and not panel.target_picker.visible,"Scientist job uses system target and amount picker")
	check(panel.mode_ids==["1","10","max"] and panel.upgrade_picker.get_item_text(0).contains("AI"),"Scientist quantities and labels come from configuration/text")
	panel.upgrade_picker.select(2)
	panel.upgrade_picker.item_selected.emit(2)
	await click(panel.assign_button)
	check(scene.game.crew.entry(scene.game,"navigator").assignmentType=="hightech_scientists" and scene.game.crew.entry(scene.game,"navigator").upgradeMode=="max","Real scientist assignment keeps MAX choice")
	check(panel.description.text.contains("平均分配") and panel.rows.engineer==other,"Scientist effect updates only assigned crew row")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://.runtime/crew-scientist-mode.png")
	scene.equipment_tabs.current_tab=1
	await frames()
	scene.refresh_visible_cards()
	check(scene.equipment_tabs.get_tab_title(1).ends_with("👤") and not scene.equipment_tabs.get_tab_title(0).contains("👤"),"Scientist assignment marks only hightech tab")
	check(tabs.get_tab_tooltip(1).contains("平均分配") and not scene.hightech_progress[tech].has("crew"),"Hightech tab tooltip retains effect and inner cards have no marker")
	scene.equipment_tabs.current_tab=5
	panel.jobs.select(panel.job_ids.find("jewel_auto"))
	panel.jobs.item_selected.emit(panel.jobs.selected)
	check(panel.target_ids==["jewels"] and not panel.target_picker.visible and not panel.upgrade_picker.visible,"Jewel system keeps configured target without redundant picker")
	await click(panel.assign_button)
	scene.equipment_tabs.current_tab=4
	await frames()
	check(scene.equipment_tabs.get_tab_title(4).ends_with("👤") and not scene.equipment_tabs.get_tab_title(1).contains("👤"),"Jewel assignment marks only jewel tab")
	check(tabs.get_tab_tooltip(4).contains("船员01") and tabs.get_tab_tooltip(4).contains("合成"),"Jewel tab tooltip identifies crew and effect")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://.runtime/crew-jewel-tab-badge.png")
	scene.game.module_entry("weapons",0).level=40
	scene.game.module_entry("defence",0).level=40
	scene.game.module_entry("weapons",0).sockets=[scene.game.new_jewel("5")]
	scene.game.module_entry("defence",0).sockets=[scene.game.new_jewel("2")]
	scene.game.profile.jewels=[scene.game.new_jewel("5",2),scene.game.new_jewel("2",2)]
	scene.refreshed_slots.clear()
	scene.game.auto_manage_jewels()
	check(scene.refreshed_slots==["weapons_0","defence_0"],"Automatic replacements refresh only changed equipment cards once each")
	scene.game.assign_crew("navigator","","")
	check(not scene.equipment_tabs.get_tab_title(4).contains("👤"),"Releasing jewel crew clears tab badge")
	scene.equipment_tabs.current_tab=5
	panel.select("navigator")
	await frames()
	check(not panel.release_button.visible and not panel.effect_section.visible,"Idle detail collapses effect and release controls")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://.runtime/crew-idle.png")
	check(panel.find_children("*","Button",true,false).all(func(b):return b in panel.rows.values() or b in [panel.jobs,panel.target_picker,panel.upgrade_picker,panel.assign_button,panel.release_button,panel.locked_preview]),"Only requested assignment controls and crew rows exist")
	scene.game.profile.cleared=range(1,36)
	scene.game.profile.grantedUnlocks=[]
	scene.game.rebuild_unlocks()
	panel.invalidate()
	await frames()
	check(panel.rows.size()==5 and panel.locked_preview.visible and panel.locked_preview.text.contains("40"),"Next locked crew remains compact")
	scene.game.assign_crew("navigator","equipment_upgrade","equipment")
	panel.select("navigator")
	for dimensions in [Vector2i(2048,1280),Vector2i(1920,1080),Vector2i(1280,720)]:
		view.size=dimensions
		var scale_factor:=minf(float(dimensions.x)/2048.0,float(dimensions.y)/1280.0)
		scene.scale=Vector2.ONE*scale_factor
		await frames()
		check(panel.title.get_global_rect().end.x<=panel.detail_scroll.get_global_rect().end.x,"Identity stays within detail at "+str(dimensions))
		check(panel.jobs.get_global_rect().end.x<=panel.upgrade_picker.get_global_rect().position.x,"Assignment fields do not overlap at "+str(dimensions))
		check(panel.assign_button.get_global_rect().end.y<=panel.detail_scroll.get_global_rect().end.y,"Actions stay within detail at "+str(dimensions))
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png("res://.runtime/crew-layout-%d.png" % dimensions.x)
	view.size=Vector2i(2048,1280)
	scene.scale=Vector2.ONE
	scene.game.profile.cleared=range(1,60)
	scene.game.rebuild_unlocks()
	panel.invalidate()
	panel.select("navigator")
	panel.jobs.select(panel.job_ids.find("reactor_upgrade"))
	panel.jobs.item_selected.emit(panel.jobs.selected)
	check(panel.target_ids==["reactor"] and not panel.parameter_column.visible,"Reactor uses one fixed system without unnecessary parameter controls")
	await click(panel.assign_button)
	check(scene.game.crew.entry(scene.game,"navigator").assignmentType=="reactor_upgrade","UI assigns reactor automation")
	check(panel.effect_title.text==UIText.t("crew.core_title.reactor") and panel.description.text.contains("反应炉页面设置") and not panel.description.text.contains("平均分配"),"Reactor detail has the two-line core effect")
	check(scene.equipment_tabs.get_tab_title(2).ends_with("👤"),"Only reactor receives its crew badge")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://.runtime/crew-reactor.png")
	await click(panel.release_button)
	check(not scene.equipment_tabs.get_tab_title(2).contains("👤"),"Reactor release clears its badge")
	for entry in [["navigator","equipment_upgrade","equipment"],["engineer","hightech_scientists","hightech"],["researcher","jewel_auto","jewels"],["crew_04","reactor_upgrade","reactor"]]:
		scene.game.assign_crew(entry[0],entry[1],entry[2])
	panel.select("crew_05")
	await frames()
	check(panel.jobs.selected==-1 and panel.assign_button.disabled and not panel.parameter_column.visible,"All occupied systems leave no selectable assignment")
	check(range(panel.jobs.item_count).all(func(i):return panel.jobs.is_item_disabled(i)),"Every occupied dropdown item is disabled")
	scene.game.assign_crew("engineer","","")
	check(not panel.jobs.is_item_disabled(panel.job_ids.find("hightech_scientists")) and panel.job_ids[panel.jobs.selected]=="hightech_scientists","Release immediately restores available option")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://.runtime/crew-occupied-options.png")
	var legacy:=BattleGame.new(scene.db,false)
	legacy.crew.load_state(legacy,[{"crewId":"navigator","level":2,"exp":7,"assignmentType":"production_output","targetId":scene.game.FURNACE}])
	check(legacy.crew.entry(legacy,"navigator").assignmentType=="" and legacy.crew.entry(legacy,"navigator").level==2 and legacy.crew.entry(legacy,"navigator").exp==7,"Removed production job restores idle with growth preserved")
	for entry in scene.game.profile.crew:scene.game.assign_crew(entry.crewId,"","")
	panel.select("navigator")
	scene.game.add_crew_exp("navigator",64)
	await frames()
	check(scene.game.crew.entry(scene.game,"navigator").level==3 and panel.exp_label.text.contains("173") and not panel.exp_label.text.contains("."),"Detail uses integer config threshold beyond former level cap")
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://.runtime/crew-level-four.png")
	# Structural config additions touch only the new row and option list.
	scene.equipment_tabs.current_tab=5
	var job: Dictionary=scene.db.data.crew_assignment.reactor_upgrade.duplicate()
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
	await click(scene.system_nav_buttons[0])
	check(scene.equipment_tabs.current_tab==0 and scene.battle_clip.position==scene.BATTLE_ORIGIN,"System navigation leaves crew page while battle stays fixed")
	scene.game.profile=scene.game.fresh_profile()
	scene.build_ui()
	check(scene.equipment_tabs.is_tab_hidden(5),"Legacy profile reset without crew data hides crew tab safely")
	print("CREW UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
