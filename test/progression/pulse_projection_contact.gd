extends SceneTree
const Presented=preload("res://scripts/presented_battle_game.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
 var g:=Presented.new(ShipDatabase.new(),false);g.state=g.State.COMBAT
 var enemy:Dictionary={"uid":1,"hp":10000.0,"max_hp":10000.0,"x":280.0,"y":100.0,"slot":0,"armourType":99,"equipment":[],"drops":[],"res_ratio":1.0}
 g.enemies=[enemy]
 var projected:=Vector2(320,80)
 g.target_provider=func(target):return Vector2(target.x+40,target.y-20)
 g.launch_provider=func(_slot,aim,_ordinal):return {"position":Vector2(220,600),"direction":(aim-Vector2(220,600)).normalized()}
 var impacts:Array=[]
 var watch:Callable=func(kind,info):
  if kind=="projectile_impact":impacts.append(info.pos)
 g.event.connect(watch)
 var entry:Dictionary=g.combat_entry(0);var weapon:Dictionary=g.player_weapon_row(entry)
 g.begin_enhancement_attack(0,enemy);var attack:Dictionary=g.jewel_attack(0)
 g.launch_player_attack(0,enemy,weapon,attack,g.player_weapon_offset(0),0.0);g.finish_enhancement_attack(0)
 check(g.projectiles.size()==1 and g.projectiles[0].launch_point==Vector2(220,600),"committed physical muzzle")
 check(g.projectile_target_point(g.projectiles[0])==projected,"collision uses same projected target as launch")
 for i in 90:g.tick_projectiles(1.0/60.0)
 check(enemy.hp<10000 and impacts==[projected],"one real damage and impact on visible target")
 check(g.projectiles.is_empty(),"successful pulse retires")
 # A moving target still may escape the frozen straight heading; no homing added.
 impacts.clear();enemy.hp=10000
 g.begin_enhancement_attack(0,enemy);attack=g.jewel_attack(0)
 g.launch_player_attack(0,enemy,weapon,attack,g.player_weapon_offset(0),0.0);g.finish_enhancement_attack(0)
 enemy.x+=80
 for i in 90:g.tick_projectiles(1.0/60.0)
 check(enemy.hp==10000 and impacts.is_empty(),"laterally moving target not granted homing hit")
 var hostile:Dictionary={"target":g.player,"hostile":true}
 check(g.projectile_target_point(hostile)==Vector2(g.player.x,g.player.y),"hostile collision unchanged")
 g.event.disconnect(watch)
 print("PULSE_PROJECTED_CONTACT ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
