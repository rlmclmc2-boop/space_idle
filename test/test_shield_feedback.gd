extends SceneTree
class UI extends "res://scripts/battlefield.gd":
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func create_battle_game(_persist:bool)->BattleGame:
  var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
  g.stat_cache_enabled=true;g.invalidate_stat_cache()
  db=g.db;g.native_execution_auto=false
  g.launch_provider=_prototype_launch_pose;g.drone_launch_provider=_prototype_drone_launch_pose
  g.target_provider=_prototype_target_point;g.rail_geometry_provider=_rail_geometry;g.rail_target_point_provider=entity_render_position
  g.enable_compiled_combat_rules()
  return g
var checks:int=0
var failures:int=0
var results:Array=[]
func check(value:bool,message:String)->void:
 checks+=1
 if not value:failures+=1;printerr("FAIL ",message)
func _initialize()->void:call_deferred("run")
func run()->void:
 for native in ([true] if "--native-only" in OS.get_cmdline_user_args() else [false,true]):
  var scene=load("res://main.tscn").instantiate();scene.set_script(UI);scene.automation_args=["--capture"];scene.music_on=false
  root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
  var g=scene.game;g.save_enabled=false;g.rng.seed=1975;g.profile.onboarding.completed=true;scene.beginner_guide.hide();g.pending_unlocks.clear()
  g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.profile.selectedShip="Heavy_Battleship"
  g.profile.loadout={"weapons":[{"key":"laser","level":1}],"defence":[{"key":"armour","level":150},{"key":"shield","level":1}]}
  g.invalidate_stat_cache();g.reset_player();g.hit_player(GrowthNumber.subtract(g.player.shield,1),0);scene.player_hit_at=-100.0;g.state=BattleGame.State.COMBAT;g.spawn_group()
  for enemy in g.enemies:enemy.hp=1e100;enemy.max_hp=1e100
  scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
  if native:
   print("SHIELD_NATIVE_COMPILE ",preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_rich15_layer2").get("error",""))
   check(g.admit_native_compiled_execution("native_rich15_layer2"),"native admission")
   g.native_execution_auto=true
   check(scene.attach_native_display(),"native display")
  var observed:Array=[]
  var callback=func(kind:String,info:Dictionary):
   if kind=="hit" and bool(info.get("player",false)):observed.append({"clock":scene.fx_time,"shield":GrowthNumber.compare(g.player.shield,0),"impact_at":scene.player_hit_at})
  g.event.connect(callback)
  var depleted=false;var held_time=0.0
  for step in 900:
   scene._process(1.0/60.0)
   if GrowthNumber.compare(g.player.shield,0)==0 and scene.player_hit_at>-99:
    depleted=true;held_time=scene.player_hit_at;break
  check(depleted,"actual incoming attack depleted shield "+str(native))
  check(scene.ship_view.shield.visible,"depletion retains real hit flash "+str(native))
  check(float(scene.ship_view.shield_material.get_shader_parameter("impact_strength"))>0.0,"positive shader strength")
  for display_frame in 3:
   await process_frame;await RenderingServer.frame_post_draw
  var image_on=root.get_texture().get_image()
  image_on.save_png("res://.runtime/shield-depletion-"+str(native)+".png")
  scene.ship_view.shield.visible=false
  for display_frame in 3:
   await process_frame;await RenderingServer.frame_post_draw
  var image_off=root.get_texture().get_image()
  image_off.save_png("res://.runtime/shield-hidden-"+str(native)+".png")
  var changed=0;var maximum=0.0
  for y in image_on.get_height():
   for x in image_on.get_width():
    var a=image_on.get_pixel(x,y);var b=image_off.get_pixel(x,y)
    var delta=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
    maximum=maxf(maximum,delta)
    if delta>0.04:changed+=1
  check(changed>100,"actual shield flash changes visible framebuffer pixels")
  print("SHIELD_PIXELS native=",native," changed=",changed," maximum=",maximum," opacity=",scene.ship_view.shield_material.get_shader_parameter("shield_opacity"))
  scene.ship_view.shield.visible=true
  var original_clock=scene.fx_time;var original_strength=scene.ship_view.shield_material.get_shader_parameter("impact_strength")
  g.paused=true
  for ignored in 4:scene._process(1.0/60.0)
  check(scene.fx_time==original_clock,"pause freezes shield clock")
  check(scene.ship_view.shield_material.get_shader_parameter("impact_strength")==original_strength,"pause preserves flash")
  g.paused=false
  for ignored in 30:scene._process(1.0/60.0)
  check(GrowthNumber.compare(g.player.shield,0)==0,"shield remains depleted")
  check(not scene.ship_view.shield.visible,"depleted shield flash expires")
  check(scene.player_hit_at==held_time,"armour-only hits do not regenerate shield flash")
  results.append({"native":native,"incoming_hits":observed,"depleted":depleted,"last_impact":scene.player_hit_at})
  g.event.disconnect(callback)
  g.begin_retreat();scene.queue_free();await process_frame;await process_frame
 FileAccess.open("res://.runtime/shield-feedback-check.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":results}))
 print("SHIELD_FEEDBACK_CHECK checks=",checks," failures=",failures);quit(failures)
