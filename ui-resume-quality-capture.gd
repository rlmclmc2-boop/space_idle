extends SceneTree
var main
var prefix:String
func _initialize()->void:call_deferred("_run")
func settle()->void:
	for frame in 45:await process_frame
	await RenderingServer.frame_post_draw
func capture(label:String)->void:
	await settle()
	root.get_texture().get_image().save_png(prefix+"-"+label+".png")
func _run()->void:
	Engine.max_fps=60
	prefix=OS.get_environment("TEMP")+"/ui-resume"
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH",prefix+"-settings.json")
	root.size=Vector2i(1560,1000)
	main=load("res://src/main.tscn").instantiate();root.add_child(main);main.set_process(false)
	if not main.startup_error.is_empty():printerr(main.startup_error);quit(1);return
	main._skip_tutorial=true;main._sync_guidance()
	var accepted:Dictionary=main.session.campaign_system.accept_reforge(main.session.campaign_system.save_state(),61)
	if not accepted.ok:printerr(accepted);quit(1);return
	var published:Dictionary=main.session._publish_progress()
	if not published.ok:printerr(published);quit(1);return
	main._refresh_feature_visibility();main.session.set_pause("user",true);main._set_page("growth")
	for dimensions in [Vector2i(1560,1000),Vector2i(572,960)]:
		root.size=dimensions
		await settle()
		print("WINDOW_REFLOW ",dimensions," logical=",root.content_scale_size," bridge=",main.growth_panel.get_global_rect())
		for feature in ["reactor","research","enhancement","crew","planet","galaxy"]:
			main._tabs.current_tab=main._pages.growth.index if feature in ["reactor","research","enhancement"] else main._pages.universe.index
			var location:Dictionary=main._module_locations[feature]
			location.tabs.current_tab=location.index
			var scroll:ScrollContainer=location.tabs.get_child(location.index)
			scroll.scroll_vertical=0
			if feature=="galaxy":
				for attempt in 600:
					await process_frame
					if not main._feature_panels.galaxy._map.preparing:break
				print("GALAXY_READY ",not main._feature_panels.galaxy._map.preparing)
			await capture(str(dimensions.x)+"-"+feature)
			print("MODULE_LAYOUT ",dimensions.x," ",feature," scroll=",scroll.size," panel=",main._feature_panels[feature].size," max=",scroll.get_v_scroll_bar().max_value)
			scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
			await capture(str(dimensions.x)+"-"+feature+"-bottom")
			if feature=="research":
				scroll.scroll_vertical=0;main._feature_panels.research._set_drawer(true)
				await capture(str(dimensions.x)+"-research-drawer")
				main._feature_panels.research._set_drawer(false)
		main._tabs.current_tab=main._pages.ship.index
		var tabs:TabContainer=main._module_tabs[main._pages.ship.box.get_instance_id()]
		for index in tabs.get_tab_count():
			tabs.current_tab=index
			await capture(str(dimensions.x)+"-ship-"+str(index))
	print("UI_RESUME_CAPTURE_COMPLETE")
	# Leave a narrow research page available for real UI interaction.
	main._tabs.current_tab=main._pages.growth.index
	main._module_locations.research.tabs.current_tab=main._module_locations.research.index
	await create_timer(1).timeout
	main._stop_audio();main.queue_free();await process_frame;quit(0)