extends RefCounted
# Diagnostic counters only. Native membership/erase and equality remain unchanged.
var totals={}
var ticks=[]
var outside_tick={}
var current={}
var index_checks=0
var index_mismatches=0
var snapshots=0
var snapshot_members=0
func reset()->void:
 totals.clear();ticks.clear();outside_tick.clear();current.clear();index_checks=0;index_mismatches=0;snapshots=0;snapshot_members=0
func begin_tick(dt:float)->void:
 finish_tick();current={"dt":dt,"sites":{},"index_checks":0,"index_mismatches":0,"snapshots":0,"snapshot_members":0}
func finish_tick()->void:
 if not current.is_empty():ticks.append(current);current={}
func note_index(mismatch:bool)->void:
 index_checks+=1;index_mismatches+=int(mismatch)
 if not current.is_empty():current.index_checks+=1;current.index_mismatches+=int(mismatch)
func note_snapshot(count:int)->void:
 snapshots+=1;snapshot_members+=count
 if not current.is_empty():current.snapshots+=1;current.snapshot_members+=count
func note(key:String,size_value:int,hit:bool)->void:
 for target in [totals,current.sites if not current.is_empty() else outside_tick]:
  if not target.has(key):target[key]={"calls":0,"array_size_sum":0,"array_size_max":0,"hits":0,"misses":0}
  var row:Dictionary=target[key];row.calls+=1;row.array_size_sum+=size_value;row.array_size_max=maxi(int(row.array_size_max),size_value)
  if hit:row.hits+=1
  else:row.misses+=1
func contains(values:Array,value,key:String)->bool:
 var result=values.has(value);note(key,values.size(),result);return result
func identity_contains(values:Array,value,key:String)->bool:
 var result=values.any(func(enemy):return is_same(enemy,value));note(key,values.size(),result);return result
func pass_size(values:Array,key:String)->void:note(key,values.size(),true)
func erase(values:Array,value,key:String)->void:
 var count=values.size();values.erase(value);note(key,count,values.size()<count)
func report()->Dictionary:
 finish_tick()
 return {"scope":"QA only native has/erase unchanged; array_size_sum is comparison-count upper bound, not measured deep comparisons/time; no profiler; per-base-game-tick rows include partial missile-ejection steps; outside_tick captures display/setup readers separately","totals":totals,"outside_tick":outside_tick,"ticks":ticks,"index_checks":index_checks,"index_mismatches":index_mismatches,"snapshots":snapshots,"snapshot_members":snapshot_members}
