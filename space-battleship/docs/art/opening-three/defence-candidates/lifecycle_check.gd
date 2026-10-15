extends SceneTree
const ROOT="res://docs/art/opening-three/defence-candidates/"
const Authority=preload("res://scripts/simulation_geometry_authority.gd")
const Runtime=preload("res://scripts/battle_slice_runtime.gd")
const Identity=preload("res://scripts/enemy_visual_identity.gd")
const Retained=preload("res://scripts/retained_enemy_contacts.gd")
const Review=preload("res://docs/art/opening-three/defence-candidates/binding_check.gd")
var checks:=0
class BoundaryProbe extends "res://scripts/simulation_geometry_authority.gd":
	var before_handoff:Dictionary={}
	func prepare(owner,simulation:BattleGame)->void:
		super.prepare(owner,simulation)
		# Runtime.install has not replaced providers or attached its view yet.
		before_handoff=display_descriptor(simulation.enemies[0])
class LegacyFragments extends "res://scripts/main.gd":
	func visual_effect_point(point:Vector2)->Vector2:return point
	func enemy_drop_anchor(enemy:Dictionary)->Vector2:return Vector2(enemy.x,enemy.y)
	func beep(_frequency:float)->void:pass
func check(ok:bool,label:String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:quit(1);assert(ok,label)
func actor(uid:int,archetype:String,size:int,armour:int,equipment:Array)->Dictionary:
	return {"id":uid,"uid":uid,"slot":0,"size":size,"archetype_id":archetype,"armourType":armour,"shieldType":2,"x":220.0,"y":160.0,"hp":100.0,"max_hp":100.0,"shield":0.0,"max_shield":0.0,"shieldRecovery":0.0,"boss":false,"equipment":equipment}
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1373,883);root.content_scale_size=Vector2i(1952,1256)
	var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
	root.add_child(scene);scene.set_process(false);scene.capture_frame=-10000;scene.game.save_enabled=false
	scene.hide()
	print("ENV Godot=",Engine.get_version_info().string," native_kernel_exercised=false; no combat ticks")
	var original=scene.visual_config.duplicate(true)
	for row in scene.visual_config.ships.values():row.erase("asset_ready")
	scene.visual_config.ships.enemy_opening_triangle_physical.asset_ready=false
	var legacy=Authority.new();legacy.prepare(scene,scene.game)
	for size in range(1,7):
		var key="enemy_"+str(size)
		check(legacy.captured_visuals.has(str(legacy.visual_config.ships[key].texture)),"unmarked legacy owner captures "+key)
	check(not legacy.captured_visuals.has(str(scene.visual_config.ships.enemy_opening_triangle_physical.texture)),"explicit unavailable descriptor stays uncaptured")
	legacy.close({"spatial":scene.game.target_spatial_source});scene.visual_config=original
	var old=actor(880001,"shielded",3,1,[{"name":"laser_mon"}])
	old.max_shield=100.0;old.shield=50.0;old.shieldRecovery=1.0;old.shieldDelay=1.0;old.shield_hit_at=0.0
	var fresh=actor(880002,"scout",1,2,[{"name":"laser_mon"}])
	scene.game.enemies.assign([old])
	var old_key=scene.enemy_ship_key(old)
	check(old_key=="enemy_opening_u_energy","before handoff old identity")
	var runtime=Runtime.new();runtime.geometry=BoundaryProbe.new();runtime.install(scene)
	check(runtime.geometry.before_handoff.ship_key==old_key,"descriptor ship_key captured before provider handoff")
	check(runtime.view.appearance(old).ship_key==old_key,"after provider handoff descriptor ship_key")
	var renderer=Retained.new();renderer.setup(scene)
	var old_record=renderer.create_record(old)
	renderer.compile_record(old_record,renderer.display_spatial(old_record,old),false)
	renderer.update_record(old_record,renderer.display_spatial(old_record,old),Vector2.ZERO)
	check(old_record.status.active and old_record.shield.visible,"old instance begins with visible active shield meter")
	var old_texture=old_record.texture
	var old_mounts=runtime.view.appearance(old).mounts.duplicate(true)
	var old_meter=scene.enemy_status_layout(old,Vector2(260,240),48,0,PackedVector2Array()).health
	runtime.geometry.freeze_display_entity(old)
	old.hp=0.0
	scene.game.enemies.assign([fresh]);scene.floats.append({"target_entity":old})
	runtime.snapshot();scene.floats.clear()
	var fresh_key=scene.enemy_ship_key(fresh)
	check(fresh_key=="enemy_opening_triangle_physical","same slot new uid resolves new archetype")
	check(runtime.view.appearance(old).ship_key==old_key,"dead descriptor retains old ship_key")
	check(runtime.view.appearance(fresh).ship_key==fresh_key,"new descriptor carries new ship_key")
	check(runtime.view.appearance(old).mounts==old_mounts,"dead mounts remain frozen")
	check(runtime.view.appearance(old).mounts!=runtime.view.appearance(fresh).mounts,"new mount description does not reuse old")
	var new_record=renderer.create_record(fresh)
	renderer.compile_record(new_record,renderer.display_spatial(new_record,fresh),false)
	renderer.update_record(new_record,renderer.display_spatial(new_record,fresh),Vector2.ZERO)
	check(not new_record.status.active and not new_record.shield.visible,"new instance does not inherit old shield meter/state")
	check(new_record.texture!=old_texture and old_record.texture==old_texture,"retained textures belong to instances")
	var fresh_meter=scene.enemy_status_layout(fresh,Vector2(260,240),48,0,PackedVector2Array()).health
	check(old_meter!=fresh_meter,"status bars use respective hull bounds")
	check(is_equal_approx(fresh_meter.size.x,clampf(48*new_record.used.size.x,28,100)),"new bar width matches new texture")
	print("METERS old=",old_meter," new=",fresh_meter)
	runtime.on_event("explode",old)
	check(int(scene.destruction_events.back().seed)==int(old.uid),"active typed destruction keeps dead uid, not slot occupant")
	print("ACTIVE_EXPLOSION typed primitives only; no hull texture fragments in battlefield/native adapter")
	check(runtime.close(),"ownership returns without native kernel")
	check(scene.enemy_pose(fresh).appearance.ship_key==fresh_key,"new appearance ship_key survives owner handback")
	check(scene.enemy_ship_key(old)==old_key and scene.enemy_ship_key(fresh)==fresh_key,"both identities survive handback")
	check(scene.enemy_weapon_components(old)[0].hardpoint!=scene.enemy_weapon_components(fresh)[0].hardpoint,"same slot legacy cache rebinds by instance")
	var fragments=LegacyFragments.new();fragments.game=scene.game;fragments.db=scene.db;fragments.visual_config=scene.visual_config
	fragments.on_event("explode",old)
	var pieces=fragments.particles.filter(func(p):return p.get("fragment",false))
	check(pieces.size()==6,"legacy base emits six old hull fragments")
	check(pieces.all(func(p):return p.texture==old_texture),"late old explosion uses old texture after replacement")
	fragments.on_event("explode",fresh)
	var all_pieces=fragments.particles.filter(func(p):return p.get("fragment",false))
	check(all_pieces.size()==12 and all_pieces.slice(6).all(func(p):return p.texture==new_record.texture),"new explosion uses new texture")
	check(pieces.all(func(p):return p.texture==old_texture),"old fragments retain their captured texture")
	fragments.game=null;fragments.free();renderer.free()
	var identity=Identity.new()
	check(identity.resolve({"size":2,"archetype_id":"unknown","armourType":1},original)=="enemy_2","unknown archetype fallback")
	check(identity.resolve({"size":2,"archetype_id":"scout","armourType":1},original)=="enemy_2","defence mismatch fallback")
	var absent=original.duplicate(true);absent.ships.erase("enemy_opening_triangle_physical")
	check(identity.resolve({"size":2,"archetype_id":"scout","armourType":2},absent)=="enemy_2","missing ship key fallback")
	absent=original.duplicate(true);absent.ships.enemy_opening_triangle_physical.asset_ready=false
	check(identity.resolve({"size":2,"archetype_id":"scout","armourType":2},absent)=="enemy_2","explicit unavailable asset fallback")
	# Visual comparison only: authoritative equipment/size, no numeric table merge.
	scene.game.enemies.clear();scene.destruction_events.clear();scene.enemy_poses.clear()
	var source=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"authoritative-loadouts.json"))
	var board=Review.PaintBoard.new();board.owner_scene=scene;board.position=Vector2(350,70)
	board.heading="SOL 6b2e98da / authoritative equipment + size / normal window scale"
	board.footer="Individual fixtures; no 18-point formations or numeric merge. Shield amount is illustrative; no combat ticks."
	var retained=Retained.new();retained.setup(scene);retained.position=Vector2(600,0);board.add_child(retained)
	var seen={};var index=0
	for row in source.rows:
		if seen.has(row.archetype_id):continue
		seen[row.archetype_id]=true
		var binding=Identity.ARCHETYPES[row.archetype_id]
		var enemy=actor(int(row.id),row.archetype_id,int(row.size),binding[1],row.equipment)
		enemy.slot=index
		if row.archetype_id=="shielded":enemy.max_shield=100.0;enemy.shield=50.0;enemy.shieldRecovery=1.0
		board.specimens.append(enemy)
		var record=retained.create_record(enemy);var spatial=retained.display_spatial(record,enemy)
		retained.compile_record(record,spatial,false)
		retained.update_record(record,spatial,Vector2(260,155+index*110)-scene.enemy_render_position(enemy))
		print("LOADOUT ",row.archetype_id," size=",row.size," equipment=",row.equipment," visible_height_at_review_scale=",scene.enemy_hull_bounds(record.texture).size.y*scene.enemy_render_width(enemy)*2*scene.enemy_recognition_screen_scale())
		index+=1
	root.add_child(board)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ROOT+"authoritative-loadouts.png")
	board.queue_free();await process_frame
	print("LIFECYCLE_CHECK_OK checks=",checks," source=",source.source_commit)
	quit()
