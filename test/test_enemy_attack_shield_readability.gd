extends SceneTree
## Actual main-scene pixel captures and independent source-alpha shield containment.
class IsolatedUI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
	func show_qa_tools()->void:pass
const GEO:=preload("res://scripts/enemy_protection_geometry.gd")
var scene
var checks:=0
var failures:=0
var records:Array=[]
var alpha_cache:Dictionary={}
var folder:=ProjectSettings.globalize_path("res://../readability-evidence")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr(label)
func _initialize()->void:call_deferred("run")
func spawn(sizes:Array,physical:bool,source_id:="")->void:
	var g=scene.game
	var slots:Array=[]
	for index in sizes.size():
		var id:=990000+index
		var row:Dictionary=g.db.enemies[source_id if not source_id.is_empty() else "2018" if physical else "1018"].duplicate(true)
		row.id=id;row.size=sizes[index];row.shieldType=1;row.armourType=2;row.shield=8000.0
		g.db.enemies[str(id)]=row;slots.append(id)
	g.db.groups["999999"]={"slots":slots,"combatTier":"normal"}
	g.db.levels[0].groups=[{"id":999999,"position":0.0},{"id":999999,"position":1.0}]
	g.stage=1;g.group_index=0;g.uid=1000;g.spawn_group()
	scene.enemy_poses.clear();g.projectiles.clear();scene.particles.clear();scene.floats.clear()
	for enemy in g.enemies:
		for index in enemy.cooldowns.size():enemy.cooldowns[index]=1000.0
		enemy.hp=1e12;enemy.max_hp=1e12
	g.refresh_missile_target_registry();scene.fx_time=5.0
	for enemy in g.enemies:scene.enemy_pose(enemy).born=0.0
func audit(label:String)->void:
	var g=scene.game
	var snapshot:Array=g.enemies.duplicate(true)
	var rng_state:int=g.rng.state
	for enemy in g.enemies:
		var texture:Texture2D=scene.ship_hull_texture("enemy_"+str(int(enemy.size)))
		var image:Image=texture.get_image()
		if not alpha_cache.has(texture.get_instance_id()):alpha_cache[texture.get_instance_id()]=GEO.alpha_boundary(image)
		var alpha_points:PackedVector2Array=alpha_cache[texture.get_instance_id()]
		# Normalize independently through the actual draw_texture_rect dimensions.
		var dimensions:=Vector2(scene.enemy_render_width(enemy),scene.enemy_render_width(enemy)*2.0)
		var hull_points:=PackedVector2Array()
		for point in alpha_points:
			var pixel:Vector2=point*float(image.get_width())+Vector2(image.get_size())*0.5
			hull_points.append((pixel/Vector2(image.get_size())-Vector2(0.5,0.5))*dimensions)
		var packet:Dictionary=scene.enemy_recognition_geometry(enemy)
		var clearance:float=GEO.min_clearance(hull_points,packet.inner)*float(packet.scale)-float(packet.shield_stroke)*float(packet.scale)*0.5-0.5
		check(clearance>=1.99,label+": actual alpha hull fully inside shield")
		var width:float=dimensions.x
		for point in [Vector2(-0.22,-0.02),Vector2(0.22,-0.02),Vector2(0.22,0.53),Vector2(-0.22,0.53)]:check(GEO.min_clearance(PackedVector2Array([point*width]),packet.inner)*float(packet.scale)-float(packet.shield_stroke)*float(packet.scale)*0.5-0.5>=1.99,label+": attack structure fits protection")
		for component in scene.enemy_weapon_components(enemy):
			var pose:Dictionary=scene.enemy_component_pose(enemy,component)
			var descriptor:Dictionary=scene.enemy_recognition.descriptors([component])[0]
			var mounted:=PackedVector2Array()
			for point in scene.enemy_recognition.mount_corners(descriptor,width,15.0/packet.scale):mounted.append((Vector2(pose.origin)+point.rotated(pose.angle)).rotated(-PI-scene.enemy_render_angle(enemy)))
			check(GEO.min_clearance(mounted,packet.inner)*float(packet.scale)-float(packet.shield_stroke)*float(packet.scale)*0.5-0.5>=1.99,label+": actual mounted attack parts fit protection")
		records.append({"label":label,"size":enemy.size,"width":dimensions.x,"clock":scene.fx_time,"screen_scale":packet.scale,"hull_gap_pixels":clearance,"hull_points":hull_points.size(),"position":str(scene.enemy_render_position(enemy)),"angle":scene.enemy_render_angle(enemy)})
	check(g.enemies==snapshot and g.rng.state==rng_state,label+": presentation does not mutate combat")
