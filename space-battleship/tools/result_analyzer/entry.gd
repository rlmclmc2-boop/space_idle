extends Node
var panel: Window

func _ready() -> void:
	get_tree().root.gui_embed_subwindows=true
	panel=Window.new()
	panel.set_script(load("res://scripts/enemy_fleet_panel.gd"))
	panel.borderless=true
	add_child(panel)
	panel.size=get_window().size
	panel.position=Vector2i.ZERO
	panel.popup()
	get_window().size_changed.connect(func():panel.size=get_window().size)
	get_window().close_requested.connect(get_tree().quit)
	get_window().files_dropped.connect(func(paths):
		if paths.size()>0:open_batch(paths[0]))
	var args := OS.get_cmdline_user_args()
	if args.size()>0:
		if args[0]=="--cycle":panel.tabs.current_tab=2
		else:open_batch(args[0])

func open_batch(path: String) -> void:
	panel.tabs.current_tab=3
	panel.analysis_section.path_input.text=path if DirAccess.dir_exists_absolute(path) else path.get_base_dir()
	panel.analysis_section.load_results()
