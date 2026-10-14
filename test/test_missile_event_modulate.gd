extends SceneTree
const Renderer=preload("res://scripts/retained_missile_events.gd")
const FX=preload("res://dev/toon_ship/missile_vfx.gd")
class Scene extends RefCounted:
 func battle_point(p:Vector2)->Vector2:return p
class Old extends Node2D:
 var events:Array=[]
 var clock:=1.0
 var budget:=0.45
 func _draw()->void:
  for e in events:
   var age:=clock-float(e.born);var p:Vector2=e.position
   if e.kind=="retired":
    p+=e.direction*e.speed*minf(age,e.coast_time)
    if age<e.coast_time:FX.flight(self,p,e.direction,1.0,e.serial,1.0,true,false)
    else:FX.retire(self,p,e.direction,age-e.coast_time)
   elif e.kind=="fire":FX.flash(self,p,e.direction,age,budget)
   else:FX.impact(self,p,e.direction,age,e.critical,budget,e.serial)
func _initialize()->void:call_deferred("run")
func viewport()->SubViewport:
 var v=SubViewport.new();v.size=Vector2i(256,256);v.transparent_bg=true;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(v);return v
func run()->void:
 var old=viewport();var fresh=viewport();var painter=Old.new();old.add_child(painter);var renderer=Renderer.new();fresh.add_child(renderer);var scene=Scene.new()
 var launch={"kind":"fire","born":0.98,"position":Vector2(120,120),"direction":Vector2.RIGHT,"serial":1}
 var hit={"kind":"impact","born":0.97,"position":Vector2(121,119),"direction":Vector2(0.4,-0.6),"critical":true,"serial":2}
 var retired={"kind":"retired","born":0.96,"position":Vector2(123,120),"direction":Vector2.UP,"coast_time":0.1,"speed":20.0,"serial":3}
 var rows:Array=[];var failures:=0
 for mode in range(5,6):
  var events:Array=[]
  match mode:
   0:events=[launch,hit,retired,hit,launch]
   1:events=[retired,hit,launch,retired]
   2:events=[]
   3:events=[hit,retired,launch];retired.coast_time=0.01
   4:events=[launch,hit];launch.direction=Vector2.ZERO;hit.direction=Vector2.ZERO
   5:events=[launch,hit,retired];painter.modulate=Color(0.6,0.8,0.9,0.4);renderer.modulate=painter.modulate
  var before:=events.duplicate(true);painter.events=events;painter.queue_redraw();renderer.sync(scene,events,1.0,0.45)
  if events!=before:failures+=1
  await process_frame;await RenderingServer.frame_post_draw;await process_frame;await RenderingServer.frame_post_draw;await process_frame;await RenderingServer.frame_post_draw
  var a=old.get_texture().get_image();var b=fresh.get_texture().get_image();var total:=0.0;var changed:=0;var colored:=0;var roi_error:=0.0
  for y in 256:
   for x in 256:
    var ac=a.get_pixel(x,y);var bc=b.get_pixel(x,y);var error=maxf(maxf(absf(ac.r-bc.r),absf(ac.g-bc.g)),maxf(absf(ac.b-bc.b),absf(ac.a-bc.a)))
    total+=error
    if error>2.0/255:changed+=1
    if ac.a>0.01 or bc.a>0.01:colored+=1;roi_error+=error
  var pass_case:=total/(256*256)<0.001 and changed<256*256*0.005 and (mode!=2 or colored==0) and roi_error/maxi(colored,1)<0.05
  if not pass_case:failures+=1
  rows.append({"case":mode,"mean_max_channel_error":total/(256*256),"pixels_over_2_255":changed,"colored":colored,"colored_mean_error":roi_error/maxi(colored,1),"input_unchanged":events==before,"pass":pass_case})
  a.save_png("res://.runtime/missile-modulate-ref-%d.png"%mode);b.save_png("res://.runtime/missile-modulate-new-%d.png"%mode)
 FileAccess.open("res://.runtime/missile-modulate-check.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":rows,"failures":failures}))
 print("MISSILE_MODULATE_CHECK ",JSON.stringify(rows));quit(failures)
