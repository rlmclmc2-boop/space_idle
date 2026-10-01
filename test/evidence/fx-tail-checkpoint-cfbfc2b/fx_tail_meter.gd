extends RefCounted
var enabled:=true
var cpu_available:=OS.has_environment("SPACE_IDLE_DIAG_THREAD_CPU_US")
var stages:Dictionary={}
var overhead_us:=0
func cpu_now()->int:
 return int(OS.get_environment("SPACE_IDLE_DIAG_THREAD_CPU_US")) if cpu_available else -1
func clear()->void:
 stages.clear();overhead_us=0
func snapshot()->Dictionary:
 return {"clock":"thread_cpu_and_wall" if cpu_available else "wall_only","record_overhead_us":overhead_us,"stages":stages.duplicate(true)}
func record(key:String,wall:int,cpu:int,shot:Dictionary,core:bool,visual:Dictionary={},ribbon:Variant=null)->void:
 var began:=Time.get_ticks_usec()
 if not stages.has(key):stages[key]={"calls":0,"wall_us":0,"cpu_us":0,"max_wall_us":-1}
 var row:Dictionary=stages[key]
 row.calls+=1;row.wall_us+=wall
 if cpu>=0:row.cpu_us+=cpu
 if wall>int(row.max_wall_us):
  row.max_wall_us=wall;row.cpu_at_max_us=cpu
  row.peak={"serial":shot.get("serial",-1),"core":core,"key":shot.get("key",""),"hostile":shot.get("hostile",false),"age":shot.get("motion_age",-1.0),"orphan":shot.get("target",{}).is_empty(),"samples":visual.get("samples",0)}
  if ribbon!=null:
   row.peak.points=ribbon.size();row.peak.zero_segments=0
   for i in range(1,ribbon.size()):
    if ribbon[i]==ribbon[i-1]:row.peak.zero_segments+=1
 overhead_us+=Time.get_ticks_usec()-began
