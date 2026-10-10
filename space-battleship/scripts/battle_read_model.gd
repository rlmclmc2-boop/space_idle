extends RefCounted
## A read-only spatial publication for one exact logical/presentation clock.
## Authority remains BattleGame; callbacks keep their original order. No RNG.
var host
var active=false
var compiling=false
var clock=-INF
var records:Dictionary={}
var config:Dictionary={}
var config_signature:Array=[]
var shape_revision=0
var geometry_revision=0
var bounds_revision=-1
var bounds:Array[Rect2]=[]
var bottom=-INF
var bounds_members:Array=[]

func setup(owner)->void:host=owner

func begin(force:bool=false)->void:
	active=true
	var next_config={"base_scale":host.player_base_art_scale(),"art_scale":host.player_art_scale(),"screen_scale":host.enemy_recognition_screen_scale(),"final":host.game.is_final_encounter(),"boss":host.game.is_boss_encounter()}
	var signature=[next_config,host.battle_visual.hash(),host.db.config.get("explicitEnemyPlayerMinGap",host.battle_visual.enemy_player_min_gap)]
	if not force and clock==host.fx_time and signature==config_signature:return
	if force or signature!=config_signature:shape_revision+=1
	config=next_config;config_signature=signature
	var visual=host.battle_visual
	config.player_front=host.BATTLE_VIEW_SIZE.y*float(visual.player_ship_y)-absf(float(visual.player_idle_y))-(host.SHIP_ART_CANVAS.y*float(visual.player_core_scale)/2.0+host.SHIP_ART_CANVAS.x*float(visual.player_core_scale)/2.0*absf(sin(deg_to_rad(float(visual.player_idle_rotation)))))*float(config.art_scale)
	var present={}
	compiling=true
	for enemy in host.game.enemies:
		var uid=int(enemy.uid);present[uid]=true
		var old:Dictionary=records.get(uid,{})
		if old.is_empty() or not is_same(old.entity,enemy):old={"entity":enemy,"position_clock":-INF};records[uid]=old
		# Appearance contracts are resolved once at the boundary, never per query.
		if int(old.get("shape_revision",-1))!=shape_revision:
			compile_shape(enemy,old)
		old.position_clock=-INF
	for uid in records.keys():
		if not present.has(uid):records.erase(uid)
	compiling=false
	clock=host.fx_time;geometry_revision+=1;bounds_revision=-1
	# Publish the complete spatial table at the boundary. Display consumers do
	# not independently walk the same geometry dependency graph.
	for enemy in host.game.enemies:
		if enemy.hp>0:position(enemy)

func compile_shape(enemy:Dictionary,row:Dictionary)->void:
	row.components=host._source_enemy_weapon_components(enemy)
	row.frontline=_frontline(enemy)
	row.width_base=_width_base(enemy)
	row.shape_revision=shape_revision

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
		_publish_position(enemy,row,logical)
	return row.position

func _publish_position(enemy:Dictionary,row:Dictionary,logical:Vector2)->void:
	row.position=host._source_enemy_render_position(enemy);row.logical=logical;row.position_clock=clock
	geometry_revision+=1;bounds_revision=-1

func fleet_bounds()->Array[Rect2]:
	ensure_clock()
	# Calculate all contacts once, then publish an immutable list to every label.
	var points=[]
	var members=[]
	for enemy in host.game.enemies:
		if enemy.hp>0:
			points.append([enemy,host.enemy_render_position(enemy)]);members.append(int(enemy.uid))
	if bounds_revision==geometry_revision and members==bounds_members:return bounds
	bounds_members=members
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
	clock=-INF;bounds_revision=-1;shape_revision+=1

func display_contact(enemy:Dictionary,offset:Vector2,boss:bool)->Dictionary:
	# One complete display publication. Native painters consume this packet;
	# they do not derive gameplay geometry or query equipment independently.
	var components_value=components(enemy)
	var supported=not boss and not host.encounter_presentation.is_leader(enemy)
	for component in components_value:
		var visual_class=str(component.profile.get("visual_class",""))
		if not ((component.damage_type==2 and visual_class=="gun") or (component.damage_type==1 and visual_class=="energy")):supported=false
	var result={"components":components_value,"supported":supported}
	if not supported:return result
	var point=host.enemy_render_position(enemy)
	var width=width_at(enemy,point.y)
	var angle=host.enemy_render_angle(enemy)
	var packet=host.enemy_recognition_geometry(enemy,width)
	var status=host.enemy_recognition.state(enemy,host.game.enemy_shield_time,host.game.paused,host.enemy_pose(enemy))
	var outline:PackedVector2Array=packet.inner
	if not status.alive:outline=PackedVector2Array()
	elif status.active and int(enemy.get("shieldType",0)) in [0,1,2]:
		outline=packet.outer if status.show_hull and int(enemy.get("armourType",0)) in [1,2] else packet.inner
		if int(enemy.get("shieldType",0))==1 and int(enemy.size)>=4:outline=packet.front if status.show_hull and int(enemy.get("armourType",0)) in [1,2] else packet.single_front
	elif not (status.show_hull and int(enemy.get("armourType",0)) in [1,2]) and not status.repair:outline=PackedVector2Array()
	var poses=[]
	for component in components_value:poses.append(host.enemy_component_pose(enemy,component,point,width))
	result.merge({"position":point+offset,"width":width,"angle":angle,"light":host.enemy_hull_light(enemy),"types":host.enemy_attack_types(enemy),"packet":packet,"status":status,"layout":host.enemy_status_layout(enemy,point+offset,width,angle,outline),"mounts":poses})
	return result
