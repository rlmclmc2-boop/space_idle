extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func write(raw: Dictionary) -> void:
 var f:=FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE);f.store_string(JSON.stringify(raw));f.close()
func _initialize() -> void:
 var db:=ShipDatabase.new();db.config.offlineMax=0
 var seed:=BattleGame.new(db,false)
 seed.profile.cleared=range(1,41);seed.rebuild_unlocks()
 seed.profile.resources={"1":1234.0,"2":5678.0};seed.profile.jewelFragments=4321.25
 seed.profile.jewels=[{"id":"4","level":99}]
 seed.profile.loadout.weapons[0].sockets=[{"id":"1","level":99}]
 seed.profile.loadout.weapons[0].attacks=234
 seed.profile.loadout.defence[0].hits=678
 var legacy=seed.profile.duplicate(true);legacy.version=3
 for key in ["enhancementVersion","enhancementLevel","enhancementOrder","enhancementAttacks","enhancementHits"]:legacy.erase(key)
 write(legacy)
 var loaded:=BattleGame.new(db,true)
 check(loaded.profile.version==4 and loaded.profile.enhancementVersion==1,"save/schema version migration")
 check(loaded.profile.resources==seed.profile.resources and loaded.profile.cleared==seed.profile.cleared,"unrelated progress preserved")
 check(loaded.profile.jewelFragments==4321.25 and loaded.profile.jewels.is_empty(),"one-time discard retains currency without refund")
 check(not loaded.profile.loadout.weapons[0].has("sockets") and not loaded.profile.loadout.weapons[0].has("attacks") and not loaded.profile.loadout.defence[0].has("hits"),"legacy socket/history discarded")
 loaded.profile.enhancementLevel=30;loaded.profile.enhancementAttacks=2345;loaded.profile.enhancementHits=987
 loaded.set_enhancement_order("weapons",["critical","repeat","proficiency"])
 loaded.set_enhancement_branch("weapons","critical",3,"B")
 loaded.queue_enhancement_deferred("armour",12)
 loaded.save_progress()
 var again:=BattleGame.new(db,true)
 check(again.enhancement_level()==30 and again.profile.enhancementAttacks==2345 and again.profile.enhancementHits==987,"new fields save/load")
 check(again.enhancement_order("weapons")==["critical","repeat","proficiency"] and again.profile.jewelFragments==4321.25,"order/currency idempotent")
 check(again.enhancement_branch_choice("weapons","critical",3)=="B","persisted placeholder branch survives reload")
 check(again.enhancement_deferred.is_empty() and again.enhancement_buffers.is_empty(),"reload preserves existing full-health battle reset policy")
 again.profile.planets["1"].degree=400;again.planet_buildings.sync(again,"1");again.profile.planets["1"].buildings.shipyard.status="built"
 check(again.can_reforge_planet("1") and again.reforge_planet("1"),"reforge fixture ready")
 check(again.enhancement_level()==0 and again.profile.enhancementAttacks==0 and again.profile.enhancementHits==0,"reforge resets run enhancement/history")
 check(again.enhancement_order("weapons")==again.default_enhancement_order().weapons and again.profile.jewelFragments==0,"reforge resets order and fragment balance")
 check(again.enhancement_branch_choice("weapons","critical",3)=="","reforge resets placeholder choices")
 check(again.enhancement_level_bonus()==1 and again.profile.planets["1"].conquered,"conquest permanent free compensation retained")
 check(again.profile.resources==seed.profile.resources,"reforge unrelated resources preserved")
 again.save_progress() # Reforge is in-memory until the user or periodic deadline saves.
 var last:=BattleGame.new(db,true)
 check(last.enhancement_level()==0 and last.enhancement_level_bonus()==1 and last.profile.jewelFragments==0,"reforge and bonuses survive reload")
 last.profile.enhancementLevel=last.enhancement_level_limit();last.profile.jewelFragments={"m":1.0,"e":200.0};last.save_progress()
 var limit_save:=BattleGame.new(db,true)
 check(limit_save.enhancement_at_limit() and limit_save.enhancement_level()==last.enhancement_level_limit(),"technical limit exact roundtrip")
 var unspent=limit_save.profile.jewelFragments.duplicate()
 check(not limit_save.can_upgrade_enhancement() and limit_save.upgrade_enhancement(-1)==0 and limit_save.profile.jewelFragments==unspent,"MAX at limit leaves balance unchanged and never wraps")
 check(GrowthNumber.valid(limit_save.enhancement_cost(limit_save.enhancement_level_limit())),"limit-level exponential cost remains valid growth quantity")

 print("ENHANCEMENT SAVE: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
