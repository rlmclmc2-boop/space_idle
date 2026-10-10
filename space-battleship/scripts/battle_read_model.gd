extends RefCounted
## A read-only spatial publication for one exact logical/presentation clock.
## Authority remains BattleGame; callbacks keep their original order. No RNG.
var host
var active=false
var compiling=false
var clock=-INF
var records:Dictionary={}
var config:Dictionary={}
var geometry_revision=0
var bounds_revision=-1
var bounds:Array[Rect2]=[]
var bottom=-INF

func setup(owner)->void:host=owner

func begin(force:bool=false)->void:
	active=true
	if not force and clock==host.fx_time:return
	config={"base_scale":host.player_base_art_scale(),"art_scale":host.player_art_scale(),"screen_scale":host.enemy_recognition_screen_scale(),"final":host.game.is_final_encounter(),"boss":host.game.is_boss_encounter()}
	var visual=host.battle_visual
	config.player_front=host.BATTLE_VIEW_SIZE.y*float(visual.player_ship_y)-absf(float(visual.player_idle_y))-(host.SHIP_ART_CANVAS.y*float(visual.player_core_scale)/2.0+host.SHIP_ART_CANVAS.x*float(visual.player_core_scale)/2.0*absf(sin(deg_to_rad(float(visual.player_idle_rotation)))))*float(config.art_scale)
	var present={}
	compiling=true
	for enemy in host.game.enemies:
		var uid=int(enemy.uid);present[uid]=true
		var old:Dictionary=records.get(uid,{})
		if old.is_empty() or not is_same(old.entity,enemy):old={"entity":enemy,"position_clock":-INF};records[uid]=old
		# Appearance contracts are resolved once at the boundary, never per query.
		old.components=host._source_enemy_weapon_components(enemy)
		old.frontline=_frontline(enemy)
		old.width_base=_width_base(enemy)
		old.position_clock=-INF
	for uid in records.keys():
		if not present.has(uid):records.erase(uid)
	compiling=false
	clock=host.fx_time;geometry_revision+=1;bounds_revision=-1
	# Publish the complete spatial table at the boundary. Display consumers do
	# not independently walk the same geometry dependency graph.
	for enemy in host.game.enemies:
		if enemy.hp>0:position(enemy)

func end()->void:active=false

func ready()->bool:
	return active and not compiling and clock==host.fx_time

func ensure_clock()->void:
	if active and not compiling and clock!=host.fx_time:begin()

func entry(enemy:Dictionary)->Dictionary:
	var row:Dictionary=records.get(int(enemy.get("uid",-1)),{})
	return row if not row.is_empty() and is_same(row.entity,enemy) else {}

func _width_base(enemy:Dictionary)->Dictionary:
	var tier=1.85 if bool(config.final) else 1.5 if int(enemy.size)>=4 else 1.0+float(int(enemy.size)-1)*0.08
	var limit=78.0 if bool(config.final) else 66.0 if int(enemy.size)>=4 else 54.0
	var base=minf(limit/(float(host.battle_visual.enemy_depth_scale_max)*float(host.battle_visual.enemy_scale_variance.y)),host.SHIP_VISUALS.CANVAS.y*1.2*float(config.base_scale)*float(host.battle_visual.enemy_base_scale)*tier)
	return {"base":base,"scale":host.enemy_config_visual_scale(int(enemy.size)),"explicit_scale":minf(1.0,float(config.screen_scale)/0.6) if enemy.get("explicit_formation",false) and int(enemy.size)>=4 else 1.0,"capped":int(enemy.get("formation_count",0))>=4}

func _frontline(enemy:Dictionary)->float:
	var half=(78.0 if bool(config.final) else 66.0 if int(enemy.size)>=4 else 54.0)*1.06*host.enemy_config_visual_scale(int(enemy.size))
	var max_y=maxf(float(host.battle_visual.enemy_max_y),0.52) if int(enemy.get("formation_columns",10))==5 else float(host.battle_visual.enemy_max_y)
	if enemy.get("explicit_formation",false):max_y=maxf(float(host.battle_visual.enemy_max_y),0.52)
	var gap=float(host.battle_visual.enemy_player_min_gap)
	if enemy.get("explicit_formation",false):gap=clampf(float(host.db.config.get("explicitEnemyPlayerMinGap",gap)),0.0,1.0)
	return minf(host.BATTLE_VIEW_SIZE.y*max_y,float(config.player_front)-host.BATTLE_VIEW_SIZE.y*gap-half)

func components(enemy:Dictionary)->Array:
	ensure_clock();var row=entry(enemy)
	return row.components if ready() and not row.is_empty() else host._source_enemy_weapon_components(enemy)

func frontline(enemy:Dictionary)->float:
	ensure_clock();var row=entry(enemy)
	return float(row.frontline) if ready() and not row.is_empty() else host._source_enemy_frontline_y_limit(enemy)

func width_at(enemy:Dictionary,y:float)->float:
	ensure_clock();var row=entry(enemy)
	if not ready() or row.is_empty():return host._source_enemy_render_width_at_y(enemy,y)
	var depth=clampf((y-90.0)/maxf(1.0,float(row.frontline)-90.0),0,1)
	var width=float(row.width_base.base)*float(row.width_base.scale)*lerpf(host.battle_visual.enemy_depth_scale_min,host.battle_visual.enemy_depth_scale_max,depth)*float(host.enemy_pose(enemy).variance)
	width*=float(row.width_base.explicit_scale)
	return minf(width,host.ENEMY_FORMATION_WIDTH_CAP) if row.width_base.capped else width

func position(enemy:Dictionary)->Vector2:
	ensure_clock();var row=entry(enemy)
	if not ready() or row.is_empty():return host._source_enemy_render_position(enemy)
	var logical=Vector2(enemy.x,enemy.y)
	if float(row.position_clock)!=clock or row.get("logical",Vector2.INF)!=logical:
		# The canonical solver keeps entry/clamping/outline iteration unchanged.
		row.position=host._source_enemy_render_position(enemy);row.logical=logical;row.position_clock=clock
		geometry_revision+=1;bounds_revision=-1
	return row.position

func fleet_bounds()->Array[Rect2]:
	ensure_clock()
	# Calculate all contacts once, then publish an immutable list to every label.
	var points=[]
	for enemy in host.game.enemies:
		if enemy.hp>0:points.append([enemy,host.enemy_render_position(enemy)])
	if bounds_revision==geometry_revision:return bounds
	bounds=[];bottom=-INF
	for item in points:
		var enemy:Dictionary=item[0];var point:Vector2=item[1]
		var width=host.enemy_render_width_at_y(enemy,point.y)
		var envelope=host.DAMAGE_ENEMY_BOUNDS_SCALE*width+Vector2(float(host.battle_visual.enemy_idle_x),float(host.battle_visual.enemy_idle_y))
		bounds.append(Rect2(point-envelope,envelope*2.0))
		var limit=floorf(host.enemy_frontline_y_limit(enemy))
		var maximum=host.ENEMY_FORMATION_WIDTH_CAP if int(enemy.get("formation_count",0))>=4 else maxf(host.enemy_render_width_at_y(enemy,90.0),host.enemy_render_width_at_y(enemy,limit))
		bottom=maxf(bottom,limit+maximum*host.DAMAGE_ENEMY_BOUNDS_SCALE.y+absf(float(host.battle_visual.enemy_idle_y)))
	bounds_revision=geometry_revision
	return bounds

func invalidate_membership()->void:
	# Event-time identity/alive changes must be visible before the next hit.
	clock=-INF;bounds_revision=-1
