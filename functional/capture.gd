extends SceneTree
var main
var directory:String
func _initialize()->void:call_deferred("_run")
func settle()->void:
	for frame in 30:await process_frame
	await RenderingServer.frame_post_draw
func capture(label:String)->void:
	await settle()
	root.get_texture().get_image().save_png(directory+"/"+label+".png")
func _run()->void:
	directory=OS.get_environment("SPACE_IDLE_EVIDENCE_DIR")
	Engine.max_fps=60
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH",directory+"/fixture/settings.json")
	root.size=Vector2i(1560,1000)
	main=load("res://src/main.tscn").instantiate();root.add_child(main);main.set_process(false)
	assert(main.startup_error.is_empty(),main.startup_error)
	main._skip_tutorial=true;main._sync_guidance()
	assert(main.session.campaign_system.accept_reforge(main.session.campaign_system.save_state(),61).ok)
	assert(main.session._publish_progress().ok);main._refresh_feature_visibility()
	var hs=main.session.hyperspace_system
	var drone:Dictionary=hs._generate_reward({"route":"alpha","level":10,"run_id":1,"luck_state":"1"}).drone
	drone.id="screenshot-fixture";drone.omen=true;drone.legendary=true;drone.ultimate=true
	drone.ultimate_affix={"key":"global_damage","tier":2,"value":0.5,"locked":false}
	drone.legendary_effect={"effect_id":"higgs_cannon","parameters":{"damage_bonus":2.5,"area_bonus":1.5}}
	hs._warehouse.append(drone)
	main.session.set_pause("user",true);main._set_page("growth")
	for dimensions in [Vector2i(1560,1000),Vector2i(572,960)]:
		root.size=dimensions;await settle()
		main._tabs.current_tab=main._pages.hyperspace.index
		var hyper=main._feature_panels.hyperspace;hyper.show();hyper._refresh();hyper._warehouse.select(0);hyper._refresh_detail()
		hyper._section_tabs.current_tab=1
		await capture(str(dimensions.x)+"-hyperspace-loadout")
		hyper._section_tabs.current_tab=2
		await capture(str(dimensions.x)+"-hyperspace-forge-subject")
		var scroll:ScrollContainer=hyper._section_tabs.get_child(2);scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
		await capture(str(dimensions.x)+"-hyperspace-forge-materials")
		main._tabs.current_tab=main._pages.settings.index
		assert(main._preview_new_game(directory,false).ok)
		main._feedback_timer.timeout.emit()
		var review:Label=main._review_labels.new_game
		await settle()
		main._pages.settings.scroll.ensure_control_visible(review)
		await capture(str(dimensions.x)+"-new-game-persistent-preview")
		assert(review.visible)
		main._invalidate_review("new_game")
	main._stop_audio()
	if main.session.save_files!=null:assert(main.session.save_files.close(2000).ok)
	print("FUNCTIONAL_CAPTURE_COMPLETE ",OS.get_environment("SPACE_IDLE_EVIDENCE_COMMIT"))
	quit(0)
