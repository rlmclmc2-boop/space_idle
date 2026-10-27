extends SceneTree
class MapStub extends Control:
	var selected_slot:int=0
	var crew_count:int=0
	func set_running(_value:bool)->void:pass
class GalaxyStub extends RefCounted:
	signal status_changed(keys:Array)
	signal availability_changed(keys:Array)
	var remaining:float=10.0
	func node_presentation(_key:String,_id:int)->Dictionary:
		return {"name":"检验设施","state":"active","level":1,"effect":"效果","bonus":"1","explored":true,"upgrade_remaining":remaining}
	func status_rows(_keys:Array=[])->Array:return []
	func assignment_options()->Array:return []
class CrewStub extends RefCounted:
	signal members_changed(ids:Array)
var main
func _initialize()->void:call_deferred("_run")
func _run()->void:
	var directory:String=OS.get_environment("SPACE_IDLE_EVIDENCE_DIR")+"/regression-fixture"
	DirAccess.make_dir_recursive_absolute(directory)
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH",directory+"/settings.json")
	main=load("res://src/main.tscn").instantiate();root.add_child(main);main.set_process(false)
	assert(main.startup_error.is_empty(),main.startup_error)
	main._skip_tutorial=true;main._sync_guidance()
	main._show_feedback("old result");main._feedback_timer.timeout.emit();assert(not main.growth_status.visible)
	main._pending_reforge={"fixture":true}
	var button:Button=main._command_button(main.growth_panel,"阻断测试",func():return {"ok":true})
	button.pressed.emit();assert(main.growth_status.visible and main.growth_status.text.contains("重铸"))
	main._pending_reforge={}
	var blocked=FileAccess.open(directory+"/blocked",FileAccess.WRITE);blocked.store_string("file, not directory");blocked.close()
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH",directory+"/blocked/settings.json")
	main.growth_status.hide();main._set_page("growth");assert(main.growth_status.visible)
	for toggle in [main._music_toggle,main._effects_toggle,main._skip_toggle]:
		main.growth_status.hide();toggle.toggled.emit(not toggle.button_pressed);assert(main.growth_status.visible)
	main.growth_status.hide();main._autosave_spin.value_changed.emit(10.0);assert(main.growth_status.visible)
	main.growth_status.hide();main._damage_option.item_selected.emit(0);assert(main.growth_status.visible)
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH",directory+"/settings.json")
	assert(main._preview_new_game(directory,false).ok)
	var review:Label=main._review_labels.new_game
	assert(review.visible)
	main._show_feedback("unrelated result");main._feedback_timer.timeout.emit();assert(review.visible and not main.growth_status.visible)
	main._invalidate_review("new_game");assert(not review.visible and main._pending_new_game.is_empty())
	print("FEEDBACK_REAPPEARS_AND_REVIEW_SURVIVES_TOAST_EXPIRY")
	assert(main.session.campaign_system.accept_reforge(main.session.campaign_system.save_state(),61).ok)
	assert(main.session._publish_progress().ok);main._refresh_feature_visibility()
	var hyper=main._feature_panels.hyperspace
	var hs=main.session.hyperspace_system
	var drone:Dictionary=hs._generate_reward({"route":"alpha","level":10,"run_id":1,"luck_state":"1"}).drone
	assert(not drone.is_empty())
	drone.id="probe-drone";drone.omen=true;drone.legendary=true;drone.ultimate=true
	drone.ultimate_affix={"key":"global_damage","tier":2,"value":0.5,"locked":false}
	drone.legendary_effect={"effect_id":"higgs_cannon","parameters":{"damage_bonus":2.5,"area_bonus":1.5}}
	hs._warehouse.append(drone);hyper._refresh();hyper._warehouse.select(0);hyper._refresh_detail()
	assert(hyper._cost_text({"ultimate_cores":1}).contains("究极核心"))
	assert(hyper._materials.text.contains("究极核心"))
	assert(hyper._detail.text.contains("预兆：已开启") and hyper._detail.text.contains("究极词缀") and hyper._detail.text.contains("2.5"))
	assert(hyper._loadout_preview.text.contains("装入：脉冲激光") and hyper._loadout_preview.text.contains("Lv10"))
	var old_state:String=JSON.stringify(hs.save_state(),"",true)
	var limits:Dictionary=hs.forge_display_limits(drone.id)
	assert(not limits.reroll_ranges.is_empty() and limits.affix_limit>0)
	assert(old_state==JSON.stringify(hs.save_state(),"",true))
	assert(hyper.FORGE_ERRORS.has("AffixCapacityExceeded") and hyper.FORGE_ERRORS.has("HangingCapacityExceeded") and hyper.FORGE_ERRORS.has("NoUnlockedAffix") and hyper.FORGE_ERRORS.has("NoPromotableAffix") and hyper.FORGE_ERRORS.has("UltimateLocked") and hyper.FORGE_ERRORS.has("ModernizationLevelUnavailable"))
	var request:Dictionary={"id":drone.id,"operation":"reroll_values","args":{"guaranteed":true}}
	var constraints:String=hyper._forge_limits_text(request,{})
	assert(constraints.contains("伤害") and constraints.contains("～") and constraints.contains("锁定"))
	print("HYPERSPACE_COST_BALANCE_TRAITS_LOADOUT_AND_READONLY_LIMITS_VISIBLE")
	var galaxy=GalaxyStub.new();var crew= CrewStub.new();var count:Dictionary={"value":2}
	var panel=load("res://src/ui/galaxy_panel.gd").new(galaxy,func():return {"galaxy_crew":{"fixture":count.value}},crew)
	root.add_child(panel);panel.set_process(false);panel._pending_full=false;panel._map=MapStub.new();panel.add_child(panel._map);panel._map_key="fixture";panel._inspector.show()
	panel._process(0.3);assert(panel._detail.text.contains("10.0") and panel._detail.text.contains("人员 2"))
	galaxy.remaining=6.0;panel._process(0.3);assert(panel._detail.text.contains("6.0"))
	count.value=0;crew.members_changed.emit(["fixture-member"]);panel._process(0.0);assert(panel._detail.text.contains("人员 0") and panel._detail.text.contains("缺人暂停"))
	print("GALAXY_VISIBLE_UPGRADE_PROGRESS_AND_LAST_CREW_REMOVAL_REFRESH")
	main._stop_audio()
	if main.session.save_files!=null:assert(main.session.save_files.close(2000).ok)
	print("REGRESSION_COMPLETE")
	quit(0)
