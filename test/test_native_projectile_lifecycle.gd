extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture():
 var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 assert(g.native_pipeline!=null and g.native_pipeline.has_method("begin_step"))
 g.profile.highestLevel=8;g.rebuild_unlocks();g.start(8,false);g.spawn_group()
 for e in g.enemies:e.hp=1e100;e.max_shield=0
 return g
func launch(g):
 g.fire(g.player,g.enemies[0],g.db.equip("laser",1),1,false,"laser")
 return g.projectiles.back()
func _initialize()->void:call_deferred("run")
func run()->void:
 var g=fixture();var shot=launch(g)
 check(g.native_lifecycle_allowed(),"canonical production writer activates managed store")
 g.tick_projectiles(1.0/60.0)
 check(g.native_pipeline.lifecycle_stats().managed_steps==1,"compiled managed continuous segment actually executed")
 var alias=g.projectiles;g.projectile_clear()
 check(alias.is_empty() and g.native_pipeline.lifecycle_stats().active==0,"clear preserves Array aliases and clears native members")
 shot=launch(g);var saved:Array[Dictionary]=[shot];alias=g.projectiles;g.projectile_clear();g.projectile_assign(saved)
 check(is_same(alias,g.projectiles) and is_same(alias[0],shot) and g.native_lifecycle_allowed(),"assign preserves destination aliases and registers original facade")
 g.projectile_clear()
 shot=launch(g);alias=g.projectiles;g.projectile_mark_dead(shot);g.tick_projectiles(1.0/60.0)
 check(not is_same(alias,g.projectiles) and alias.size()==1 and g.projectiles.is_empty(),"cleanup replaces Array while retained alias keeps old member")
 shot=launch(g);var equal=shot.duplicate();g.projectile_append(equal)
 check(not g.native_lifecycle_allowed(),"duplicate serial or facade takes compatibility path")
 g.projectile_erase(equal)
 check(g.projectiles.size()==1 and is_same(g.projectiles[0],equal),"erase removes first equal Dictionary, preserving distinct identity")
 var external=func(_kind,_info):pass
 g.event.connect(external);var before=g.native_pipeline.lifecycle_stats().compatibility_steps
 g.tick_projectiles(1.0/60.0)
 check(g.native_pipeline.lifecycle_stats().compatibility_steps>before,"unknown event subscriber explicitly uses original kernel")
 g.event.disconnect(external);g.projectile_clear()
 shot=launch(g);var lease=shot.motion_lease;var weak=weakref(g.native_pipeline)
 var position=lease.position();g.native_pipeline=null
 check(weak.get_ref()==null,"facade and lease do not retain lifecycle pipeline")
 check(lease.position()==position,"retained lease keeps numeric arena after store release")
 var victory=fixture();victory.rng.seed=77
 for e in victory.enemies:e.hp=0
 victory.enemies[0].hp=1;victory.group_index=victory.db.levels[victory.stage-1].groups.size()
 var killer=launch(victory);launch(victory)
 killer.motion_lease.set_position(Vector2(killer.target.x,killer.target.y))
 victory.tick_projectiles(.05)
 check(victory.native_pipeline.lifecycle_stats().managed_steps==1 and victory.projectiles.is_empty() and victory.enemies[0].hp<=0,"actual final-target death clears managed members before next snapshot projectile")
 for action in ["newborn","restore_old"]:
  var results=[]
  for use_native in [true,false]:
   var game=fixture();game.rng.seed=164772
   if not use_native:game.native_pipeline=null
   var first=launch(game);var second=launch(game)
   if use_native:first.motion_lease.set_position(Vector2(first.target.x,first.target.y))
   else:first.x=first.target.x;first.y=first.target.y
   var changed=[false];var trace=[];var born=[]
   var observer=func(kind,info):
    if kind=="projectile_impact" and not changed[0]:
     changed[0]=true;game.projectile_clear()
     var child=launch(game) if action=="newborn" else second
     if action=="restore_old":game.projectile_append(second)
     born.append(game.projectile_position(child));game.rng.randf()
    if kind=="hit":trace.append([info.uid,info.amount,info.type])
   if use_native:game.native_transaction_observer(observer)
   game.event.connect(observer);game.tick_projectiles(.05);game.event.disconnect(observer)
   if use_native:game.native_forget_observer(observer)
   check(changed[0] and game.projectiles.size()==1 and (game.projectile_position(game.projectiles[0])==born[0] if action=="newborn" else game.projectile_position(game.projectiles[0])!=born[0]),"synchronous clear/add applies before next snapshot member; newborn does not advance")
   if use_native:check(game.native_pipeline.lifecycle_stats().managed_steps==1,"mutation case executes managed kernel rather than compatibility")
   results.append([trace,str(game.rng.state),game.projectile_position(game.projectiles[0])])
  check(results[0]==results[1],"immediate hit/RNG and transaction boundary match original script")
 print("PROJECTILE LIFECYCLE: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
