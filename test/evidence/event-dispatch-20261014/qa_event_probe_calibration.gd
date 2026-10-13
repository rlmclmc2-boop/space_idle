extends SceneTree
const Probe=preload("res://event_dispatch_probe.gd")
class Hub extends RefCounted:
 signal event(kind:String,payload:Dictionary)
class Empty extends RefCounted:
 func deliver(_kind:String,_payload:Dictionary)->void:pass
func _initialize()->void:
 call_deferred("run")
func run()->void:
 var data:Dictionary={}
 for count in [6,10]:
  var hub=Hub.new();var holders:Array=[]
  for i in count:
   var listener=Empty.new();holders.append(listener);hub.event.connect(listener.deliver)
  var payload:Dictionary={"x":1.0,"y":1.0,"amount":1.0}
  for i in 1000:hub.event.emit("hit",payload)
  var start:=Time.get_ticks_usec()
  for i in 20000:hub.event.emit("hit",payload)
  var direct:=Time.get_ticks_usec()-start
  var result={"emits":20000,"listeners":count,"direct_us":direct,"direct_us_per_emit":float(direct)/20000.0}
  if count==10:
   Probe.install(hub);Probe.enabled=true
   start=Time.get_ticks_usec()
   for i in 20000:Probe.emit_selected(hub,"hit",payload)
   result.wrapped_us=Time.get_ticks_usec()-start
   result.added_us_per_emit=float(result.wrapped_us-direct)/20000.0
   result.emit_costs=Probe.emits.duplicate(true);result.listener_costs=Probe.costs.duplicate(true)
   Probe.enabled=false;Probe.uninstall(hub)
  data[str(count)]=result
 data.note="Separate paused no-op probe calibration only, no battle replay or algorithm A/B. Same Godot binary; headless CPU microcalibration. Six empty callbacks bound dispatch work proposed for removal, conservatively charging complete broadcast overhead. Not an accepted whole-frame savings measurement."
 FileAccess.open("res://.runtime/event-probe-calibration.json",FileAccess.WRITE).store_string(JSON.stringify(data))
 print("PROBE_CALIBRATION ",data["6"].direct_us_per_emit," ",data["10"].direct_us_per_emit," extra ",data["10"].added_us_per_emit)
 quit()
