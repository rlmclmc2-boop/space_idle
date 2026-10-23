extends RefCounted
## Fixed model dimensions and authored formation bounds. Owned by the existing
## mutable pose; shared by native geometry and a legacy owner after handoff.
static func sync(host)->bool:
	# Check mutable configuration once at a simulation/display boundary, never
	# build the old full parameter key for each position query.
	var members:Array=[]
	for enemy in host.game.enemies:
		members.append([int(enemy.uid),int(enemy.slot),int(enemy.size),enemy.get("explicit_formation",false),enemy.get("size_formation",false),enemy.get("formation_columns",10),enemy.get("formation_count",0),enemy.get("hull_scale",1.0)])
	var scales:Array=[]
	for size_class in range(1,7):scales.append(host.enemy_config_visual_scale(size_class))
	var signature:Array=[host.battle_visual.hash(),host.player_base_art_scale(),host.player_art_scale(),host.enemy_recognition_screen_scale(),host.game.is_final_encounter(),host.db.config.get("explicitEnemyPlayerMinGap",host.battle_visual.enemy_player_min_gap),scales,members]
	if signature==host.fixed_layout_signature:return false
	host.fixed_layout_signature=signature;host.fixed_layout_revision+=1
	return true

static func width(host,enemy:Dictionary,variance:float)->float:
	var tier:=1.85 if host.game.is_final_encounter() else 1.5 if int(enemy.size)>=4 else 1.0+float(int(enemy.size)-1)*0.08
	var limit:=78.0 if host.game.is_final_encounter() else 66.0 if int(enemy.size)>=4 else 54.0
	var base:=minf(limit/(float(host.battle_visual.enemy_depth_scale_max)*float(host.battle_visual.enemy_scale_variance.y)),host.SHIP_VISUALS.CANVAS.y*1.2*host.player_base_art_scale()*float(host.battle_visual.enemy_base_scale)*tier)
	# A model has one width throughout entry/hover, independent of screen Y.
	var value:float=base*host.enemy_config_visual_scale(int(enemy.size))*variance
	if enemy.get("explicit_formation",false) and int(enemy.size)>=4:value*=minf(1.0,host.enemy_recognition_screen_scale()/0.6)
	return (minf(value,74.0) if int(enemy.get("formation_count",0))>=4 else value)*float(enemy.get("hull_scale",1.0))

static func ensure(host,enemy:Dictionary,pose:Dictionary)->Dictionary:
	var scale_value:float=host.enemy_recognition_screen_scale()
	var layout:Dictionary=pose.get("fixed_layout",{})
	if not layout.is_empty() and layout.revision==host.fixed_layout_revision and layout.scale==scale_value and layout.variance==pose.variance and layout.size==enemy.size:return layout
	var model_width:=width(host,enemy,float(pose.variance))
	var visual:Dictionary=host.battle_visual
	var explicit:bool=enemy.get("explicit_formation",false)
	var player_half:float=(host.SHIP_ART_CANVAS.y*float(visual.player_core_scale)/2.0+host.SHIP_ART_CANVAS.x*float(visual.player_core_scale)/2.0*absf(sin(deg_to_rad(float(visual.player_idle_rotation)))))*host.player_art_scale()
	var player_front:float=host.BATTLE_VIEW_SIZE.y*float(visual.player_ship_y)-absf(float(visual.player_idle_y))-player_half
	var gap:float=float(host.db.config.get("explicitEnemyPlayerMinGap",visual.enemy_player_min_gap)) if explicit else float(visual.enemy_player_min_gap)
	var maximum:float=maxf(float(visual.enemy_max_y),0.52) if explicit or int(enemy.get("formation_columns",10))==5 else float(visual.enemy_max_y)
	# Fixed model margins replace rotated-outline fitting and depth iteration.
	# Authored rear boundary: model-dependent clearance pushed the back row
	# toward row two. Keep the row at its authored position instead of fitting it.
	var top:=100.0
	var front:=maxf(top,player_front-host.BATTLE_VIEW_SIZE.y*clampf(gap,0.0,1.0)-model_width*1.6)
	if explicit or host.game.enemies.size()<10:front=minf(front,host.BATTLE_VIEW_SIZE.y*maximum)
	front=maxf(top,front)
	var fixed_rows:bool=not explicit and enemy.get("size_formation",false) and int(enemy.get("formation_count",0))>5
	if fixed_rows:front=host.BATTLE_VIEW_SIZE.y*0.52
	layout={"revision":host.fixed_layout_revision,"width":model_width,"top":top,"frontline":front,"scale":scale_value,"variance":pose.variance,"size":enemy.size}
	pose.fixed_layout=layout
	if not pose.get("fixed_target_initialized",false):
		# Keep row membership, but author equal display spacing independently of
		# the nonlinear combat projection. Compute once, never fit ship outlines.
		if fixed_rows:
			var source_rows:Array=[]
			for member in host.game.enemies:
				var source_y:float=float(member.y)
				if not source_rows.has(source_y):source_rows.append(source_y)
			source_rows.sort()
			var row:int=source_rows.find(float(enemy.y))
			var last_y:float=float(source_rows.back())
			var last_target:float=minf(front,last_y+smoothstep(220.0,420.0,last_y)*220.0)
			var pitch:float=minf(196.0,(last_target-110.0)/maxi(1,source_rows.size()-1))
			pose.target.y=110.0+maxi(0,row)*pitch
		# Explicit layouts retain their authored coordinates.
		# Legacy dense slots receive evenly spaced fixed rows once at birth.
		if not explicit and not enemy.get("size_formation",false) and host.game.enemies.size()>=10:
			var columns:=maxi(1,int(enemy.get("formation_columns",5)))
			if host.game.enemies.size()>columns:columns=5
			var rows:=ceili(float(host.game.enemies.size())/columns)
			pose.target.y=lerpf(top+float(visual.enemy_entry_distance),front,float(int(enemy.slot)/columns)/maxf(1.0,rows-1))
		pose.fixed_target_initialized=true
	# Entry travels the authored distance; the resident top limit is not an
	# animation clamp. The former clamp collapsed front-row entry to ~8 px.
	layout.entry_distance=maxf(0.0,float(visual.enemy_entry_distance))
	return layout

