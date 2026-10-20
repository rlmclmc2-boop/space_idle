extends SceneTree

class UI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass

func _initialize()->void:
 call_deferred("run")

func run()->void:
 var scene:Node=load("res://main.tscn").instantiate()
 scene.set_script(UI)
 scene.automation_args=["--capture"]
 root.add_child(scene)
 scene.automation_args=[]
 scene.set_process(false)
 scene.battlefield_motion_enabled=true
 assert(scene.retained_contacts_enabled)
 var game:BattleGame=scene.game
 game.save_enabled=false
 game.profile.onboarding.completed=true
 game.rng.seed=740221
 assert(game.start(1,false))
 game.group_index=1
 game.spawn_group()
 var enemy:Dictionary=game.enemies[0]
 enemy.hp=1e100;enemy.max_hp=1e100
 var logical:=Vector2(float(enemy.x),float(enemy.y))
 var uid:=int(enemy.uid)
 var min_x:=INF;var max_x:=-INF
 var min_y:=INF;var max_y:=-INF
 var min_angle:=INF;var max_angle:=-INF
 var max_root_error:=0.0
 var max_shield_error:=0.0
 var max_hit_anchor_error:=0.0
 var max_mount_error:=0.0
 var max_muzzle_error:=0.0
 var mount_checks:=0
 var first_mount:=Vector2.INF
 var min_mount_x:=INF;var max_mount_x:=-INF
 var settled_hull_builds:=-1
 var settled_protection_builds:=-1
 var visible_frames:=0
 for frame in 300:
  # Keep the combat state fixed so the actual cached Canvas owners can be
  # sampled over multiple display frames without killing the subject.
  scene._battlefield_motion_frame(1.0/60.0)
  scene.retained_contacts.sync(Vector2.ZERO,false)
  var record=scene.retained_contacts.records.get(uid)
  assert(record!=null and record.supported and record.root.visible and record.hull.visible)
  if frame==10:
   settled_hull_builds=record.hull.builds
   settled_protection_builds=record.protection.builds
  var spatial:Dictionary=scene.retained_contacts.display_spatial(record,enemy)
  var state:Dictionary=scene._battlefield_motion_enemy(enemy)
  assert(not state.is_empty())
  var expected:Vector2=Vector2(spatial.position)+Vector2(state.offset)
  max_root_error=maxf(max_root_error,record.root.position.distance_to(expected))
  max_shield_error=maxf(max_shield_error,absf(record.protection.rotation-record.hull.rotation))
  max_hit_anchor_error=maxf(max_hit_anchor_error,scene._battlefield_motion_enemy_point(enemy,Vector2(spatial.position)).distance_to(record.root.position))
  for mount in record.mounts:
   var global_mount:Vector2=record.root.position+mount.node.position
   if first_mount==Vector2.INF:first_mount=global_mount
   min_mount_x=minf(min_mount_x,global_mount.x);max_mount_x=maxf(max_mount_x,global_mount.x)
   if not is_same(scene.enemy_component_for_slot(enemy,mount.owner_slot),mount.component):continue
   var shot:Dictionary={"hostile":true,"source":enemy,"mount":mount.owner_slot,"target":game.player}
   var sampled_muzzle:Vector2=scene.battle_point(scene.visual_muzzle(shot))
   var base_art:Dictionary=scene.enemy_weapon_art_pose(enemy,mount.component)
   if base_art.is_empty():
    var width:float=scene.enemy_render_width_at_y(enemy,Vector2(spatial.position).y)
    var module_width:float=width*mount.module_factor
    var w:float=maxf(1.0/maxf(0.1,record.screen_scale),module_width*0.45)
    var tip:float=0.73 if mount.physical else 0.45
    var painted_muzzle:Vector2=global_mount+Vector2(0.0,w*tip).rotated(mount.node.rotation)
    max_muzzle_error=maxf(max_muzzle_error,painted_muzzle.distance_to(sampled_muzzle))
    mount_checks+=1
    continue
   var local_muzzle:=Vector2(base_art.muzzle)-Vector2(base_art.origin)
   var base_angle:=float(base_art.angle)
   var shown_art:Dictionary=scene._battlefield_motion_art_pose(base_art,state,mount.component)
   max_mount_error=maxf(max_mount_error,mount.node.position.distance_to(Vector2(shown_art.origin)))
   var cached_muzzle:Vector2=record.root.position+mount.node.position+local_muzzle.rotated(float(shown_art.angle)-base_angle)
   max_muzzle_error=maxf(max_muzzle_error,cached_muzzle.distance_to(sampled_muzzle))
   mount_checks+=1
  assert(record.health.rotation==0.0 and record.shield.rotation==0.0)
  assert(Vector2(float(enemy.x),float(enemy.y))==logical)
  min_x=minf(min_x,record.root.position.x);max_x=maxf(max_x,record.root.position.x)
  min_y=minf(min_y,record.root.position.y);max_y=maxf(max_y,record.root.position.y)
  min_angle=minf(min_angle,record.hull.rotation);max_angle=maxf(max_angle,record.hull.rotation)
  visible_frames+=1
  await process_frame
 var retained_record=scene.retained_contacts.records[uid]
 var result:Dictionary={"retained_enabled":scene.retained_contacts_enabled,"visible_frames":visible_frames,"root_x_span":max_x-min_x,"root_y_span":max_y-min_y,"hull_angle_span_degrees":rad_to_deg(max_angle-min_angle),"root_pose_error":max_root_error,"shield_angle_error":max_shield_error,"hit_anchor_error":max_hit_anchor_error,"mount_position_error":max_mount_error,"mount_global_x_span":max_mount_x-min_mount_x,"visible_muzzle_error":max_muzzle_error,"mount_checks":mount_checks,"hull_rebuilds_after_settle":retained_record.hull.builds-settled_hull_builds,"protection_rebuilds_after_settle":retained_record.protection.builds-settled_protection_builds,"logical_position_unchanged":Vector2(float(enemy.x),float(enemy.y))==logical}
 print("BATTLEFIELD_RETAINED_VISIBLE ",JSON.stringify(result))
 scene.queue_free()
 await process_frame
 quit(0 if result.root_x_span>1.0 and result.root_y_span>0.4 and result.hull_angle_span_degrees>0.1 and result.mount_global_x_span>1.0 and max_root_error<0.001 and max_shield_error<0.001 and max_hit_anchor_error<0.001 and max_mount_error<0.001 and max_muzzle_error<2.0 and mount_checks>0 and result.hull_rebuilds_after_settle==0 and result.protection_rebuilds_after_settle==0 else 1)
