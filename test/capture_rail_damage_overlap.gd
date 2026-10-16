extends SceneTree
# One staged orthogonal overlap: real rail feedback draw call, damage text draw
# call, and the mounted main UI. No combat, resources, save or timing changes.

func _initialize()->void:
	call_deferred("run")

func run()->void:
	if DisplayServer.get_name()=="headless":
		printerr("CAPTURE_NEEDS_RENDERER")
		quit(1)
		return
	var scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	scene.set_process(false)
	scene.game.save_enabled=false
	var clip_children:Array=scene.battle_clip.get_children()
	if clip_children.find(scene.damage_text_layer)<=clip_children.find(scene.pulse_layer) or scene.damage_text_layer.z_index!=scene.pulse_layer.z_index:
		printerr("INVALID_DAMAGE_ORDER")
		quit(1)
		return
	var beam_x:=286.0
	scene.rail_events.append({"kind":"fire","position":scene.battle_logical_point(Vector2(beam_x,520)),"aim":scene.battle_logical_point(Vector2(beam_x,80)),"direction":Vector2.UP,"born":scene.fx_time,"full_width":56.0})
	scene.floats.append({"damage":true,"life":0.2,"text":"2.76K","pos":scene.battle_logical_point(Vector2(beam_x-22,190)),"tag_size":Vector2(85,25),"tag_ascent":22.0,"size":24,"color":Color.WHITE})
	scene.pulse_layer.show()
	scene.damage_text_layer.show()
	scene.battle_layer.queue_redraw()
	scene.pulse_layer.queue_redraw()
	scene.damage_text_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path=ProjectSettings.globalize_path("res://../test/evidence/parent-candidate-play-20261016/15-rail-damage-layer.png")
	var result=root.get_texture().get_image().save_png(path)
	print("RAIL_DAMAGE_LAYER_CAPTURE ",path," result=",result," pulse_index=",clip_children.find(scene.pulse_layer)," damage_index=",clip_children.find(scene.damage_text_layer))
	quit(0 if result==OK else 1)
