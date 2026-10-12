extends "res://scripts/presented_battle_game.gd"
## UI query projection. Never advances battle; authoritative commands pass through
## one ordered gateway. Own dictionaries/native renderer are detached from kernel.
var command_gateway:Callable
var display_ready:bool=false
var display_shots:Dictionary={}
var display_entities:Dictionary={}
var display_chain_targets:Dictionary={}
var display_defense_projection:Dictionary={}
var display_deferred_projection:Variant=0.0
var _constructor_profile:Dictionary={}
func _init(database:ShipDatabase,persist:bool=false,initial_profile:Dictionary={})->void:
	_constructor_profile=initial_profile
	super(database,persist)
	# Replace helper instances before UI captures them. Keep constructor config;
	# the presenter later copies detached source values into these instances.
	if event.is_connected(crew.on_event):event.disconnect(crew.on_event)
	crew=preload("res://scripts/simulation_crew_display.gd").new();crew.attach(self)
	planet_buildings=preload("res://scripts/simulation_planet_buildings_display.gd").new()
	var display_hyperspace=preload("res://scripts/simulation_hyperspace_display.gd").new()
	display_hyperspace.configure(hyperspace.config)
	hyperspace=display_hyperspace
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
		command("collect_uid",[int(drop.get("uid",-1)),manual])
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

func beam_chain_targets(shot:Dictionary)->Array:
	return display_chain_targets.get(int(shot.get("serial",-1)),[]) if projectiles.has(shot) and long_laser_valid(shot) else []

func resume_progress() -> void:
	if display_ready:
		command("resume_progress",[])
		return
	super.resume_progress()

func equip_slot(category: String, index: int, key: String) -> bool:
	if display_ready:
		return command("equip_slot",[category,index,key])
	return super.equip_slot(category,index,key)

func unequip_slot(category: String, index: int) -> bool:
	if display_ready:
		return command("unequip_slot",[category,index])
	return super.unequip_slot(category,index)

func upgrade_reactor(amount: int) -> bool:
	if display_ready:
		return command("upgrade_reactor",[amount])
	return super.upgrade_reactor(amount)

func set_reactor_allocation(key: String, value) -> bool:
	if display_ready:
		return command("set_reactor_allocation",[key,value])
	return super.set_reactor_allocation(key,value)

func equalize_reactor_allocation() -> bool:
	if display_ready:
		return command("equalize_reactor_allocation",[])
	return super.equalize_reactor_allocation()

func scientist_purchase(amount := 1) -> Dictionary:
	if display_ready:
		return command("scientist_purchase",[amount])
	return super.scientist_purchase(amount)

func generate_scientist(amount := 1) -> bool:
	if display_ready:
		return command("generate_scientist",[amount])
	return super.generate_scientist(amount)

func distribute_scientists() -> bool:
	if display_ready:
		return command("distribute_scientists",[])
	return super.distribute_scientists()

func assign_scientist(key: String, delta: int) -> bool:
	if display_ready:
		return command("assign_scientist",[key,delta])
	return super.assign_scientist(key,delta)

func set_planet_auto(id: String, enabled: bool) -> bool:
	if display_ready:
		return command("set_planet_auto",[id,enabled])
	return super.set_planet_auto(id,enabled)

func start_planet_exploration(id: String, crew_id: String) -> bool:
	if display_ready:
		return command("start_planet_exploration",[id,crew_id])
	return super.start_planet_exploration(id,crew_id)

func cancel_planet_exploration(id: String) -> bool:
	if display_ready:
		return command("cancel_planet_exploration",[id])
	return super.cancel_planet_exploration(id)

func change_state(next: State) -> void:
	if display_ready:
		command("change_state",[next])
		return
	super.change_state(next)

func select_loop_level(level: int) -> bool:
	if display_ready:
		return command("select_loop_level",[level])
	return super.select_loop_level(level)

func set_guard_death(mode: int) -> void:
	if display_ready:
		command("set_guard_death",[mode])
		return
	super.set_guard_death(mode)

func set_hyperspace_auto(route:String,crew_id:String,enabled:bool)->bool:
	if display_ready:
		return command("set_hyperspace_auto",[route,crew_id,enabled])
	return super.set_hyperspace_auto(route,crew_id,enabled)

func start_hyperspace_challenge(route:String)->bool:
	if display_ready:
		return command("start_hyperspace_challenge",[route])
	return super.start_hyperspace_challenge(route)

func claim_hyperspace(round_id:int=-1,run_id:int=-1)->bool:
	if display_ready:
		return command("claim_hyperspace",[round_id,run_id])
	return super.claim_hyperspace(round_id,run_id)

func advance_after_clear() -> bool:
	if display_ready:
		return command("advance_after_clear",[])
	return super.advance_after_clear()

func clear_level() -> void:
	if display_ready:
		command("clear_level",[])
		return
	super.clear_level()

func upgrade_slot(category: String, index: int, levels := 1) -> bool:
	if display_ready:
		return command("upgrade_slot",[category,index,levels])
	return super.upgrade_slot(category,index,levels)

func upgrade_equipment_batch(mode: String) -> bool:
	if display_ready:
		return command("upgrade_equipment_batch",[mode])
	return super.upgrade_equipment_batch(mode)

func upgrade_enhancement(count := 1) -> int:
	if display_ready:
		return command("upgrade_enhancement",[count])
	return super.upgrade_enhancement(count)

func collect_near(pos: Vector2, clicked := false, position_overrides: Dictionary = {}, path_start: Variant = null) -> void:
	if display_ready:
		command("collect_near",[pos,clicked,position_overrides,path_start])
		return
	super.collect_near(pos,clicked,position_overrides,path_start)

func chrono_affordable_seconds(real_dt: float) -> float:
	if display_ready:
		return command("chrono_affordable_seconds",[real_dt])
	return super.chrono_affordable_seconds(real_dt)

func set_onboarding_flag(key: String, value: bool) -> bool:
	if display_ready:
		return command("set_onboarding_flag",[key,value])
	return super.set_onboarding_flag(key,value)

func read_tutorial_unlock(id: String) -> bool:
	if display_ready:
		return command("read_tutorial_unlock",[id])
	return super.read_tutorial_unlock(id)

func enhancement_protection_status() -> Dictionary:
	return display_defense_projection if display_ready else super.enhancement_protection_status()

func enhancement_deferred_total() -> Variant:
	return display_deferred_projection if display_ready else super.enhancement_deferred_total()

func enhancement_protection_current() -> Variant:
	return display_defense_projection.get("current",0.0) if display_ready else super.enhancement_protection_current()

func enhancement_protection_capacity() -> Variant:
	return display_defense_projection.get("capacity",0.0) if display_ready else super.enhancement_protection_capacity()

func enhancement_visible_buffer(index: int, capacity: Variant = null) -> Variant:
	if not display_ready:return super.enhancement_visible_buffer(index,capacity)
	for component in display_defense_projection.get("components",[]):
		if int(component.index)==index:return component.current if capacity==null else GrowthNumber.minimum(component.current,capacity)
	return 0.0
