extends "res://qa/cached_battlefield.gd"
## Experimental QA presentation only; never change game.speed or canonical provider methods.
var force_fast:bool=OS.get_environment("QA_STAGE_VFX_FAST")=="1"
var qa_events:=0
var qa_created_entries:=0
const QA_VFX_ARRAYS=["particles","floats","pickup_effects","beam_visuals","projectile_visuals","destruction_events","missile_events","rail_events","enemy_impacts","pulse_events"]
func fast_mode_enabled()->bool:
 return force_fast or super.fast_mode_enabled()
func on_event(kind:String,info:Dictionary)->void:
 var counts:Dictionary={}
 for key in QA_VFX_ARRAYS:counts[key]=get(key).size()
 super.on_event(kind,info)
 qa_events+=1
 for key in QA_VFX_ARRAYS:qa_created_entries+=maxi(0,get(key).size()-int(counts[key]))
func _exit_tree()->void:
 var output=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR")
 if output.is_empty() or game==null:return
 FileAccess.open(output+"/qa-vfx-counts.json",FileAccess.WRITE).store_string(JSON.stringify({"experimental_fast":force_fast,"game_speed":game.speed,"event_calls":qa_events,"retained_vfx_entries_created":qa_created_entries,"scope":"Net positive per-event container changes; not internal temporary allocations or GPU time"},"\t"))
