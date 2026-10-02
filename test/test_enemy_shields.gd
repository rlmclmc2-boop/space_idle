extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr(label)
func fixture(weapon:="",shield:=20.0,hp:=100.0) -> BattleGame:
 var db:=ShipDatabase.new()
 var g:=BattleGame.new(db,false)
 g.start(1,false);g.spawn_group()
 var enemy:Dictionary=g.enemies[0]
 g.enemies.assign([enemy]);enemy.equipment=[];enemy.cooldowns=[];enemy.hp=hp;enemy.max_hp=hp
 enemy.shield=shield;enemy.max_shield=shield;enemy.shieldType=1;enemy.armourType=2;enemy.shieldRecovery=0.5;enemy.shieldDelay=0.3;enemy.shield_since_hit=0.0
 enemy.x=g.player.x;enemy.y=g.player.y
 g.profile.loadout=g.empty_loadout(g.profile.selectedShip)
 g.profile.loadout.defence[0]={"key":"armour","level":1}
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 if weapon!="":
  g.profile.loadout.weapons[0]={"key":weapon,"level":1}
  db.equipment[weapon][0].dmg=10;db.equipment[weapon][0].dmgMulti=0
  if weapon=="longLaser":db.equipment[weapon][0].para3=0.0;db.equipment[weapon][0].para2=1.0
 g.reset_player()
 return g
func _initialize():call_deferred("run")
func run():
 for sample in [[15,1,12.5,100],[60,1,0,80],[60,2,0,80],[200,2,0,10]]:
  var g:=fixture();var e:Dictionary=g.enemies[0];var rng_state=g.rng.state
  g.hit_enemy(e,sample[0],int(sample[1]))
  check(is_equal_approx(float(e.shield),float(sample[2])) and is_equal_approx(float(e.hp),float(sample[3])),"shield-first raw overflow and separate body resistance "+str(sample))
  check(g.rng.state==rng_state,"nonlethal absorption does not roll RNG")
 var whole:=fixture();var e:Dictionary=whole.enemies[0]
 whole.hit_enemy(e,40,1);check(e.shield==0 and e.hp==100,"exact shield depletion does not damage HP")
 whole.hit_enemy(e,20,1);check(e.hp==80,"broken shield forwards raw once")
 var targeting:=fixture();var front:Dictionary=targeting.enemies[0];var other:Dictionary=front.duplicate(true)
 front.slot=4;other.slot=0;other.uid=999;other.shieldType=2;other.armourType=1;targeting.enemies.append(other)
 check(targeting.targets(1)[0].uid==999,"aim considers the active shield resistance")
 front.shield=0
 check(targeting.targets(1)[0].uid==front.uid,"broken shield exposes body resistance for aim")
 front.shield=front.max_shield
 check(targeting.targets(2)[0].uid==front.uid,"physical aim also follows the active defense layer")
 var regen:=fixture();e=regen.enemies[0];regen.hit_enemy(e,20,1)
 regen.advance_enemy_shields(0.2);check(e.shield==10,"no healing before delay")
 regen.advance_enemy_shields(0.2);check(is_equal_approx(e.shield,11),"only elapsed portion after delay heals")
 regen.paused=true;regen.tick(1);check(is_equal_approx(e.shield,11),"pause freezes shield clock")
 regen.paused=false;regen.advance_enemy_shields(10);check(e.shield==20,"heal caps at authored shield maximum")
 e.hp=0;e.shield=0;regen.advance_enemy_shields(10);check(e.shield==0,"dead enemy never recovers")
 var immune:=fixture();immune.db.config.dmgReduce=1.0;e=immune.enemies[0];immune.hit_enemy(e,60,1)
 check(e.hp==100 and e.shield==19,"full type resistance keeps minimum shield damage without HP leakage")
 var effects:=fixture();e=effects.enemies[0];effects.hit_enemy(e,40,1,[{"enemy_resistance":0.25}],true)
 check(e.shield==0 and e.hp==86,"shared resistance effect applies to shield and overflow, once")
 for damage_type in [0,1,2]:
  for raw in [0,0.2,1,31,100]:
   var old:=fixture("",0);var target:Dictionary=old.enemies[0]
   var expected:=maxf(1,ceilf(raw*(0.5 if damage_type==2 else 1.0)))
   old.hit_enemy(target,raw,damage_type)
   check(target.hp==100-expected,"zero-capacity enemies retain legacy min/rounding "+str([raw,damage_type]))
 var beam:=fixture("longLaser",100,1000);e=beam.enemies[0];e.armourType=0;e.shieldType=0;e.shieldRecovery=1.0
 for i in 61:beam.tick(1.0/60.0)
 check(e.shield<50 and is_equal_approx(e.hp,1000),"0.2s continuous hits suppress recovery without damaging protected HP")
 check(beam.profile.enhancementAttacks==1 and beam.projectiles[0].ticks>=5,"periods remain one main attack")
 var laser:=fixture("laser",100,1000);e=laser.enemies[0];e.armourType=0;e.shieldType=0;e.shieldRecovery=1.0
 for i in 61:laser.tick(1.0/60.0)
 check(e.shield>80 and e.hp==1000,"0.5s pulse gaps permit shield recovery")
 var stepped:=fixture("longLaser",100,1000);var batched:=fixture("longLaser",100,1000)
 for sample in [stepped,batched]:
  sample.enemies[0].shieldType=0;sample.enemies[0].shieldRecovery=1.0;sample.enemies[0].armourType=0
 for i in 14:stepped.tick(0.1)
 batched.tick(1.4)
 check(is_equal_approx(stepped.enemies[0].shield,batched.enemies[0].shield),"scheduled periodic hits prevent recovery across a batched step")
 var lethal:=fixture("longLaser",5,5);e=lethal.enemies[0];e.armourType=0;e.shieldType=0
 lethal.tick(1.0/60.0)
 check(e.hp<=0 and lethal.projectiles.is_empty(),"first lethal overflow immediately clears beam logic")
 print("Enemy shields: %d checks, %d failures" %[checks,failures]);quit(1 if failures else 0)
