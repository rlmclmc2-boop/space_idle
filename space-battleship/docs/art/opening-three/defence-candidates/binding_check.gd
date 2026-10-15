extends SceneTree
const Identity=preload("res://scripts/enemy_visual_identity.gd")
const Authority=preload("res://scripts/simulation_geometry_authority.gd")
const View=preload("res://scripts/simulation_geometry_view.gd")
const Retained=preload("res://scripts/retained_enemy_contacts.gd")
const OUT="res://docs/art/opening-three/defence-candidates/binding-check.json"
var result={"fixture_only":true,"native_execution_tested":false,"mappings":[],"fallbacks":[],"checks":0}
class PaintBoard extends Node2D:
	var owner_scene
	var specimens:Array=[]
	func _draw():
		draw_rect(Rect2(0,0,1200,1100),Color("101820"))
		draw_string(ThemeDB.fallback_font,Vector2(30,35),"PRODUCTION DRAW PATHS / descriptor fixture, not Sol loadouts",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(280,80),"Fallback painter",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(780,80),"Retained painter",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
		var previous=owner_scene.draw_surface;owner_scene.draw_surface=self
		for i in specimens.size():
			var enemy:Dictionary=specimens[i]
			var point=Vector2(260,155+i*110)
			owner_scene.draw_enemy_hull_and_status(enemy,point-owner_scene.enemy_render_position(enemy),false)
			draw_string(ThemeDB.fallback_font,Vector2(30,point.y),str(enemy.archetype_id),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
		owner_scene.draw_surface=previous
		draw_string(ThemeDB.fallback_font,Vector2(30,1070),"One synthetic laser slot each; no combat ticks, no roster edits. Same resolved texture, mounts and state layer.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
	if not ok:push_error(message);quit(1);assert(ok,message)
	result.checks+=1
func run():
	root.size=Vector2i(1200,1100);root.content_scale_size=root.size
	var scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
	scene.capture_frame=-10000;scene.game.save_enabled=false
	var authority=Authority.new();authority.prepare(scene,scene.game)
	var view=View.new();var identity=Identity.new()
	var retained=Retained.new();retained.setup(scene)
	var board=PaintBoard.new();board.owner_scene=scene
	board.add_child(retained);retained.position=Vector2(600,0)
	var index=0
	for archetype in Identity.ARCHETYPES:
		var binding:Array=Identity.ARCHETYPES[archetype]
		# Synthetic descriptor fixture, never added to gameplay or persisted.
		var enemy={"id":990000+index,"uid":990000+index,"slot":index,"size":2,"x":220.0,"y":160.0,"hp":100.0,"max_hp":100.0,"shield":0.0,"max_shield":0.0,"shieldRecovery":0.0,"archetype_id":archetype,"armourType":binding[1],"shieldType":2,"equipment":[{"name":"laser_mon"}]}
		if archetype=="shielded":enemy.max_shield=100.0;enemy.shield=50.0;enemy.shieldRecovery=1.0;enemy.shieldDelay=1.0;enemy.shield_hit_at=0.0
		var before=enemy.duplicate(true)
		check(scene.enemy_ship_key(enemy)==binding[0],"legacy identity")
		var appearance=authority.enemy_appearance(enemy)
		check(appearance.ship_key==binding[0],"authority identity")
		var captured=authority.ship_hull_texture(appearance.ship_key)
		check(captured.identity==scene.ship_hull_texture(binding[0]).get_instance_id(),"captured texture identity")
		var packet=authority.enemy_recognition_geometry(enemy,48)
		check(not packet.inner.is_empty(),"prepared geometry")
		var descriptor=authority.display_descriptor(enemy);view.descriptor(enemy.uid,descriptor)
		check(view.appearance(enemy).ship_key==binding[0],"birth descriptor roundtrip")
		view.ready=true;scene.simulation_geometry_view=view
		check(scene.enemy_ship_key(enemy)==binding[0],"published display identity")
		scene.simulation_geometry_view=null
		var record=retained.create_record(enemy)
		var spatial=retained.display_spatial(record,enemy)
		check(spatial.appearance.ship_key==binding[0],"retained legacy descriptor")
		retained.compile_record(record,spatial,false)
		check(record.texture==scene.ship_hull_texture(binding[0]),"retained texture")
		check(record.used==scene.enemy_hull_bounds(record.texture),"meter bounds")
		retained.update_record(record,spatial,Vector2(260,155+index*110)-scene.enemy_render_position(enemy))
		board.specimens.append(enemy)
		var drop=enemy.duplicate(true);drop.id+=100000
		check(identity.resolve(drop,scene.visual_config)==binding[0],"drop id retains archetype")
		check(enemy==before,"read-only identity and geometry")
		result.mappings.append({"archetype":archetype,"ship_key":appearance.ship_key,"texture_identity_shared":true})
		index+=1
	for sample in [{"size":3},{"size":3,"archetype_id":"unknown","armourType":1},{"size":3,"archetype_id":"scout","armourType":1}]:
		check(identity.resolve(sample,scene.visual_config)=="enemy_3","legacy fallback")
		result.fallbacks.append(sample)
	var missing=scene.visual_config.duplicate(true)
	missing.ships.enemy_opening_triangle_physical.asset_ready=false
	check(identity.resolve({"size":4,"archetype_id":"scout","armourType":2},missing)=="enemy_4","missing asset fallback without IO")
	result.diagnostics=identity.diagnostics
	FileAccess.open(OUT,FileAccess.WRITE).store_string(JSON.stringify(result,"  ")+"\n")
	root.size=Vector2i(1200,1100);root.content_scale_size=root.size
	scene.hide();root.add_child(board)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT.replace("binding-check.json","binding-render.png"))
	board.queue_free()
	await process_frame
	authority.close({"spatial":scene.game.target_spatial_source})
	print("OPENING_BINDING_CHECK_OK ",result.checks)
	quit()
