extends SceneTree
class QuietUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
class Surface extends Node2D:
 var scene
 var retained
 func _draw()->void:
  var previous=scene.draw_surface
  scene.draw_surface=self;scene.battle_draw_active=true;scene.enemy_entry_batch_active=true
  scene.battle_draw_enemy_positions.clear()
  if retained!=null:retained.sync(Vector2.ZERO,false)
  else:
   for enemy in scene.game.enemies:
    if enemy.hp>0:scene.draw_enemy_hull_and_status(enemy,Vector2.ZERO,false)
  scene.battle_draw_active=false;scene.battle_draw_enemy_positions.clear();scene.enemy_entry_batch_active=false
  scene.draw_surface=previous
var scene
var checks=0
var failures=0
func _initialize()->void:call_deferred("run")
func run()->void:
 scene=load("res://main.tscn").instantiate();scene.set_script(QuietUI)
 scene.automation_args=["--capture"];root.add_child(scene);scene.automation_args=[]
 scene.set_process(false);scene.hide()
 var g=scene.game;g.save_enabled=false;g.paused=true;g.rng.seed=1701
 g.stage=20;g.group_index=0;g.state=BattleGame.State.COMBAT;g.spawn_group()
 for enemy in g.enemies:enemy.hp=1e100;enemy.max_hp=1e100;scene.enemy_pose(enemy)
 var views=[];var surfaces=[]
 for i in 2:
  var view=SubViewport.new();view.size=Vector2i(572,960);view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);views.append(view)
  var surface=Surface.new();surface.scene=scene;view.add_child(surface);surfaces.append(surface)
  if i==1:
   surface.retained=preload("res://scripts/retained_enemy_contacts.gd").new()
   surface.add_child(surface.retained);surface.retained.setup(scene)
 for sample in 6:
  scene.fx_time=0.02 if sample==0 else 5.0+float(sample)*0.137
  if sample==3:
   for enemy in g.enemies:enemy.hp=enemy.max_hp*0.43
  if sample==4:
   for enemy in g.enemies:enemy.shield=0.0
  if sample==5:
   for enemy in g.enemies:enemy.hp=0.0
  var snapshot=JSON.stringify({"enemies":g.enemies,"player":g.player,"projectiles":g.projectiles,"rng":str(g.rng.state)})
  for surface in surfaces:surface.queue_redraw()
  await process_frame;await RenderingServer.frame_post_draw
  var a=views[0].get_texture().get_image();var b=views[1].get_texture().get_image()
  a.convert(Image.FORMAT_RGBA8);b.convert(Image.FORMAT_RGBA8)
  var left=a.get_data();var right=b.get_data();var maximum=0;var changed=0
  for index in left.size():
   var delta=absi(int(left[index])-int(right[index]));maximum=maxi(maximum,delta)
   if delta>0:changed+=1
  var painted=0
  for index in range(3,left.size(),4):
   if left[index]>0:painted+=1
  if (sample<5 and painted<100) or (sample==5 and painted!=0):failures+=1
  if snapshot!=JSON.stringify({"enemies":g.enemies,"player":g.player,"projectiles":g.projectiles,"rng":str(g.rng.state)}):failures+=1
  checks+=3
  print("PIXEL sample=",sample," channels=",left.size()," changed=",changed," maximum=",maximum," painted=",painted)
  if maximum>1:
   failures+=1;a.save_png("res://.runtime/contact-legacy-%d.png"%sample);b.save_png("res://.runtime/contact-retained-%d.png"%sample)
 for view in views:view.queue_free()
 scene.game.launch_provider=Callable();scene.game.target_provider=Callable();scene.queue_free()
 await process_frame;await process_frame
 print("CHECKS ",checks," FAILURES ",failures)
 quit(1 if failures else 0)
