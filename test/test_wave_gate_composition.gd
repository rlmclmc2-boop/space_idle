extends SceneTree
var checks=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:printerr(label);quit(1);assert(ok)
func _initialize():
 var db=ShipDatabase.new()
 var Rewards=preload("res://scripts/candidate_rewards.gd")
 var Formation=preload("res://scripts/enemy_formation.gd")
 for wave in range(6,10):
  var gid=str(int(db.levels[13].groups[wave-1].id))
  var group:Dictionary=db.groups[gid]
  var members=group.slots.filter(func(id):return id!=null).map(func(id):return db.enemies[str(int(id))])
  check(members.size()==(9 if wave<9 else 3),"Only intended live14 formation count")
  check(members.filter(func(m):return m.size>=4).size()==1,"One visually primary hull")
  check(Rewards.binding_error(gid,db.groups,db.enemies,db.levels,14,float(db.levels[13].resRatio),float(db.levels[13].jewelRatio)).is_empty(),"Main candidate reward reference budgets valid")
  check(Formation.explicit_error(group.slots,db.enemies,group.formation_positions).is_empty(),"Authored formation geometry valid")
  var positions=Formation.positions(group.slots,db.enemies,group.formation_positions)
  check(positions.size()==members.size(),"Every live actor has an authored position")
  var iron=0.0;var draws=0;var physical=0;var energy=0
  for m in members:
   draws+=Rewards.rolls(m.get("jewelDropRolls",1))
   for d in m.drops:iron+=d.amount*d.chance
   for weapon in m.equipment:
    var kind=int(db.enemy_weapon(weapon.name).dmgtype)
    if kind==1:energy+=1
    elif kind==2:physical+=1
  check(draws==(15 if wave<9 else 1),"Preserve former fragment draw quota")
  check(is_equal_approx(iron,60.0 if wave<9 else 120.0),"Preserve former raw iron quota")
  if wave<9:check(physical==4 and energy==5,"Mixed pressure instead of all equal-phase weapons")
  var view=preload("res://scripts/hyperspace_encounter_database.gd").new()
  view.configure(db,14,[int(gid)])
  check(Rewards.binding_error(gid,view.groups,view.enemies,view.levels,14,view.ratio(14,0,"resRatio"),view.ratio(14,0,"jewelRatio")).is_empty(),"Manual view retains required canonical reward references")
  var g=BattleGame.new(db,false);g.stage=14;g.group_index=wave-1;g.spawn_group()
  check(g.enemies.size()==members.size() and g.state==BattleGame.State.COMBAT,"Real spawn consumes the authored formation")
  check(g.enemies.all(func(e):return e.hp>0 and e.max_hp==e.hp),"New actors start with lawful full health")
 var captain=db.enemies["54924"]
 var original=captain.jewelDropRolls;captain.jewelDropRolls+=1
 check(not Rewards.binding_error("30146",db.groups,db.enemies,db.levels,14,float(db.levels[13].resRatio),float(db.levels[13].jewelRatio)).is_empty(),"Reject accidental bonus fragment draw")
 captain.jewelDropRolls=original
 print("WAVE_COMPOSITION ",checks," checks passed");quit()
