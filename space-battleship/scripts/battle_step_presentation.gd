extends RefCounted
## Scene-owned read model and ordered damage presentation transaction.
## A logical pose time and event barrier bound geometry reuse. No game state,
## animation clock, collision, launch callback or random draw moves here.
var active:=false
var pose_time:float=-INF
var positions:Dictionary={}
var alive_ids:Array[int]=[]
var world:Dictionary={}
var pending:Array[Dictionary]=[]

func begin(enabled:bool)->void:
	active=enabled
	invalidate()

func invalidate()->void:
	pose_time=-INF
	positions.clear()
	alive_ids.clear()
	world={}

func ensure_time(time:float)->void:
	if pose_time!=time:
		invalidate()
		pose_time=time

func layout_context(scene)->Dictionary:
	ensure_time(scene.fx_time)
	var living:Array[int]=[]
	for enemy in scene.game.enemies:
		if enemy.hp>0:living.append(int(enemy.uid))
	# Death changes obstacles, not the unchanged survivor poses. Previously
	# recorded events keep their own world dictionary, never this new one.
	if living!=alive_ids:
		alive_ids=living
		world={}
	return world

func record(scene,info:Dictionary)->void:
	var context:=layout_context(scene)
	# Snapshot event-time obstacles before a later hit can remove an enemy.
	# The queue is drained before every non-hit event and next logical tick.
	if not context.has("fleet_bottom"):
		context.fleet_bottom=scene.damage_text_enemy_bottom()
	if not context.has("enemy_bounds"):
		context.enemy_bounds=scene.damage_text_enemy_bounds()
	pending.append({"info":info.duplicate(true),"anchor":scene.damage_number_anchor(info),"world":context})

func drain(scene)->void:
	if pending.is_empty():return
	var records:=pending
	pending=[]
	for event in records:
		scene.queue_damage_number(event.info,event.anchor,event.world)

func finish(scene)->void:
	drain(scene)
	active=false
	invalidate()
