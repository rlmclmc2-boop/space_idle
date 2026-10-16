extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;printerr("FAIL: ",label)

func kernel(armour: float, shield: float):
	var native = ClassDB.instantiate("SpaceCombatKernel")
	var enemy := {"uid":100,"slot":4,"x":30.0,"y":0.0,"hp":100.0,"max_hp":100.0,"armourType":2,"shieldType":1,"shield":0.0,"max_shield":0.0}
	var weapon := {"kind":0,"type":1,"slot":0,"source":0,"hostile":false,"damage":1.0,"interval":10.0,"remaining":10.0,"speed":720.0,"charge":0.0,"ramp":1.0,"maximum":1.0,"salvo":1,"muzzle":Vector2.ZERO,"entry":{"key":"laser"},"row":{"cd":10.0,"para1":1.0,"para2":1.0,"para3":0.0}}
	var world := {"clock":0.0,"rng_state":418,"resistance":0.0,"player":{"x":50.0,"y":0.0,"armour":armour,"shield":shield,"armour_type":2,"shield_type":1},"enemies":[enemy],"weapons":[weapon]}
	check(native.configure(world),"native admission")
	return native

func _initialize() -> void:
	var native = kernel(0,100)
	check(native.receive_player_hit(10.0,1),"pure shield hit accepted")
	check(native.player_view().armour==0 and native.player_view().shield==90 and not native.export_handoff().is_empty(),"pure shield remains active")
	check(native.receive_player_hit(1000.0,1),"lethal shield overflow accepted")
	check(native.player_view().shield==0 and native.export_handoff().is_empty(),"both pools empty ends native battle")
	native = kernel(100,0)
	check(native.receive_player_hit(10.0,2),"pure armour hit accepted")
	check(native.player_view().armour==90 and not native.export_handoff().is_empty(),"pure armour remains active")
	native = kernel(100,100)
	check(native.receive_player_hit(10.0,1),"mixed hit accepted")
	check(native.player_view().shield==90 and native.player_view().armour==100,"mixed shield pays before armour")
	var game = preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
	game.profile.unlocked=["laser","armour","shield"]
	game.start(1,false)
	game.spawn_group()
	check(game.equip_slot("defence",0,"shield"),"integrated pure shield refit")
	check(game.admit_native_compiled_execution("native_low_contract"),"integrated pure shield native admission")
	if game.native_execution!=null:
		game.tick(1.0/60.0)
		check(game.native_execution!=null and game.player_alive() and game.state!=BattleGame.State.RETREAT,"integrated shield-only native step stays active")
	print("Single slot native: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
