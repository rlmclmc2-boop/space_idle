extends SceneTree
const Session=preload("res://src/game_session.gd")
const Geometry=preload("res://scripts/ship_geometry_convention.gd")
const Art=preload("res://scripts/approved_weapon_art.gd")
const KEYS=["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]
func _initialize()->void:
	var status=GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if status not in [GDExtensionManager.LOAD_STATUS_OK,GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:quit(1);return
	call_deferred("_run")
func _bounds(points:PackedVector2Array)->Rect2:
	var rect:=Rect2(points[0],Vector2.ZERO)
	for point in points:rect=rect.expand(point)
	return rect
func _run()->void:
	var session=Session.new()
	if not session.initialize("res://generated/config.json",871).ok:quit(1);return
	var before:Dictionary=session.save_payload()
	if not before.get("ok",false):printerr("snapshot unavailable: ",before);quit(1);return
	var rows:Array=[]
	var weapon_hulls:Dictionary={}
	for key in session.battle._weapon_manifest:
		weapon_hulls[key]=Geometry.normalized_hull(session.battle._weapon_art[key].get_image())
	for key in KEYS:
		var model:Dictionary=session.battle.hull_presentation(key)
		var hull:Rect2=_bounds(model.hull)
		var complete:Rect2=hull
		var image:Image=model.texture.get_image()
		var opaque:int=0
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x,y).a>0.0:opaque+=1
		var area:float=float(opaque)*model.dimensions.x/image.get_width()*model.dimensions.y/image.get_height()
		for slot in model.art.slot_map.size():
			var pivot:Vector2=Geometry.mount_position(model.art,slot,Vector2.ZERO,model.dimensions)
			for weapon in session.battle._weapon_manifest:
				for degree in range(0,360):
					var pose:Dictionary=Art.player_pose(weapon,session.battle._weapon_manifest[weapon],session.battle._weapon_art[weapon].get_size(),pivot,deg_to_rad(degree),model.height,model.art)
					for vertex in weapon_hulls[weapon]:
						var local:Vector2=pose.rect.position+(vertex+Vector2(0.5,0.5))*pose.dimensions
						complete=complete.expand(pivot+local.rotated(pose.angle))
		var world:Rect2=Rect2(complete.position+Vector2(286,520),complete.size)
		var row:Dictionary={"ship":key,"hull_width":hull.size.x,"hull_height":hull.size.y,"opaque_area_alpha_gt_zero":area,"full_turret_sweep_width":complete.size.x,"full_turret_sweep_height":complete.size.y,"envelope_top_at_current_player_y":world.position.y,"envelope_bottom_at_current_player_y":world.end.y,"hud_top":708,"hud_clearance":708-world.end.y,"front_enemy_center_y":350,"center_separation":170,"shield_visual_envelope":"No in-world player shield shell is currently rendered; shield bar is separate. Future shield radius remains unapproved."}
		rows.append(row)
		print("HULL_SPACE_FACT ",JSON.stringify(row))
	if session.save_payload()!=before:printerr("hull analysis mutated session");quit(1);return
	var report:Dictionary={"baseline":"64ff8539","scale_changes_applied":false,"position_changes_applied":false,"alpha_threshold":0.0,"turret_angles":"all four legal weapon arts at every mount, full 360-degree 1-degree sweep; conservative union, not simultaneous installation","facts":rows,"candidates":[{"id":"A","layout":"current 572x960 combat coordinates; independent desktop workspace","gameplay_impact":"none","limitation":"UI separation does not improve the 170-unit enemy/player center gap"},{"id":"B","layout":"reserve complete assembly envelopes and a separately approved inter-fleet gap before selecting scale ratios","gameplay_impact":"any player_y/formation-row/projectile-boundary change requires explicit approval; no value selected or implemented"}],"acceptance":"G9 remains open: enemy shields/bars, all ranked dense formations and future expansion need complete envelopes plus real-window review; these facts do not approve a multiplier"}
	var output:String=OS.get_environment("SPACE_IDLE_HULL_SPACE_REPORT")
	if not output.is_empty():
		var file=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("STAGE6_HULL_SPACE_FACTS_READONLY_OK G9_OPEN")
	quit(0)
