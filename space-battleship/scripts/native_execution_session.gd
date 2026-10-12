extends RefCounted
## Explicit low-load execution boundary. Rich content stays refused until its
## rule compiler is complete; this session never runs a shadow Game battle.
var kernel:RefCounted
var actor_rows:Array[Dictionary]=[]
var actor_by_uid:Dictionary={}
var paused_by_configuration:=false
var ticks:=0
var feedback_rows:=0

func admit(game:RefCounted,descriptor:Dictionary)->bool:
	if descriptor.get("execution_scope","")!="native_low_contract":return false
	if not ClassDB.class_exists("SpaceCombatKernel"):return false
	if descriptor.get("requires_drop_rules",false):return false
	if descriptor.get("enemies",[]).size()>2:return false
	var candidate:RefCounted=ClassDB.instantiate("SpaceCombatKernel")
	if not candidate.configure(descriptor):return false
	kernel=candidate
	actor_rows=kernel.enemy_views()
	for row in actor_rows:actor_by_uid[int(row.uid)]=row
	# Retire old queues and bodies before publishing the new owner. These are
	# one-time bindings to stable rows; tick never serializes the world back.
	game.projectile_clear()
	game.native_pipeline=null
	game.cooldowns.clear()
	game.jewel_repeats.clear()
	if "missile_queue" in game:game.missile_queue.clear()
	game.enemies=actor_rows
	game.player=kernel.player_view()
	game.projectiles=kernel.projectile_views()
	return true

func advance(game:RefCounted,dt:float)->void:
	if kernel==null or paused_by_configuration:return
	kernel.advance(dt)
	ticks+=1
	consume_feedback(game)

func consume_feedback(game:RefCounted)->void:
	for row in kernel.take_feedback():
		feedback_rows+=1
		var p:Vector2=row.position
		match int(row.kind):
			0:game.event.emit("fire",{"x":p.x,"y":p.y,"type":row.type,"shot":row.shot,"spread":0.0})
			1:game.event.emit("projectile_impact",{"shot":row.shot,"pos":p})
			2:game.event.emit("hit",{"x":p.x,"y":p.y,"amount":row.amount,"absorbed":row.absorbed,"player":row.player,"type":row.type,"uid":row.uid,"critical":row.critical})
			3:game.event.emit("explode",actor_by_uid[int(row.uid)])
			4:game.event.emit("enhancement_chain",{"source":p,"target":Vector2(row.shot.target.x,row.shot.target.y),"weapon":row.shot.key,"shot":row.shot})
			5:game.event.emit("prototype_missile_retired",{"shot":row.shot,"reason":"native_cancel"})

func cancel(game:RefCounted)->void:
	if kernel==null:return
	kernel.cancel()
	consume_feedback(game)

func configuration_changed()->void:
	# A mutation cannot resume the old executor. Later rich admission will
	# replace this pause with explicit typed configuration commands.
	paused_by_configuration=true
