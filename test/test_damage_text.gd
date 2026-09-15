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
			scene.on_event("hit",{"x":260.0 if player else 1050.0,"y":400.0,"amount":1234567+i,"type":i%2+1,"player":player})
	assert(scene.floats.size()==24,"Every hit remains visible")
	verify(scene)
	for entry in scene.floats:
		entry.pos.y -= 5.6
		entry.life -= 0.2
	for i in range(6):
		scene.on_event("hit",{"x":1050.0,"y":356.0+i*12,"amount":99+i,"type":1,"player":false})
	verify(scene)
	scene.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://damage-text.png")
	scene.floats.clear()
	scene.on_event("hit",{"x":260.0,"y":400.0,"amount":1,"type":1,"player":true})
	assert(scene.floats[0].pos==Vector2(260,364),"Free position is reused")
	print("Damage text: simultaneous enemy/player hits, adjacent targets, moving labels and position reuse passed")
	quit()
