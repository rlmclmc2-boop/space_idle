extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:
	var db := ShipDatabase.new()
	var g := BattleGame.new(db,false)
	g.profile.resources = {"1":0.0,"2":0.0}
	var raw := {"offlineSavedAt":1000.0,"offlineRates":{"1":1.25,"2":0.125}}
	g.settle_offline_resources(raw,1061)
	check(g.profile.resources["1"]==77 and g.profile.resources["2"]==8,"Rate times elapsed rounds once per resource")
	check(g.resource_samples.is_empty() and g.run_resources["1"]==0,"Offline credit does not enter online rate or run income")
	g.profile.resources = {"1":0.0,"2":0.0}
	db.config.offlineMax = 4
	g.settle_offline_resources(raw,1000+86400)
	check(g.profile.resources["1"]==18000 and g.profile.resources["2"]==1800,"Four-hour cap")
	g.profile.resources = {"1":0.0,"2":0.0}
	db.config.offlineMax = 0.5
	g.settle_offline_resources(raw,1000+86400)
	check(g.profile.resources["1"]==2250,"Cap reads configured hours")
	db.config.offlineMax = 0
	g.settle_offline_resources(raw,1000+86400)
	check(g.offline_rewards.is_empty(),"Zero configured limit disables rewards")
	db.config.offlineMax = 4
	g.settle_offline_resources(raw,999)
	check(g.offline_rewards.is_empty(),"Clock rollback grants nothing")
	g.settle_offline_resources({},2000)
	check(g.offline_rewards.is_empty(),"Legacy save without rate grants nothing")
	g.settle_offline_resources({"offlineSavedAt":1000,"offlineRates":{"1":-1,"2":"bad"}},2000)
	check(g.offline_rewards.is_empty(),"Invalid rates ignored")
	g.resource_samples.assign([{"time":Time.get_unix_time_from_system(),"id":"1","amount":75.0}])
	g.save_enabled = true
	g.save_progress()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(saved.offlineRates["1"]==1.25 and saved.offlineRates["2"]==0,"Snapshot saves full-precision minute rate")
	# Fix time in the isolated save, retaining no online samples to prevent feedback.
	saved.offlineSavedAt = floorf(Time.get_unix_time_from_system())-3600
	saved.resourceSamples = []
	saved.resources = {"1":0.0,"2":0.0}
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	var loaded := BattleGame.new(db,true)
	check(loaded.profile.resources["1"]>=4500 and loaded.profile.resources["1"]<=4503,"Loading credits offline income")
	var loaded_again := BattleGame.new(db,true)
	check(loaded_again.profile.resources["1"]==loaded.profile.resources["1"] and loaded_again.offline_rewards.is_empty(),"Immediate reload cannot reclaim prior offline interval")
	print("Offline resources: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
