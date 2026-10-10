extends SceneTree
class Counting extends "res://scripts/battlefield.gd":
 var scans=0
 func projectile_visual(shot:Dictionary,index:Dictionary={})->Dictionary:
  scans+=1
  return super.projectile_visual(shot,index)
class Legacy extends Counting:
 func draw_projectile_body_override(shot:Dictionary,pos:Vector2,angle:float,_known_visual:Variant=null)->bool:
  if not _is_own_missile(shot):return false
  var visual:=projectile_visual(shot)
  MISSILE_VFX.flight(draw_surface,pos,Vector2.from_angle(angle),float(shot.get("motion_age",visual.get("age",0.0))),int(shot.get("serial",0)),0.4 if missile_density>6 else 1.0,true,not shot.target.is_empty())
  return true
func _initialize():call_deferred("run")
func run():
 var views=[];var owners=[];var rows=[]
 var serial=0
 for orphan in [false,true]:
  for angle in [-PI/2,-0.2,0.7,PI]:
   for age in [0.0,0.1,0.22,0.4,0.65,1.2]:
    var shot={"key":"missile","hostile":false,"target":{} if orphan else {"x":0,"y":0},"serial":serial}
    if serial%2==0:shot.motion_age=age
    var visual={"shot":shot,"age":age}
    rows.append({"shot":shot,"visual":visual,"angle":angle,"pos":Vector2(25+(serial%8)*64,35+(serial/8)*64)})
    serial+=1
 for mode in 3:
  var view=SubViewport.new();view.size=Vector2i(512,384);view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  root.add_child(view);views.append(view)
  var surface=Node2D.new();view.add_child(surface)
  var owner=Legacy.new() if mode==0 else Counting.new();owners.append(owner);owner.draw_surface=surface;owner.missile_density=1024;owner.set_meta("standalone",mode==2)
  for row in rows:owner.projectile_visuals.append(row.visual)
  surface.draw.connect(func():
   for row in rows:owner.draw_projectile_body_override(row.shot,row.pos,row.angle,null if owner.get_meta("standalone") else row.visual))
 await process_frame;await RenderingServer.frame_post_draw
 var equal=views[0].get_texture().get_image().get_data()==views[1].get_texture().get_image().get_data()
 var indexed_scans=owners[1].scans
 # The full standalone override still resolves the legacy visual and pixels.
 var fallback=owners[2].scans==rows.size() and views[0].get_texture().get_image().get_data()==views[2].get_texture().get_image().get_data()
 print("MISSILE_INDEX_PIXELS exact_equal=",equal," pixels=",512*384," indexed_scans=",indexed_scans," legacy_scans=",owners[0].scans," fallback=",fallback)
 for owner in owners:owner.free()
 for view in views:view.queue_free()
 await process_frame;quit(0 if equal and indexed_scans==0 and fallback else 1)
