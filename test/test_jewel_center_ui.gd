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
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func click(control: Control) -> void:
	if not is_instance_valid(control):check(false,"Click target exists");return
	var mouse:=InputEventMouseMotion.new()
	mouse.position=control.get_global_rect().get_center()*Vector2(root.size)/Vector2(2048,1280)
	if control.get_window()!=root and root.gui_embed_subwindows:mouse.position+=Vector2(control.get_window().position)
	Input.parse_input_event(mouse)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=mouse.position
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame

func settle() -> void:
	await create_timer(0.4).timeout
	await process_frame

func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/"+name+".png")

func run() -> void:
	root.gui_embed_subwindows=true
	var scene:=TrackedUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	scene.game.profile.highestLevel=50
	scene.game.profile.jewelFragments=0.0
	scene.game.profile.jewels.clear()
	scene.refresh_tab_visibility()
	var panel=scene.jewel_panel
	var builds:=scene.builds
	var defence: Label=scene.equipment_panel.cards.defence_0.fields.title
	check(not panel.visible and not panel.is_processing(),"Center starts hidden without frame polling")
	for state in [BattleGame.State.TRAVEL,BattleGame.State.COMBAT,BattleGame.State.LEVEL_CLEAR]:
		scene.game.state=state
		scene.on_event("state",{})
		check(not panel.visible,"Battle navigation does not open center")
	var entry:=scene.game.module_entry("weapons",0)
	entry.level=20
	entry.sockets=[]
	var first:=scene.game.new_jewel("7")
	var second:=scene.game.new_jewel("7")
	var third:=scene.game.new_jewel("7")
	var incompatible:=scene.game.new_jewel("2")
	scene.game.profile.jewels=[first,second,third,incompatible]
	await settle()
	await click(scene.system_nav_buttons[4])
	await settle()
	check(panel.visible and panel.socket_row.visible,"Real entry opens module-oriented center")
	check(scene.equipment_tabs.get_child(4).get_child_count()==0,"Jewel tab has no intermediate launcher or instructions")
	check(scene.system_nav.get_global_rect().end.x<=panel.get_global_rect().position.x,"Navigation remains clickable beside the jewel center")
	await capture("jewel-direct-tab")
	check(panel.position.y>=150 and panel.get_global_rect().end.y<=1200 and panel.size.y==1180,"Workshop fills the shared workspace")
	check(panel.workshop_art.get_global_rect().end.y<=1200 and panel.fragments.get_global_rect().end.y<=1200,"Artwork and footer stay inside workshop")
	check(panel.get_global_rect().position.y>scene.sound_button.get_global_rect().end.y,"Workshop does not overlap global sound control")
	check(scene.equipment_tabs.position==scene.WORK_CONTENT_RECT.position and scene.workspace_title.get_global_rect().end.y<=panel.get_global_rect().position.y,"Workspace stays below the global header")
	check(panel.module_buttons.size()==scene.game.module_entries("weapons").size()+scene.game.module_entries("defence").size(),"Every existing module has an in-panel destination")
	check(panel.socket_buttons.size()==3 and not panel.socket_buttons[0].disabled and panel.socket_buttons[2].disabled,"Empty sockets clickable; future slot shows locked level")
	check(panel.socket_buttons[2].text.contains("40"),"Locked socket exposes exact level requirement")
	check(not panel.gem_buttons[incompatible.token].visible and panel.cells.size()==3,"Default candidates exclude incompatible gems")
	check(panel.combine_all.visible and not panel.has_method("set_mode") and not panel.has_method("request_compose"),"Single page exposes bulk synthesis without management or decomposition")
	var before:=scene.game.profile.duplicate(true)
	await click(panel.socket_buttons[1])
	await click(panel.gem_buttons[first.token])
	check(scene.game.profile==before and panel.target_socket==1,"Socket and gem clicks only select; no gameplay mutation")
	check(panel.preview.text.contains("暴击率") and not panel.socket_action.disabled,"Explicit preview uses real critical calculation")
	var hover:=InputEventMouseMotion.new()
	hover.position=panel.socket_buttons[0].get_global_rect().get_center()*Vector2(root.size)/Vector2(2048,1280)
	Input.parse_input_event(hover)
	await process_frame
	check(panel.target_socket==1,"Hover never changes target")
	scene.writes.clear()
	await click(panel.socket_action)
	check(entry.sockets[1].token==first.token and scene.game.jewel_inventory(first.token).is_empty(),"Explicit action transfers selected gem to selected socket")
	check(not scene.writes.has(defence) and scene.builds==builds,"Socket action preserves unrelated equipment and root UI")
	check(not panel.remove_action.disabled and not panel.upgrade_action.disabled,"Installed gem exposes removal and material-backed upgrade")
	check(panel.gem_buttons[second.token].visible,"Same type can replace its own socket")
	await click(panel.upgrade_action)
	check(entry.sockets[1].level==2 and scene.game.profile.jewels.size()==1,"Real installed upgrade consumes exactly two matching materials")
	check(panel.selected.is_empty() and panel.detail.text.contains("已镶嵌"),"Upgrade preserves inspected socket and installed details")
	await click(panel.remove_action)
	check(entry.sockets[1].is_empty() and scene.game.profile.jewels.size()==2,"Explicit removal returns upgraded gem")
	var upgraded: Dictionary=scene.game.profile.jewels.back()
	await click(panel.gem_buttons[upgraded.token])
	await click(panel.socket_action)
	var duplicate:=scene.game.new_jewel("7",3)
	scene.game.profile.jewels.append(duplicate)
	panel.inventory_changed()
	await click(panel.socket_buttons[0])
	check(not panel.gem_buttons[duplicate.token].visible,"Same-type conflict is filtered for other socket")
	await click(panel.usable_only)
	check(panel.gem_buttons[duplicate.token].visible,"Show all exposes rejected candidate for explanation")
	await click(panel.gem_buttons[duplicate.token])
	check(panel.socket_action.disabled and panel.preview.text.contains("同ID"),"Duplicate type explains reason without modifying module")
	await click(panel.socket_buttons[1])
	await click(panel.gem_buttons[duplicate.token])
	var socket_button=panel.socket_buttons[1]
	await click(panel.socket_action)
	check(entry.sockets[1].token==duplicate.token and not scene.game.jewel_inventory(upgraded.token).is_empty(),"Same-type replacement returns old gem")
	check(panel.socket_buttons[1]==socket_button,"Replacement retains socket control")
	await click(panel.module_buttons.defence_0)
	check(panel.category=="defence" and panel.equipment_index==0 and panel.selected.is_empty(),"Switch module without closing; candidate cleared")
	await click(panel.module_buttons.weapons_0)
	await click(panel.socket_buttons[1])
	await click(panel.gem_buttons[upgraded.token])
	check(panel.action_reason.text.contains("降低") and panel.preview.get_theme_color("font_color")==scene.ORANGE,"Lower stats use explicit warning and orange preview")
	await capture("jewel-center-sockets")
	scene.game.profile.jewels=[scene.game.new_jewel("7"),scene.game.new_jewel("7"),scene.game.new_jewel("7")]
	panel.inventory_changed()
	await settle()
	var sockets_before: Array=entry.sockets.duplicate(true)
	await click(panel.combine_all)
	check(scene.game.profile.jewels.size()==1 and scene.game.profile.jewels[0].level==2,"Bulk synthesis works directly from socket page without selecting materials")
	check(entry.sockets==sockets_before and panel.socket_row.visible,"Bulk synthesis preserves installed gems and socket context")
	check(not panel.bulk_summary.is_empty() and panel.preview.text.contains("Lv.2"),"Bulk result is visible on the same page")
	for i in 18:scene.game.profile.jewels.append(scene.game.new_jewel("1"))
	var protected:=scene.game.new_jewel("2")
	protected.locked=true
	scene.game.profile.jewels.append(protected)
	panel.inventory_changed()
	var survivor=panel.gem_buttons[protected.token]
	var notices: Array=[]
	var event_callback:=func(kind,info):
		if kind=="jewels_changed":notices.append(info)
	scene.game.event.connect(event_callback)
	panel.search.text="__no_match__"
	panel.search.text_changed.emit(panel.search.text)
	await click(panel.combine_all)
	check(notices.size()==1 and panel.bulk_summary.contains("合成 8 次") and panel.bulk_rewards.contains("Lv.3 ×2"),"Bulk synthesis is atomic and reports final rewards")
	check(panel.gem_buttons[protected.token]==survivor and scene.builds==builds,"Bulk synthesis preserves survivor control and main UI")
	check(panel.cells.is_empty(),"Bulk synthesis includes inventory hidden by active filters")
	await capture("jewel-center-combine")
	panel.search.text=""
	panel.search.text_changed.emit("")
	before=scene.game.profile.duplicate(true)
	await click(panel.combine_all)
	check(scene.game.profile==before and notices.size()==1,"Repeated empty bulk action cannot debit or notify")
	scene.game.event.disconnect(event_callback)
	var maxed:=scene.game.new_jewel("4",scene.db.jewel_max_level("4"))
	scene.game.profile.jewels.append(maxed)
	panel.inventory_changed()
	await settle()
	await click(panel.combine_all)
	check(not scene.game.jewel_inventory(maxed.token).is_empty(),"Bulk synthesis preserves max-level gems")
	while scene.game.profile.jewels.size()<200:scene.game.profile.jewels.append(scene.game.new_jewel("1"))
	panel.inventory_changed()
	panel.open("weapons",0)
	await click(panel.socket_buttons[1])
	check(panel.remove_action.disabled,"Full bag removal visibly blocked")
	var replacement:=scene.game.new_jewel("7",4)
	scene.game.profile.jewels[0]=replacement
	panel.inventory_changed()
	await settle()
	await click(panel.gem_buttons[replacement.token])
	check(not panel.socket_action.disabled,"Full bag replacement visibly available")
	var previous_token: int=entry.sockets[1].token
	await click(panel.socket_action)
	check(entry.sockets[1].token==replacement.token and not scene.game.jewel_inventory(previous_token).is_empty() and scene.game.profile.jewels.size()==200,"Full bag real click swaps owners without losing a gem")
	panel.usable_only.button_pressed=false
	panel.refresh()
	await settle()
	panel.inventory_scroll.scroll_vertical=120
	var scroll: int=panel.inventory_scroll.scroll_vertical
	var retained: Button=panel.cells[0]
	panel.search.grab_focus()
	var focus=panel.search
	scene.game.sort_jewels(true)
	check(panel.gem_buttons.values().has(retained) and panel.inventory_scroll.scroll_vertical==scroll and focus.has_focus(),"Inventory reorder retains controls, scroll and search focus")
	panel.search.text="__no_match__"
	panel.search.text_changed.emit(panel.search.text)
	check(panel.cells.is_empty() and panel.empty_hint.visible,"Search empty result explains filtering")
	panel.search.text=""
	panel.search.text_changed.emit("")
	check(panel.cells.size()==200,"Clear search restores candidates")
	var draws:={"background":0,"defence":0,"cell":0}
	scene.background_layer.draw.connect(func():draws.background+=1)
	scene.equipment_panel.cards.defence_0.draw.connect(func():draws.defence+=1)
	panel.cells[0].draw.connect(func():draws.cell+=1)
	await settle()
	scene.writes.clear()
	for key in draws:draws[key]=0
	for i in 3:
		panel.refresh()
		await process_frame
	check(scene.writes.is_empty(),"Unchanged paused center performs no property writes")
	check(draws.background==0 and draws.defence==0 and draws.cell==0,"Unchanged center does not redraw unrelated surfaces")
	check(not panel.get_children().any(func(child):return child is Button and child.text==UIText.t("gem.setup.text_03")),"Jewel center has no redundant close button")
	await click(scene.system_nav_buttons[0])
	check(not panel.visible and panel.metrics_timer.is_stopped() and panel.animations.is_empty(),"System navigation stops hidden jewel timers and animations")
	scene.writes.clear()
	scene.game.pickup_jewel_fragment()
	check(not panel.visible and scene.writes.is_empty(),"Hidden receipt does not open or write center")
	panel.open()
	check(panel.fragments.text.contains("%.2f" % scene.game.profile.jewelFragments),"Reopen catches up hidden fragment changes")
	check(panel.socket_row.visible and panel.inventory_scroll.scroll_vertical==scroll,"Reopen retains socket view and scroll")
	# All retained modules are manageable, including dormant and empty modules.
	var dormant: Dictionary={"key":"laser","level":20,"sockets":[scene.game.new_jewel("7")],"attacks":0,"hits":0}
	scene.game.profile.loadout.weapons.append(dormant)
	var dormant_index:=scene.game.module_entries("weapons").size()-1
	panel.refresh()
	check(panel.module_buttons[scene.game.slot_id("weapons",dormant_index)].get_index()<panel.module_buttons.defence_0.get_index(),"New modules remain grouped by category without rebuilding existing controls")
	await process_frame
	panel.module_scroll.scroll_vertical=0
	await click(panel.module_buttons[scene.game.slot_id("weapons",dormant_index)])
	check(panel.equipment_index==dormant_index and panel.detail.text.contains("暂不生效"),"Dormant module is visible and explains inactive battle effects")
	dormant.key=""
	scene.on_event("module_changed",{"slot":scene.game.slot_id("weapons",dormant_index)})
	check(panel.socket_buttons[0].icon!=null and panel.remove_action.disabled,"Empty module retains visible gems even when full bag blocks removal")
	scene.game.profile.jewels.clear()
	scene.game.profile.jewelFragments=0
	panel.inventory_changed()
	await click(panel.remove_action)
	check(dormant.sockets[0].is_empty() and scene.game.profile.jewels.size()==1,"Empty dormant module permits retrieval without equipping first")
	panel.open("weapons",0)
	var replacement_entry: Dictionary=entry.duplicate(true)
	scene.game.profile.loadout.weapons[0]=replacement_entry
	panel.selected=[int(scene.game.profile.jewels[0].token)]
	scene.on_event("module_changed",{"slot":"weapons_0"})
	check(panel.selected.is_empty() and is_same(panel.equipment_identity,replacement_entry),"Refit invalidates stale module identity and candidate")
	scene.game.paused=false
	panel.hide()
	panel.open()
	check(not scene.game.paused,"Opening expanded center does not pause ongoing battle")
	scene.game.paused=true
	panel.usable_only.button_pressed=false
	scene.game.profile.jewels.clear()
	scene.game.profile.jewelFragments=0
	panel.inventory_changed()
	await settle()
	check(panel.empty_hint.visible and panel.combine_all.visible,"Empty inventory keeps guidance and bulk action available for feedback")
	await capture("jewel-center-empty")
	scene.game.profile.jewelFragments=scene.game.jewel_create_cost()-1
	scene.game.pickup_jewel_fragment()
	check(panel.cells.size()==1 and panel.new_tokens.size()==1,"Receipt creates and marks new gem")
	await click(panel.cells[0])
	check(panel.new_tokens.is_empty(),"Inspect acknowledges new gem")
	for i in 3:panel.hide();panel.open()
	check(panel.combine_all.get_signal_connection_list("pressed").size()==1,"Reopen does not duplicate bulk action handlers")
	# Inspect the new raster art in the real renderer at inventory and hero sizes.
	scene.game.profile.jewels.clear()
	for id in scene.db.data.jewel:
		scene.game.profile.jewels.append(scene.game.new_jewel(str(id),int(id)%4+1))
	panel.search.text=""
	panel.usable_only.button_pressed=false
	panel.inventory_scroll.scroll_vertical=0
	panel.inventory_changed()
	await settle()
	var art: Texture2D=panel.gem_texture("7")
	check(art is AtlasTexture and art.atlas.get_image().get_pixel(0,0).a==0,"Premium gems use the transparent production atlas")
	check(panel.gem_texture("1")!=art and panel.gem_texture("10") is AtlasTexture,"Gem identities use separate atlas regions")
	await click(panel.gem_buttons[scene.game.profile.jewels[6].token])
	await capture("jewel-premium-collection")
	panel.open("weapons",0)
	panel.select_socket(1)
	panel.usable_only.button_pressed=false
	panel.refresh()
	await settle()
	await click(panel.gem_buttons[scene.game.profile.jewels[6].token])
	await capture("jewel-premium-sockets")
	var escape:=InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.pressed=true
	Input.parse_input_event(escape)
	await process_frame
	check(not panel.visible,"Escape closes expanded center")
	print("Jewel center UI: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
