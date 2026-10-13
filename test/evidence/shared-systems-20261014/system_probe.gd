extends RefCounted
static var enabled:=false
static var stack:Array=[]
static var rows:Dictionary={}
static var overhead_us:=0
static func begin(name:String)->void:
 if not enabled:return
 var t:=Time.get_ticks_usec()
 var path:=name if stack.is_empty() else str(stack[-1].path)+">"+name
 stack.append({"path":path,"start":0,"child":0})
 var now:=Time.get_ticks_usec()
 overhead_us+=now-t
 stack[-1].start=now
static func end()->void:
 if not enabled:return
 var t:=Time.get_ticks_usec()
 var node:Dictionary=stack.pop_back()
 var elapsed:int=t-int(node.start)
 if not rows.has(node.path):rows[node.path]={"calls":0,"inclusive_us":0,"exclusive_us":0,"max_us":0}
 var row:Dictionary=rows[node.path]
 row.calls+=1;row.inclusive_us+=elapsed;row.exclusive_us+=elapsed-int(node.child);row.max_us=maxi(row.max_us,elapsed)
 if not stack.is_empty():stack[-1].child+=elapsed
 overhead_us+=Time.get_ticks_usec()-t
static func reset()->void:
 assert(stack.is_empty());rows.clear();overhead_us=0
