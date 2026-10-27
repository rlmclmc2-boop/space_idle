extends SceneTree
var main
var prefix:String
func _initialize()->void:call_deferred("_run")
func capture(label:String)->void:
	for frame in 40:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(prefix+label+".png")
func find_equipment(node:Node):
	if node.get_script()!=null and node.get_script().resource_path=="res://src/ui/equipment_panel.gd":return node
	for child in node.get_children():
		var found=find_equipment(child)
		if found!=null:return found
	return null
func find_button(node:Node,title:String)->Button:
	if node is Button and node.text==title:return node
	for child in node.get_children():
		var found:Button=find_button(child,title)
		if found!=null:return found
	return null
func _run()->void:
	print("EVIDENCE_CODE_COMMIT ",OS.get_environment("SPACE_IDLE_EVIDENCE_COMMIT"))
	Engine.max_fps=60;prefix=OS.get_environment("TEMP")+"/ui-r2-"
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH",prefix+"focused-settings.json")
	root.size=Vector2i(1560,1000)
	main=load("res://src/main.tscn").instantiate();root.add_child(main);main.set_process(false)
	if not main.startup_error.is_empty():printerr(main.startup_error);quit(1);return
	main._skip_tutorial=true;main._sync_guidance();main._set_page("battle")
	root.size=Vector2i(572,960);await capture("572-battle-opening-normal-start")
	main.session.campaign_system.accept_reforge(main.session.campaign_system.save_state(),61)
	main.session._publish_progress();main._refresh_feature_visibility();main.session.set_pause("user",true);main._set_page("growth")
	var hs=main.session.hyperspace_system
	var drone:Dictionary=hs._generate_reward({"route":"alpha","level":10,"run_id":1,"luck_state":"1"}).drone
	if not drone.is_empty():hs._warehouse.append(drone);hs._favorites.append(drone.id)
	for dimensions in [Vector2i(1560,1000),Vector2i(572,960)]:
		root.size=dimensions
		main._tabs.current_tab=main._pages.growth.index
		var research=main._feature_panels.research
		main._module_locations.research.tabs.current_tab=main._module_locations.research.index
		research._budget.hide();research._set_drawer(false)
		await capture(str(dimensions.x)+"-research")
		print("RESEARCH_CURRENT_READOUT ",research._research_detail.text)
		research._budget.show();await capture(str(dimensions.x)+"-research-terminal");research._budget.hide()
		research._set_drawer(true);await capture(str(dimensions.x)+"-research-drawer")
		var chosen:String=""
		for key in research._machine_rows:
			if key!="singularity" and not research._machine_rows[key].button.disabled:chosen=key;break
		if not chosen.is_empty():
			research._machine_rows[chosen].button.pressed.emit()
			await capture(str(dimensions.x)+"-research-selected-machine")
			if research._drawer.visible or research._research.save_state().current!=chosen:printerr("research callback mismatch");quit(1);return
			print("RESEARCH_BUTTON_CALLBACK_SELECTION_OK ",chosen)
		research._set_drawer(false);research._budget.show()
		var actual:Dictionary=research._research.panel_model()
		research.investment_inputs["1"].text="invalid-amount";research.investment_inputs["1"].text_changed.emit("invalid-amount")
		for child in research.investment_inputs["1"].get_parent().get_children():
			if child is Button:child.pressed.emit()
		await capture(str(dimensions.x)+"-research-invalid-input")
		if research._research.panel_model()!=actual or research.investment_inputs["1"].text!="invalid-amount":printerr("invalid draft lost or applied");quit(1);return
		print("INVALID_INVESTMENT_DRAFT_RETAINED_ACTUAL_SETTINGS_UNCHANGED")
		research.investment_inputs["1"].text="0";research._drafts.clear();research.refresh_investment();research._budget.hide();main.growth_status.hide()
		main._tabs.set_tab_hidden(main._pages.hyperspace.index,false);main._tabs.current_tab=main._pages.hyperspace.index
		var hyper=main._feature_panels.hyperspace;hyper.show();hyper._refresh()
		if hyper._ids.size()>0:hyper._warehouse.select(0);hyper._refresh_detail()
		hyper._section_tabs.current_tab=1;await capture(str(dimensions.x)+"-hyperspace-1")
		main._tabs.current_tab=main._pages.ship.index
		var ship_tabs:TabContainer=main._module_tabs[main._pages.ship.box.get_instance_id()];ship_tabs.current_tab=0
		await capture(str(dimensions.x)+"-ship-0")
		var equipment=find_equipment(main)
		var slots:Array=main.session.equipment.presentation_slots(main.session.equipment_presentation_inputs())
		var before:int=int(slots[0].level)
		main.session.economy.credit_yield("1",main.session.amount_api.apply("from_decimal",["1e12"]).value,0.0,0.0,false)
		var upgrade:Button=find_button(equipment._editor,"+1")
		if upgrade==null:printerr("unique slot upgrade unavailable");quit(1);return
		upgrade.pressed.emit();await capture(str(dimensions.x)+"-equipment-upgrade-success")
		var after:Array=main.session.equipment.presentation_slots(main.session.equipment_presentation_inputs())
		if int(after[0].level)!=before+1:printerr("slot upgrade callback target");quit(1);return
		print("SLOT_CARD_BUTTON_CALLBACK_SINGLE_LEVEL_OK ",before," -> ",after[0].level)
		main._tabs.current_tab=main._pages.hyperspace.index
		var scroll:ScrollContainer=hyper._section_tabs.get_child(1);scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
		await capture(str(dimensions.x)+"-hyperspace-detail")
	print("FOCUSED_SCENE_READOUT_CAPTURE_OK")
	main._stop_audio();main.queue_free();await process_frame;quit(0)