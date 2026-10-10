extends RefCounted
var rows=[]
var transition_rows=[]
var reference_script=preload("res://reference_retained_enemy_contacts.gd")
var reference_visual=preload("res://reference_enemy_recognition_visual.gd").new()
func game_digest(scene)->String:
	return JSON.stringify({"enemies":scene.game.enemies,"projectiles":scene.game.projectiles,"player":scene.game.player,"rng":str(scene.game.rng.state)}).sha256_text()
func after_draw(scene,index:int,root:Viewport)->void:
	if index not in [1,30,90,300]:return
	var before=game_digest(scene)
	var current=scene.retained_contacts
	var image=root.get_texture().get_image()
	var reference=reference_script.new();current.get_parent().add_child(reference);reference.setup(scene)
	var boss=scene.game.state==BattleGame.State.COMBAT and scene.game.is_boss_encounter()
	var offset:Vector2=current.frame.get("offset",Vector2.ZERO)
	scene.battle_read_model.begin()
	reference.sync(offset,boss)
	reference.stage_foreground(current.frame.flights,current.frame.shots,offset)
	scene.battle_read_model.end()
	current.hide()
	await scene.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var expected=root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8);expected.convert(Image.FORMAT_RGBA8)
	if image.get_size()!=expected.get_size():push_error("NATIVE_SIZE_MISMATCH");return
	var a=image.get_data();var b=expected.get_data();var changed=0;var maximum=0;var over_one=0;var over_four=0
	var box=Rect2i();var initialized=false
	for pixel in image.get_width()*image.get_height():
		var delta=0
		for channel in 4:delta=maxi(delta,absi(int(a[pixel*4+channel])-int(b[pixel*4+channel])))
		if delta>0:
			changed+=1;maximum=maxi(maximum,delta)
			if delta>1:over_one+=1
			if delta>4:over_four+=1
			var point=Vector2i(pixel%image.get_width(),pixel/image.get_width())
			if not initialized:box=Rect2i(point,Vector2i.ONE);initialized=true
			else:box=box.expand(point)
	image.save_png("res://.runtime/native-current-%d.png"%index)
	expected.save_png("res://.runtime/native-reference-%d.png"%index)
	# Compare width packets against the pinned canonical implementation, with
	# alternating clearance/display widths rather than only the most recent one.
	var packets_equal=true
	for enemy in scene.game.enemies:
		var texture=scene.ship_hull_texture("enemy_"+str(clampi(int(enemy.size),1,6)))
		var mounts=scene.enemy_recognition_mounts(enemy)
		var cache={};var actual_cache={}
		for width in [12.0,35.0,65.0,12.0,65.0,35.0]:
			var actual=scene.enemy_recognition.geometry(texture,width,mounts,true,actual_cache,scene.enemy_recognition_screen_scale(),int(enemy.size)>=4)
			var canonical=reference_visual.geometry(texture,width,mounts,true,cache,scene.enemy_recognition_screen_scale(),int(enemy.size)>=4)
			packets_equal=packets_equal and actual==canonical
	current.show();reference.hide();reference.queue_free()
	await scene.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var state_equal=before==game_digest(scene)
	rows.append({"frame":index,"changed_pixels":changed,"max_channel_delta":maximum,"over_one":over_one,"over_four":over_four,"bounds":str(box),"canonical_packets_equal":packets_equal,"combat_state_unchanged":state_equal})
	if not packets_equal or not state_equal:push_error("NATIVE_CONTRACT_MISMATCH")
	if index==1:await check_transitions(scene,root)
func report()->Dictionary:return {"transitions":transition_rows,"frames":rows,"scope":"same live battle state, native reference6144 painter versus transformed resident fills; snapshot comparison only, not clean timing"}

