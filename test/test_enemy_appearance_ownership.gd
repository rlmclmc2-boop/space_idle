extends SceneTree
class QuietUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
var failures:=0
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("OWNERSHIP_FAIL ",label)
func _initialize()->void:call_deferred("run")
func combat(g)->String:return JSON.stringify({"enemies":g.enemies,"player":g.player,"projectiles":g.projectiles,"rng":str(g.rng.state)})
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(QuietUI)
 scene.automation_args=["--capture"];root.add_child(scene);scene.automation_args=[];scene.set_process(false);scene.hide()
 var g=scene.game;g.save_enabled=false;g.paused=true;g.rng.seed=1701
 g.stage=20;g.group_index=0;g.state=BattleGame.State.COMBAT;g.spawn_group()
 for enemy in g.enemies:enemy.equipment=[{"name":"cannon-mon"}]
 var enemy:Dictionary=g.enemies[0];var model=scene.battle_read_model;var contacts=scene.retained_contacts
 scene.fx_time=2.0;model.begin(true);contacts.sync(Vector2.ZERO,false)
 var row:Dictionary=model.entry(enemy)
 var appearance:Dictionary=row.get("appearance",{"components":row.components,"mounts":scene.enemy_recognition_mounts(enemy)})
 var original_pose:Dictionary=scene.enemy_pose(enemy);var record=contacts.records[int(enemy.uid)]
 var mount_node_ids=record.mounts.map(func(m):return m.node.get_instance_id())
 var shape:int=model.shape_revision;var snapshot:=combat(g)
 scene.fx_time=3.0;model.begin();var old_position:Vector2=model.position(enemy)
 scene.enemy_poses.erase(int(enemy.slot))
 check(not scene.enemy_recognition_mounts(enemy).is_empty(),"cached appearance descriptors survive same-entity pose pruning")
 check(is_same(scene.enemy_weapon_components(enemy),appearance.components),"component and descriptor publication keeps one immutable owner")
 var replaced_pose:Dictionary=scene.enemy_pose(enemy)
 check(not is_same(original_pose,replaced_pose),"pose identity really replaced")
 var new_position:Vector2=model.position(enemy)
 check(new_position.is_equal_approx(scene._source_enemy_render_position(enemy)),"same-clock pose replacement refreshes only its spatial solve")
 check(not new_position.is_equal_approx(old_position),"recreated entry pose is not served the old settled position")
 contacts.sync(Vector2.ZERO,false)
 check(is_same(record.pose,replaced_pose),"persistent display binds current mutable pose")
 check(is_same(record.descriptors,appearance.mounts),"persistent descriptors follow immutable appearance rather than old pose")
 check(record.mounts.map(func(m):return m.node.get_instance_id())==mount_node_ids,"pose rebind retains native mount nodes")
 check(model.shape_revision==shape,"pose rebind does not invalidate all shapes")
 check(snapshot==combat(g),"display ownership queries leave combat and RNG unchanged")
 # The first dead enemy stays in the fleet and is still referenced by a
 # turret. Normal clearance deliberately includes it, as in the QA failure.
 enemy.hp=0.0;scene.turret_pose(0).target=enemy
 scene.refresh_draw_layers(0.0)
 check(not scene.enemy_poses.has(int(enemy.slot)),"normal drawing prunes dead first pose")
 snapshot=combat(g);scene.fx_time+=1.0/60.0;model.begin()
 var clearance:float=scene.enemy_safe_entry_distance()
 check(is_finite(clearance) and not scene.enemy_recognition_mounts(enemy).is_empty(),"dead first residual reference has complete appearance after pruning")
 scene.advance_turrets(1.0/60.0)
 check(snapshot==combat(g),"dead-reference turret/clearance queries preserve combat and RNG")
 contacts.sync(Vector2.ZERO,false)
 check(not record.root.visible,"dead contact stays hidden")
 # Same uid but a new Dictionary must replace the spatial/display owner.
 var replacement:Dictionary=enemy.duplicate(true);replacement.hp=replacement.max_hp
 g.enemies[0]=replacement;scene.fx_time+=1.0/60.0;model.begin();contacts.sync(Vector2.ZERO,false)
 var replacement_row:Dictionary=model.entry(replacement)
 check(model.entry(enemy).is_empty() and is_same(replacement_row.entity,replacement),"same uid entity replacement rejects old spatial identity")
 check(not is_same(replacement_row.appearance,appearance),"same uid new entity owns its own appearance")
 var replacement_record=contacts.records[int(replacement.uid)]
 check(not is_same(record,replacement_record) and is_same(replacement_record.entity,replacement),"same uid replaces persistent display record")
 check(not scene.enemy_recognition_mounts(enemy).is_empty() and model.entry(enemy).is_empty(),"departed old entity remains queryable without taking the new spatial record")
 model.position(replacement);contacts.sync(Vector2.ZERO,false)
 check(is_same(replacement_record.pose,scene.enemy_pose(replacement)),"live display rebinds after old residual slot access")
 var next_entity:Dictionary=replacement.duplicate(true);next_entity.uid=int(replacement.uid)+1000000
 g.enemies[0]=next_entity;scene.fx_time+=1.0/60.0;model.begin();contacts.sync(Vector2.ZERO,false)
 check(model.entry(replacement).is_empty() and not contacts.records.has(int(replacement.uid)),"new uid retires previous spatial and display membership")
 check(is_same(model.entry(next_entity).entity,next_entity) and is_same(contacts.records[int(next_entity.uid)].entity,next_entity),"new uid binds exact new entity owners")
 model.end();scene.queue_free();await process_frame
 print("OWNERSHIP_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
