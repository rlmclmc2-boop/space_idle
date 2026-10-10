extends RefCounted
var rows=[]
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
func report()->Dictionary:return {"frames":rows,"scope":"same live battle state, native reference6144 painter versus transformed resident fills; snapshot comparison only, not clean timing"}
