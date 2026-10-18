extends RefCounted
static var enabled:=false
static var counts:Dictionary={}
static func legacy_call(name:String)->void:
 if enabled:counts[name]=int(counts.get(name,0))+1
static func snapshot()->Dictionary:return counts.duplicate()
