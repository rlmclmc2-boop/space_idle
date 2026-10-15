extends SceneTree
## Existing checkpoint API in an isolated no-save profile; no simulated damage or VFX injection.
var scene
var out:String
var evidence={"native_extension":false,"transitions":[],"combat":[],"texture_rids":[],"render_state_checks":0}
func _initialize()->void:call_deferred("run")
func refresh_guides(node:Node)->void:
 var script=node.get_script()
 if script!=null and str(script.resource_path).ends_with("beginner_guide.gd"):node.call("refresh")
 for child in node.get_children():refresh_guides(child)
func fresh_scene()->void:
 var prior=scene
 scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false);scene.capture_frame=-10000
 scene.game.save_enabled=false;scene.game.profile.highestLevel=10
 if prior!=null:prior.queue_free()
func checkpoint(stage:int,combat:bool)->Dictionary:
 var level:Dictionary=scene.db.levels[stage-1]
 var index:int=maxi(0,level.groups.size()-2)
 return {"distance":float(level.groups[index].position)*float(level.length) if combat else float(level.length),"groupIndex":index+1 if combat else level.groups.size(),"state":scene.game.State.COMBAT if combat else scene.game.State.LEVEL_CLEAR,"guardArrived":false,"retreatBossPending":false}
func restore(stage:int,combat:bool)->void:
 assert(scene.game.start(stage,false,checkpoint(stage,combat)))
 scene.game.profile.onboarding.completed=true;scene.game.profile.onboarding.dismissed=true
 scene.refresh_structure();refresh_guides(scene)
func screenshot(path:String)->void:
 var before_enemies=scene.game.enemies.duplicate(true)
 var before_shots=scene.game.projectiles.duplicate(true)
 var before_distance=scene.game.distance;var before_rng=scene.game.rng.state
 scene.refresh_draw_layers(0.0);scene.stars_layer.queue_redraw();scene.battle_layer.queue_redraw()
 await process_frame
 await RenderingServer.frame_post_draw
 assert(scene.game.enemies==before_enemies and scene.game.projectiles==before_shots and scene.game.distance==before_distance and scene.game.rng.state==before_rng)
 evidence.render_state_checks+=1
 root.get_texture().get_image().save_png(path)
func run()->void:
 out=OS.get_environment("OPENING_REVIEW_DIR")
 scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false);scene.capture_frame=-10000
 scene.game.save_enabled=false
 # Only this temporary profile's access gate, never persisted or shipped as gameplay data.
 scene.game.profile.highestLevel=10
 root.size=Vector2i(1373,883)
 evidence.native_extension=ClassDB.class_exists("SpaceCombatPresentation")
 for texture in scene.OPENING_SCENERY:evidence.texture_rids.append(texture.get_rid().get_id())
 for stage in [2,5,9]:
  restore(stage,false)
  var entry={"from":stage,"to":stage+1,"checkpoint":checkpoint(stage,false),"advance_tick":-1}
  var frames="/tmp/opening-v2/runtime-transition-%d"%stage;DirAccess.make_dir_recursive_absolute(frames)
  await screenshot(out+"/transition-%d-end.png"%stage)
  for tick in 210:
   scene._process(1.0/60.0)
   if scene.game.stage==stage+1 and entry.advance_tick<0:
    entry.advance_tick=tick+1
    await screenshot(out+"/transition-%d-start.png"%(stage+1))
   if tick%6==0:await screenshot(frames+"/%03d.png"%(tick/6))
  entry.end_stage=scene.game.stage;entry.end_distance=scene.game.distance
  assert(entry.advance_tick>=0 and entry.end_stage==stage+1)
  evidence.transitions.append(entry)
 for stage in [3,6,7,10]:
  # Separate temporary sessions prevent a prior encounter toast appearing in the next sample.
  fresh_scene()
  await process_frame
  restore(stage,true)
  var entry={"stage":stage,"checkpoint":checkpoint(stage,true),"initial_enemy_count":scene.game.enemies.size(),"max_projectiles":0,"frames":40,"dt":1.0/60.0}
  var frames="/tmp/opening-v2/runtime-combat-%d"%stage;DirAccess.make_dir_recursive_absolute(frames)
  await screenshot(out+"/combat-%d-entry.png"%stage)
  for tick in 120:
   scene._process(1.0/60.0)
   entry.max_projectiles=maxi(entry.max_projectiles,scene.game.projectiles.size())
   if tick%3==0:await screenshot(frames+"/%03d.png"%(tick/3))
   if tick in [11,59,119]:await screenshot(out+"/combat-%d-t%03d.png"%[stage,tick+1])
  entry.end_state=scene.game.state;entry.end_enemy_count=scene.game.enemies.size()
  evidence.combat.append(entry)
 var final_rids=[]
 for texture in scene.OPENING_SCENERY:final_rids.append(texture.get_rid().get_id())
 evidence.background_rids_stable=final_rids==evidence.texture_rids
 assert(evidence.background_rids_stable)
 var file=FileAccess.open(out+"/runtime-validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(evidence,"\t"))
 print("REAL_MAIN_CAPTURE_OK / three automatic transitions / four existing combat encounters / stable background RIDs")
 quit()
