extends SceneTree

const UI=preload("res://scripts/battlefield.gd")

func _initialize()->void:
	call_deferred("run")

func run()->void:
	var scene=load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.automation_args=[]
	var game=scene.game
	game.save_enabled=false
	game.native_execution_auto=false
	game.profile.onboarding.completed=true
	game.profile.onboarding.dismissed=true
	game.profile.highestLevel=maxi(2,int(game.profile.highestLevel))
	assert(game.start(2,false))
	assert(game.native_execution==null)
	game.group_index=2
	game.spawn_group()
	var enemy:Dictionary=game.enemies[0]
	var events:Array[Dictionary]=[]
	game.event.connect(func(kind:String,info:Dictionary)->void:
		if kind=="hit" and not bool(info.get("player",false)):events.append(info.duplicate())
	)
	var cases=[
		{"name":"shield","shield":10.0,"raw":2.0,"expected":true,"breaks":false},
		{"name":"break","shield":2.0,"raw":10.0,"expected":true,"breaks":true},
		{"name":"hull","shield":0.0,"raw":2.0,"expected":false,"breaks":false},
	]
	for test in cases:
		enemy.hp=1000000.0
		enemy.max_hp=1000000.0
		enemy.shield=test.shield
		enemy.max_shield=10.0
		var count=events.size()
		game.hit_enemy(enemy,test.raw,0)
		assert(events.size()==count+1,test.name+": hit event")
		var info:Dictionary=events.back()
		assert(info.has("absorbed"),test.name+": paid shield field")
		assert(UI.enemy_hit_struck_shield(info)==test.expected,test.name+": chosen meter")
		if test.breaks:assert(float(enemy.shield)==0.0,"breaking hit leaves zero shield")
		print("METER_CASE ",test.name," absorbed=",info.absorbed," shield_after=",enemy.shield," chosen_shield=",UI.enemy_hit_struck_shield(info))
	print("METER_FEEDBACK_DONE")
	quit()