func capture(name:String)->void:
	scene.refresh_draw_layers(0.0);scene.battle_layer.queue_redraw()
	await process_frame
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")
func run()->void:
	DirAccess.make_dir_recursive_absolute(folder)
	scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI)
	scene.music_on=false;scene.sound_on=false;scene.automation_args=["--capture"]
	root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
	var g=scene.game;g.save_enabled=false;g.rng.seed=12345
	g.profile.onboarding.completed=true;scene.beginner_guide.hide()
	g.profile.cleared=range(1,76);g.rebuild_unlocks();g.profile.selectedShip="Frigate"
	g.profile.loadout={"weapons":[{"key":"","level":1},{"key":"","level":1},{"key":"","level":1}],"defence":[{"key":"armour","level":10},{"key":"","level":1}]}
	g.start(1,false);scene.refresh_structure();scene.refresh_tab_visibility()
	await process_frame
	for design in g.db.data.battle_design.values():
		var slots:Array=g.db.groups[str(int(design.group_id))].slots
		for id in slots:
			if id==null:continue
			var enemy:Dictionary=g.db.enemies[str(int(id))].duplicate(true)
			enemy.slot=0;enemy.uid=2000;enemy.x=286.0;enemy.y=140.0;enemy.formation_columns=5
			scene.enemy_poses.clear()
			check(scene.enemy_attack_types(enemy)==[int(design.attack_type)],"all 40 designs use actual outgoing attack type, independently of protection")
	for physical in [false,true]:
		spawn([1,2,3,4,5,6],physical)
		for clock in [0.0,5.0,8.0]:
			scene.fx_time=clock
			var label:="%s-%s"%["physical" if physical else "energy","entry" if clock==0 else "stable" if clock==5 else "drift"]
			audit(label);await capture(label)
	for size in [4,5,6]:
		spawn([size],false)
		for clock in [0.0,5.0,8.0]:
			scene.fx_time=clock;var label:="large-%d-%s"%[size,"entry" if clock==0 else "stable" if clock==5 else "drift"]
			audit(label);await capture(label)
		# Recovery and extra front layer remain driven by the actual shield state.
		var enemy:Dictionary=g.enemies[0]
		enemy.shieldRecovery=100.0;enemy.shieldDelay=0.0;enemy.shield=4000.0
		scene.fx_time=5.0;audit("large-%d-recovery"%size);await capture("large-%d-recovery"%size)
		for source_id in [str(size*2-1),"1062" if size==4 else "1088" if size==5 else "1090"]:
			spawn([size],false,source_id)
			# Inspect the authored large rows and full native multi-turret hulls.
			for yaw in [-0.09,0.09]:
				scene.enemy_pose(g.enemies[0]).rotation=yaw
				audit("large-%d-source-%s-yaw-%s"%[size,source_id,str(yaw)])
			await capture("large-%d-source-%s"%[size,source_id])
		g.group_index=2
		audit("large-%d-final-wave-scale"%size);await capture("large-%d-final-wave-scale"%size)
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_size(Vector2i(960,540));await process_frame;await process_frame
		for size in [4,5,6]:spawn([size],false);audit("small-window-%d"%size);await capture("small-window-%d"%size)
	var file:=FileAccess.open(folder+"/audit.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"  "));file.close()
	print("ATTACK / SHIELD READABILITY checks=",checks," failures=",failures," evidence=",folder)
	g.launch_provider=Callable();g.target_provider=Callable();scene.queue_free();await process_frame;quit(1 if failures else 0)
