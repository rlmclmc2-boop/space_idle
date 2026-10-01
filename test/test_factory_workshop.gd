extends SceneTree
## Isolated playable layout fixture. Real research functions, never player saves.
var workshop
var game: BattleGame
var checks:=0
var failures:=0
var machine_keys: Array=[]
class PreviewClock extends Node:
	var source: BattleGame
	func _process(delta: float) -> void:
		if not source.paused:source.advance_hightech(delta,delta)

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(message)
func _initialize() -> void:call_deferred("run")
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> void:
	await frame()
	root.get_texture().get_image().save_png("res://.runtime/"+name+".png")
func run() -> void:
	root.size=Vector2i(1176,1015)
	root.content_scale_size=Vector2i(1176,1015)
	var db:=ShipDatabase.new()
	game=BattleGame.new(db,false)
	game.profile.cleared=range(1,51)
	game.rebuild_unlocks()
	game.profile.scientists=32
	game.profile.resources={"1":100000.0,"2":10000.0}
	machine_keys=db.data.hightech.keys()
	for i in machine_keys.size():
		var key: String=machine_keys[i]
		game.profile.hightechLevels[key]=2
		game.profile.scientistAssignments[key]=[11,9,8,0][i]
		game.profile.techPoints[key]=game.hightech_required(key)*[0.32,0.28,0.48,0.1][i]
	workshop=load("res://scripts/hightech_workshop.gd").new()
	root.add_child(workshop)
	workshop.scale=Vector2.ONE*0.875
	workshop.setup(game)
	workshop.set_process(false)
	workshop.select_project(BattleGame.ENERGY_FOCUS)
	for i in 36:workshop.machines[workshop.selected].advance(1.0/24,false)
	await capture("workshop-focus-actual-size")
	check(workshop.size==Vector2(1344,1160) and workshop.scale==Vector2.ONE*0.875,"Fixture matches the actual workspace scale")
	check(workshop.rows.size()==4,"All four unlocked independent projects remain accessible")
	check(workshop.machines.values().filter(func(c):return c.is_visible_in_tree()).size()==1,"Only selected equipment draws animation")
	var controls: Array=workshop.rows.values().map(func(row):return row.button.get_instance_id())
	var before: Dictionary=game.profile.duplicate(true)
	workshop.select_project(BattleGame.DENSE_ARMOUR)
	await capture("workshop-armour-actual-size")
	check(game.profile==before,"Changing the viewed work cell never changes research or AI")
	check(controls==workshop.rows.values().map(func(row):return row.button.get_instance_id()),"Selection reuses all worklist controls")
	var assigned:=game.assigned_scientists(BattleGame.DENSE_ARMOUR)
	# Real button input goes through the existing AI assignment method.
	var b: Button=workshop.actions[1]
	var click:=InputEventMouseButton.new()
	click.position=b.get_global_rect().get_center()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	root.push_input(click,true)
	await process_frame
	click=click.duplicate()
	click.pressed=false
	root.push_input(click,true)
	await process_frame
	workshop.refresh()
	check(game.assigned_scientists(BattleGame.DENSE_ARMOUR)==assigned+1,"Clicking +1 AI uses original allocation rule")
	check(game.idle_scientists()==3,"Idle AI feedback updates after assignment")
	var count: int=workshop.get_child_count()
	var room_draws: int=workshop.room.draws
	workshop.select_project(BattleGame.ENERGY_FOCUS)
	await frame()
	var hidden_phase: float=workshop.machines[BattleGame.DENSE_ARMOUR].phase
	var completed_before:=game.hightech_level(BattleGame.ENERGY_FOCUS)
	DirAccess.make_dir_recursive_absolute("res://.runtime/workshop-frames")
	var record:=OS.get_cmdline_user_args().has("--record")
	if record:
		var preview_tag:=Label.new()
		preview_tag.text="隔离样稿 · 4×时间演示"
		preview_tag.position=Vector2(25,996)
		preview_tag.add_theme_font_override("font",preload("res://scripts/shell_presentation.gd").face(500))
		preview_tag.add_theme_font_size_override("font_size",12)
		preview_tag.modulate=Color("90a7b2")
		root.add_child(preview_tag)
	for i in 144:
		# 4x preview time: points come from unmodified advance_hightech, not a slider.
		game.advance_hightech(4.0/12,4.0/12)
		workshop.refresh()
		workshop.machines[workshop.selected].advance(1.0/12,false)
		if record:
			await frame()
			root.get_texture().get_image().save_png("res://.runtime/workshop-frames/%03d.png" % i)
	await frame()
	check(game.hightech_level(BattleGame.ENERGY_FOCUS)>completed_before and workshop.factory_events>0,"Actual research reaches completion and begins the next assembly")
	check(workshop.room.draws==room_draws,"Research never redraws the static room")
	check(workshop.get_child_count()==count,"Progress never rebuilds the page")
	check(workshop.machines[BattleGame.DENSE_ARMOUR].phase==hidden_phase,"Other machines have no background animation clock")
	game.paused=true
	workshop.dirty=true
	workshop._process(0.1)
	var saved_writes: int=workshop.writes
	var saved_energy: int=workshop.machines[workshop.selected].energy_writes
	workshop._process(0.5)
	check(saved_writes==workshop.writes and saved_energy==workshop.machines[workshop.selected].energy_writes,"Paused page performs no repeated writes")
	workshop.hide()
	workshop.dirty=true
	workshop._process(0.5)
	check(saved_writes==workshop.writes,"Hidden page performs no writes")
	workshop.show()
	var save_before: Dictionary=game.profile.duplicate(true)
	workshop.refresh()
	check(save_before==game.profile and not game.save_enabled,"Presentation remains read-only and never enables save")
	game.profile.cleared=[]
	game.profile.grantedUnlocks=[]
	workshop.sync_projects()
	await frame()
	check(workshop.rows.is_empty() and workshop.selected.is_empty() and not workshop.console.visible,"Locked projects reveal no machine, title or allocation action")
	check(workshop.stage_title.text==workshop.t("empty"),"Relocking clears stale selected-device text")
	game.profile=save_before
	workshop.sync_projects()
	workshop.refresh()
	print("FACTORY_WORKSHOP_CHECKS=",checks," FAILURES=",failures," ROOM_DRAWS=",workshop.room.draws)
	if OS.get_cmdline_user_args().has("--play"):
		game.paused=false
		workshop.set_process(true)
		var clock:=PreviewClock.new()
		clock.source=game
		root.add_child(clock)
		return
	quit(1 if failures else 0)
