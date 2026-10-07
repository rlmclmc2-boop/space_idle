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
	var minimum:=maxf(half_height+8.0,scene.enemy_display_top_clearance(enemy,maxf(point.y,target.y)))
	for iteration in 3:minimum=maxf(minimum,scene.enemy_display_top_clearance(enemy,minimum))
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
