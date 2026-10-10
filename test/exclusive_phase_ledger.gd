extends RefCounted
# One active category at a time; nested scopes replace, never add to parents.
var enabled=false
var active="engine_render_schedule_residual"
var stack=[]
var last=0
var frame={}
var calls={}
var rows=[]
func charge()->void:
 var now=Time.get_ticks_usec()
 if enabled:frame[active]=frame.get(active,0)+now-last
 last=now
func start_frame(value:bool)->void:
 enabled=value;frame={};calls={};stack=[];active="engine_render_schedule_residual";last=Time.get_ticks_usec()
func enter(category:String,key:String)->void:
 charge();stack.append(active)
 if category=="geometry_queries":
  category="geometry_authority" if active=="geometry_authority" or "geometry_authority" in stack else "geometry_display"
 if category=="numeric_queries":
  category="numeric_combat" if active=="simulation" or "simulation" in stack else "numeric_display"
 active=category
 if enabled:calls[key]=calls.get(key,0)+1
func leave()->void:
 charge();active=stack.pop_back()
func end_frame(index:int)->void:
 charge()
 if enabled:rows.append({"index":index,"exclusive_us":frame.duplicate(),"calls":calls.duplicate(),"stack_balanced":stack.is_empty()})
 enabled=false
func report()->Dictionary:
 var totals={};var call_totals={};var balanced=true
 for row in rows:
  balanced=balanced and row.stack_balanced
  for key in row.exclusive_us:totals[key]=totals.get(key,0)+row.exclusive_us[key]
  for key in row.calls:call_totals[key]=call_totals.get(key,0)+row.calls[key]
 var means={}
 for key in totals:means[key]=float(totals[key])/rows.size()
 return {"scope":"instrumented attribution only; exactly one active category, disjoint CPU-wall intervals; residual includes native rendering/driver/scheduling/unwrapped callbacks, NOT measured wait or GPU busy time","frames":rows.size(),"balanced":balanced,"exclusive_mean_us":means,"calls":call_totals,"rows":rows}
