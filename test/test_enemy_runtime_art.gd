extends SceneTree
## Production painter acceptance: no QA renderer or mount installation.
## RUNTIME_ART_OUTPUT=/absolute/evidence godot --path space-battleship --script /absolute/test/test_enemy_runtime_art.gd
## Use isolated XDG_DATA_HOME/XDG_CONFIG_HOME/XDG_CACHE_HOME; fixture disables saving.
const KEYS=["anchor","reactive","shielded","command"]
var checks:=0
var failures:=0
var fires:=0
var hits:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func identity_checks()->void:
 var lookup=preload("res://scripts/enemy_visual_identity.gd").new()
 var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json"))
 for key in config.ships:config.ships[key].asset_ready=true
 for key in KEYS:
  for size in range(1,7):
   for state in [["normal",false,""],["elite",false,"_elite"],["boss",true,"_boss"],["ultimate",true,"_boss"],["boss",false,""],["ultimate",false,""]]:
    check(lookup.resolve({"archetype_id":key,"armourType":1,"size":size,"combat_tier":state[0],"encounter_leader":state[1]},config)=="enemy_opening_"+key+str(state[2]),"published tier/leader identity is independent of numeric size")
  var missing:Dictionary=config.duplicate(true);missing.ships["enemy_opening_"+key+"_elite"].asset_ready=false
  check(lookup.resolve({"archetype_id":key,"armourType":1,"size":6,"combat_tier":"elite"},missing)=="enemy_opening_"+key,"unavailable ranked art falls back to ordinary hull")
 check(lookup.resolve({"archetype_id":"scout","armourType":2,"size":6,"combat_tier":"elite"},config)=="enemy_opening_scout","other archetypes keep ordinary art")
 check(lookup.resolve({"archetype_id":"anchor","armourType":2,"size":6,"combat_tier":"elite"},config)=="enemy_6","armour mismatch keeps legacy fallback")
