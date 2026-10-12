extends "res://scripts/presented_battle_game.gd"
## UI query projection. Never advances battle; authoritative commands pass through
## one ordered gateway. Own dictionaries/native renderer are detached from kernel.
var command_gateway:Callable
var display_ready:bool=false
var display_shots:Dictionary={}
var display_entities:Dictionary={}
var _constructor_profile:Dictionary={}
func _init(database:ShipDatabase,persist:bool=false,initial_profile:Dictionary={})->void:
	_constructor_profile=initial_profile
	super(database,persist)
	_constructor_profile={}
func fresh_profile()->Dictionary:
	return _constructor_profile.duplicate(true) if not _constructor_profile.is_empty() else super.fresh_profile()
func tick(_dt:float)->void:
	assert(false,"Display Game cannot advance battle")
func command(name:String,args:Array)->Variant:
	assert(command_gateway.is_valid())
	return command_gateway.call(name,args)

func set_speed(multiplier: float) -> bool:
	if display_ready:
		return command("set_speed",[multiplier])
	return super.set_speed(multiplier)

func set_save_interval(text: String) -> bool:
	if display_ready:
		return command("set_save_interval",[text])
	return super.set_save_interval(text)

func check_timed_save() -> void:
	if display_ready:
		command("check_timed_save",[])
		return
	super.check_timed_save()

func save_progress() -> void:
	if display_ready:
		command("save_progress",[])
		return
	super.save_progress()

func assign_crew(crew_id: String, assignment_type: String, target_id: String) -> bool:
	if display_ready:
		return command("assign_crew",[crew_id,assignment_type,target_id])
	return super.assign_crew(crew_id,assignment_type,target_id)

func toggle_loop() -> void:
	if display_ready:
		command("toggle_loop",[])
		return
	super.toggle_loop()

func start(level: int, loop_mode: bool, checkpoint: Dictionary = {}, start_paused := false) -> bool:
	if display_ready:
		return command("start",[level,loop_mode,checkpoint,start_paused])
	return super.start(level,loop_mode,checkpoint,start_paused)

func begin_retreat() -> void:
	if display_ready:
		command("begin_retreat",[])
		return
	super.begin_retreat()

func acknowledge_unlocks() -> void:
	if display_ready:
		command("acknowledge_unlocks",[])
		return
	super.acknowledge_unlocks()

func collect(drop: Dictionary, manual: bool) -> void:
	if display_ready:
		command("collect",[drop,manual])
		return
	super.collect(drop,manual)

func upgrade(key: String, levels := 1) -> bool:
	if display_ready:
		return command("upgrade",[key,levels])
	return super.upgrade(key,levels)

func upgrade_max(key: String) -> bool:
	if display_ready:
		return command("upgrade_max",[key])
	return super.upgrade_max(key)

func set_enhancement_branch(category: String, effect: String, node: int, choice: String) -> bool:
	if display_ready:
		return command("set_enhancement_branch",[category,effect,node,choice])
	return super.set_enhancement_branch(category,effect,node,choice)

func set_enhancement_order(category: String, order: Array) -> bool:
	if display_ready:
		return command("set_enhancement_order",[category,order])
	return super.set_enhancement_order(category,order)
