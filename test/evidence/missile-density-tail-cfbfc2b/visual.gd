extends SceneTree
class Sheet extends Node2D:
 var vfx:Script
 func _draw():
  for row in 6:
   for col in 8:
    var direction=Vector2.from_angle(float(col)*TAU/8.0+0.13)
    var age=[0.0,0.1,0.22,0.255,0.65,2.0][row]
    vfx.flight(self,Vector2(40+col*72,40+row*72),direction,age,1,1.0,true,row!=5)
  # Following command must retain the caller's original identity transform.
  draw_line(Vector2(10,450),Vector2(565,450),Color.GREEN,1.0,true)
func _initialize():call_deferred('run')
func run():
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.content_scale_size=Vector2i.ZERO
 root.size=Vector2i(1200,480)
 for i in 2:
  var node=Sheet.new();node.vfx=load('res://missile_reference.gd' if i==0 else 'res://dev/toon_ship/missile_vfx.gd')
  node.position.x=i*600;node.scale=Vector2(0.67,0.67);root.add_child(node)
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png('res://visual.png')
 quit()
