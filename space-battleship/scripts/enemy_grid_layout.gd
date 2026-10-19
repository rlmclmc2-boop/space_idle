extends RefCounted
## Display-only allocation. Never writes an actor or changes encounter capacity.
const COLUMNS:=5
const ROWS:=3
# Current maximum own hull + five weapons + shield begins at Y605.4.
# End at400 to preserve the existing192-unit combat gap with idle margin.
const AREA:=Rect2(0,0,572,400)
const INSET:=Vector4(12,42,12,12) # left, top (caption+shield+health+gap), right, bottom
static func insets(enemy:Dictionary)->Vector4:
 return Vector4(12,60,12,12) if bool(enemy.get("encounter_leader",false)) else INSET
static func footprint(enemy:Dictionary)->Vector2i:
 if bool(enemy.get("encounter_leader",false)):return Vector2i(3,2)
 return Vector2i(2,2) if int(enemy.get("size",1))>=4 else Vector2i.ONE
static func pack(enemies:Array,front_boss:=false)->Dictionary:
 var result={"placements":{},"footprints":{},"overflow":false,"required_cells":0,"area":AREA}
 var actors=enemies.duplicate()
 actors.sort_custom(func(a,b):
  var aa:=footprint(a);var bb:=footprint(b)
  if aa.x*aa.y!=bb.x*bb.y:return aa.x*aa.y>bb.x*bb.y
  return int(a.slot)<int(b.slot))
 for enemy in actors:
  var span:=footprint(enemy);result.required_cells+=span.x*span.y
  result.footprints[int(enemy.uid)]=span
 result.overflow=result.required_cells>COLUMNS*ROWS or not _place(actors,0,[],result.placements,front_boss)
 # Atomic fallback: never mix grid/legacy positions, hide an actor, or shrink
 # an approved footprint. Backtracking also handles boss+elite side by side.
 if result.overflow:result.placements.clear()
 return result
static func _place(actors:Array,cursor:int,occupied:Array,placements:Dictionary,front_boss:bool)->bool:
 if cursor==actors.size():return true
 var enemy:Dictionary=actors[cursor];var span:=footprint(enemy)
 var rows:Array=range(ROWS-span.y+1)
 if front_boss and span.x==3:rows.reverse()
 var columns:Array=range(COLUMNS-span.x+1)
 if span.x>1:columns.sort_custom(func(a,b):
  var da:=absf(a+span.x*.5-COLUMNS*.5);var db:=absf(b+span.x*.5-COLUMNS*.5)
  return a<b if da==db else da<db)
 for row in rows:
  for col in columns:
   var box:=Rect2i(Vector2i(col,row),span);var free:=true
   for other in occupied:
    if box.intersects(other):free=false;break
   if not free:continue
   occupied.append(box);placements[int(enemy.uid)]=box
   if _place(actors,cursor+1,occupied,placements,front_boss):return true
   occupied.pop_back();placements.erase(int(enemy.uid))
 return false
static func valid_for(plan:Dictionary,enemies:Array)->bool:
 if plan.is_empty():return false
 for enemy in enemies:
  if plan.get("footprints",{}).get(int(enemy.uid),Vector2i.ZERO)!=footprint(enemy):return false
 return true
static func cell_rect(plan:Dictionary,enemy:Dictionary)->Rect2:
 var box:Rect2i=plan.get("placements",{}).get(int(enemy.uid),Rect2i())
 if box.size==Vector2i.ZERO:return Rect2()
 var step:Vector2=AREA.size/Vector2(COLUMNS,ROWS)
 return Rect2(AREA.position+Vector2(box.position)*step,Vector2(box.size)*step)
static func body_rect(plan:Dictionary,enemy:Dictionary)->Rect2:
 var cell:=cell_rect(plan,enemy)
 if cell.size==Vector2.ZERO:return cell
 var padding:=insets(enemy)
 return Rect2(cell.position+Vector2(padding.x,padding.y),cell.size-Vector2(padding.x+padding.z,padding.y+padding.w))
static func fit_scale(opaque:Vector2,available:Vector2,angle:float)->float:
 # Reserve the actual rotated AABB, preserving the source aspect exactly.
 var c:=absf(cos(angle));var s:=absf(sin(angle))
 var rotated:=Vector2(opaque.x*c+opaque.y*s,opaque.x*s+opaque.y*c)
 return minf(available.x/maxf(rotated.x,.001),available.y/maxf(rotated.y,.001))
