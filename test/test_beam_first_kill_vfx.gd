extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
	func create_battle_game(_persist: bool) -> BattleGame:return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
var checks:=0
var failures:=0
var scene
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func setup(hp:float)->Dictionary:
	var g=scene.game
	g.start(1,false);g.spawn_group();g.enemies.resize(2)
	g.projectiles.clear();scene.particles.clear()
	for i in g.enemies.size():
		var e:Dictionary=g.enemies[i]
		e.hp=hp if i==0 else 100000;e.max_hp=e.hp;e.equipment=[];e.cooldowns=[];e.x=250.0+float(i)*100.0;e.y=120.0
	g.refresh_missile_target_registry()
	var target:Dictionary=g.targets(1)[0]
	target.hp=hp;target.max_hp=hp
	return target
func run()->void:
	scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI)
	scene.music_on=false;scene.automation_args=["--capture"]
	root.add_child(scene);current_scene=scene;scene.set_process(false);scene.automation_args=[]
	var g=scene.game
	g.save_enabled=false;g.rng.seed=92841;g.speed=1
	g.profile.onboarding.completed=true
	if is_instance_valid(scene.beginner_guide):scene.beginner_guide.hide()
	g.profile.cleared=range(1,76);g.rebuild_unlocks();g.profile.selectedShip="Frigate"
	g.profile.loadout={"weapons":[{"key":"longLaser","level":1},{"key":"","level":1},{"key":"","level":1}],"defence":[{"key":"armour","level":10},{"key":"","level":1}]}
	g.db.equipment.longLaser[0].merge({"dmg":10,"dmgtype":1,"cd":0.2,"para1":1.0,"para2":3.0,"para3":0.3},true)
	g.db.data.enhance_config.base_critical_rate.value=0;g.db.data.enhance_config.repeat_probability.value=0
	if OS.get_environment("BEAM_DEMO")=="1":
		await demo();return
	var victim:=setup(1.0)
	scene.refresh_structure();scene.refresh_tab_visibility()
	scene._process(0.01)
	var shot:Dictionary=g.projectiles[0]
	g.tick_projectiles(0.29)
	scene.sync_beam_visuals()
	check(victim.hp<=0 and not g.long_laser_valid(shot),"first scheduled hit kills immediately and invalidates lock")
	check(int(shot.ticks)==1,"first-kill beam settles exactly one real tick")
	check(not g.projectiles.has(shot) and g.beam_chain_targets(shot).is_empty(),"dead beam leaves projectiles and retains no logical chain")
	var contacts:Dictionary=scene.get("beam_contacts") if scene.get("beam_contacts")!=null else {}
	check(contacts.has(int(shot.serial)),"first-kill hit retains a value-only visible contact")
	print("FIRST_KILL ticks=",shot.ticks," hp=",victim.hp," valid=",g.long_laser_valid(shot)," cached_contacts=",contacts.size()," legacy_particles=",scene.particles.size())
	if OS.get_environment("BEAM_BASELINE")=="1":
		await finish();return
	if contacts.has(int(shot.serial)):
		var contact:Dictionary=contacts[int(shot.serial)]
		check(contact.has("retired_at") and not contact.has("shot") and not contact.has("target"),"retired visual stores no dead target or logical beam reference")
		check(Vector2(contact.start).distance_to(contact.end)>10,"instant kill preserves full muzzle-to-hit segment")
		var endpoint:Vector2=contact.end
		victim.x+=100
		check(contact.end==endpoint,"dead target movement cannot drag the recorded hit position")
		var rng_before:int=g.rng.state
		var ticks_before:int=shot.ticks
		scene.fx_time+=0.1;scene.sync_beam_visuals()
		check(contacts.has(int(shot.serial)),"first-kill beam remains visible for the short hold")
		check(g.rng.state==rng_before and int(shot.ticks)==ticks_before,"visual hold consumes no combat RNG and causes no extra hit")
		scene.game.paused=true
		var clock_before:float=scene.fx_time
		scene._process(0.1)
		check(scene.fx_time==clock_before,"pause freezes visual lifetime")
		scene.game.paused=false
		scene.fx_time+=0.13;scene.sync_beam_visuals()
		check(not contacts.has(int(shot.serial)),"retired visual expires after 0.22 seconds")
	victim=setup(100000)
	g.tick(0.3);scene.sync_beam_visuals()
	shot=g.projectiles[0]
	check(g.long_laser_valid(shot) and int(shot.ticks)==1,"normal target keeps the sustained lock")
	var contact:Dictionary=scene.beam_contacts[int(shot.serial)]
	check(not contact.has("retired_at"),"living sustained beam has no duplicate finish effect")
	var hp:float=victim.hp
	g.tick_projectiles(0.2);scene.sync_beam_visuals()
	check(int(shot.ticks)==2 and victim.hp<hp,"normal beam retains its next scheduled damage tick")
	g.enemies.erase(victim);g.tick(0.01);scene.sync_beam_visuals()
	check(not g.long_laser_valid(shot) and scene.beam_contacts[int(shot.serial)].has("retired_at"),"target removal ends old lock and begins only visual finish")
	var next:Dictionary=g.projectiles[0]
	check(not is_same(next,shot) and int(next.ticks)==0,"retarget creates an independent freshly charging beam")
	check(not scene.beam_contacts.has(int(next.serial)),"new target has no contact before a real hit")
	g.projectiles.clear();scene.sync_beam_visuals()
	check(not scene.beam_contacts.has(int(next.serial)),"cancelled windup never fabricates a hit")
	await finish()
