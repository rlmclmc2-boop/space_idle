extends SceneTree

# One serial graphical pass over real stage 1–3 encounters plus the ship UI.
# No damage, timing, spawn composition, combat speed or save edits.
const SCENARIOS:=[
	{"label":"stage1-scout-sentry","stage":1,"index":4},
	{"label":"stage2-swarm-interceptor","stage":2,"index":2},
	{"label":"stage2-swarm-anchor","stage":2,"index":5},
	{"label":"stage3-reactive-shielded","stage":3,"index":5},
	{"label":"stage3-command-shielded","stage":3,"index":6},
]

func _initialize()->void:
	call_deferred("capture")

func capture()->void:
	var out:=OS.get_environment("FLEET_CAPTURE_DIR")
	assert(not out.is_empty())
	DirAccess.make_dir_recursive_absolute(out)
	var scene:Node=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.size=Vector2i(1440,900)
	root.add_child(scene)
	scene.automation_args=[]
	var approved_body := scene.ship_view.ship.find_child("ApprovedHullArt",true,false) as MeshInstance3D
	assert(approved_body!=null and approved_body.visible,"Approved player PNG is not in the live battle ship")
	var approved_material := approved_body.material_override as StandardMaterial3D
	assert(approved_material!=null and approved_material.albedo_texture!=null)
	print("FLEET_PLAYER_LIVE_ART hull=",scene.ship_view.hull_key," texture=",approved_material.albedo_texture.resource_path)
	var game=scene.game
	game.save_enabled=false
	game.profile.onboarding.completed=true
	game.profile.onboarding.dismissed=true
	game.profile.highestLevel=maxi(7,int(game.profile.highestLevel))
	seed(24017)
	for scenario in SCENARIOS:
		assert(game.start(int(scenario.stage),false),str(scenario.label))
		game.group_index=int(scenario.index)
		game.spawn_group()
		var keys:Dictionary={}
		for enemy in game.enemies:
			var key:String=scene.enemy_ship_key(enemy)
			keys[key]=int(keys.get(key,0))+1
		for frame in 30:await process_frame
		var verified_mounts:=0
		for record in scene.retained_contacts.records.values():
			if not record.supported:continue
			for mount in record.mounts:
				var component=scene.enemy_component_for_slot(record.entity,mount.owner_slot)
				var pose:Dictionary=scene.enemy_component_pose(record.entity,component)
				var width:float=mount.node.pieces.body.scale.x
				var face:=0.64 if mount.physical else 0.45
				var mouth:Vector2=mount.node.position+Vector2(face*width,0).rotated(float(pose.angle))
				assert(mouth.distance_to(Vector2(pose.muzzle))<0.1,"Retained weapon mouth drift")
				verified_mounts+=1
		RenderingServer.force_draw()
		var png:=out.path_join(str(scenario.label)+".png")
		var status:=root.get_texture().get_image().save_png(png)
		print("FLEET_CAPTURE ",scenario.label," keys=",keys," remaining=",game.enemies.size()," speed=",game.speed," native=",game.combat_presentation!=null," retained_mounts=",verified_mounts," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," texture_bytes=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)," result=",status)
		assert(status==OK)
	for key in ["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]:
		game.profile.selectedShip=key
		assert(scene.ship_view.set_hull(key),key)
		scene.current_hull=key
		scene._set_reference_dimensions()
		assert(scene.ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons")))
		assert(game.start(1,false),key)
		game.group_index=4
		game.spawn_group()
		for frame in 12:await process_frame
		var body:=scene.ship_view.ship.find_child("ApprovedHullArt",true,false) as MeshInstance3D
		assert(body!=null and body.visible,key)
		var texture:Texture2D=(body.material_override as StandardMaterial3D).albedo_texture
		assert(texture.resource_path.ends_with("/player/"+["01-frigate.png","02-destroyer.png","03-cruiser.png","04-battleship.png","05-heavy-battleship.png"][["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"].find(key)]),key)
		var body_id:=body.get_instance_id()
		assert(scene.ship_view.set_hull(key) and body_id==body.get_instance_id(),"Same hull reloaded")
		RenderingServer.force_draw()
		var player_status:=root.get_texture().get_image().save_png(out.path_join("player-"+key.to_lower()+".png"))
		assert(player_status==OK)
		print("FLEET_PLAYER_CAPTURE ",key," texture=",texture.resource_path," same_hull_cached=true result=",player_status)
	game.profile.cleared=range(1,101)
	game.profile.highestLevel=101
	game.rebuild_unlocks()
	scene.refresh_structure()
	scene.refresh_tab_visibility()
	var page:Control=scene.ship_controls.page
	page.candidate="Heavy_Battleship"
	page.refresh()
	scene.select_system(scene.equipment_tabs.get_tab_idx_from_control(page))
	for frame in 8:await process_frame
	RenderingServer.force_draw()
	var ui_status:=root.get_texture().get_image().save_png(out.path_join("ship-ui-five.png"))
	print("FLEET_UI_CAPTURE candidate=",page.candidate," unlocked=",game.ship_unlocked("Heavy_Battleship")," result=",ui_status)
	assert(ui_status==OK)
	print("FLEET_CAPTURE_DONE ",SCENARIOS.size()+6)
	quit()
