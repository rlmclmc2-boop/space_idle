extends RefCounted
var comparisons=0
var frames=0
func same_value(actual,expected,label:String)->void:
	comparisons+=1
	if actual!=expected:push_error("BATTLE_BOUNDARY_MISMATCH "+label+" actual="+str(actual)+" expected="+str(expected))
func check(scene)->void:
	var model=scene.battle_read_model
	model.end()
	var rows=[]
	for enemy in scene.game.enemies:
		if enemy.hp<=0:continue
		var point=scene.enemy_render_position(enemy)
		var width=scene.enemy_render_width_at_y(enemy,point.y)
		var poses=[]
		for component in scene.enemy_weapon_components(enemy):poses.append(scene.enemy_component_pose(enemy,component,point,width))
		rows.append({"enemy":enemy,"point":point,"width":width,"front":scene.enemy_frontline_y_limit(enemy),"geometry":scene.enemy_recognition_geometry(enemy,width),"mounts":poses})
	var bounds=scene.damage_text_enemy_bounds()
	var bottom=scene.damage_text_enemy_bottom()
	model.begin(true)
	for row in rows:
		var enemy:Dictionary=row.enemy
		same_value(scene.enemy_render_position(enemy),row.point,"position")
		same_value(scene.enemy_render_width_at_y(enemy,row.point.y),row.width,"width")
		same_value(scene.enemy_frontline_y_limit(enemy),row.front,"frontline")
		var display=model.display_contact(enemy,Vector2.ZERO,false)
		if display.supported:
			same_value(display.position,row.point,"display_position")
			same_value(display.width,row.width,"display_width")
			same_value(display.packet,row.geometry,"recognition")
			same_value(display.mounts,row.mounts,"mounts")
	same_value(scene.damage_text_enemy_bounds(),bounds,"bounds")
	same_value(scene.damage_text_enemy_bottom(),bottom,"bottom")
	# An alive/dead change without a new pose clock must invalidate only membership.
	if not rows.is_empty():
		var enemy:Dictionary=rows[0].enemy
		var hp=enemy.hp;enemy.hp=0
		var dead_bounds=scene.damage_text_enemy_bounds().duplicate()
		model.end();same_value(dead_bounds,scene.damage_text_enemy_bounds(),"same_clock_death")
		enemy.hp=hp
		model.begin(true)
	model.end();frames+=1
func report()->Dictionary:return {"frames":frames,"comparisons":comparisons,"scope":"same-clock canonical spatial/recognition/mount/layout equality, including entry and alive-membership change; validation overhead excluded from clean timing"}
