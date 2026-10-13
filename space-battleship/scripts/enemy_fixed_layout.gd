extends RefCounted
## Fixed model dimensions and authored formation bounds. Owned by the existing
## mutable pose; shared by native geometry and a legacy owner after handoff.
static func sync(host)->bool:
	# Check mutable configuration once at a simulation/display boundary, never
	# build the old full parameter key for each position query.
	var members:Array=[]
	for enemy in host.game.enemies:
		members.append([int(enemy.uid),int(enemy.slot),int(enemy.size),enemy.get("explicit_formation",false),enemy.get("size_formation",false),enemy.get("formation_columns",10),enemy.get("formation_count",0)])
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
	return minf(value,74.0) if int(enemy.get("formation_count",0))>=4 else value

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
	layout={"revision":host.fixed_layout_revision,"width":model_width,"top":top,"frontline":front,"scale":scale_value,"variance":pose.variance,"size":enemy.size}
	pose.fixed_layout=layout
	if not pose.get("fixed_target_initialized",false):
		# Source coordinates already own explicit and size-sorted formations.
		# Legacy dense slots receive evenly spaced fixed rows once at birth.
		if not explicit and not enemy.get("size_formation",false) and host.game.enemies.size()>=10:
			var columns:=maxi(1,int(enemy.get("formation_columns",5)))
			if host.game.enemies.size()>columns:columns=5
			var rows:=ceili(float(host.game.enemies.size())/columns)
			pose.target.y=lerpf(top+float(visual.enemy_entry_distance),front,float(int(enemy.slot)/columns)/maxf(1.0,rows-1))
		pose.fixed_target_initialized=true
	layout.entry_distance=minf(float(visual.enemy_entry_distance),maxf(0.0,float(pose.target.y)-top-absf(float(visual.enemy_idle_y))))
	return layout

static func position(host,enemy:Dictionary,pose:Dictionary)->Vector2:
	var layout:=ensure(host,enemy,pose)
	var age:=maxf(0.0,float(host.fx_time)-float(pose.born))
	var enter:=1.0-pow(1.0-clampf(age/float(pose.duration),0.0,1.0),3)
	var target:Vector2=pose.target+Vector2(enemy.x,enemy.y)-pose.logical_position
	var hover:=Vector2(sin(host.fx_time*1.13+float(pose.phase))*float(host.battle_visual.enemy_idle_x),sin(host.fx_time*0.91+float(pose.phase))*float(host.battle_visual.enemy_idle_y))
	if enemy.get("size_formation",false):hover*=0.25
	var point:=target+Vector2(float(pose.entry_x)*(1.0-enter),-float(layout.entry_distance)*(1.0-enter))+hover*enter
	if not enemy.get("explicit_formation",false):
		point.x=clampf(point.x,54.0,host.BATTLE_VIEW_SIZE.x-54.0)
		point.y=maxf(point.y,float(layout.top))
	point.y=minf(point.y,floorf(float(layout.frontline)))
	return point
