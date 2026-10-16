extends SceneTree

func _initialize()->void:call_deferred("run")

func run()->void:
	var source:=Vector2(300,100)
	var weapon={"kind":1,"type":0,"slot":0,"source":0,"hostile":false,"damage":100.0,"interval":10.0,"remaining":0.0,"speed":720.0,"charge":0.0,"ramp":1.0,"maximum":1.0,"salvo":1,"chain_count":1,"muzzle":Vector2(286,520),"entry":{"key":"cannon"},"row":{"cd":10.0,"para1":1.0,"para2":1.0,"para3":0.0}}
	var world={"clock":0.0,"rng_state":418,"resistance":0.0,"player":{"x":286.0,"y":520.0,"armour":100.0,"shield":100.0,"armour_type":2,"shield_type":1},"enemies":[{"uid":100,"slot":0,"x":90.0,"y":100.0,"hp":1.0,"max_hp":1.0,"armourType":0,"shieldType":0,"shield":0.0,"max_shield":0.0},{"uid":101,"slot":1,"x":source.x,"y":source.y,"hp":1e9,"max_hp":1e9,"armourType":0,"shieldType":0,"shield":0.0,"max_shield":0.0}],"weapons":[weapon]}
	var native=ClassDB.instantiate("SpaceCombatKernel")
	assert(native.configure(world),"chain origin fixture admission")
	var hop:Dictionary={}
	var chain_impact_origin:=Vector2.INF
	var chain_fire:=false
	for i in 45:
		assert(native.advance(1.0/60.0),"native combat step")
		for event in native.take_feedback():
			if not bool(event.get("shot",{}).get("chain_hop",false)):continue
			if int(event.kind)==4:chain_impact_origin=Vector2(event.position)
			if int(event.kind)==0:chain_fire=true
		for row in native.presentation_projectile_rows():
			if bool(row.get("chain_hop",false)):
				hop=row
				break
		if not hop.is_empty():break
	assert(not hop.is_empty(),"chain carrier spawned")
	assert(hop.get("chain_weapon","")=="cannon","chain retains cannon source")
	assert(Vector2(hop.launch_point).distance_to(source)<0.001,"carrier launches at hit enemy")
	assert(Vector2(hop.launch_point).distance_to(Vector2(weapon.muzzle))>100,"carrier does not launch at player turret")
	assert(chain_impact_origin.distance_to(source)<0.001 and not chain_fire,"chain creates an origin impact, not a muzzle rail fire")
	var slice=preload("res://scripts/battle_slice_runtime.gd").new()
	assert(slice.style(hop)==3,"chain impact keeps cannon style")
	native.cancel()
	print("NATIVE CHAIN VISUAL ORIGIN: 7 checks, 0 failures")
	quit(0)
