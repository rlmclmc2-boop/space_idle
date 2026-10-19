extends SceneTree
## Real main scene, isolated save-disabled QA formation; no screenshot compositing.
const KEYS=["scout","sentry","interceptor","swarm","anchor","reactive","shielded","command"]
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
 await process_frame;await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 assert(image.save_png(output.path_join("base-eight-battle.png"))==OK)
 # A second actual window render provides more pixels for the wide hulls.
 root.size=Vector2i(1952,1256)
 for frame in 8:await process_frame
 await RenderingServer.frame_post_draw
 var large:=root.get_texture().get_image()
 assert(large.save_png(output.path_join("base-eight-battle-large.png"))==OK)
 var result={"fixture":"save-disabled held-health QA formation in actual main.tscn; not a natural encounter","keys":KEYS,"friendly_fires":friendly_fires,"hostile_fires":hostile_fires,"hits":hits,"native":g.native_execution!=null,"engine":Engine.get_version_info().string,"window_png":[image.get_width(),image.get_height()],"large_png":[large.get_width(),large.get_height()],"rows":rows}
 FileAccess.open(output.path_join("battle.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("ENEMY_BASE_BATTLE ",JSON.stringify(result));quit()
