extends SceneTree
var checks:=0
var failures:=0
func check(value:bool,label:String):
	checks+=1
	if not value:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
	var db=ShipDatabase.new();var fresh=BattleGame.new(db,false)
	var raw=fresh.portable_save_data()
	raw.resources={"1":10.25,"2":20.75};raw.chronoParticles=3.0
	raw.chronoSavedAt=Time.get_unix_time_from_system()-60.5
	raw.hightechSavedAt=Time.get_unix_time_from_system()-3600
	var text=JSON.stringify(raw)
	FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE).store_string(text)
	var first=BattleGame.new(db,true)
	check(first.login_chrono_particles>=60 and first.login_chrono_particles<=61,"One offline interval credits particles")
	check(first.profile.resources==raw.resources,"Offline settlement grants no resources")
	check(FileAccess.get_file_as_string(BattleGame.SAVE_PATH)==text,"Loading obeys existing manual/timed-only save contract")
	var unsaved_reload=BattleGame.new(db,true)
	check(unsaved_reload.profile.chronoParticles==first.profile.chronoParticles,"Reloading same unsaved snapshot does not add the interval twice")
	check(unsaved_reload.login_chrono_particles==first.login_chrono_particles,"Unsaved snapshot can repeat login report; this is not another cumulative credit")
	first.save_progress()
	check(first.last_save_error==OK,"Explicit save persists settlement")
	var committed=BattleGame.new(db,true)
	check(committed.login_chrono_particles==0,"Reload after explicit save reports no new interval")
	check(committed.profile.chronoParticles==first.profile.chronoParticles,"Committed particles survive once")
	check(committed.profile.resources==raw.resources,"Committed settlement still has no offline resource grant")
	var reserve:float=committed.profile.chronoParticles
	committed.speed=10.0
	var affordable:float=committed.chrono_affordable_seconds(reserve/9.0)
	check(is_equal_approx(affordable*10.0,affordable+reserve),"Boost game time equals online X1 plus retained offline X1")
	check(is_zero_approx(committed.profile.chronoParticles),"Retained particles are consumed once")
	committed.save_progress()
	var spent=BattleGame.new(db,true)
	check(spent.login_chrono_particles==0 and spent.profile.chronoParticles==0,"Explicitly saved spent reserve is not awarded again")
	var huge_raw=fresh.portable_save_data()
	huge_raw.resources={"1":{"m":9.7,"e":400.0},"2":1.25}
	var huge=BattleGame.new(db,false);huge.load_progress_data(huge_raw)
	check(huge.profile.resources==huge_raw.resources,"Load preserves huge GrowthNumber and ordinary fraction")
	huge_raw.resources["1"].m=8.5
	check(huge.profile.resources["1"].m==9.7,"Loaded resource dictionary does not alias mutable import data")
	print("OFFLINE_SETTLEMENT_CONTRACT checks=",checks," failures=",failures," scope=manual/timed save contract; unsaved snapshot reload is a replay, not cumulative earning")
	quit(1 if failures else 0)
