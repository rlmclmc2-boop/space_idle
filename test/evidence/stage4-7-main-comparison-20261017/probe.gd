extends RefCounted
static var active:=false
static var effects:Dictionary={}
static func effect(key:String,count:int=1)->void:
 if active:effects[key]=int(effects.get(key,0))+count
static var spans:Array=[]
static var stack:Array=[]
static var next_id:=0
static var roots_visited:=0
static var policy_changes:=0
static var bookkeeping_us:=0
static func begin(name:String)->Array:
 var t:=Time.get_ticks_usec()
 var id:=next_id
 next_id+=1
 var row:Array=[id,stack.back() if not stack.is_empty() else -1,name,0,0]
 stack.append(id)
 row[3]=Time.get_ticks_usec()
 bookkeeping_us+=int(row[3])-t
 return row
static func finish(row:Array)->void:
 var t:=Time.get_ticks_usec()
 row[4]=t
 assert(stack.pop_back()==row[0])
 spans.append(row)
 bookkeeping_us+=Time.get_ticks_usec()-t
static func reset()->void:
 assert(stack.is_empty())
 spans.clear();next_id=0;roots_visited=0;policy_changes=0;bookkeeping_us=0
