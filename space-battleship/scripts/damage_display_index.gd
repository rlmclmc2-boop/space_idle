extends RefCounted
## Derived display indexes only; entries, hit history and geometry keep their owners.
var active:Dictionary={}
var pending:Dictionary={}
var slots:Dictionary={}
var ready:=false
var metrics:Dictionary={}
var metric_order:Array=[]
var metric_font:Font
var metric_builds:=0
var obstacle_builds:=0
var obstacle_view
var obstacle_revision:=-1
var obstacle_enemies:Array=[]
var obstacle_alive:Array=[]
var obstacle_padding:=Vector2.INF
var obstacles:Array[Rect2]=[]
func key(entry:Dictionary)->Array:return [entry.target,bool(entry.critical),int(entry.type)]
func add(table:Dictionary,k:Variant,entry:Dictionary)->void:
 if not table.has(k):table[k]=[]
 table[k].append(entry)
func remove(table:Dictionary,k:Variant,entry:Dictionary)->void:
 if not table.has(k):return
 var rows:Array=table[k]
 for i in rows.size():
  if is_same(rows[i],entry):rows.remove_at(i);break
 if rows.is_empty():table.erase(k)
func ensure(floats:Array,waiting:Array)->void:
 if ready:return
 ready=true
 for entry in floats:
  if entry.get("damage",false):add(active,key(entry),entry);add(slots,entry.target,entry)
 for entry in waiting:add(pending,key(entry),entry)
func find(target:String,critical:bool,category:int,clock:float)->Dictionary:
 var k:Array=[target,critical,category]
 for table in [active,pending]:
  for entry in table.get(k,[]):
   if clock-entry.born<0.2 and not entry.get("retiring",false):return entry
 return {}
func append_pending(entry:Dictionary)->void:add(pending,key(entry),entry)
func remove_pending(entry:Dictionary)->void:remove(pending,key(entry),entry)
func promote(entry:Dictionary)->void:
 remove_pending(entry);add(active,key(entry),entry);add(slots,entry.target,entry)
func remove_active(entry:Dictionary)->void:
 remove(active,key(entry),entry);remove(slots,entry.target,entry)
func clear()->void:
 active.clear();pending.clear();slots.clear();ready=false
 invalidate_metrics();obstacle_view=null;obstacle_revision=-1
 obstacle_enemies.clear();obstacle_alive.clear();obstacles.clear()
func invalidate_metrics()->void:metrics.clear();metric_order.clear()
func measure(font:Font,value:String,size_value:int)->Dictionary:
 if not is_same(font,metric_font):
  if metric_font!=null and metric_font.changed.is_connected(invalidate_metrics):metric_font.changed.disconnect(invalidate_metrics)
  metric_font=font;metric_font.changed.connect(invalidate_metrics);invalidate_metrics()
 var k:Array=[value,size_value]
 if not metrics.has(k):
  # Bounded display-only reuse across frames; no historical damage retained here.
  if metric_order.size()>=256:metrics.erase(metric_order.pop_front())
  metrics[k]={"width":font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x,"ascent":font.get_ascent(size_value),"height":font.get_height(size_value)}
  metric_order.append(k);metric_builds+=1
 return metrics[k]
func cached_obstacles(view,entities:Array,padding:Vector2)->bool:
 if view==null or not view.ready:obstacle_view=null;return false
 var unchanged:bool=is_same(obstacle_view,view) and obstacle_revision==view.applied_rows and obstacle_padding==padding and obstacle_enemies.size()==entities.size()
 if unchanged:
  for i in entities.size():
   if not is_same(obstacle_enemies[i],entities[i]) or obstacle_alive[i]!=(entities[i].hp>0):unchanged=false;break
 if unchanged:return true
 obstacle_view=view;obstacle_revision=view.applied_rows;obstacle_padding=padding
 obstacle_enemies=entities.duplicate();obstacle_alive.clear()
 for entity in entities:obstacle_alive.append(entity.hp>0)
 return false
