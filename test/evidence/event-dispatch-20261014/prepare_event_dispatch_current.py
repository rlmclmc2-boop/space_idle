from pathlib import Path
import shutil
r=Path('D:/CodexBuild/space_idle/stable-integration');iso=r/'test/work/battle-fix-20261013/space-battleship'
for p in (r/'space-battleship/scripts').rglob('*.gd'):shutil.copy2(p,iso/p.relative_to(r/'space-battleship'))
probe='''extends RefCounted
static var enabled:=false
static var active:=false
static var children:=0
static var listeners:Array=[]
static var manifest:Array=[]
static var costs:Dictionary={}
static var emits:Dictionary={}
static var nested_other:=0
class Listener extends RefCounted:
 var index:int
 var invoke_callback:Callable
 func deliver(kind:String,payload:Dictionary)->void:
  invoke_callback.call(kind,payload,index)
static func install(g)->void:
 var connections:Array=g.event.get_connections()
 for connection in connections:
  assert(int(connection.flags)==0,"diagnostic requires synchronous ordinary connections")
  g.event.disconnect(connection.callable)
 for connection in connections:
  var cb:Callable=connection.callable
  var obj=cb.get_object()
  var script=obj.get_script()
  var id:=listeners.size()
  var holder=Listener.new();holder.index=id;holder.invoke_callback=invoke
  var wrapper:Callable=holder.deliver
  listeners.append({"original":cb,"wrapper":wrapper,"holder":holder})
  manifest.append({"id":id,"script":script.resource_path if script!=null else "","method":str(cb.get_method()),"class":obj.get_class(),"flags":connection.flags})
  assert(g.event.connect(wrapper)==OK)
 for kind in ["hit","projectile_impact","fire","nested_other"]:
  var rows:Array=[]
  for i in listeners.size():rows.append({"calls":0,"body_inclusive_us":0,"body_exclusive_us":0,"nested_us":0,"bookkeeping_us":0,"max_body_us":0})
  costs[kind]=rows
static func uninstall(g)->void:
 assert(g.event.get_connections().size()==listeners.size(),"no listener set changes during sample")
 for listener in listeners:g.event.disconnect(listener.wrapper)
 for listener in listeners:g.event.connect(listener.original)
 listeners.clear()
static func invoke(kind:String,payload:Dictionary,id:int)->void:
 var cb:Callable=listeners[id].original
 if not active:
  cb.call(kind,payload);return
 var entry:=Time.get_ticks_usec()
 var prior_children:=children;children=0
 var start:=Time.get_ticks_usec()
 cb.call(kind,payload)
 var finish:=Time.get_ticks_usec()
 var nested:=children
 var key:=kind if kind in ["hit","projectile_impact","fire"] else "nested_other"
 if key=="nested_other":nested_other+=1
 var row:Dictionary=costs[key][id]
 row.calls+=1;row.body_inclusive_us+=finish-start;row.body_exclusive_us+=finish-start-nested;row.nested_us+=nested;row.max_body_us=maxi(row.max_body_us,finish-start)
 var end:=Time.get_ticks_usec()
 row.bookkeeping_us+=(start-entry)+(end-finish)
 children=prior_children+end-entry
static func emit_selected(g,kind:String,payload:Dictionary)->void:
 if not enabled:
  g.event.emit(kind,payload);return
 var was_active:=active;var prior_children:=children
 active=true;children=0
 var start:=Time.get_ticks_usec()
 g.event.emit(kind,payload)
 var elapsed:=Time.get_ticks_usec()-start
 if not emits.has(kind):emits[kind]={"calls":0,"inclusive_us":0,"dispatch_residual_us":0,"listener_wrapper_us":0,"nested_emit_calls":0}
 var row:Dictionary=emits[kind]
 row.calls+=1;row.inclusive_us+=elapsed;row.dispatch_residual_us+=elapsed-children;row.listener_wrapper_us+=children
 if was_active:row.nested_emit_calls+=1
 active=was_active;children=prior_children+elapsed if was_active else prior_children
static func empty_listener(_kind:String,_payload:Dictionary)->void:pass
static func calibration()->Dictionary:
 # Paused synthetic empty-listener timing only; no game events or simulation rerun.
 var saved_costs:=costs;var saved_listeners:=listeners;var saved_active:=active;var saved_children:=children
 costs={"hit":[{"calls":0,"body_inclusive_us":0,"body_exclusive_us":0,"nested_us":0,"bookkeeping_us":0,"max_body_us":0}]}
 var cb:Callable=empty_listener;listeners=[{"original":cb}]
 active=true;children=0
 var start:=Time.get_ticks_usec()
 for i in 20000:cb.call("hit",{})
 var direct:=Time.get_ticks_usec()-start
 start=Time.get_ticks_usec()
 for i in 20000:invoke("hit",{},0)
 var wrapped:=Time.get_ticks_usec()-start
 var result={"calls":20000,"direct_us":direct,"wrapped_us":wrapped,"added_us_per_call":float(wrapped-direct)/20000.0,"note":"Synthetic paused no-op wrapper calibration, not a net frame-time correction or algorithm A/B."}
 costs=saved_costs;listeners=saved_listeners;active=saved_active;children=saved_children
 return result
'''
(iso/'event_dispatch_probe.gd').write_text(probe,encoding='utf-8')
p=iso/'scripts/native_execution_session.gd';s=p.read_text(encoding='utf-8')
for kind in ['hit','projectile_impact','fire']:
 old='game.event.emit("'+kind+'",';assert old in s;s=s.replace(old,'preload("res://event_dispatch_probe.gd").emit_selected(game,"'+kind+'",')
p.write_text(s,encoding='utf-8')
s=(r/'test/evidence/shared-systems-20261014/qa_shared_systems_current.gd').read_text(encoding='utf-8')
s=s.replace('res://system_probe.gd','res://event_dispatch_probe.gd')
s=s.replace('g.event.connect(record_event);Probe.reset();Probe.enabled=true;scene.set_process(true)','g.event.connect(record_event);Probe.install(g);Probe.enabled=true;scene.set_process(true)')
s=s.replace('"cost_paths":Probe.rows,"probe_bookkeeping_us":Probe.overhead_us,','"listener_manifest":Probe.manifest,"emit_costs":Probe.emits,"listener_costs":Probe.costs,"nested_other_listener_calls":Probe.nested_other,')
s=s.replace('"source":"346c67f8856dac075cc604e21c41fe96220f78df"','"source":"e1353c97"')
s=s.replace(' FileAccess.open(', ' row.probe_calibration=Probe.calibration()\n Probe.uninstall(g)\n FileAccess.open(',1)
s=s.replace('shared-systems-current','event-dispatch-current').replace('SHARED_SYSTEMS_RESULT','EVENT_DISPATCH_RESULT')
s=s.replace('One diagnostic run, visible AI workshop throughout; no A/B and no benefit claim. Path exclusive times subtract measured child spans; probe bookkeeping can remain in ancestor exclusive cost. Existing battle fixture and 12 finite purchased AI; no database/config changes.','Single hit/impact/fire dispatch diagnostic; original synchronous listener order preserved. Listener body exclusive subtracts nested callback spans; emit residual excludes measured wrapper spans. No production changes or algorithm A/B. Necessary presentation is not removable overhead.')
(iso/'qa_event_dispatch_current.gd').write_text(s,encoding='utf-8')
print('Prepared event-only isolated probes')
