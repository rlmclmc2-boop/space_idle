extends SceneTree
const Audit=preload("res://missile_audit.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.resources={"1":1e30,"2":1e30}
 g.profile.cleared=range(1,101);g.profile.highestLevel=101;g.rebuild_unlocks()
 g.profile.selectedShip="Heavy_Battleship"
 g.profile.loadout.weapons=[]
 for i in 8:g.profile.loadout.weapons.append({"key":"missile","level":150})
 g.profile.loadout.defence=[{"key":"armour","level":1},{"key":"shield","level":1}]
 g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT
 g.enemies.assign([{"uid":100,"slot":4,"x":286.0,"y":150.0,"hp":1e100,"max_hp":1e100,"armourType":2,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
 g.cooldowns[g.slot_id("weapons",0)]=0.0
 var stress=preload("res://combat_stress_fixture.gd").new()
 if not stress.configure(g,2):printerr("SMOKE fixture admission failed");quit(1);return
 var native=g.admit_native_compiled_execution("native_low_contract")
 assert(native==(OS.get_environment("PERF_SIDE")=="B"))
 Audit.game=g;Audit.enabled=true;g.event.connect(Audit.event)
 for i in 360:g.tick(1.0/60.0)
 var report=Audit.report();report.native=native
 FileAccess.open("res://.runtime/audit-smoke.json",FileAccess.WRITE).store_string(JSON.stringify(report))
 print("AUDIT_SMOKE ",JSON.stringify(report.totals)," errors=",JSON.stringify(report.errors))
 quit(0 if report.errors.is_empty() and int(report.totals.counts.get("missile_hits",0))>0 else 1)
