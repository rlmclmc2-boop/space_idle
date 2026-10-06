extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Policy=preload("res://qa/hyperspace_player_policy.gd")
var tested:=0
var failed:=0
func check(ok:bool,label:String)->void:
 tested+=1
 if not ok:failed+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var source:String=OS.get_environment("QA_REPAIR_SOURCE")
 var d:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source));var raw:Dictionary=d.save.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system()
 var g=Game.new(ShipDatabase.new());g.save_enabled=false;g.load_progress_data(raw)
 var p=Policy.new();var before:String=JSON.stringify(g.profile);var rng_before:String=str(g.rng.state)
 var allowed:Array=g.WEAPON_KEYS.filter(func(key):return g.content_unlocked("equipment",str(key)))
 var slots:int=g.active_slot_count("weapons");check(slots==6 and allowed.has("cannon") and allowed.has("longLaser"),"Actual34 earned hull and known unlocked counter families")
 # Visible-indicator classification fixtures; no spawned fleet or future enemy inspection.
 var mixed:Dictionary=p.visible_loadout_plan(g,allowed,{1:2,2:1},{1:1,2:2},1,3)
 check(mixed.weapons.filter(func(k):return k in ["missile","cannon"]).size()==4 and mixed.weapons.filter(func(k):return k=="longLaser").size()==2,"Repair glyph preserves initial observed resistance coverage, rather than six energy slots")
 var physical:Dictionary=p.visible_loadout_plan(g,allowed,{1:3,2:0},{1:3,2:0},1,3)
 check(physical.weapons.all(func(k):return k=="cannon"),"Pure energy protection still selects known physical counter even with repair glyph")
 check(physical.defences[0]=="armour" and physical.defences.slice(1).all(func(k):return k=="shield"),"Visible energy attacks select available shields while retaining mandatory positive armor")
 var energy:Dictionary=p.visible_loadout_plan(g,allowed,{1:0,2:3},{1:0,2:3},1,3)
 check(energy.weapons.all(func(k):return k=="longLaser") and energy.defences.all(func(k):return k=="armour"),"Visible physical protection with repairs still permits full sustained-energy/physical-defense plan")
 var restricted:Dictionary=p.visible_loadout_plan(g,["longLaser"],{1:3,2:0},{1:1,2:0},1,3)
 check(restricted.weapons.all(func(k):return k=="longLaser"),"Unknown/unavailable counter family is never invented")
 check(JSON.stringify(g.profile)==before and str(g.rng.state)==rng_before,"Visible planning changes no owned levels, funds, RNG or profile")
 var out:String=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR");FileAccess.open(out+"/repair-coverage.json",FileAccess.WRITE).store_string(JSON.stringify({"source":source,"scope":"Actual34 legal owned hull; explicit visible resistance/repair/attack indicator classification fixtures, not a battle performance or optimality proof","mixed":mixed,"physical":physical,"energy":energy,"no_model_mutation":true},"\t"))
 print("VISIBLE_REPAIR_COVERAGE ",tested," checks ",failed," failures");quit(1 if failed else 0)
