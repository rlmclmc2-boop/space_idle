extends SceneTree
const Names=preload("res://scripts/enemy_name_presentation.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.cleared=range(1,16);g.profile.highestLevel=16;g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 var original_row:String=JSON.stringify(g.db.enemies["56187"])
 check(Names.name_for(g.db.enemies["56187"],"56187")=="装甲旗舰","Unbound generated stage16 boss resolves to an identity rather than its authoring recommendation")
 check(Names.name_for(g.db.enemies["1087"],"1087")==UIText.data_text("enemies","1087","des"),"Existing template boss name remains consistent with generated clones")
 check(Names.name_for(g.db.enemies["1088"],"1088")=="护盾旗舰" and Names.name_for(g.db.enemies["1089"],"1089")=="重装决战舰" and Names.name_for(g.db.enemies["1090"],"1090")=="护盾决战舰","Actual shield and hull size distinguish flagship and final warship")
 check(Names.name_for(g.db.enemies["56167"],"56167")=="装甲磁轨轻型舰" and Names.name_for(g.db.enemies["56173"],"56173")=="装甲磁轨侦察艇","Physical variants use actual weapon and size rather than stale draft size tags")
 check(Names.name_for(g.db.enemies["1"],"1")==UIText.data_text("enemies","1","des"),"Existing formally named ship retains its catalog name")
 check(Names.name_for({"des":"灰港护航舰","size":6,"shield":100,"armourType":2})=="灰港护航舰","New formal names are preserved without inferring a different identity")
 var mixed:Dictionary={"des":"编排草案-normal-neutral-尺寸1","size":3,"shield":100,"equipment":[{"name":"laser_mon"},{"name":"missile-mon"}]}
 check(Names.name_for(mixed)=="护盾混装巡洋舰","Mixed weapon and shield identity uses actual data without tactical claims")
 var representative:Array=["1001","1007","1016","1017","1043","56167","1088","1089","1090","56187"]
 var clean:=true
 for id in representative:
  var display:String=Names.name_for(g.db.enemies[id],id)
  clean=clean and not display.contains("编排") and not display.contains("占优") and not display.contains("模板") and not display.contains("变体")
 check(clean,"Representative generated families never expose design instructions as identity")
 g.start(16,false);g.group_index=g.db.levels[15].groups.size()-1;g.spawn_group()
 var enemy:Dictionary=g.enemies[0];var before:=JSON.stringify(g.profile);var rng_before:int=g.rng.state
 check(int(enemy.id)==56187 and scene.encounter_leader_name(enemy)=="装甲旗舰","Real stage16 final wave uses the new battlefield name")
 check(g.boss_info()=="装甲旗舰","Discovered stage16 boss info uses the same display identity")
 var cards:Array=scene.boss_health_cards()
 check(cards.size()==1 and cards[0].label.contains("装甲旗舰") and not cards[0].label.contains("占优"),"Actual boss health card uses the same identity")
 check(scene.enemy_defence_inspector.defence_text(enemy).contains(scene.enemy_defence_inspector.resistance_text(int(enemy.armourType))),"Separate defence inspection continues to show actual resistance")
 g.manual_hyperspace.active=true
 check(scene.encounter_leader_name(enemy)==g.db.enemies["56187"].des and Names.name_for(g.db.enemies["56187"],"56187",false)==g.db.enemies["56187"].des,"Manual registry cannot resolve a coincident mainline display ID")
 g.manual_hyperspace.active=false
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before and JSON.stringify(g.db.enemies["56187"])==original_row,"Display paths leave saved state, RNG and authored enemy definition intact")
 scene.queue_free();await process_frame
 print("ENEMY IDENTITY NAMES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
