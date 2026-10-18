extends SceneTree

var capture_dir := ""
var started_at := 0
var frame_number := 0
var last_capture_at := 0

func _initialize() -> void:
	capture_dir = OS.get_environment("REVIEW_A_CAPTURE_DIR")
	started_at = Time.get_ticks_msec()
	call_deferred("_start_game")

func _start_game() -> void:
	var error := change_scene_to_file("res://main.tscn")
	if error != OK:
		printerr("review capture: scene load failed: ", error)

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()
	if capture_dir.is_empty() or now - started_at < 1000 or now - last_capture_at < 1000:
		return false
	last_capture_at = now
	var image := get_root().get_texture().get_image()
	if image.is_empty():
		return false
	var path := capture_dir.path_join("frame-%06d.jpg" % frame_number)
	var error := image.save_jpg(path, 0.85)
	if error == OK:
		frame_number += 1
		if frame_number == 1:
			print("review capture: ", path)
	else:
		printerr("review capture: save failed: ", error)
	return false
