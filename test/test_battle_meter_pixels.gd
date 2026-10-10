extends SceneTree
class Legacy extends "res://scripts/battlefield.gd":
 func battle_meter(rect:Rect2,ratio:float,color:Color)->void:
  var style:=StyleBoxFlat.new()
  style.bg_color=Color("0b1b28")
  style.set_corner_radius_all(3)
  draw_surface.draw_style_box(style,rect)
  if ratio<=0:return
  style=style.duplicate()
  style.bg_color=color
  draw_surface.draw_style_box(style,Rect2(rect.position,Vector2(rect.size.x*clampf(ratio,0,1),rect.size.y)))
func _initialize():call_deferred("run")
func run():
 var views=[]
 var owners=[]
 for old in [true,false]:
  var view=SubViewport.new();view.size=Vector2i(256,512);view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  root.add_child(view);views.append(view)
  var surface=Node2D.new();view.add_child(surface)
  var owner=Legacy.new() if old else load("res://scripts/battlefield.gd").new();owners.append(owner);owner.draw_surface=surface
  surface.draw.connect(func():
   var index=0
   for color in [Color("d9a477"),Color("64b5ff"),Color("ffaf61"),Color("c6ced2"),Color("70b8bd")]:
    for ratio in [-1.0,0.0,0.125,0.5,1.0,2.0]:
     owner.battle_meter(Rect2(12.25,8.5+index*15,180.5,5.5),ratio,color);index+=1)
 await process_frame;await RenderingServer.frame_post_draw
 var first=views[0].get_texture().get_image();var second=views[1].get_texture().get_image()
 var equal=first.get_data()==second.get_data()
 print("METER_PIXELS exact_equal=",equal," pixels=",first.get_width()*first.get_height())
 for owner in owners:owner.free()
 for view in views:view.queue_free()
 await process_frame;quit(0 if equal else 1)
