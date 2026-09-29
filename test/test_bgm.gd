extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scripts/main.gd").new()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled = false
	var stream := scene.music.stream as AudioStreamOggVorbis
	if stream == null or not stream.loop or stream.get_length() < 118.0 or stream.get_length() > 122.0:
		printerr("BGM stream missing, wrong duration, or not looping")
		quit(1)
		return
	if not scene.music_on or not scene.music.playing or scene.music_button.text != "音乐：开":
		printerr("BGM did not start with its visible toggle")
		quit(1)
		return
	scene.toggle_music()
	if scene.music_on or scene.music.playing or scene.music_button.text != "音乐：关":
		printerr("BGM toggle did not stop playback")
		quit(1)
		return
	scene.toggle_music()
	if not scene.music_on or not scene.music.playing or scene.music_button.text != "音乐：开":
		printerr("BGM toggle did not restart playback")
		quit(1)
		return
	scene.queue_free()
	await process_frame
	var first_launch = load("res://scripts/main.gd").new()
	first_launch.automation_args = []
	root.add_child(first_launch)
	first_launch.set_process(false)
	if not first_launch.music_on:
		first_launch.toggle_music()
	first_launch.toggle_music()
	if first_launch.music_on or first_launch.music.playing:
		printerr("BGM did not turn off before restart")
		quit(1)
		return
	first_launch.queue_free()
	await process_frame
	var second_launch = load("res://scripts/main.gd").new()
	second_launch.automation_args = []
	root.add_child(second_launch)
	second_launch.set_process(false)
	if second_launch.music_on or second_launch.music.playing or second_launch.music_button.text != "音乐：关":
		printerr("BGM off setting was not restored")
		quit(1)
		return
	second_launch.toggle_music()
	second_launch.queue_free()
	await process_frame
	var third_launch = load("res://scripts/main.gd").new()
	third_launch.automation_args = []
	root.add_child(third_launch)
	third_launch.set_process(false)
	if not third_launch.music_on or not third_launch.music.playing or third_launch.music_button.text != "音乐：开":
		printerr("BGM on setting was not restored")
		quit(1)
		return
	third_launch.queue_free()
	print("BGM import, loop, autoplay, toggle, and offline preference passed")
	quit(0)
