extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	var settings := ProjectSettings.globalize_path("res://../test/work/opening-feedback-settings.cfg")
	DirAccess.make_dir_recursive_absolute(settings.get_base_dir())
	scene.tutorial_settings_path=settings
	scene.game.save_enabled=true
	var keys: Array=scene.db.data.unlock.keys()
	check(not scene.tutorial_auto_skip,"Automatic tutorial skip defaults off")
	scene.game.paused=true
	scene.game.pending_unlocks.assign([str(keys[0]),str(keys[1])])
	scene.refresh_navigation()
	check(scene.unlock_pause_owned and scene.game.paused,"Pending notice holds previously paused state")
	scene.advance_unlock_notice(Time.get_ticks_msec()+4000)
	check(scene.game.pending_unlocks.size()==2,"Default notice never expires during reading")
	scene.game.acknowledge_unlocks()
	scene.refresh_navigation()
	check(scene.game.pending_unlocks.size()==1 and scene.game.paused,"Stacked notice waits for its own confirmation")
	scene.game.acknowledge_unlocks()
	scene.refresh_navigation()
	check(scene.game.paused and not scene.unlock_pause_owned,"Last confirmation restores player pause")
	scene.game.paused=false
	scene.game.pending_unlocks.assign([str(keys[0]),str(keys[1])])
	scene.refresh_navigation()
	scene.set_tutorial_auto_skip(true)
	check(not scene.game.paused,"Enabling automatic skip releases notice-owned pause")
	scene.advance_unlock_notice(Time.get_ticks_msec()+4000)
	check(scene.game.pending_unlocks.size()==1,"Optional automatic skip advances only one notice")
	var fresh = load("res://main.tscn").instantiate()
	fresh.automation_args=["--capture"]
	root.add_child(fresh)
	fresh.automation_args=[]
	fresh.set_process(false)
	fresh.tutorial_settings_path=settings
	fresh.load_tutorial_setting()
	check(fresh.tutorial_auto_skip,"Automatic skip preference survives scene reopen")
	var drop := {"uid":8801,"x":220.0,"y":340.0,"age":1.0,"id":"1","amount":10.0}
	scene.game.drops.append(drop)
	var manual_projected = scene.pickup_preview_amount(drop,true)
	var projected = scene.pickup_preview_amount(drop,false)
	check(GrowthNumber.compare(manual_projected,projected)>0,"Actual per-drop manual receipt exceeds automatic receipt")
	scene.game.collect(drop,false)
	check(GrowthNumber.compare(scene.resource_pickup_totals["1"].amount,projected)==0,"Top receipt matches separately rounded automatic credit")
	check(not scene.battle_notices().any(func(item):return item.has("resources")),"Collection creates no battlefield banner")
	check(scene.RESOURCE_STRIP_PRESENTATION.card_rect(1,2).end.x<=485.0,"Two-resource strip fits")
	check(not scene.game.jewels_unlocked(),"Fragments remain hidden before feature unlock")
	scene.game.profile.cleared=range(1,9)
	scene.game.rebuild_unlocks()
	check(scene.game.jewels_unlocked() and scene.RESOURCE_STRIP_PRESENTATION.card_rect(2,3).end.x<=485.0,"Third resource appears only after actual unlock and fits")
	var fragment := {"uid":8802,"x":220.0,"y":340.0,"age":1.0,"jewel":true,"amount":5.0,"jewelRatio":scene.game.jewel_ratio()}
	var preview: String = scene.pickup_comparison(fragment)
	var preview_builds: int = scene.pickup_preview_builds
	check(scene.pickup_comparison(fragment)==preview and scene.pickup_preview_builds==preview_builds,"Repeated fragment hover reuses both previews")
	var neighbour := fragment.duplicate()
	neighbour.uid=8803
	scene.pickup_comparison(neighbour)
	scene.pickup_comparison(fragment)
	check(scene.pickup_preview_builds==preview_builds+1 and scene.pickup_preview_cache.size()==2,"Nearby drops retain independent bounded previews")
	scene.game.invalidate_stat_cache()
	scene.pickup_comparison(fragment)
	check(scene.pickup_preview_builds==preview_builds+2,"Configuration revision invalidates fragment preview")
	scene.game.drops.append(fragment)
	scene.game.collect(fragment,true)
	check(not scene.pickup_preview_cache.has(8802),"Collected drop removes its cached preview")
	for index in 65:
		neighbour.uid=9000+index
		scene.pickup_comparison(neighbour)
	check(scene.pickup_preview_cache.size()<=64 and scene.pickup_preview_order.size()<=64,"Preview cache stays bounded across distinct drops")
	var large_drop := {"uid":9999,"id":"1","amount":GrowthNumber.make(1.0,80.0)}
	scene.pickup_comparison(large_drop)
	preview_builds=scene.pickup_preview_builds
	scene.pickup_comparison(large_drop)
	check(scene.pickup_preview_builds==preview_builds,"Large-number drop reuses preview without type errors")
	scene.game.income_history.replace_records([{"time":100.0,"id":"jewel","amount":2.5}])
	scene.resource_rate_mode=true
	check(scene.game.resource_minute_total("jewel",100.0)==2.5 and scene.resource_display("jewel",100.0)==UIText.t("inventory.rate",{"rate":scene.NUMBER_FORMAT.rate(2.5/60.0)}),"Fragment top rate follows actual minute samples")
	print("Opening feedback: %d checks, %d failures" % [checks,failures])
	scene.queue_free();fresh.queue_free()
	quit(1 if failures else 0)
