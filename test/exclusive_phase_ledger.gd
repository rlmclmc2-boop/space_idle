extends RefCounted
# One active category at a time; nested scopes replace, never add to parents.
var enabled=false
var active="engine_render_schedule_residual"
var stack=[]
var active_function="<outside_wrappers>"
var function_stack=[]
var function_self={}
var function_categories={}
var last=0
var frame={}
var calls={}
var rows=[]
func charge()->void:
 var now=Time.get_ticks_usec()
 if enabled:
  var elapsed=now-last
  frame[active]=frame.get(active,0)+elapsed
  function_self[active_function]=function_self.get(active_function,0)+elapsed
  if not function_categories.has(active_function):function_categories[active_function]={}
  var categories:Dictionary=function_categories[active_function]
  categories[active]=categories.get(active,0)+elapsed
 last=now
func start_frame(value:bool)->void:
 enabled=value;frame={};calls={};stack=[];function_stack=[];function_self={};function_categories={};active_function="<outside_wrappers>";active="engine_render_schedule_residual";last=Time.get_ticks_usec()
func enter(category:String,key:String)->void:
 charge();stack.append(active);function_stack.append(active_function);active_function=key
 if category=="geometry_queries":
  category="geometry_authority" if active=="geometry_authority" or "geometry_authority" in stack else "geometry_display"
 if category=="numeric_queries":
  category="numeric_display"
  var ancestry=[active];var parents=stack.duplicate();parents.reverse();ancestry.append_array(parents)
  for parent in ancestry:
   if parent in ["numeric_display","ui_refresh","event_presentation","damage_layout","display_publication","draw_materialization","presentation_update"]:break
   if parent in ["simulation","numeric_combat"]:category="numeric_combat";break
 active=category
 if enabled:calls[key]=calls.get(key,0)+1
func leave()->void:
 charge();active=stack.pop_back();active_function=function_stack.pop_back()
func end_frame(index:int)->void:
 charge()
 if enabled:rows.append({"index":index,"exclusive_us":frame.duplicate(),"calls":calls.duplicate(),"function_self_us":function_self.duplicate(),"function_categories_us":function_categories.duplicate(true),"stack_balanced":stack.is_empty() and function_stack.is_empty()})
 enabled=false
func report()->Dictionary:
 var totals={};var call_totals={};var balanced=true;var self_totals={};var category_totals={}
 for row in rows:
  balanced=balanced and row.stack_balanced
  for key in row.exclusive_us:totals[key]=totals.get(key,0)+row.exclusive_us[key]
  for key in row.calls:call_totals[key]=call_totals.get(key,0)+row.calls[key]
  for key in row.function_self_us:self_totals[key]=self_totals.get(key,0)+row.function_self_us[key]
  for key in row.function_categories_us:
   if not category_totals.has(key):category_totals[key]={}
   for category in row.function_categories_us[key]:category_totals[key][category]=category_totals[key].get(category,0)+row.function_categories_us[key][category]
 var function_means={};var function_per_call={}
 for key in self_totals:
  function_means[key]=float(self_totals[key])/rows.size()
  if call_totals.has(key):function_per_call[key]=float(self_totals[key])/int(call_totals[key])
 for key in category_totals:
  for category in category_totals[key]:category_totals[key][category]=float(category_totals[key][category])/rows.size()
 var means={}
 for key in totals:means[key]=float(totals[key])/rows.size()
 return {"scope":"instrumented attribution only; exactly one active category, disjoint CPU-wall intervals; residual includes native rendering/driver/scheduling/unwrapped callbacks, NOT measured wait or GPU busy time","frames":rows.size(),"balanced":balanced,"exclusive_mean_us":means,"calls":call_totals,"function_self_mean_us":function_means,"function_self_per_call_us":function_per_call,"function_self_by_category_mean_us":category_totals,"self_scope":"Existing wrappers only; child intervals excluded. Unwrapped callees/native calls remain attributed to their caller; probe overhead included. Outside wrappers is not a function measurement.","rows":rows}
