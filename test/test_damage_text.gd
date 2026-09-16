extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func verify(scene) -> void:
	for i in range(scene.floats.size()):
		var a = scene.floats[i]
		for j in range(i):
			var b = scene.floats[j]
			assert(not scene.damage_text_rect(a.pos,a.text).intersects(scene.damage_text_rect(b.pos,b.text)),"Damage labels overlap")

func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	scene.game.pending_unlocks.clear()
	scene.floats.clear()
	for player in [true,false]:
		for i in range(12):
			scene.on_event("hit",{"x":260.0 if player else 1050.0,"y":400.0,"amount":1234567+i,"type":i%2+1,"player":player,"uid":1})
	assert(scene.floats.size()==2,"One accumulated label per target")
	for entry in scene.floats:
		assert(entry.amount==14814870,"Accumulate raw damage before formatting")
		assert(entry.text=="−%s" % scene.number(14814870),"Text shows total")
	verify(scene)
	for entry in scene.floats:
		entry.pos.y -= 5.6
		entry.life -= 0.2
	var old_pos: Vector2 = scene.floats[1].pos
	scene.on_event("hit",{"x":1080.0,"y":420.0,"amount":130,"type":1,"player":false,"uid":1})
	assert(scene.floats.size()==2 and scene.floats[1].amount==14815000,"Moving target keeps accumulating")
	assert(scene.floats[1].pos==old_pos and is_equal_approx(scene.floats[1].life,0.7),"Accumulation keeps flight and lifetime")
	scene.on_event("hit",{"x":1050.0,"y":400.0,"amount":999,"type":1,"player":false,"uid":2})
	assert(scene.floats.size()==3 and scene.floats[2].amount==999,"Different enemy at same position stays separate")
	scene.floats[1].life = 0
	scene.on_event("hit",{"x":1050.0,"y":400.0,"amount":7,"type":2,"player":false,"uid":1})
	assert(scene.floats.size()==4 and scene.floats[3].amount==7,"Expired label starts fresh total")
	scene.floats = scene.floats.filter(func(entry):return entry.life > 0)
	verify(scene)
	scene.battle_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://damage-text.png")
	scene.floats.clear()
	scene.on_event("hit",{"x":260.0,"y":400.0,"amount":1,"type":1,"player":true})
	assert(scene.floats[0].pos==Vector2(260,364),"Free position is reused")
	print("Damage text: enemy/player totals, mixed types, moving target, independent enemies, preserved lifetime, expiry and layout passed")
	quit()
