extends RefCounted
## Screen-only encounter hierarchy. Never supplies combat geometry or changes entities.

var route := ""
var scenery_route := ""
var scenery_presence := 0.0
var scenery_time := 0.0
var tier := "normal"
var leader_uid := -1
var identity := ""
var age := 0.0
var transition := 2.0 # Inactive on startup; only an actual route change starts it.
var departure := false
var leader_fall := 2.0
var focus := Vector2(286,190)
var accent := Color("77bbcf")
var return_success := false
var clear_age := 2.0

func sync(game,delta:float) -> bool:
	var next_route := str(game.profile.hyperspace.active.get("route","")) if game.manual_hyperspace.active else ""
	var changed := next_route!=route
	if changed:
		departure=next_route.is_empty()
		route=next_route
		transition=0.0
		if not departure:
			scenery_route=route
			accent={"alpha":Color("81d5da"),"beta":Color("d9a67b"),"gamma":Color("a8bacd"),"delta":Color("b1a0dc")}.get(route,Color("81d5da"))
		elif game.paused:
			# Returning restores the mainline pause state. Finish presentation now;
			# never unpause gameplay just to drain a departure animation timer.
			scenery_presence=0.0
			scenery_route=""
			transition=2.0
	var next_identity := str([route,game.stage,game.group_index,game.encounter_tier()])
	if next_identity!=identity:
		identity=next_identity
		tier=game.encounter_tier()
		leader_uid=-1
		age=0.0
	# Choose once from the actual encounter; do not promote escorts after death.
	if leader_uid<0 and game.state==BattleGame.State.COMBAT and tier in ["boss","ultimate"]:
		var largest := -1
		for enemy in game.enemies:
			if int(enemy.size)>largest:
				largest=int(enemy.size)
				leader_uid=int(enemy.uid)
	if not game.paused:
		scenery_time+=delta
		scenery_presence=move_toward(scenery_presence,0.0 if route.is_empty() else 1.0,delta/1.6)
		age+=delta
		transition=minf(2.0,transition+delta)
		leader_fall=minf(2.0,leader_fall+delta)
		clear_age=minf(2.0,clear_age+delta)
	return changed

func is_leader(enemy:Dictionary) -> bool:
	return int(enemy.get("uid",-2))==leader_uid

func draw_space(canvas:CanvasItem,size:Vector2) -> void:
	if not route.is_empty():
		# Route scenery lives in the persistent star mesh, below every combat
		# primitive. Keep only the encounter endpoint cues on this dynamic layer.
		var center := Vector2(size.x*0.5,190)
		var final := tier=="ultimate"
		var opening := 174.0 if final else 210.0
		if tier in ["boss","ultimate"]:
			canvas.draw_arc(center,opening-24,PI,TAU,40,Color(accent,0.27),7.0,true)
			if final:
				canvas.draw_arc(center,opening-24,0,PI,40,Color(accent,0.18),7.0,true)
				# A terminal crossbar closes the corridor behind the fleet.
				canvas.draw_line(Vector2(68,42),Vector2(size.x-68,42),Color(accent,0.55),4.0,true)
	if transition<1.2 and (departure or not route.is_empty()):
		var progress := smoothstep(0.0,1.2,transition)
		var inset := (1.0-progress if departure else progress)*size.x*0.46
		for x_value in [inset,size.x-inset]:
			var x:float=float(x_value)
			canvas.draw_line(Vector2(x,0),Vector2(x,size.y),Color(accent,(1.0-progress)*0.48),3.0,true)

func draw_leader_frame(canvas:CanvasItem,position:Vector2,width:float) -> void:
	focus=position
	var spread := width*0.48+12.0
	var arrival := 1.0-smoothstep(0.0,1.1,age)
	for side_value in [-1.0,1.0]:
		var side:float=float(side_value)
		var x:float=position.x+side*(spread+arrival*32.0)
		canvas.draw_polyline(PackedVector2Array([Vector2(x-side*12,position.y-32),Vector2(x,position.y-32),Vector2(x,position.y+32),Vector2(x-side*12,position.y+32)]),Color(accent,0.35+arrival*0.35),2.0,true)

func draw_fall(canvas:CanvasItem) -> void:
	if leader_fall>=1.4:return
	# Two severed command brackets fall apart; no screen flash or fake victory.
	var progress := leader_fall/1.4
	for side_value in [-1.0,1.0]:
		var side:float=float(side_value)
		var point:Vector2=focus+Vector2(side*(32+progress*85),progress*65)
		canvas.draw_line(point-Vector2(0,26),point+Vector2(0,26),Color(accent,(1.0-progress)*0.8),3.0,true)
