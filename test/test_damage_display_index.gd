extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func state(scene)->String:
 var rows:Array=[]
 for entries in [scene.floats,scene.damage_pending]:
  var items:Array=[]
  for e in entries:
   items.append([e.target,e.critical,e.type,e.amount,e.absorbed,e.text,e.born,e.life,e.origin,e.pos,e.get("retiring",false),e.needs_origin])
  rows.append(items)
 return JSON.stringify([rows,scene.damage_history_records,scene.damage_history_head])
func trial(scene,enabled:bool)->Array:
 scene.damage_display_cache_enabled=enabled;scene.damage_display_index.clear()
 scene.floats.clear();scene.damage_pending.clear();scene.damage_history_records.clear();scene.damage_history_head=0
 scene.damage_mode=0;scene.show_damage_numbers=true
 var traces:Array=[]
 var clock:float=10.0
 for step in 180:
  var dt:float=[0.0,0.016,0.031,0.07][step%4];clock+=dt;scene.fx_time=clock
  if step in [35,65,95,125]:scene.set_damage_mode(1 if step==35 else 2 if step==65 else 0)
  for i in 9:
   var enemy:Dictionary=scene.game.enemies[i%scene.game.enemies.size()]
   scene.queue_damage_number({"player":i%5==0,"uid":enemy.uid,"type":1+i%2,"amount":12345.0+step*7+i,"absorbed":float(i%3),"critical":i%4==0})
  for entry in scene.floats:
   entry.life-=dt;entry.pos.y-=dt*12
   if entry.life<=0:scene.damage_display_index.remove_active(entry)
  scene.floats=scene.floats.filter(func(e):return e.life>0)
  scene.flush_damage_numbers(dt)
  traces.append(state(scene))
  for target in scene.damage_display_index.slots:
   check(scene.damage_display_index.slots[target].size()<=2,"index respects original two active display cap")
 return traces
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(load("res://scripts/battlefield.gd"))
 scene.automation_args=["--capture"];scene.music_on=false;root.add_child(scene);scene.set_process(false);scene.automation_args=[]
 scene.game.save_enabled=false;scene.game.paused=true;scene.game.pending_unlocks.clear()
 scene.retained_gpu_beams_enabled=false
 scene.game.start(1,false);scene.game.spawn_group();scene.game.paused=true
 scene.refresh_structure();scene.fx_time=5.0
 for enemy in scene.game.enemies:scene.enemy_render_position(enemy)
 var original=trial(scene,false);var candidate=trial(scene,true)
 check(original==candidate,"all per-frame labels, amounts, history, positions, lifetimes and grouping match original")
 check(scene.damage_history_records.size()==40,"original bounded history keeps each hit write")
 var idx=scene.damage_display_index
 var first:Dictionary=idx.measure(scene.font,"unchanged",19);var count:int=idx.metric_builds
 for i in 10:check(is_same(idx.measure(scene.font,"unchanged",19),first),"unchanged text/size reuses exact metric row")
 check(idx.metric_builds==count,"no repeated font measurement")
 scene.font.emit_changed();idx.measure(scene.font,"unchanged",19)
 check(idx.metric_builds==count+1,"same-font resource change invalidates metrics")
 var view=load("res://scripts/simulation_geometry_view.gd").new();view.ready=true
 var entity={"uid":7,"hp":1};var members:Array=[entity]
 check(not idx.cached_obstacles(view,members,Vector2.ZERO),"initial obstacle publication invalid")
 check(idx.cached_obstacles(view,members,Vector2.ZERO),"unchanged publication reused")
 members[0]=entity.duplicate();check(not idx.cached_obstacles(view,members,Vector2.ZERO),"same uid new identity invalidates")
 members[0].hp=0;check(not idx.cached_obstacles(view,members,Vector2.ZERO),"death invalidates before next geometry revision")
 view.applied_rows+=1;check(not idx.cached_obstacles(view,members,Vector2.ZERO),"new geometry row invalidates")
 check(not idx.cached_obstacles(null,members,Vector2.ZERO),"handoff to legacy never uses stale obstacles")
 idx.clear();check(not idx.ready and idx.active.is_empty() and idx.pending.is_empty() and idx.slots.is_empty(),"scene/mode reset releases all entry indexes")
 scene.queue_free();await process_frame
 print("DAMAGE_INDEX_RESULT ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
