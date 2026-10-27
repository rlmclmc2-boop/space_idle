extends SceneTree
var main
var prefix:String
func _initialize()->void:call_deferred("_run")
func settle()->void:
	for frame in 45:await process_frame
	await RenderingServer.frame_post_draw
func verify_selection()->void:
	var crew=main._feature_panels.crew
	if crew.world_crew_picker.item_count>1:
		crew.world_crew_picker.select(1);crew.world_crew_picker.item_selected.emit(1)
		var id:String=str(crew.world_crew_picker.get_item_metadata(1))
		var row:Dictionary=main.session.crew_system.status_rows([id])[0]
		assert(crew._selection_summary.text.contains(row.text))
		assert(crew._member_buttons[id].button_pressed)
		assert(crew._portrait_path({"portrait":"res://assets/ui/crew.svg","kind":"system_job","target":"hightech_scientists"})=="res://assets/ui/shell/research.svg")
		print("CREW_PICKER_SUMMARY_SELECTION_BADGE_SYNCHRONIZED")
func capture(label:String)->void:
	await settle()
	root.get_texture().get_image().save_png(prefix+"-"+label+".png")
func _run()->void:
	print("EVIDENCE_CODE_COMMIT ",OS.get_environment("SPACE_IDLE_EVIDENCE_COMMIT"))
	Engine.max_fps=60
	prefix=OS.get_environment("TEMP")+"/ui-r2"
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH",prefix+"-settings.json")
	root.size=Vector2i(1560,1000)
	main=load("res://src/main.tscn").instantiate();root.add_child(main);main.set_process(false)
	if not main.startup_error.is_empty():printerr(main.startup_error);quit(1);return
	main._skip_tutorial=true;main._sync_guidance()
	main._set_page("battle")
	await capture("1560-battle-opening-normal-start")
	var accepted:Dictionary=main.session.campaign_system.accept_reforge(main.session.campaign_system.save_state(),61)
	if not accepted.ok:printerr(accepted);quit(1);return
	var published:Dictionary=main.session._publish_progress()
	if not published.ok:printerr(published);quit(1);return
	main._refresh_feature_visibility()
	# Disposable UI fixture; never reads or overwrites personal progress.
	var hs=main.session.hyperspace_system
	for i in 4:
		var route:String=["alpha","beta","gamma","delta"][i]
		var drone:Dictionary=hs._generate_reward({"route":route,"level":10,"run_id":i+1,"luck_state":"1"}).drone
		if not drone.is_empty():
			drone.id="review-drone-"+str(i);hs._warehouse.append(drone)
			if i==0:hs._favorites.append(drone.id)
			if i==1:hs._sealed[drone.id]=100
	main.session.set_pause("user",true);main._set_page("growth")
	for dimensions in [Vector2i(1560,1000),Vector2i(572,960)]:
		root.size=dimensions
		await settle()
		print("WINDOW_REFLOW ",dimensions," logical=",root.content_scale_size," bridge=",main.growth_panel.get_global_rect())
		for feature in ["reactor","research","enhancement","crew","planet","galaxy"]:
			main._tabs.current_tab=main._pages.growth.index if feature in ["reactor","research","enhancement"] else main._pages.universe.index
			var location:Dictionary=main._module_locations[feature]
			location.tabs.current_tab=location.index
			var scroll:ScrollContainer=location.tabs.get_child(location.index)
			if feature=="crew":await settle();verify_selection()
			scroll.scroll_vertical=0
			if feature=="galaxy":
				for attempt in 600:
					await process_frame
					if not main._feature_panels.galaxy._map.preparing:break
				print("GALAXY_READY ",not main._feature_panels.galaxy._map.preparing)
			await capture(str(dimensions.x)+"-"+feature)
			if feature=="research":print("AI_SCENE_LAYOUT ",main._feature_panels.research._readout.size," minimum=",main._feature_panels.research._readout.get_combined_minimum_size()," children=",main._feature_panels.research._readout.get_child(0).get_children())
			print("MODULE_LAYOUT ",dimensions.x," ",feature," scroll=",scroll.size," panel=",main._feature_panels[feature].size," max=",scroll.get_v_scroll_bar().max_value)
			scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
			await capture(str(dimensions.x)+"-"+feature+"-bottom")
			if feature=="reactor":
				main._feature_panels.reactor._stage.module_selected.emit("defence")
				scroll.scroll_vertical=0
				await capture(str(dimensions.x)+"-reactor-device-controls")
			if feature=="planet":
				var planet=main._feature_panels.planet
				var planet_id:String=str(planet.world_planet_picker.get_item_metadata(planet.world_planet_picker.selected))
				var options:Array=main.session.planet_system.building_options(planet_id)
				if not options.is_empty():planet._select_facility(str(options[0].id))
				await capture(str(dimensions.x)+"-planet-facility-detail")
				planet._inspector.hide()
			if feature=="galaxy":
				main._feature_panels.galaxy._show_slot(0)
				await capture(str(dimensions.x)+"-galaxy-node-detail")
				main._feature_panels.galaxy._inspector.hide()
			if feature=="research":
				scroll.scroll_vertical=0;main._feature_panels.research._set_drawer(true)
				await capture(str(dimensions.x)+"-research-drawer")
				main._feature_panels.research._set_drawer(false)
				main._feature_panels.research._budget.show()
				await capture(str(dimensions.x)+"-research-terminal")
				main._feature_panels.research._budget.hide()
		main._tabs.current_tab=main._pages.ship.index
		var tabs:TabContainer=main._module_tabs[main._pages.ship.box.get_instance_id()]
		for index in tabs.get_tab_count():
			tabs.current_tab=index
			await capture(str(dimensions.x)+"-ship-"+str(index))
		main._tabs.set_tab_hidden(main._pages.hyperspace.index,false)
		main._tabs.current_tab=main._pages.hyperspace.index
		var hyper=main._feature_panels.hyperspace;hyper.show();hyper._refresh()
		if hyper._ids.size()>0:hyper._warehouse.select(0);hyper._refresh_detail()
		for section in 4:
			hyper._section_tabs.current_tab=section
			await capture(str(dimensions.x)+"-hyperspace-"+str(section))
	var old_rect:Rect2=main._tabs.get_global_rect()
	var button:Button=main._command_button(main.growth_panel,"feedback-probe",func():return {"ok":true,"message":"当前对象操作已完成"})
	button.hide();button.pressed.emit();await settle()
	if main._tabs.get_global_rect()!=old_rect:printerr("feedback moved navigation");quit(1);return
	print("RESULT_FEEDBACK_NAVIGATION_RECT_STABLE")
	print("UI_R2_CAPTURE_COMPLETE")
	# Leave a narrow research page available for real UI interaction.
	main._tabs.current_tab=main._pages.growth.index
	main._module_locations.research.tabs.current_tab=main._module_locations.research.index
	await create_timer(1).timeout
	main._stop_audio();main.queue_free();await process_frame;quit(0)