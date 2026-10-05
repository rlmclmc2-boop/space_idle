extends RefCounted
static func clean(value):
 if value is float and not is_finite(value):return str(value)
 if value is Array:
  var result:Array=[]
  for item in value:result.append(clean(item))
  return result
 if value is Dictionary:
  var result:Dictionary={}
  for key in value:result[key]=clean(value[key])
  return result
 return value
static func signature(g)->Dictionary:
 var p:Dictionary=g.profile.duplicate(true)
 for key in ["hightechSavedAt","chronoSavedAt","resourceSamples"]:p.erase(key)
 var result:Dictionary={"profile":p,"rng":str(g.rng.state),"galaxies":g.galaxy.save_data(),"branch_weapons":g.enhancement_branches.weapons,"branch_defenses":g.enhancement_branches.defenses,"branch_sources":g.enhancement_branches.incoming_sources}
 for key in ["stage","group_index","state","distance","player","enemies","projectiles","missile_queue","cooldowns","drops","motion_clock","pending_unlocks","since_hit","clear_timer","guard_elapsed","guard_index","guard_engaged","guard_arrived","retreat_from","retreat_target","retreat_elapsed","retreat_boss_pending","run_resources","uid","projectile_serial","main_attack_serial","attack_instance_serial","auto_gen_elapsed","resource_prune_elapsed","jewel_repeats","jewel_defence_times","jewel_defence_damage","jewel_charged","enhancement_attack_contexts","enhancement_buffers","enhancement_buffer_owners","enhancement_memory_elapsed","enhancement_defense_time","enhancement_deferred_elapsed","enhancement_deferred_tick","enhancement_deferred","enemy_shield_time","enemy_shield_hit_time"]:result[key]=g.get(key)
 return clean(result)
var timing:Dictionary={"controller_us":0,"before_tick_us":0,"game_tick_us":0,"after_tick_us":0,"state_log_us":0}
var ticks:=0
var start:=0
var state_times:Dictionary={}
var stream:FileAccess
var mode:=""
func begin(output:String,variant:String,g)->void:
 mode=variant;start=Time.get_ticks_usec();stream=FileAccess.open(output+"/stage-states.jsonl",FileAccess.WRITE)
 stream.store_line(JSON.stringify({"step":0,"state":signature(g)},"",true))
func tick(g,before_state:int,controller:int,pre:int,core:int,post:int)->void:
 if stream==null:return
 timing.controller_us+=controller;timing.before_tick_us+=pre;timing.game_tick_us+=core;timing.after_tick_us+=post;ticks+=1
 var kind:String="combat" if before_state==g.State.COMBAT else "noncombat"
 if not state_times.has(kind):state_times[kind]={"ticks":0,"wall_us":0}
 state_times[kind].ticks+=1;state_times[kind].wall_us+=pre+core+post
 if ticks%60==0:
  var now:=Time.get_ticks_usec();stream.store_line(JSON.stringify({"step":ticks,"state":signature(g)},"",true));timing.state_log_us+=Time.get_ticks_usec()-now
func finish(output:String,g)->void:
 if stream==null:return
 stream.close()
 var wall:float=float(Time.get_ticks_usec()-start)/1e6
 FileAccess.open(output+"/stage-performance.json",FileAccess.WRITE).store_string(JSON.stringify({"mode":mode,"wall_seconds":wall,"x1_seconds":float(ticks)/60.0,"x1_per_wall":float(ticks)/60.0/wall,"ticks":ticks,"timing":timing,"state_times":state_times,"final_stage":g.stage,"final_group":g.group_index,"final_rng":str(g.rng.state)},"\t"))
