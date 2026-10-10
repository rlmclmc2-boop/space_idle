extends SceneTree
## Entry geometry must stay exact while the fleet-wide calculation is shared.
class Probe extends "res://scripts/battlefield.gd":
	var clearance_calls:=0
	func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
	func show_qa_tools()->void:pass
	func show_chrono_login_report()->void:pass
	func enemy_display_top_clearance(enemy:Dictionary,y:float)->float:
		clearance_calls+=1
		return super.enemy_display_top_clearance(enemy,y)
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")

func original_clearance(scene,enemy:Dictionary,y:float)->float:
	var pose:Dictionary=scene.enemy_pose(enemy)
	var width:float=scene.enemy_render_width_at_y(enemy,y)
	var scale_value:float=scene.enemy_recognition_screen_scale()
	var packet:Dictionary=scene.enemy_recognition.geometry(scene.ship_hull_texture("enemy_"+str(clampi(int(enemy.size),1,6))),width,scene.enemy_recognition.descriptors(scene.enemy_weapon_components(enemy)),float(enemy.get("max_shield",0))>0 and float(enemy.get("shieldRecovery",0))>0,{},scale_value,int(enemy.size)>=4)
	var outlines:Array=[packet.inner]
	if float(enemy.get("max_shield",0))>0:
		outlines.append(packet.outer)
		if int(enemy.get("shieldType",0))==1 and int(enemy.size)>=4:outlines.append(packet.front)
	var top:=0.0
	var angle:float=PI+scene.enemy_render_angle(enemy)
	for outline in outlines:
		for point in outline:top=minf(top,Vector2(point).rotated(angle).y)
	return -top+(28.0 if scene.game.is_boss_encounter() else 16.0)+6.0+4.0/scale_value

func original_position(scene,enemy:Dictionary)->Vector2:
	# Independent pre-fix formula, including all three fixed-point iterations.
	var pose:Dictionary=scene.enemy_pose(enemy)
	var age:=maxf(0,scene.fx_time-float(pose.born))
	var enter:=1.0-pow(1.0-clampf(age/float(pose.duration),0,1),3)
	var target:Vector2=pose.target+Vector2(enemy.x,enemy.y)-pose.logical_position
	if not enemy.get("explicit_formation",false):target.x=clampf(target.x,54,scene.BATTLE_VIEW_SIZE.x-54)
	var hover:=Vector2(sin(scene.fx_time*1.13+float(pose.phase))*float(scene.battle_visual.enemy_idle_x),sin(scene.fx_time*0.91+float(pose.phase))*float(scene.battle_visual.enemy_idle_y))
	if enemy.get("size_formation",false):hover*=0.25
	var distance:float=scene.enemy_safe_entry_distance() if enter<1.0 else 0.0
	var point:=target+Vector2(float(pose.entry_x)*(1.0-enter),-distance*(1.0-enter))+hover*enter
	var half_height:float=(78.0 if scene.game.is_final_encounter() else 66.0 if int(enemy.size)>=4 else 54.0)*1.06
	var minimum:=maxf(half_height+8.0,original_clearance(scene,enemy,maxf(point.y,target.y)))
	for iteration in 3:minimum=maxf(minimum,original_clearance(scene,enemy,minimum))
	if not enemy.get("explicit_formation",false):point.y=clampf(point.y,minimum,floorf(scene.enemy_frontline_y_limit(enemy)))
	else:point.y=minf(point.y,floorf(scene.enemy_frontline_y_limit(enemy)))
	return point

func compare_positions(scene,label:String)->void:
	scene.enemy_entry_batch_active=false
	var expected:Array=[]
	for enemy in scene.game.enemies:expected.append(original_position(scene,enemy))
	var before:Dictionary=scene.game.profile.duplicate(true)
	var rng_state:int=scene.game.rng.state
	scene.enemy_entry_batch_active=true
	scene.enemy_entry_distance_time=-INF
	for index in scene.game.enemies.size():
		check(scene.enemy_render_position(scene.game.enemies[index])==expected[index],label+" exact position "+str(index))
	check(scene.game.profile==before and scene.game.rng.state==rng_state,label+" preserves profile and RNG")
	scene.enemy_entry_batch_active=false

