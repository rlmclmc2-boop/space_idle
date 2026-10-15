extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func close_ratio(a: float, b: float) -> bool:
	return absf(a-b) <= 0.000001

func world(scale: float) -> Dictionary:
	return {"rng_state":1729,"player":{"armour":1000.0*scale,"shield":500.0*scale,"x":286.0,"y":520.0},
		"enemies":[{"uid":991,"slot":0,"x":286.0,"y":100.0,"hp":1000.0*scale,"max_hp":1000.0*scale,"shield":600.0*scale,"max_shield":600.0*scale,"shieldType":2,"armourType":0,"shieldDelay":0.5,"shieldRecovery":0.08,"shield_hit_at":0.0,"shield_updated_at":0.0,"reactiveReduction":1,"compiled_drops":[]}],
		"weapons":[{"kind":0,"type":1,"slot":0,"source":-1,"damage":0.0,"factor":1.0,"interval":1000.0,"remaining":1000.0,"speed":100.0,"entry":{"key":"laser"},"row":{}}],
		"defences":[{"layer":0,"type":1,"base":500.0*scale,"factor":1.0,"maximum":500.0*scale,"loss":0.0,"buffer":50.0*scale,"last_hit":0.0,"delay":2.0,"rate":0.3},
			{"layer":1,"type":2,"base":1000.0*scale,"factor":1.0,"maximum":1000.0*scale,"loss":0.0,"buffer":50.0*scale,"last_hit":0.0}],
		"requires_module_defense":true}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ClassDB.class_exists("SpaceCombatKernel"),"native class loaded from isolated build")
	if not ClassDB.class_exists("SpaceCombatKernel"):
		quit(1)
		return
	var baseline := {}
	for scale in [1.0,100.0,1000.0,100000.0,1.0e40]:
		var kernel = ClassDB.instantiate("SpaceCombatKernel")
		var admitted: bool = kernel.configure(world(scale))
		check(admitted,"native descriptor admission scale="+str(scale))
		if not admitted:continue
		var handle: PackedInt64Array = kernel.actor_handle(991)
		check(kernel.hit_handle(handle,200.0*scale,1),"native enemy hit scale="+str(scale))
		check(close_ratio(float(kernel.enemy_views()[0].shield)/scale,400.0),"native shield absorption scale="+str(scale))
		check(kernel.advance(1.2),"native 1.2-second advance scale="+str(scale))
		check(close_ratio(float(kernel.enemy_views()[0].shield)/scale,433.6),"native shield recovery scale="+str(scale))
		check(kernel.receive_player_hit(100.0*scale,0),"native player incoming scale="+str(scale))
		var result := {"hp":float(kernel.enemy_views()[0].hp)/scale,"shield":float(kernel.enemy_views()[0].shield)/scale,"player_shield":float(kernel.player_view().shield)/scale,"player_armour":float(kernel.player_view().armour)/scale}
		if baseline.is_empty():baseline=result
		for key in result:check(close_ratio(float(result[key]),float(baseline[key])),"native normalized state "+key+" scale="+str(scale))
		var boundary := world(scale)
		boundary.enemies[0].hp = 5000.0*scale
		boundary.enemies[0].max_hp = 5000.0*scale
		boundary.enemies[0].shield = 0.0
		boundary.enemies[0].max_shield = 0.0
		boundary.enemies[0].reactiveReduction = 0
		if kernel.configure(boundary):
			handle = kernel.actor_handle(991)
			for shot in 25:
				kernel.hit_handle(handle,200.0*scale,1)
			var residual: float = float(kernel.enemy_views()[0].hp)/scale
			print("NATIVE_BOUNDARY ",scale," residual_normalized=",residual)
			check(residual == 0.0,"native exact-25-hit boundary scale="+str(scale))
	print("NATIVE WEAPON SCALE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
