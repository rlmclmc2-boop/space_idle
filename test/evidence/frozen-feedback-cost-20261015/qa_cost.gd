extends RefCounted
## QA-only inclusive wall clocks. Timer-off keeps identical wrappers and counts.
static var enabled:=false
static var calls:Dictionary={}
static var durations_us:Dictionary={}

static func reset()->void:
 enabled=false
 calls.clear()
 durations_us.clear()

static func begin()->int:
 return Time.get_ticks_usec() if enabled else 0

static func record(scope:String,started:int)->void:
 if enabled:durations_us[scope]=int(durations_us.get(scope,0))+Time.get_ticks_usec()-started
 calls[scope]=int(calls.get(scope,0))+1

static func report()->Dictionary:
 return {"calls":calls.duplicate(true),"durations_us":durations_us.duplicate(true)}
