extends SceneTree
const DB=preload("res://scripts/database.gd")
const PULSE=preload("res://dev/toon_ship/pulse_vfx.gd")
const MISSILE=preload("res://dev/toon_ship/missile_vfx.gd")
const RAIL=preload("res://dev/toon_ship/rail_vfx.gd")
const BEAM=preload("res://dev/toon_ship/continuous_beam_vfx.gd")
class Grid extends Node2D:
 var db=DB.new()
 var rail=RAIL.new()
 var font=SystemFont.new()
 func _draw()->void:
  draw_rect(Rect2(Vector2.ZERO,Vector2(1370,790)),Color("102638"))
  draw_string(font,Vector2(25,36),"PRODUCTION WEAPON VFX  |  paid evolution Lv.20 - 200",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("eef6ff"))
  var names=["PULSE","MISSILE","RAIL","LONG LASER"]
  for row in 4:
   var top:=60.0+float(row)*177.0
   draw_string(font,Vector2(24,top+20),names[row],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("c6dbe9"))
   for i in 10:
    var x:=24.0+float(i)*134.0
    var area:=Rect2(Vector2(x,top+29),Vector2(126,132))
    draw_rect(area,Color("19354b"))
    draw_rect(area,Color("53758d"),false,1.0)
    var level: int=(i+1)*20
    var tint:Color=Color(str(db.data.equipment_evolution.visual_palette[i]))
    tint.a=clampf(float(db.data.equipment_evolution.visual_strength_start)+float(db.data.equipment_evolution.visual_strength_per_tier)*float(i+1),0.0,1.0)
    draw_rect(Rect2(Vector2(x+6,top+35),Vector2(15,8)),tint)
    draw_string(font,Vector2(x+30,top+44),"Lv.%d"%level,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e8f2f9"))
    var point:=Vector2(x+63,top+104)
    match row:
     0:PULSE.flight(self,point,Vector2.UP,tint)
     1:MISSILE.flight(self,point,Vector2.UP,0.9,level,1.0,true,true,tint)
     2:
      rail.flash(self,point+Vector2(0,20),Vector2.UP,0.005,1.0,tint)
      rail.impact(self,point-Vector2(0,20),Vector2.UP,0.02,true,1.0,tint)
     3:BEAM.active(self,point+Vector2(0,43),point-Vector2(0,35),0.8,5.0,0.8,0.4,tint)
func _initialize()->void:
 var viewport:=SubViewport.new()
 viewport.size=Vector2i(1370,790)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var grid=Grid.new()
 viewport.add_child(grid)
 grid.queue_redraw()
 await process_frame
 await RenderingServer.frame_post_draw
 var output="res://.runtime/visual-tiers-20-200.png"
 var error=viewport.get_texture().get_image().save_png(output)
 print("VISUAL_TIERS_SAVED ",output," error=",error)
 quit()
