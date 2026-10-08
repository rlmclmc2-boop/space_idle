extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:
 var db=ShipDatabase.new();db.config.offlineMax=0
 var groups_before=JSON.stringify(db.groups);var enemies_before=JSON.stringify(db.enemies)
 for route in ["alpha","beta","gamma","delta"]:
  var g=BattleGame.new(db,false);g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear()
  check(g.load_hyperspace_routes(),route+" production loader and reward bindings")
  check(g.start_hyperspace(route,5),route+" paid manual dispatch")
  var type:int=int(db.equip(str(g.hyperspace.config.routes[route].weapon),1).dmgtype)
  for point in 10:
   g.group_index=point;g.spawn_group()
   var label=route+" wave "+str(point+1)
   check(g.manual_hyperspace.active and not g.enemies.is_empty(),label+" actual production actors spawn")
   check(g.enemies.all(func(e):return g.enemy_resistance_type(e)!=type and int(e.armourType)!=type),label+" route weapon meets no matching armor/shield resistance")
   check(g.enemies.all(func(e):return e.equipment.size()==1),label+" dedicated single mount")
   check(g.db.ratio(5,point,"lifeRatio")==db.levels[4].lifeRatio and g.db.ratio(5,point,"atkRatio")==db.levels[4].atkRatio,label+" selected original combat scale")
   if point>=8:
    check(g.enemies.size()<=3,label+" few boss actors")
    var leader=g.enemies.reduce(func(a,e):return e if float(e.max_hp)+float(e.max_shield)>float(a.max_hp)+float(a.max_shield) else a,g.enemies[0])
    var total:float=g.enemies.reduce(func(sum,e):return sum+float(e.max_hp)+float(e.max_shield),0.)
    check((float(leader.max_hp)+float(leader.max_shield))/total>=.70,label+" one main endurance target")
    check(g.targets(type).back().uid==leader.uid,label+" screen resolves before leader under existing global targeting")
  check(g.manual_hyperspace.finish(g,false),route+" scope cleanup")
  check(is_same(g.db,db) and g.profile.hyperspace.history.is_empty(),route+" no main clear or synthetic win")
 check(JSON.stringify(db.groups)==groups_before and JSON.stringify(db.enemies)==enemies_before,"all forty leave mainline registries unchanged")
 print("DEDICATED ROUTES: %d checks, %d failures; all40 production spawns, not player acceptance"%[checks,failures]);quit(1 if failures else 0)
