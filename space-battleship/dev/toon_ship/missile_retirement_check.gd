extends SceneTree
## Focused developer-only lifecycle cases; no player save or production configuration.
const PrototypeGame=preload("res://dev/toon_ship/prototype_battle_game.gd")
var errors:Array[String]=[]
func check(ok:bool,message:String)->void:
	if not ok:errors.append(message);printerr(message)
func rocket(g,target:Dictionary,pos:Vector2)->Dictionary:
	g.fire(g.player,target,g.db.equip("missile",1),100,false,"missile")
	var shot:Dictionary=g.projectiles.back()
	shot.prototype_missile=true;shot.motion_age=1.0;shot.orphan_age=0.0
	shot.last_target_point=pos;shot.closest_range=INF;shot.x=pos.x;shot.y=pos.y;shot.direction=Vector2.UP
	return shot
func _initialize()->void:
	var db:=ShipDatabase.new()
	var g=PrototypeGame.new(db,false)
	g.start(1,false);g.spawn_group()
	var enemy:Dictionary=g.enemies[0];g.enemies.clear();g.enemies.append(enemy);enemy.hp=1
	g.group_index=db.levels[0].groups.size()
	var killer:=rocket(g,enemy,Vector2(enemy.x,enemy.y))
	var survivor:=rocket(g,enemy,Vector2(260,300))
	g.tick(1.0/60.0)
	check(g.state==g.State.LEVEL_CLEAR,"Boss fixture must enter level clear")
	check(g.projectiles.is_empty(),"Boss clear must keep authoritative projectile removal")
	check(g.missile_retirements.size()==1 and int(g.missile_retirements[0].serial)==int(survivor.serial),"Only the non-impact survivor receives visual coast")
	check(bool(g.missile_retirements[0].coast),"Clear survivor must coast without gameplay projectile")
	check(g.hit_records.size()==1 and int(g.hit_records[0].serial)==int(killer.serial),"Visual coast must not produce an extra hit")
	g.start(1,false);g.spawn_group()
	var orphan:=rocket(g,{},Vector2(220,300));orphan.orphan_age=0.79
	g.tick_projectiles(0.05)
	check(not bool(orphan.dead),"Old 0.8 s boundary must not silently delete a visible orphan")
	orphan.orphan_age=3.0
	g.tick_projectiles(1.0/60.0)
	check(bool(orphan.dead) and str(g.missile_retirements.back().reason)=="orphan_timeout","Lingering fallback must emit a neutral retirement event")
	var count:int=g.missile_retirements.size();var clock_before:float=g.motion_clock
	g.paused=true;g.tick(1.0)
	check(g.missile_retirements.size()==count and g.motion_clock==clock_before,"Pause must freeze missile lifecycle")
	print("MISSILE_RETIREMENT_CHECK ",JSON.stringify({"passed":errors.is_empty(),"errors":errors,"cases":["boss survivor","no ghost hit","old boundary coast","neutral fallback","pause"]}))
	quit(0 if errors.is_empty() else 1)