static func explicit_entry_distance(host)->float:
	# Fit only the transient approach to the actual meters/protection envelope.
	# Resident authored coordinates, fixed model size and gameplay never move.
	var owner:Dictionary=host.enemy_pose(host.game.enemies[0])
	var signature:Array=[host.fixed_layout_revision,host.enemy_recognition_screen_scale()]
	if owner.get("explicit_entry_signature",[])==signature:return float(owner.explicit_entry_distance)
	var distance:=maxf(0.0,float(host.battle_visual.enemy_entry_distance))
	for member in host.game.enemies:
		if not member.get("explicit_formation",false):continue
		var member_pose:Dictionary=host.enemy_pose(member)
		var layout:=ensure(host,member,member_pose)
		var target:Vector2=member_pose.target+Vector2(member.x,member.y)-member_pose.logical_position
		target.y=minf(target.y,floorf(float(layout.frontline)))
		for part in preload("res://scripts/explicit_formation_geometry.gd").swept_parts(host,member,target):
			for point in part.polygon:distance=minf(distance,maxf(0.0,float(point.y)-6.25))
	owner.explicit_entry_signature=signature;owner.explicit_entry_distance=distance
	return distance

static func position(host,enemy:Dictionary,pose:Dictionary)->Vector2:
	var layout:=ensure(host,enemy,pose)
	# The existing pose owns residence. Time matters only while entering; logical
	# movement and layout/authoring changes invalidate the exact final position.
	var logical:=Vector2(enemy.x,enemy.y)
	var key:Array=[layout.revision,layout.width,layout.top,layout.frontline,pose.target,pose.logical_position,logical,pose.born,pose.duration,pose.entry_x,layout.entry_distance,enemy.get("explicit_formation",false)]
	if pose.get("residence_key",[])==key and host.fx_time>=float(pose.born)+float(pose.duration):return pose.residence_position
	var age:=maxf(0.0,float(host.fx_time)-float(pose.born))
	var enter:=1.0-pow(1.0-clampf(age/float(pose.duration),0.0,1.0),3)
	var target:Vector2=pose.target+Vector2(enemy.x,enemy.y)-pose.logical_position
	if not enemy.get("explicit_formation",false):target.y=maxf(target.y,float(layout.top))
	target.y=minf(target.y,floorf(float(layout.frontline)))
	var entry_distance:float=explicit_entry_distance(host) if enter<1.0 and enemy.get("explicit_formation",false) else float(layout.entry_distance)
	var point:=target+Vector2(float(pose.entry_x)*(1.0-enter),-entry_distance*(1.0-enter))
	if not enemy.get("explicit_formation",false):
		point.x=clampf(point.x,54.0,host.BATTLE_VIEW_SIZE.x-54.0)
	if enter==1.0:
		pose.residence_key=key;pose.residence_position=point
	return point