func run()->void:
	var scene:=Probe.new()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.set_process(false);scene.automation_args=[]
	scene.music.stop();scene.sound_on=false
	scene.game.profile.highestLevel=7
	scene.game.profile.onboarding.completed=true
	scene.game.profile.loadout={"weapons":[{"key":"laser","level":1},{"key":"cannon","level":1},{"key":"missile","level":1}],"defence":[{"key":"armour","level":10},{"key":"shield","level":10}]}
	scene.game.rng.seed=1701
	for wave in [6,7,8,9]:
		check(scene.game.start(7,false),"start fixture")
		scene.game.group_index=wave-1
		scene.game.spawn_group()
		for enemy in scene.game.enemies:scene.enemy_pose(enemy).born=0.0
		for time in [0.0,0.1,0.5,1.0,1.2]:
			scene.fx_time=time
			compare_positions(scene,"wave %d time %.1f"%[wave,time])
		scene.fx_time=0.2
		scene.enemy_entry_batch_active=true;scene.enemy_entry_distance_time=-INF
		scene.clearance_calls=0
		var first:float=scene.enemy_safe_entry_distance()
		for i in 50:check(scene.enemy_safe_entry_distance()==first,"shared limit exact")
		check(scene.clearance_calls==scene.game.enemies.size(),"one fleet traversal per boundary")
		scene.fx_time+=1.0/60.0
		scene.enemy_safe_entry_distance()
		check(scene.clearance_calls==scene.game.enemies.size()*2,"next logical step recalculates")
		scene.on_event("state",{})
		scene.enemy_safe_entry_distance()
		check(scene.clearance_calls==scene.game.enemies.size()*3,"same-time state event invalidates")
		scene.enemy_entry_batch_active=false
		for speed in [1.0,2.0,10.0]:
			scene.game.speed=speed
			scene._process(1.0/60.0)
			check(not scene.enemy_entry_batch_active and scene.enemy_entry_distance_time==-INF,"process releases cache at speed "+str(speed))
			compare_positions(scene,"after real process speed "+str(speed))
	# Cached extrema follow geometry identity, exact angle and shield layers.
	var enemy:Dictionary=scene.game.enemies[0]
	var equipment:Array=enemy.equipment.duplicate(true)
	for names in [["cannon-mon"],["laser-mon","missile-mon"],[]]:
		enemy.equipment.clear()
		for name in names:enemy.equipment.append({"name":name})
		var mounts:Array=scene.enemy_recognition_mounts(enemy)
		check(mounts==scene.enemy_recognition.descriptors(scene.enemy_weapon_components(enemy)),"appearance mounts match independent descriptor projection")
		check(is_same(mounts,scene.enemy_recognition_mounts(enemy)),"unchanged component owner reuses mounts")
		check(scene.enemy_display_top_clearance(enemy,150.0)==original_clearance(scene,enemy,150.0),"equipment replacement invalidates exact envelope")
	enemy.equipment=equipment
	var projectiles:Array=scene.game.projectiles.duplicate()
	# Query-only high-load fixture. No logic tick or rendering sees these fillers.
	while scene.game.projectiles.size()<64:scene.game.projectiles.append({"beam":false})
	scene.fx_time=10.0
	for e in scene.game.enemies:scene.enemy_pose(e).born=0.0
	enemy.explicit_formation=false
	scene.enemy_entry_batch_active=true
	scene.enemy_pose(enemy).erase("steady_position_key")
	scene.enemy_render_position(enemy)
	var calls:int=scene.clearance_calls
	for i in 50:scene.enemy_render_position(enemy)
	check(scene.clearance_calls==calls,"settled batch avoids repeated top solves")
	scene.enemy_entry_batch_active=false
	for field in ["x","y","size","max_shield","shieldRecovery","shieldType"]:
		var previous=enemy.get(field,0)
		enemy[field]=previous+1
		compare_positions(scene,"same-time live entity change "+field)
		enemy[field]=previous
	for field in ["rotation","variance","phase","entry_x"]:
		var pose:Dictionary=scene.enemy_pose(enemy)
		var previous=pose[field]
		pose[field]=previous+0.1
		compare_positions(scene,"same-time pose change "+field)
		pose[field]=previous
	for field in ["enemy_idle_x","enemy_idle_y","enemy_idle_rotation","enemy_base_scale","enemy_max_y","enemy_player_min_gap","player_core_scale","player_ship_y"]:
		var previous=scene.battle_visual[field]
		scene.battle_visual[field]=previous+0.01
		compare_positions(scene,"same-time visual setting change "+field)
		scene.battle_visual[field]=previous
	var old_gap=ProjectSettings.get_setting("visuals/enemy_protection_gap_pixels",2.0)
	ProjectSettings.set_setting("visuals/enemy_protection_gap_pixels",float(old_gap)+1.0)
	compare_positions(scene,"same-time protection pixel gap change")
	ProjectSettings.set_setting("visuals/enemy_protection_gap_pixels",old_gap)
	for explicit in [false,true]:
		enemy.explicit_formation=explicit
		for shield_type in [0,1,2]:
			enemy.max_shield=100.0;enemy.shieldType=shield_type
			for time in [0.2,2.0]:
				scene.fx_time=time
				for y in [50.0,90.0,250.0]:
					var expected:float=original_clearance(scene,enemy,y)
					check(scene.enemy_display_top_clearance(enemy,y)==expected,"cached clearance exactly matches fresh geometry")
					check(scene.enemy_display_top_clearance(enemy,y)==expected,"repeated clearance keeps exact value")
				compare_positions(scene,"shield/angle/authored boundary")
	scene.game.projectiles=[]
	scene.fx_time=10.0
	var expected_provider:Vector2=scene.battle_logical_point(original_position(scene,enemy))
	scene.enemy_pose(enemy).erase("steady_position_key")
	scene.enemy_entry_batch_active=true
	check(scene._prototype_target_point(enemy)==expected_provider,"actual guidance provider keeps exact target point at low projectile count")
	calls=scene.clearance_calls
	for i in 50:check(scene._prototype_target_point(enemy)==expected_provider,"repeated guidance provider keeps exact target point")
	check(scene.clearance_calls==calls and not scene.enemy_provider_query_active,"guidance owns bounded reuse and releases context")
	# A read-only label solve can supply a same-time draw. The draw still checks
	# every original live input and does not build a key for a cold pose.
	enemy.explicit_formation=false
	scene.damage_text_enemy_bounds()
	check(not scene.enemy_provider_query_active,"label obstacle query releases provider context")
	var before_draw:Dictionary=scene.game.profile.duplicate(true)
	var before_rng:int=scene.game.rng.state
	scene.battle_draw_active=true;scene.battle_draw_enemy_positions.clear()
	var expected_draw:Vector2=original_position(scene,enemy)
	calls=scene.clearance_calls
	check(scene.enemy_render_position(enemy)==expected_draw,"warm draw reuses the exact label position")
	check(scene.clearance_calls==calls,"warm draw avoids solving the same top envelope again")
	for field in ["x","y","max_shield"]:
		var previous=enemy.get(field,0)
		enemy[field]=previous+1;scene.battle_draw_enemy_positions.clear()
		check(scene.enemy_render_position(enemy)==original_position(scene,enemy),"draw rejects same-time live input change "+field)
		enemy[field]=previous
	scene.battle_draw_active=false;scene.battle_draw_enemy_positions.clear()
	check(scene.game.profile==before_draw and scene.game.rng.state==before_rng,"layout-to-draw sharing leaves business state and RNG unchanged")
	var real_projectiles=scene.game.projectiles.duplicate()
	for count in [0,7,8,31,32]:
		scene.game.projectiles.clear()
		for i in count:scene.game.projectiles.append({})
		for item in scene.game.enemies:scene.enemy_pose(item).erase("steady_position_key")
		compare_positions(scene,"busy fleet threshold %d"%count)
	scene.game.projectiles.assign(real_projectiles)
	var original_size=enemy.size
	for size in range(1,7):
		enemy.size=size
		for y in [50.0,90.0,150.0,250.0,400.0]:
			var position:=Vector2(220.0,y)
			var width:float=scene.enemy_render_width_at_y(enemy,y)
			for component in scene.enemy_weapon_components(enemy):
				check(scene.enemy_component_pose(enemy,component,position)==scene.enemy_component_pose(enemy,component,position,width),"same-draw known width keeps exact mount/muzzle geometry")
		var width:float=scene.enemy_render_width(enemy)
		var live:Dictionary=scene.enemy_recognition_geometry(enemy)
		check(live==scene.enemy_recognition_geometry(enemy,width),"same-draw known width keeps exact recognition/protection packet")
	enemy.size=original_size
	check(scene.game.profile==before_draw and scene.game.rng.state==before_rng,"known drawing widths do not change business state or RNG")
	scene.enemy_entry_batch_active=false
	scene.game.projectiles=projectiles
	enemy.explicit_formation=false
	scene.game.paused=true
	scene._process(1.0/60.0)
	compare_positions(scene,"paused")
	scene.scale=Vector2(0.8,0.8)
	compare_positions(scene,"resized")
	scene.battle_layer.hide()
	scene._process(0)
	scene.battle_layer.show()
	compare_positions(scene,"revealed")
	await process_frame
	await RenderingServer.frame_post_draw
	check(not scene.enemy_entry_batch_active,"draw releases cache")
	print("Enemy entry batch: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
