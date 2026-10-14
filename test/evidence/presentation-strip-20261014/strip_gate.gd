extends RefCounted
static var mode:=0
static var sampled:=false
static var profiling:=false
static var steps:=0
static var limit:=180
static var counts:Dictionary={}
static var spans:Array=[]
static func mark(name:String)->void:
 if sampled:counts[name]=int(counts.get(name,0))+1
static func allow(name:String,threshold:int)->bool:
 if mode>=threshold:
  mark("blocked:"+name);return false
 mark("executed:"+name);return true
static func redraw(item:CanvasItem)->void:
 if mode>=2:mark("blocked:node.redraw");return
 item.queue_redraw()
static func begin()->int:
 return Time.get_ticks_usec() if profiling and sampled else 0
static func end(start:int,name:String)->void:
 if start>0:spans.append([start,Time.get_ticks_usec(),name])
