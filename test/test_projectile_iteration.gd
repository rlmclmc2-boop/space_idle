extends SceneTree

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:
	var db := ShipDatabase.new()
	for mutation in ["erase","reverse","clear_and_fire"]:
		var g := BattleGame.new(db,false)
		g.start(1,false)
		g.spawn_group()
		var target: Dictionary=g.enemies[0]
		target.hp=1e10
		var shots: Array=[]
		for i in 4:
			g.fire(g.player,target,db.equip("laser",1),0,false,"laser")
			var shot: Dictionary=g.projectiles.back()
			shot.x=200.0
			shot.y=300.0
			shot.speed=60.0
			shot.direction=Vector2.UP
			if i>0:shot.target={}
			shots.append(shot)
		shots[0].x=target.x
		shots[0].y=target.y
		g.event.connect(func(kind,info):
			if kind!="projectile_impact" or not is_same(info.shot,shots[0]):return
			if mutation=="erase":g.projectiles.erase(shots[1])
			elif mutation=="reverse":g.projectiles.reverse()
			else:
				g.projectiles.clear()
				g.fire(g.player,target,db.equip("laser",1),0,false,"laser")
				g.projectiles.back().target={}
				g.projectiles.back().y=300.0
			)
		g.tick_projectiles(1.0/60)
		if mutation=="clear_and_fire":
			check(g.projectiles.size()==1 and g.projectiles[0].y==300.0,"New shot waits until the next snapshot")
			check(shots.slice(1).all(func(shot):return shot.y==300.0),"Cleared snapshot shots never advance")
		else:
			check(shots[2].y==299.0 and shots[3].y==299.0,"Surviving shots advance exactly once after "+mutation)
			check(shots[1].y==(300.0 if mutation=="erase" else 299.0),"Removed/reordered shot obeys live membership: "+mutation)
			check(not g.projectiles.has(shots[0]),"Impact is removed after "+mutation)
		for connection in g.event.get_connections():g.event.disconnect(connection.callable)
	print("Projectile iteration: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
