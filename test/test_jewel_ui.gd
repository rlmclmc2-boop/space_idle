extends SceneTree

class TrackedUI extends "res://scripts/main.gd":
	var writes: Array = []
	var builds := 0
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property) != value:
			writes.append(control)
		super.set_ui_value(control,property,value)
	func build_ui() -> void:
		builds += 1
		super.build_ui()

var checks := 0
var failures := 0

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func click(control: Control) -> void:
	var mouse := InputEventMouseMotion.new()
	mouse.position=control.get_global_rect().get_center()
	if control.get_window()!=root and root.gui_embed_subwindows:mouse.position+=Vector2(control.get_window().position)
	Input.parse_input_event(mouse)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=mouse.position
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame

func run() -> void:
	var scene:=TrackedUI.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	scene.game.profile.highestLevel=int(scene.db.config.jewelDropLevel)-1
	scene.refresh_tab_visibility()
	check(scene.equipment_tabs.is_tab_hidden(5),"Jewel tab hidden below gate")
	var tabs:=scene.equipment_tabs
	var builds:=scene.builds
	var defence: Label=scene.equipment_card_controls.defence_0.title
	scene.game.profile.highestLevel+=1
	scene.refresh_tab_visibility()
	scene.refresh_equipment_cards("weapons_0")
	check(not tabs.is_tab_hidden(5) and scene.builds==builds,"Unlock only changes visibility")
	var panel=scene.jewel_panel
	check(not panel.is_processing(),"Workshop does not poll inventory every frame")
	for next_state in [BattleGame.State.TRAVEL,BattleGame.State.COMBAT,BattleGame.State.LEVEL_CLEAR]:
		scene.writes.clear()
		scene.game.state=next_state
		scene.on_event("state",{})
		check(not panel.visible and not scene.writes.has(panel),"Navigation must not open hidden workshop: " + str(next_state))
		panel.hide()
	for i in 3:
		scene.game.profile.jewels.append(scene.game.new_jewel("7"))
	scene.equipment_tabs.current_tab=5
	await process_frame
	await click(scene.equipment_tabs.get_child(5).get_child(0))
	check(panel.visible and panel.cells.size()==3,"Real click opens gem grid")
	check(panel.inventory_list.columns==6 and panel.empty_cells.size()==27,"Six-column grid retains empty gem slots")
	check(panel.cells[0].icon!=null and not panel.cells[0].tooltip_text.is_empty(),"Occupied slot shows corresponding gem image and effect")
	check(panel.cells[0].get_meta("jewel_palette")=="ready" and panel.cells[0].text.contains("↑"),"Enough matching gems have a distinct combine border and marker")
	var close_button: Button=null
	for child in panel.get_children():
		if child is Button and child.text=="关闭":
			close_button=child
	await click(close_button)
	check(not panel.visible,"Real close button hides workshop")
	scene.game.state=BattleGame.State.TRAVEL
	scene.on_event("state",{})
	check(not panel.visible and not panel.is_processing(),"Travel after closing cannot reopen workshop")
	panel.hide()
	await click(scene.equipment_tabs.get_child(5).get_child(0))
	check(panel.visible,"Explicit button can reopen closed workshop")
	check(scene.builds==builds and scene.equipment_tabs==tabs,"Visibility changes preserve UI instances")
	var cell=panel.cells[0]
	var draws:={"background":0,"defence":0,"cell":0}
	scene.background_layer.draw.connect(func():draws.background+=1)
	scene.equipment_panels.defence_0.draw.connect(func():draws.defence+=1)
	cell.draw.connect(func():draws.cell+=1)
	await click(cell)
	check(cell.get_meta("jewel_palette")=="selected" and cell.get_theme_stylebox("normal").border_width_left==2,"Selection has a distinct two-pixel border")
	check(panel.preview.text.contains("下一等级") and panel.combine.tooltip_text.contains("数量不足"),"Details preview next effect and explain disabled combine")
	await click(panel.cells[1])
	await click(panel.cells[2])
	check(panel.selected.size()==3 and not panel.combine.disabled,"Mouse stages matching gems")
	await click(panel.combine)
	check(scene.game.profile.jewels.size()==1 and scene.game.profile.jewels[0].level==2,"Real click combines")
	check(panel.selected.is_empty() and panel.combine.disabled,"Consumed selection cleared; double click safe")
	check(scene.equipment_tabs==tabs and scene.builds==builds,"Combine preserves unrelated controls")
	check(panel.feedback.text.contains("Lv.1 → Lv.2") and panel.detail_heading.text.contains("Lv.2"),"Combine result and level gain remain visible")
	check(panel.flights.any(func(icon):return icon.visible) and panel.flights.size()==8,"Combine uses bounded reusable icon flights")
	panel.hide()
	scene.equipment_tabs.current_tab=0
	await process_frame
	await click(scene.equipment_card_controls.weapons_0.socket)
	check(panel.visible and panel.equipment_index==0,"Equipment button opens socket UI")
	await click(panel.cells[0])
	var before_preview: Dictionary=scene.game.profile.duplicate(true)
	panel.refresh_detail()
	check(panel.preview.text.contains("暴击率") and scene.game.profile==before_preview,"Socket stat preview reuses calculations without mutating profile")
	scene.writes.clear()
	await click(panel.socket_buttons[0])
	check(scene.game.profile.jewels.is_empty() and scene.game.slot_entry("weapons",0).sockets[0].id=="7","Mouse sockets gem")
	check(scene.game.jewel_critical(scene.game.slot_entry("weapons",0)).x>0 and panel.socket_buttons[0].icon!=null and not panel.socket_buttons[0].tooltip_text.is_empty(),"Socketing shows gem and applies its combat effect")
	check(not scene.writes.has(defence),"Socket never writes unrelated defence label")
	await click(panel.socket_buttons[0])
	check(panel.socket_action.visible and panel.socket_action.text=="卸下" and panel.detail.text.contains("已镶嵌"),"Installed gem opens details with unsocket action")
	await click(panel.socket_action)
	check(scene.game.profile.jewels.size()==1 and scene.game.slot_entry("weapons",0).sockets[0].is_empty(),"Mouse unsockets gem")
	scene.game.slot_entry("weapons",0).level=20
	panel.refresh()
	check(panel.socket_buttons.size()==2,"Socket structure follows equipment level")
	await click(panel.cells[0]);await click(panel.socket_buttons[0])
	scene.game.profile.jewels.append(scene.game.new_jewel("7",1))
	panel.refresh()
	await click(panel.cells[0]);await click(panel.socket_buttons[1])
	check(scene.game.profile.jewels.size()==1 and panel.preview.text.contains("同ID") and panel.socket_buttons[1].disabled,"Different-level same-ID conflict visibly rejected")
	var old_socket_token: int=scene.game.slot_entry("weapons",0).sockets[0].token
	var replacement_token: int=scene.game.profile.jewels[0].token
	var socket_control=panel.socket_buttons[0]
	scene.writes.clear()
	await click(socket_control)
	check(scene.game.slot_entry("weapons",0).sockets[0].token==replacement_token and scene.game.profile.jewels[0].token==old_socket_token,"Real click replaces same-ID gem without losing either owner")
	check(panel.socket_buttons[0]==socket_control and not scene.writes.has(defence) and scene.builds==builds,"Replacement reuses socket control and leaves unrelated UI untouched")
	check(panel.selected.is_empty() and panel.socket_buttons[0].text.contains("已镶嵌"),"Replacement clears consumed selection and shows installed status")
	panel.open()
	scene.game.profile.jewels.append(scene.game.new_jewel("4",10))
	panel.refresh()
	await process_frame
	await process_frame
	await click(panel.cells[1])
	check(not panel.compose.disabled and panel.combine.disabled,"Max-level action availability")
	var iron: float=scene.game.profile.resources["1"]
	var refund: float=scene.game.jewel_compose_reward(scene.game.profile.jewels[1])
	await click(panel.compose)
	check(panel.compose_dialog.visible and scene.game.profile.jewels.size()==2,"Destructive decomposition waits for confirmation")
	await click(panel.compose_dialog.get_cancel_button())
	check(scene.game.profile.jewels.size()==2 and panel.pending_compose==-1,"Cancel keeps gem and clears pending destructive action")
	await click(panel.compose)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/jewel-confirm.png")
	await click(panel.compose_dialog.get_ok_button())
	check(scene.game.profile.resources["1"]==iron and scene.game.profile.jewels.size()==200 and scene.game.profile.jewelFragments==refund-199*scene.game.jewel_create_cost(),"Actual mouse decomposes to fragments and gems")
	check(panel.fragments.text.begins_with("背包已满"),"Full inventory feedback is visible")
	panel.open("weapons",0)
	var full_before: Dictionary=scene.game.profile.duplicate(true)
	await click(panel.socket_buttons[0])
	check(scene.game.profile==full_before,"Real click cannot unsocket into full inventory")
	await click(panel.cells[0])
	check(panel.detail.text.contains("持有") and panel.detail.text.contains("未镶嵌"),"Detail displays owned count and inventory status")
	await click(panel.socket_buttons[0])
	check(scene.game.profile==full_before,"Real click cannot replace into full inventory")
	panel.open()
	panel.cells[0].draw.connect(func():draws.cell+=1)
	scene._process(0)
	await create_timer(0.45).timeout
	await process_frame
	await process_frame
	scene.writes.clear()
	for key in draws:draws[key]=0
	for i in 3:
		panel.refresh()
		scene._process(0)
		await process_frame
	check(scene.writes.is_empty(),"Paused unchanged UI no property writes")
	check(draws.background==0 and draws.defence==0 and draws.cell==0,"Paused unchanged controls no redraws")
	panel.hide()
	scene.writes.clear()
	scene.game.pickup_jewel_fragment("1")
	check(scene.writes.is_empty() and not panel.is_processing(),"Hidden workshop stops updates")
	panel.open()
	check(panel.fragments.text.contains("%.2f" % scene.game.profile.jewelFragments) and panel.fragments.text.contains("每分钟宝石碎片获取量"),"Opening catches up fragment state")
	scene.game.profile.jewels.clear()
	for id in scene.db.data.jewel:
		scene.game.profile.jewels.append(scene.game.new_jewel(str(id),3))
	panel.refresh()
	check(panel.cells.all(func(button):return button.icon != null),"Every gem has its corresponding image")
	var first_row=panel.cells[0]
	first_row.grab_focus()
	var scroll: ScrollContainer=panel.inventory_list.get_parent()
	await process_frame
	scroll.scroll_vertical=48
	var scroll_before:=scroll.scroll_vertical
	scene.game.sort_jewels(true)
	check(panel.gem_buttons.values().has(first_row),"Sorting preserves gem button identity")
	check(first_row.has_focus() and scroll.scroll_vertical==scroll_before,"Sorting preserves focus and scroll position")
	check(not panel.summary.text.contains("/200") and not panel.summary.text.contains("背包"),"Capacity UI removed")
	scroll.scroll_vertical=0
	await process_frame
	await process_frame
	await click(panel.cells[4])
	check(not panel.selected.is_empty() and panel.detail.size.y>0 and panel.preview.size.y>0,"Visible details and preview have nonzero layout height")
	await create_timer(0.4).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/jewel-workshop.png")
	scene.game.profile.jewelFragments=0.0
	scene.game.profile.jewels=[scene.game.new_jewel("7",2)]
	panel.open("weapons",0)
	await create_timer(0.4).timeout
	await click(panel.cells[0])
	check(panel.preview.text.contains("替换预览") or panel.preview.text.contains("镶嵌预览"),"Equipment details include the target slot comparison")
	check(panel.preview.text.contains("+0.50%"),"Replacement preview shows the precise critical-rate increase")
	await create_timer(0.4).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/jewel-sockets.png")
	await presentation_boundaries(scene)
	await bulk_ui(scene)
	print("Jewel UI: %d checks, %d failures" % [checks,failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)

func presentation_boundaries(scene: Node) -> void:
	var panel=scene.jewel_panel
	scene.game.profile.jewels.clear()
	scene.game.profile.jewelFragments=0.0
	panel.open()
	await create_timer(0.4).timeout
	check(panel.empty_hint.visible and not panel.combine.visible and not panel.compose.visible and not panel.socket_action.visible,"Empty inventory shows guidance and hides meaningless actions")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/jewel-empty.png")
	scene.game.profile.jewelFragments=scene.game.jewel_create_cost()-1
	var drop: Dictionary={"uid":987654,"x":500,"y":300,"age":0.0,"jewel":true,"jewelRatio":1.0,"amount":1.0}
	scene.game.drops.append(drop)
	scene.game.collect(drop,true)
	check(panel.cells.size()==1 and panel.new_tokens.has(scene.game.profile.jewels[0].token) and not panel.empty_hint.visible,"Actual pickup generates a gem and marks its reused inventory presentation as new")
	check(panel.feedback.text.contains("生成宝石 ×1") and panel.flights.any(func(icon):return icon.visible),"Generated gem receipt is stronger than fragment-only pickup")
	await process_frame
	await process_frame
	await click(panel.cells[0])
	check(panel.new_tokens.is_empty(),"Inspecting a new gem acknowledges its new marker")
	panel.hide()
	check(panel.animations.is_empty() and panel.metrics_timer.is_stopped() and panel.flights.all(func(icon):return not icon.visible),"Closing cancels animations and stops the metrics timer")
	var nodes: int=panel.effect_layer.get_child_count()
	for i in 12:
		var next: Dictionary={"uid":987655+i,"x":500,"y":300,"age":0.0,"jewel":true,"jewelRatio":1.0,"amount":1.0}
		scene.game.drops.append(next)
		scene.game.collect(next,true)
	check(not panel.visible and panel.effect_layer.get_child_count()==nodes and nodes==8,"Rapid hidden pickups reuse eight effects and never reopen the workshop")
	for i in 3:
		panel.open()
		panel.hide()
	check(panel.compose_dialog.get_signal_connection_list("confirmed").size()==1 and panel.gem_buttons.values()[0].get_signal_connection_list("pressed").size()==1,"Reopening does not bind duplicate handlers")

func bulk_ui(scene: Node) -> void:
	var panel=scene.jewel_panel
	scene.game.profile.jewels.clear()
	scene.game.profile.jewelFragments=0.0
	for i in 18:scene.game.profile.jewels.append(scene.game.new_jewel("1"))
	var survivor: Dictionary=scene.game.new_jewel("2")
	survivor.locked=true
	scene.game.profile.jewels.append(survivor)
	panel.open()
	await create_timer(0.4).timeout
	var old_cell: Button=panel.gem_buttons[survivor.token]
	var card=scene.equipment_card_controls.weapons_0.title
	var old_builds: int=scene.builds
	var notices := [0]
	var on_event := func(kind,_info):
		if kind=="jewels_changed":notices[0]+=1
	scene.game.event.connect(on_event)
	scene.writes.clear()
	await click(panel.combine_all)
	check(scene.game.profile.jewels.size()==3 and notices[0]==1,"One real click chains all upgrades and sends one final inventory refresh")
	check(panel.bulk_summary.contains("合成 8 次") and panel.bulk_summary.contains("24 颗") and panel.bulk_rewards.contains("Lv.3 ×2"),"Result reports operation count, cumulative consumed count and merged final rewards")
	check(panel.gem_buttons[survivor.token]==old_cell and scene.builds==old_builds and not scene.writes.has(card),"Bulk update preserves protected gem control and unrelated equipment UI")
	check(panel.animations.size()>0 and panel.detail_heading.text=="一键合成完成","New high-level results receive brief highlight and dedicated detail report")
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/jewel-bulk-result.png")
	var before: Dictionary=scene.game.profile.duplicate(true)
	await click(panel.combine_all)
	check(scene.game.profile==before and notices[0]==1 and scene.message=="当前没有可合成宝石","Repeat click cannot debit and reports exact empty-result message")
	await create_timer(0.4).timeout
	scene.writes.clear()
	panel.refresh()
	check(scene.writes.is_empty(),"Unchanged bulk result remains stable without repeated property writes")
	scene.game.event.disconnect(on_event)