func run()->void:
 identity_checks()
 var output:=OS.get_environment("RUNTIME_ART_OUTPUT");DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1373,883)
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];scene.music_on=false;root.add_child(scene);scene.automation_args=[]
 var g=scene.game;g.save_enabled=false;g.native_execution_auto=false;g.rng.seed=20261020
 if scene.battle_slice_runtime!=null:
  check(scene.battle_slice_runtime.close(),"close pre-existing session before isolated GDS fixture")
  scene.battle_slice_runtime=null;scene.simulation_geometry_view=null
 g.profile.onboarding.completed=true;g.profile.onboarding.dismissed=true;scene.beginner_guide.hide()
 g.profile.cleared=range(1,101);g.profile.highestLevel=101;g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.rebuild_unlocks();g.pending_unlocks.clear()
 check(g.start(1,false),"actual battle starts");g.group_index=1;g.spawn_group()
 g.profile.selectedShip="Heavy_Battleship";g.profile.loadout={"weapons":[],"defence":[{"key":"armour","level":1},{"key":"shield","level":1}]}
 for key in ["cannon","missile","laser","longLaser","cannon"]:g.profile.loadout.weapons.append({"key":key,"level":1})
 g.invalidate_stat_cache();g.reset_player();g.player.armour=1e10;g.player.shield=1e10
 scene.current_hull="Heavy_Battleship";scene.ship_view.set_hull(scene.current_hull);scene._set_reference_dimensions();scene.ship_view.set_loadout(g.weapon_entries(),g.active_slot_count("weapons"))
 var template:Dictionary=g.enemies[0].duplicate(true)
 g.event.connect(func(kind:String,_info:Dictionary):
  if kind=="fire":fires+=1
  if kind=="hit":hits+=1)
 var snapshots:Array=[];var case_index:=0
 for rank in ["elite","boss"]:
  for key in KEYS:
   g.paused=true;g.enemies.clear();scene.enemy_poses.clear();scene.fixed_layout_signature.clear()
   var encounter:Dictionary=g.db.levels[g.stage-1].groups[g.group_index-1];g.db.groups[str(int(encounter.id))].combatTier=rank;g.db.groups[str(int(encounter.id))].description=key+" "+rank
   var source:Dictionary=g.db.enemies[str(270005+KEYS.find(key))]
   var hero:Dictionary=template.duplicate(true)
   for field in ["id","equipment","dmgMultiple","armourType","size","shieldType","shieldRecovery","shieldDelay","archetype_id"]:
    hero[field]=source[field].duplicate(true) if source[field] is Array or source[field] is Dictionary else source[field]
   hero.uid=93000+case_index;hero.slot=0;hero.cooldowns=[]
   for entry in hero.equipment:hero.cooldowns.append(0.0)
   hero.combat_tier=rank;hero.encounter_leader=rank=="boss";hero.hull_scale=1.35 if hero.encounter_leader else 1.0
   hero.x=286.0;hero.y=210.0;hero.hp=1e10;hero.max_hp=1e10;hero.shield=1e10;hero.max_shield=1e10;hero.shieldRecovery=0.0
   hero.explicit_formation=true;hero.size_formation=true;hero.formation_columns=5;hero.formation_count=3;g.enemies.append(hero)
   for i in [1,2]:
    var escort:Dictionary=template.duplicate(true);escort.uid=94000+case_index*10+i;escort.slot=i;escort.archetype_id="sentry";escort.armourType=2;escort.size=6;escort.combat_tier=rank;escort.encounter_leader=false;escort.x=65.0 if i==1 else 507.0;escort.y=90.0;escort.hp=1e10;escort.max_hp=1e10;escort.shield=1e10;escort.max_shield=1e10;escort.explicit_formation=true;escort.size_formation=true;escort.formation_columns=5;escort.formation_count=3;g.enemies.append(escort)
   scene.encounter_presentation.identity="";scene.encounter_presentation.leader_uid=-1;scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
   await process_frame;await RenderingServer.frame_post_draw
   if case_index==0:
    g.paused=false
    for frame in 150:
     await process_frame
     if frame>=100 and fires>0 and hits>0:break
    check(fires>0 and hits>0,"real fire and hit in production renderer")
   g.paused=true;scene.fx_time=4.0;scene.shake=0.0
   for e in g.enemies:scene.enemy_pose(e).born=0.0
   g.projectile_clear();scene.projectile_visuals.clear();scene.floats.clear();scene.damage_pending.clear();scene.rail_events.clear();scene.missile_events.clear();scene._pulse_events.clear()
   scene.battle_layer.queue_redraw();scene.pulse_layer.queue_redraw();scene.encounter_presentation.sync(g,0.0)
   check(scene.enemy_recognition.get_script().resource_path=="res://scripts/enemy_recognition_visual.gd","production recognition painter, no QA injection")
   check(hero.equipment==source.equipment and hero.dmgMultiple==source.dmgMultiple and hero.size==source.size,"actual table equipment/damage/size retained")
   check(scene.enemy_ship_key(hero)=="enemy_opening_"+key+"_"+rank,"ranked production hull selected")
   var components:Array=scene.enemy_weapon_components(hero)
   check(components.size()==hero.equipment.size(),"one real component per real equipment in selected rows")
   var mounts:Array=[];var point:Vector2=scene.enemy_render_position(hero);var width:float=scene.enemy_render_width(hero);var rect:Rect2=scene.enemy_hull_rect(hero,width)
   var packet:Dictionary=scene.enemy_recognition_geometry(hero)
   var texture:Texture2D=scene.ship_hull_texture(scene.enemy_ship_key(hero));var used:Rect2i=texture.get_image().get_used_rect()
   var centre:Vector2=rect.position+(Vector2(used.position)+Vector2(used.size)*.5)/texture.get_size()*rect.size
   check(centre.length()<.001,"hull alpha centre remains fixed battle centre")
   for component in components:
    var before_profile:Dictionary=component.profile.duplicate(true);var before_point:Dictionary=component.hardpoint.duplicate(true)
    var before:Dictionary=scene.enemy_component_pose(hero,component).duplicate(true)
    var art:Dictionary=scene.enemy_weapon_art_pose(hero,component)
    check(not art.is_empty(),"production texture pose exists for actual gun/energy component")
    check(scene.enemy_component_pose(hero,component)==before and component.profile==before_profile and component.hardpoint==before_point,"art query leaves simulation pose/profile/hardpoint unchanged")
    var socket:Dictionary=scene.ship_visual_entry(scene.enemy_ship_key(hero)).rotating_mounts[components.find(component)]
    var axis:Vector2=(rect.position+Vector2(socket.centre_px[0],socket.centre_px[1])/texture.get_size()*rect.size).rotated(PI+scene.enemy_render_angle(hero))
    check(axis.distance_to(art.origin)<.001,"art axis at baked foundation centre")
    check(is_equal_approx(art.scale*scene.visual_config.enemy_rotating_art.housing_width_px,socket.housing_width_uv*rect.size.x),"exact07 per-base housing coverage")
    var shot={"hostile":true,"source":hero,"mount":component.owner_slot,"chain_hop":false}
    check(scene.battle_point(scene.visual_muzzle(shot)).distance_to(point+Vector2(art.muzzle))<.001,"render flash/beam emitter follows art aperture")
    mounts.append({"owner_slot":component.owner_slot,"axis":art.origin,"muzzle":art.muzzle,"scale":art.scale,"angle":art.angle})
   await process_frame;await RenderingServer.frame_post_draw
   var record=scene.retained_contacts.records[int(hero.uid)]
   if rank=="elite":
    check(record.supported,"elite uses production retained renderer")
    check(record.mounts.size()==components.size(),"retained renderer preserves actual component count")
    for mount in record.mounts:
     var art:Dictionary=scene.enemy_weapon_art_pose(hero,mount.component)
     check(mount.node.pieces.body.data.has("art") and mount.node.position.distance_to(art.origin)<.001,"retained uses same authored pivot")
     check(is_equal_approx(mount.node.rotation,art.angle-PI/2) and is_equal_approx(mount.node.pieces.body.data.art.scale,art.scale),"retained/canonical art rotation and scale agree")
   else:check(not record.supported,"boss uses production canonical painter")
   check(scene.enemy_recognition_geometry(hero).inner==packet.inner,"art leaves centre-hit recognition geometry intact")
   var geometry=preload("res://scripts/simulation_geometry_authority.gd").new();geometry.prepare(scene,g)
   var view=preload("res://scripts/simulation_geometry_view.gd").new()
   for e in g.enemies:view.descriptor(int(e.uid),geometry.display_descriptor(e))
   view.apply(geometry.display_frame(g.enemies,false));scene.simulation_geometry_view=view
   for index in components.size():
    var component=scene.enemy_weapon_components(hero)[index]
    var native_art:Dictionary=scene.enemy_weapon_art_pose(hero,component)
    var native_rect:Rect2=scene.enemy_hull_rect(hero,scene.enemy_render_width(hero))
    var socket:Dictionary=scene.ship_visual_entry(scene.enemy_ship_key(hero)).rotating_mounts[index]
    var native_axis:Vector2=(native_rect.position+Vector2(socket.centre_px[0],socket.centre_px[1])/texture.get_size()*native_rect.size).rotated(PI+scene.enemy_render_angle(hero))
    check(not native_art.is_empty() and native_art.origin.distance_to(native_axis)<.001,"native display component art exactly follows its baked foundation")
    check(native_axis.distance_to(Vector2(mounts[index].axis))<.001,"native display view and canonical art axes agree")
   scene.simulation_geometry_view=null;geometry.close({"providers":{},"spatial":g.target_spatial_source})
   await process_frame;await RenderingServer.frame_post_draw
   var filename:String=key+"-"+rank+".png";root.get_texture().get_image().save_png(output.path_join(filename))
   if rank=="boss" and key=="command":
    var original_x:float=g.player.x
    var original_anchor:Vector2=scene.stable_center
    var original_batch_anchor:Vector2=scene.battle_draw_player_position
    var turn_angles:Array=[]
    for player_x in [0.0,572.0]:
     g.player.x=player_x
     scene.stable_center=Vector2(player_x,original_anchor.y)
     # Retained foreground keeps the batch active; move its display target too.
     scene.battle_draw_player_position=scene.stable_center
     scene.battle_layer.queue_redraw()
     for r in scene.retained_contacts.records.values():r.fallback.queue_redraw()
     await process_frame;await RenderingServer.frame_post_draw
     var art:Dictionary=scene.enemy_weapon_art_pose(hero,components[0])
     turn_angles.append(art.angle)
     print("TURN ",player_x," player=",scene.player_render_position()," view=",scene.simulation_geometry_view!=null," angle=",art.angle," role=",components[0].mode()," active=",scene.battle_draw_active)
     check(Vector2(art.origin).distance_to(Vector2(mounts[0].axis))<.001,"actual aiming rotation keeps mechanical pivot fixed")
     root.get_texture().get_image().save_png(output.path_join("command-boss-aim-"+str(int(player_x))+".png"))
    g.player.x=original_x;scene.stable_center=original_anchor;scene.battle_draw_player_position=original_batch_anchor
    check(absf(float(turn_angles[0])-float(turn_angles[1]))>.1,"actual aiming responds in both directions")
   snapshots.append({"case":key+"_"+rank,"file":filename,"equipment":hero.equipment,"actor_size":hero.size,"dmgMultiple":hero.dmgMultiple,"component_count":components.size(),"fixed_bases":scene.ship_visual_entry(scene.enemy_ship_key(hero)).rotating_mounts.size(),"retained":record.supported,"mounts":mounts});case_index+=1
 var result={"fixture":"production main.tscn; actual 270005-270008 equipment/size/damage; held health and staged tier/position only; no QA art/mount/profile replacement","checks":checks,"failures":failures,"fires":fires,"hits":hits,"window_png":root.get_texture().get_image().get_size(),"snapshots":snapshots,"native_full_run":false}
 FileAccess.open(output.path_join("runtime.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("RUNTIME_ART ",JSON.stringify(result));quit(1 if failures else 0)
