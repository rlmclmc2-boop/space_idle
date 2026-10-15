extends RefCounted
## QA only: one timestamp pair per top-level function/step, never per flight.
static var enabled:=false
static var durations:Dictionary={}
static var bookkeeping_us:=0
static func reset()->void:
 durations.clear();bookkeeping_us=0;enabled=false
static func begin()->int:
 return Time.get_ticks_usec() if enabled else 0
static func finish(key:String,began:int)->void:
 if began==0:return
 var ended:=Time.get_ticks_usec()
 if not durations.has(key):durations[key]=[]
 durations[key].append(ended-began)
 bookkeeping_us+=Time.get_ticks_usec()-ended
static func report()->Dictionary:
 return {"durations_us":durations,"bookkeeping_us":bookkeeping_us}
