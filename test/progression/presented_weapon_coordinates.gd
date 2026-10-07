extends SceneTree
const Presented=preload("res://scripts/presented_battle_game.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func fixture(key:String):
	var g=Presented.new(ShipDatabase.new(),false)
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	g.profile.loadout.weapons[0]={"key":key,"level":1}
	g.invalidate_stat_cache();g.reset_player();g.start(1,false);g.spawn_group()
	g.enemies.resize(1)
	var enemy:Dictionary=g.enemies[0]
	enemy.hp=1e12;enemy.max_hp=enemy.hp;enemy.shield=0.0;enemy.max_shield=0.0
	enemy.armourType=99;enemy.x=280.0;enemy.y=100.0
	enemy.equipment=[];enemy.cooldowns=[];enemy.drops=[]
	g.refresh_missile_target_registry()
	g.target_provider=func(target):return Vector2(target.x+40,target.y-20)
	g.launch_provider=func(_slot,aim,_ordinal):return {"position":Vector2(220,600),"direction":(Vector2(aim)-Vector2(220,600)).normalized()}
	return g
func advance(g,seconds:float)->void:
	for i in ceili(seconds*60.0):
		g.motion_clock+=1.0/60.0;g.tick_projectiles(1.0/60.0)
func _initialize()->void:
	var g=fixture("missile")
	var enemy:Dictionary=g.enemies[0]
	var row:Dictionary=g.player_weapon_row(g.combat_entry(0))
	var count:int=int(row.para1)
	for ordinal in count:g.jewel_fire(0,enemy,row,g.player_weapon_offset(0),1.0,0.0,ordinal,count)
	advance(g,6.0)
	check(g.launch_records.size()==count,"missile batch count follows the current authoritative row")
	check(g.hit_records.size()==count and g.projectiles.is_empty(),"every configured missile resolves one hit and retires")
	check(enemy.hp<1e12,"missile actual damage remains enabled")
	for i in range(1,g.launch_records.size()):check(absf(g.launch_records[i].time-g.launch_records[i-1].time-g.EJECTION_GAP)<=1.0/60.0+.000001,"missile staggered ejection stays configured")
	g=fixture("longLaser");enemy=g.enemies[0];row=g.player_weapon_row(g.combat_entry(0))
	g.lock_long_laser(g.player,row,false,0,g.combat_entry(0))
	var beam:Dictionary=g.projectiles.back()
	check(beam.get("beam",false) and not beam.has("ballistic_target_origin"),"continuous beam does not inherit pulse snapshots")
	advance(g,maxf(4.0,float(row.para2)+float(row.cd)*3.0))
	check(int(beam.ticks)>0 and enemy.hp<1e12,"configured continuous beam charges and applies real periodic damage")
	check(g.projectiles.has(beam),"valid continuous beam remains locked")
	var projected:Vector2=g.projectile_target_point(beam)
	enemy.x+=30.0
	check(g.projectile_target_point(beam)==projected+Vector2(30,0),"non-pulse projected targets still follow real movement")
	g=fixture("cannon");enemy=g.enemies[0];row=g.player_weapon_row(g.combat_entry(0))
	var impacts:Array=[]
	g.event.connect(func(kind,info):
		if kind=="projectile_impact":impacts.append(info))
	g.jewel_fire(0,enemy,row,g.player_weapon_offset(0))
	check(impacts.size()==1 and enemy.hp<1e12,"rail cannon retains immediate primary impact and real damage")
	check(g.projectiles.is_empty() and not impacts[0].shot.has("ballistic_target_origin"),"rail cannon remains separate from ordinary pulse flight")
	check(impacts[0].pos==g.target_point(enemy),"rail impact retains its current projected target")
	var hostile:Dictionary={"x":200.0,"y":100.0,"uid":77}
	g.fire(hostile,g.player,g.db.enemy_weapon("laser-mon"),10,true,"laser-mon")
	var shot:Dictionary=g.projectiles.back()
	check(not shot.has("ballistic_target_origin") and g.projectile_target_point(shot)==Vector2(g.player.x,g.player.y),"hostile pulse keeps its existing logical collision path")
	print("PRESENTED_WEAPON_COORDINATES ",checks," checks ",failures," failures")
	quit(1 if failures else 0)