func finish()->void:
	print("BEAM FIRST KILL checks=",checks," failures=",failures)
	scene.game.launch_provider=Callable();scene.game.target_provider=Callable();scene.queue_free();await process_frame;current_scene=null
	quit(1 if failures else 0)

func demo()->void:
	var title:=Label.new()
	title.position=Vector2(25,190);title.add_theme_font_size_override("font_size",22)
	title.add_theme_color_override("font_color",Color("aff8ff"));scene.add_child(title)
	var g=scene.game
	var version:="BASELINE" if OS.get_environment("BEAM_BASELINE")=="1" else "CANDIDATE"
	title.text=version+" | 1x real-time | ready"
	setup(100000);scene.refresh_structure();scene.refresh_tab_visibility()
	g.paused=true;scene.set_process(true)
	await create_timer(2.0).timeout
	for cycle in 3:
		setup(1.0)
		title.text=version+" | 1x | low HP: first hit kills ("+str(cycle+1)+"/3)"
		g.paused=false
		var hits:=[0]
		var watch:Callable=func(kind,_info):
			if kind=="beam_hit":hits[0]+=1
		g.event.connect(watch)
		while hits[0]==0:await process_frame
		g.event.disconnect(watch)
		print("DEMO lowHP cycle=",cycle," first_hit_at=",scene.fx_time," contacts=",scene.get("beam_contacts"))
		if cycle==0 and OS.get_environment("BEAM_SCREENSHOTS")=="1":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../beam-first-kill.png")
		await create_timer(0.5).timeout
		g.paused=true
		await create_timer(0.35).timeout
	var victim:=setup(100000)
	title.text=version+" | 1x | sustained lock and ramp"
	g.paused=false
	await create_timer(2.5).timeout
	if OS.get_environment("BEAM_SCREENSHOTS")=="1":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../beam-sustained.png")
	title.text=version+" | 1x | current target dies: new target charges"
	# The next real tick kills the current target; the next lock starts normally.
	victim.hp=1
	await create_timer(2.0).timeout
	if OS.get_environment("BEAM_SCREENSHOTS")=="1":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../beam-retargeted.png")
	title.text=version+" | 1x | finished"
	await create_timer(0.5).timeout
	await finish()
