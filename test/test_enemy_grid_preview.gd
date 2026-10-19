extends SceneTree
## Preview-only ruler on the unchanged actual battle. No production fit/config edits.
const KEYS=["scout","sentry","interceptor","swarm","anchor","reactive","shielded","command"]
class GridRuler extends Node2D:
 var area:=Rect2(0,0,572,499.2)
 var physical_cell:=Vector2.ZERO
 func _draw()->void:
  var face:=ThemeDB.fallback_font
  draw_rect(area,Color(0.1,0.8,0.9,0.025))
  for col in 6:
   var x:float=area.position.x+area.size.x*col/5.0
   draw_line(Vector2(x,area.position.y),Vector2(x,area.end.y),Color(0.2,0.95,1,0.85),1.5,true)
  for row in 4:
   var y:float=area.position.y+area.size.y*row/3.0
   draw_line(Vector2(area.position.x,y),Vector2(area.end.x,y),Color(0.2,0.95,1,0.85),1.5,true)
  for row in 3:
   for col in 5:
    var p:Vector2=area.position+Vector2(col*area.size.x/5.0+6,row*area.size.y/3.0+18)
    draw_string_outline(face,p,str(row*5+col+1),HORIZONTAL_ALIGNMENT_LEFT,-1,16,4,Color("10202d"))
    draw_string(face,p,str(row*5+col+1),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("9cf7ff"))
  var labels:Array=["5 x 3 | cell 114.4 x 166.4 logical","PNG cell %.1f x %.1f px"%[physical_cell.x,physical_cell.y]]
  for i in labels.size():
   var p:=Vector2(8,area.end.y+24+22*i)
   draw_string_outline(face,p,labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,17,5,Color("10202d"))
   draw_string(face,p,labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("b8fbff"))
var friendly_fires:=0
var hostile_fires:=0
var hits:=0
func _initialize()->void:call_deferred("run")
func run()->void:
 var output:=OS.get_environment("ENEMY_BASE_OUTPUT");assert(not output.is_empty())
 DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1373,883)
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);scene.automation_args=[]
 var g=scene.game;g.save_enabled=false;g.native_execution_auto=false;g.rng.seed=81019
 g.profile.onboarding.completed=true;g.profile.onboarding.dismissed=true;scene.beginner_guide.hide()
 g.profile.selectedShip="Frigate";g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.loadout={"weapons":[{"key":"laser","level":1}],"defence":[{"key":"armour","level":1}]}
 g.invalidate_stat_cache();g.reset_player();g.player.armour=1e8
 scene.ship_view.set_hull("Frigate");scene.current_hull="Frigate";scene._set_reference_dimensions();scene.ship_view.set_loadout(g.weapon_entries(),g.active_slot_count("weapons"))
 assert(g.start(1,false));g.group_index=1;g.spawn_group();g.player.armour=1e8
 var template:Dictionary=g.enemies[0].duplicate(true);g.enemies.clear()
 for i in KEYS.size():
  var enemy:Dictionary=template.duplicate(true)
  enemy.uid=81000+i;enemy.slot=i;enemy.archetype_id=KEYS[i];enemy.armourType=2 if i<2 else 1;enemy.shieldType=1
  enemy.size=1 if i<4 else 2 if i<6 else 3
  enemy.x=90.0+130.0*(i%4);enemy.y=130.0+130.0*(i/4)
  enemy.hp=1e8;enemy.max_hp=1e8;enemy.shield=0.0;enemy.max_shield=0.0;enemy.shieldRecovery=0.0
  enemy.equipment=[{"name":"laser_mon"}];enemy.cooldowns=[0.0]
  enemy.explicit_formation=true;enemy.formation_columns=4;enemy.formation_count=8;enemy.size_formation=true
  g.enemies.append(enemy)
 g.event.connect(func(kind:String,info:Dictionary):
  if kind=="fire":
   if info.get("shot",{}).get("hostile",false):hostile_fires+=1
   else:friendly_fires+=1
  if kind=="hit":hits+=1)
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
 for frame in 160:
  await process_frame
  if frame>=110 and friendly_fires>0 and hostile_fires>0 and hits>0:break
 assert(friendly_fires>0 and hostile_fires>0 and hits>0,"Actual combat did not fire and settle damage")
 var rows:Array=[]
 for enemy in g.enemies:
  var key:String=scene.enemy_ship_key(enemy)
  assert(key=="enemy_opening_"+str(enemy.archetype_id),"Archetype fell back")
  var texture:Texture2D=scene.ship_hull_texture(key)
  var used:Rect2i=texture.get_image().get_used_rect()
  var rect:Rect2=scene.enemy_hull_rect(enemy,scene.enemy_render_width(enemy))
  var centre:Vector2=rect.position+(Vector2(used.position)+Vector2(used.size)*.5)/texture.get_size()*rect.size
  assert(centre.length()<0.001,"Display alpha centre left combat centre")
  rows.append({"archetype":enemy.archetype_id,"visual_key":key,"texture":scene.visual_config.ships[key].texture,"geometry_texture":scene.visual_config.ships[key].geometry_texture,"centre_error":centre.length(),"position":scene.enemy_render_position(enemy),"width":scene.enemy_render_width(enemy)})
 scene.game.paused=true
 var ruler:=GridRuler.new();ruler.z_index=100;scene.battle_clip.add_child(ruler)
 await process_frame;await RenderingServer.frame_post_draw
 var first:=root.get_texture().get_image()
 var transform:Transform2D=root.get_final_transform()*scene.battle_clip.get_global_transform_with_canvas()
 var raster_factor:=Vector2.ONE # get_final_transform already maps canvas to PNG pixels
 var origin:Vector2=(transform*ruler.area.position)*raster_factor
 var end:Vector2=(transform*ruler.area.end)*raster_factor
 var physical_size:Vector2=end-origin
 ruler.physical_cell=physical_size/Vector2(5,3);ruler.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 assert(image.save_png(output.path_join("enemy-area-grid-5x3.png"))==OK)
 var result={"baseline":"02725575","production_changes":false,"hull_size_changes":false,"grid_only_preview":true,"fixture":"same eight actors and sizes as previous actual main-scene QA preview; ruler only","friendly_fires":friendly_fires,"hostile_fires":hostile_fires,"hits":hits,"engine":Engine.get_version_info().string,"native":g.native_execution!=null,"window_png":[image.get_width(),image.get_height()],"battle_logical":[572,960],"area_logical":{"x":0,"y":0,"width":572,"height":499.2,"end_y":499.2},"cell_logical":[114.4,166.4],"area_png":{"x":origin.x,"y":origin.y,"width":physical_size.x,"height":physical_size.y},"cell_png":[ruler.physical_cell.x,ruler.physical_cell.y],"boundary_basis":"Existing enemy band: battle clip top0 to fifteen-contact fixed_rows frontline=BATTLE_VIEW_SIZE.y*0.52=499.2. Layout top100 is a centre inset within this band, retained for meters/status; x uses full battle clip width. Preview ruler only, not new ship footprint/capacity rules.","rows":rows}
 FileAccess.open(output.path_join("grid-measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("ENEMY_GRID_PREVIEW ",JSON.stringify(result));quit()
