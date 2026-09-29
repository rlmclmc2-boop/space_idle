extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:
	for capacity in [100.0,10000.0,1e12,1e18,1e24]:
		for target_slot in [0,1]:
			var db := ShipDatabase.new()
			db.config.equipmentSocket = 10
			db.equipment.armour[0].para1 = capacity
			db.equipment.shield[0].para1 = capacity
			var g := BattleGame.new(db,false)
			g.start(1,false)
			g.spawn_group()
			g.profile.unlocked = ["armour","shield"]
			g.profile.loadout.defence = [{"key":"shield","level":1},{"key":"armour","level":1}]
			g.profile.loadout.defence[target_slot].sockets = [g.new_jewel("6",1)]
			g.reset_player()
			for i in 100:
				g.hit_player(capacity*0.0123,1)
				if g.player.armour<=0:break
				g.since_hit += 0.016
				g.advance_jewel_repair(0.016)
			g.hit_player(capacity*100,1)
			check(g.player.armour==0 and g.state==BattleGame.State.RETREAT,"lethal after fractional recovery capacity=%s slot=%s remaining=%s" % [capacity,target_slot,g.player.armour])
			g.reset_player()
			g.change_state(BattleGame.State.COMBAT)
			g.player.armour = 0.25
			g.player.shield = 0.0
			g.hit_player(capacity*100,0)
			check(g.player.armour==0 and g.state==BattleGame.State.RETREAT,"tiny real health cannot vanish from module allocation at capacity="+str(capacity))
	var live := BattleGame.new(ShipDatabase.new(),false)
	live.db.config.equipmentSocket = 10
	live.db.equipment.armour[0].para1 = 100
	live.db.equipment.shield[0].para1 = 100
	live.db.equipment.shield[0].para2 = 0.05
	live.db.equipment.shield[0].para3 = 3.0
	live.start(1,false)
	live.spawn_group()
	live.profile.unlocked = ["armour","shield"]
	live.profile.loadout.defence = [{"key":"shield","level":1,"sockets":[live.new_jewel("6",1)]},{"key":"armour","level":1}]
	live.reset_player()
	live.player.shield = 0
	live.since_hit = 0
	live.jewel_defence_times[0] = 0.0
	live.advance_jewel_repair(0.016)
	check(is_equal_approx(live.player.shield,0.004), "tenacity recovers only reduced rate during hit delay")
	live.hit_player(10,0)
	check(live.player.shield==0 and live.player.armour==90, "tiny recovered shield does not swallow the attack")
	for i in 20:
		if live.player.armour<=0:break
		live.advance_jewel_repair(0.016)
		live.hit_player(10,0)
	check(live.player.armour==0 and live.state==BattleGame.State.RETREAT, "continuous tiny regeneration cannot prevent lethal overflow")
	if FileAccess.file_exists("res://.runtime/save-fixture.json"):
		var copied := FileAccess.open("user://progress.json",FileAccess.WRITE)
		copied.store_string(FileAccess.get_file_as_string("res://.runtime/save-fixture.json"))
		copied.close()
		var saved := BattleGame.new(ShipDatabase.new(),false)
		saved.load_progress()
		saved.reset_player()
		saved.start(32,false)
		saved.spawn_group()
		saved.player.armour = 10000000.0
		saved.player.shield = 0.0
		saved.since_hit = 0.0
		saved.advance_jewel_repair(0.016)
		print("Save reproduction: max armour=",saved.stat("armour")," remaining=",saved.player.armour," shield=",saved.player.shield)
		saved.hit_player(saved.stat("armour")*100,0)
		check(saved.player.armour==0 and saved.state==BattleGame.State.RETREAT,"current save tiny remaining health must die; actual="+str(saved.player.armour))
	print("Tenacity survival: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