func compare_transition(scene,root:Viewport,reference,label:String,boss:bool,expected_recovering:int=-1)->void:
	var current=scene.retained_contacts
	var offset:Vector2=current.frame.get("offset",Vector2.ZERO)
	var before=game_digest(scene)
	var enemy:Dictionary=scene.game.enemies[0]
	var canonical_cache:Dictionary=scene.enemy_pose(enemy).duplicate()
	var canonical_status:Dictionary=reference_visual.state(enemy,scene.game.enemy_shield_time,scene.game.paused,canonical_cache)
	scene.battle_draw_enemy_positions={}
	scene.battle_read_model.begin(true)
	current.sync(offset,boss);current.stage_foreground(current.frame.flights,current.frame.shots,offset)
	scene.battle_read_model.end()
	reference.hide();current.show()
	await scene.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var actual=root.get_texture().get_image()
	var record=current.records[int(enemy.uid)]
	var identity_ok=is_same(record.entity,enemy)
	var fallback_ok=record.fallback.visible==boss
	var canonical_state_ok=boss or record.status==canonical_status
	var status_ok=true
	if expected_recovering>=0:status_ok=bool(record.status.recovering)==bool(expected_recovering)
	scene.battle_read_model.begin()
	reference.sync(offset,boss);reference.stage_foreground(current.frame.flights,current.frame.shots,offset)
	scene.battle_read_model.end()
	current.hide();reference.show()
	await scene.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var expected=root.get_texture().get_image()
	actual.convert(Image.FORMAT_RGBA8);expected.convert(Image.FORMAT_RGBA8)
	var a=actual.get_data();var b=expected.get_data();var changed=0;var maximum=0;var over_one=0
	for pixel in actual.get_width()*actual.get_height():
		var delta=0
		for channel in 4:delta=maxi(delta,absi(int(a[pixel*4+channel])-int(b[pixel*4+channel])))
		if delta>0:changed+=1;maximum=maxi(maximum,delta)
		if delta>1:over_one+=1
	var unchanged=before==game_digest(scene)
	transition_rows.append({"case":label,"changed_pixels":changed,"max_channel_delta":maximum,"over_one":over_one,"identity_exact":identity_ok,"fallback_exact":fallback_ok,"recovery_exact":status_ok,"canonical_state_exact":canonical_state_ok,"combat_state_unchanged_during_render":unchanged})
	if not identity_ok or not fallback_ok or not status_ok or not canonical_state_ok or not unchanged or over_one>0:push_error("NATIVE_TRANSITION_MISMATCH "+label)
	reference.hide();current.show()

func check_transitions(scene,root:Viewport)->void:
	# Temporary mutations inside the existing isolated fixture; no game tick, no
	# gameplay/replay replacement. Restore authoritative fields and visual clocks.
	var before=game_digest(scene)
	var enemy:Dictionary=scene.game.enemies[0]
	var pose:Dictionary=scene.enemy_pose(enemy)
	var fields={};var pose_fields={}
	for key in ["max_shield","shield","shieldRecovery","shieldDelay","shield_hit_at","shieldType"]:fields[key]=[enemy.has(key),enemy.get(key)]
	for key in ["recognition_shield_clock","recognition_shield_amount","recognition_recovering"]:pose_fields[key]=[pose.has(key),pose.get(key)]
	var shield_clock=scene.game.enemy_shield_time;var paused=scene.game.paused
	var leader_uid=scene.encounter_presentation.leader_uid;var tier=scene.encounter_presentation.tier;var focus=scene.encounter_presentation.focus
	var reference=reference_script.new();scene.retained_contacts.get_parent().add_child(reference);reference.setup(scene);reference.hide()
	var twin:Dictionary=enemy.duplicate(true);twin.x+=7.0
	scene.game.enemies[0]=twin
	await compare_transition(scene,root,reference,"same_uid_replacement",false)
	scene.game.enemies[0]=enemy;scene.enemy_poses[int(enemy.slot)]=pose
	await compare_transition(scene,root,reference,"identity_restored",false)
	enemy.max_shield=100.0;enemy.shield=0.0;enemy.shieldRecovery=10.0;enemy.shieldDelay=0.0;enemy.shield_hit_at=-100.0;enemy.shieldType=1
	await compare_transition(scene,root,reference,"shield_broken",false,0)
	enemy.shield=20.0;scene.game.enemy_shield_time=shield_clock+0.2
	await compare_transition(scene,root,reference,"shield_recovering",false,1)
	scene.game.paused=true
	await compare_transition(scene,root,reference,"shield_recovery_paused",false,0)
	scene.game.paused=false;enemy.shield=40.0;scene.game.enemy_shield_time=shield_clock+0.4
	await compare_transition(scene,root,reference,"shield_recovery_resumed",false,1)
	scene.encounter_presentation.leader_uid=int(enemy.uid);scene.encounter_presentation.tier="boss"
	await compare_transition(scene,root,reference,"boss_leader_fallback",true)
	scene.encounter_presentation.leader_uid=leader_uid;scene.encounter_presentation.tier=tier
	await compare_transition(scene,root,reference,"ordinary_after_boss",false,1)
	for key in fields:
		if fields[key][0]:enemy[key]=fields[key][1]
		else:enemy.erase(key)
	for key in pose_fields:
		if pose_fields[key][0]:pose[key]=pose_fields[key][1]
		else:pose.erase(key)
	scene.game.enemy_shield_time=shield_clock;scene.game.paused=paused;scene.encounter_presentation.focus=focus
	scene.battle_draw_enemy_positions={};scene.battle_read_model.begin(true)
	var current=scene.retained_contacts;current.sync(current.frame.offset,false)
	current.stage_foreground(current.frame.flights,current.frame.shots,current.frame.offset)
	scene.battle_read_model.end();reference.hide();reference.queue_free();current.show()
	await scene.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var restored=before==game_digest(scene)
	transition_rows.append({"case":"authoritative_restore","exact":restored})
	if not restored:push_error("NATIVE_TRANSITION_RESTORE_MISMATCH")
