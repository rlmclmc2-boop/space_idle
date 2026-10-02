extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr(label)
func response(key:String,with_shield:bool,reduction:=-1.0)->Dictionary:
 var db:=ShipDatabase.new()
 if reduction>=0:db.config.dmgReduce=reduction
 var game:=BattleGame.new(db,false)
 game.profile.selectedShip="Destroyer"
 game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 game.profile.grantedUnlocks=[db.unlock_id("ship","Destroyer")]
 game.profile.loadout={"weapons":[],"defence":[]}
 if with_shield:game.profile.loadout.defence.append({"key":"shield","level":1})
 game.profile.loadout.defence.append({"key":"armour","level":1})
 game.profile.crew=[];game.profile.enhancementLevel=0
 game.reset_player();game.state=BattleGame.State.COMBAT
 var row:Dictionary=db.data.battle_design[key]
 var eid:int=int(db.groups[str(int(row.group_id))].slots.filter(func(e):return e!=null)[0])
 var mount:String=db.enemies[str(eid)].equipment[0].name
 var weapon:Dictionary=db.enemy_weapon(mount)
 var shield:float=float(game.player.shield);var armour:float=float(game.player.armour)
 check(shield>100.0 if with_shield else shield==0.0,"fixture equips its requested unlocked shield")
 # Equal raw impact isolates mitigation; the real weapon lookup/fire/collision
 # path determines damage type. No authored weapon or growth value is changed.
 game.fire({"x":game.player.x,"y":game.player.y-5.0},game.player,weapon,100.0,true,mount,Vector2.ZERO)
 check(game.projectiles.size()==1 and int(game.projectiles[0].type)==int(row.attack_type),"real projectile uses declared outgoing type")
 game.tick_projectiles(0.1)
 check(game.projectiles.is_empty(),"real collision consumes normalized impact")
 return {"shield":shield-float(game.player.shield),"armour":armour-float(game.player.armour)}
func _initialize():
 var db:=ShipDatabase.new()
 for row in db.data.battle_design.values():
  for eid in db.groups[str(int(row.group_id))].slots:
   if eid==null:continue
   for mount in db.enemies[str(int(eid))].equipment:
    check(int(db.enemy_weapon(mount.name).dmgtype)==int(row.attack_type),"all40 templates resolve actual declared attack types")
 var live:float=float(db.config.dmgReduce)
 var distinct:float=0.25 if not is_equal_approx(live,0.25) else 0.1
 for configured in [-1.0,distinct]:
  var reduced:float=ceilf(100.0*(1.0-(live if configured<0 else configured)))
  var energy:=response("normal_laser",true,configured);var physical:=response("normal_laser_physical_attack",true,configured)
  check(is_equal_approx(energy.shield,reduced) and is_equal_approx(physical.shield,100.0),"energy shield reduces only its configured type")
  check(energy.armour==0 and physical.armour==0,"intact shield protects hull in both types")
  energy=response("normal_laser",false,configured);physical=response("normal_laser_physical_attack",false,configured)
  check(is_equal_approx(energy.armour,100.0) and is_equal_approx(physical.armour,reduced),"composite armour reduces only its configured type")
 print("ENEMY ATTACK PAIRS: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
