extends SceneTree
const Presented=preload("res://scripts/presented_battle_game.gd")
const Balanced=preload("res://scripts/balance_game.gd")
class ObservedPresented extends "res://scripts/presented_battle_game.gd":
 var query_times:Array=[]
 func enemy_resistance_type(enemy:Dictionary)->int:
  query_times.append(enemy_shield_time if enemy_shield_hit_time<0 else enemy_shield_hit_time)
  return super.enemy_resistance_type(enemy)
var checks:=0
var failures:=0
var games:Array=[]
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr(label)
func fixture(klass=BattleGame):
 var db:=ShipDatabase.new()
 db.data.enhance_config.base_critical_rate.value=0
 db.data.enhance_config.repeat_probability.value=0
 var row:Dictionary=db.equipment.longLaser[0]
 row.dmg=10;row.dmgMulti=0;row.cd=.2;row.para3=.2;row.para2=1
 var g=klass.new(db) if klass==Balanced else klass.new(db,false)
 games.append(g);g.rng.seed=1701;g.start(1,false);g.spawn_group()
 var e:Dictionary=g.enemies[0]
 g.enemies.assign([e]);e.equipment=[];e.cooldowns=[];e.hp=10000;e.max_hp=10000
 e.shield=0.0;e.max_shield=100.0;e.shieldType=0;e.armourType=0;e.shieldRecovery=1.0;e.shieldDelay=.3;e.shield_updated_at=0.0;e.shield_hit_at=0.0
 e.x=g.player.x;e.y=g.player.y
 g.profile.loadout=g.empty_loadout(g.profile.selectedShip)
 g.profile.loadout.defence[0]={"key":"armour","level":1}
 g.profile.loadout.weapons[0]={"key":"longLaser","level":1}
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.reset_player()
 return g
func beam(g,mount:=0):
 var entry:Dictionary=g.slot_entry("weapons",mount)
 g.lock_long_laser(g.player,g.player_weapon_row(entry),false,mount,entry)
 return g.projectiles.back()
func record(g,out:Array):
 g.event.connect(func(kind,payload):
  if kind=="hit" and not payload.player:
   for e in g.enemies:
    if e.uid==payload.uid:out.append(float(e.get("shield_hit_at",g.enemy_shield_time))))
func _initialize():call_deferred("run")
func run():
 var g=fixture();var e:Dictionary=g.enemies[0];var times:Array=[];record(g,times)
 g.fire(g.player,e,{"para1":1000,"dmgtype":1},10,false,"laser",Vector2.ZERO)
 beam(g);g.tick(1)
 check(e.shield==0 and e.hp==9940,"normal round preceding beam must not recover shield ahead of earlier periods "+str([e.shield,e.hp,times]))
 check(times.size()==6 and is_equal_approx(times[0],.2) and is_equal_approx(times[4],1.0) and is_equal_approx(times[5],1.0),"beam periods precede boundary impact")
 check(g.profile.enhancementAttacks==1,"all five periods remain one main attack")
 check(is_equal_approx(g.enemy_shield_time,1.0) and is_equal_approx(e.shield_hit_at,1.0),"public combat tick advances shield clock once")
 g=fixture();e=g.enemies[0];g.db.equipment.longLaser[0].cd=.4
 g.profile.loadout.weapons[1]={"key":"longLaser","level":1}
 var first:Dictionary=beam(g);var second:Dictionary=beam(g,1);second.charge=.4
 times=[];record(g,times);g.tick(1)
 check(e.shield==0 and e.hp==9950,"two interleaved beams suppress recovery across mounts")
 check(times.size()==5 and is_equal_approx(times[1],.4) and is_equal_approx(times[2],.6) and is_equal_approx(times[3],.8),"global beam order follows due rather than mount order")
 check(first.ticks==3 and second.ticks==2 and g.profile.enhancementAttacks==2,"each beam counts once without duplicated periods")
 g=fixture();e=g.enemies[0];var secondary:Dictionary=e.duplicate(true);secondary.uid=999;secondary.slot=0;secondary.shield=20;secondary.shieldRecovery=.1
 g.enemies.append(secondary);e.shield=100;e.shieldRecovery=.1
 g.db.equipment.longLaser[0].para3=1;g.db.equipment.longLaser[0].cd=2
 var shot:Dictionary=beam(g);shot.attack_snapshot.secondary=true;shot.attack_snapshot.secondary_used=false
 g.tick(1.4)
 for target in g.enemies:g.settle_enemy_shield(target,g.enemy_shield_time)
 check(is_equal_approx(secondary.shield,18.0) and is_equal_approx(secondary.shield_hit_at,1.0),"synchronous secondary shares due and recovers only after its true delay")
 check(is_equal_approx(e.shield_hit_at,secondary.shield_hit_at) and g.profile.enhancementAttacks==1,"primary and secondary share one attack and hit timestamp")
 g.tick(.1);check(secondary.shield_hit_at==1.0 and g.enemy_shield_hit_time==-1,"secondary executes once and hit scope restores")
 g=fixture();e=g.enemies[0];secondary=e.duplicate(true);secondary.uid=999;secondary.shield=20;secondary.shieldRecovery=.1
 g.enemies.append(secondary);g.db.equipment.longLaser[0].para3=1;g.db.equipment.longLaser[0].cd=2
 shot=beam(g);var chain:Dictionary=shot.attack_instance.chain
 chain.count=1;chain.links=[{"target":secondary,"broken":false}]
 shot.attack_snapshot.effects=[{"kind":"repeat","level":1,"p2":0.0,"p4":0.0,"chain":true,"chain_targets":1,"weapon_key":"longLaser"}]
 g.tick(1.4)
 check(is_equal_approx(secondary.shield_hit_at,1.0) and is_equal_approx(secondary.shield,18.0),"synchronous beam chain inherits scheduled due and recovery delay")
 check(g.projectiles.size()==1 and shot.ticks==1 and g.profile.enhancementAttacks==1,"chain creates no extra beam, attack count or repeated carrier")
 g.tick(.1);check(secondary.shield_hit_at==1.0,"same beam period cannot chain twice")
 g=fixture();e=g.enemies[0];e.armourType=2;e.shieldType=1;e.slot=4
 var other:Dictionary=e.duplicate(true);other.uid=999;other.slot=0;other.max_shield=0;other.shield=0
 g.enemies.append(other);g.enemy_shield_time=.4
 check(g.targets(1)[0].uid==999 and is_equal_approx(e.shield,10.0),"target order uses recovered front layer at query time")
 g.targets(1);check(is_equal_approx(e.shield,10.0),"same-time target query does not heal twice")
 # Presented's invalid pending missile selects a replacement before base hit
 # processing. It must not settle the shield to the later step boundary.
 g=fixture(Presented);e=g.enemies[0];g.profile.loadout.weapons[1]={"key":"missile","level":1}
 g.refresh_missile_target_registry();var dead:Dictionary=e.duplicate(true);dead.uid=998;dead.hp=0
 var attack={"damage":10,"effects":[],"critical":false}
 g.launch_player_attack(1,dead,g.player_weapon_row(g.slot_entry("weapons",1)),attack,Vector2.ZERO,0.0)
 beam(g);g.tick(1)
 check(g.missile_retarget_count==1 and e.shield==0 and e.hp<=9950,"Presented pending retarget cannot recover shields before earlier beam")
 check(is_equal_approx(g.enemy_shield_time,1.0),"Presented override advances shield clock once")
 g=fixture(ObservedPresented);e=g.enemies[0];e.y-=300
 e.shield=55;e.shield_updated_at=.35;g.enemy_shield_time=.35
 g.profile.loadout.weapons[1]={"key":"missile","level":1}
 other=e.duplicate(true);other.uid=997;other.armourType=2;other.max_shield=0;other.shield=0;g.enemies.append(other);g.refresh_missile_target_registry()
 dead=e.duplicate(true);dead.uid=998;dead.hp=0
 g.launch_player_attack(1,dead,g.player_weapon_row(g.slot_entry("weapons",1)),attack,Vector2.ZERO,0.0)
 shot=beam(g);shot.charge=.4;shot.elapsed=.35;shot.next_hit_at=.4
 g.query_times.clear();g.tick_projectiles(.15)
 check(g.missile_retarget_count==1 and is_equal_approx(e.shield,50.0) and is_equal_approx(e.shield_hit_at,.4),"Presented coarse prepass crossing recovery boundary cannot pre-heal before beam due")
 check(is_equal_approx(g.enemy_shield_time,.5),"Presented direct coarse call advances the single clock by exactly dt")
 check(not g.query_times.is_empty() and g.query_times.all(func(at):return is_equal_approx(at,.35)),"Presented real multi-target retarget comparisons run at step start")
 g=fixture();e=g.enemies[0];g.enemy_shield_time=1.4;g.db.equipment.longLaser[0].para3=1;g.db.equipment.longLaser[0].cd=2
 shot=beam(g);g.tick_long_laser(shot,1.4)
 check(is_equal_approx(g.enemy_shield_time,1.4) and is_equal_approx(e.shield_hit_at,1.0),"low-level beam resolver uses caller clock and scheduled due without advancing clock twice")
 # Live membership must be checked again after each beam-hit callback.
 for mutation in ["erase","reverse","clear_and_fire"]:
  var sample=fixture();sample.profile.loadout.weapons[1]={"key":"longLaser","level":1}
  var a:Dictionary=beam(sample);var b:Dictionary=beam(sample,1);var added:Array=[]
  sample.event.connect(func(kind,payload):
   if kind!="beam_hit" or not is_same(payload.shot,a) or int(a.ticks)!=1:return
   if mutation=="erase":sample.projectiles.erase(b)
   elif mutation=="reverse":sample.projectiles.reverse()
   else:
    sample.projectiles.clear();added.append(beam(sample)))
  sample.tick_projectiles(1.0)
  check(a.ticks==(1 if mutation=="clear_and_fire" else 5),"primary beam periods obey callback membership: "+mutation)
  check(b.ticks==(5 if mutation=="reverse" else 0),"removed/reordered beam periods obey live membership: "+mutation)
  if mutation=="clear_and_fire":check(added.size()==1 and added[0].ticks==0,"new callback beam waits for next snapshot")
 # The collection pass must also tolerate a live order differing from pending.
 g=fixture();g.profile.loadout.weapons[1]={"key":"longLaser","level":1}
 first=beam(g);second=beam(g,1)
 var beam_pending:Array=g.projectiles.duplicate();g.projectiles.reverse();g.enemy_shield_time=.4
 g.tick_shield_beams(beam_pending,.4)
 check(first.ticks==2 and second.ticks==2,"collection retains both beams after live reorder")
 # FAST here is the Lab implementation choice, never a game speed multiplier.
 var exact=fixture(Balanced);var fast=fixture(Balanced);fast.simulation_mode="fast"
 for sample in [exact,fast]:
  beam(sample)
  sample.fire(sample.player,sample.enemies[0],{"para1":1000,"dmgtype":1},10,false,"laser",Vector2.ZERO)
 for i in 60:
  exact.tick_projectiles(1.0/60.0);fast.tick_projectiles(1.0/60.0)
 check(is_equal_approx(exact.enemies[0].shield,fast.enemies[0].shield) and exact.enemies[0].hp==fast.enemies[0].hp,"shield exact and Lab fast agree at normal 1x step")
 check(exact.rng.state==fast.rng.state and exact.profile.enhancementAttacks==fast.profile.enhancementAttacks,"Lab fast preserves shield attack count and RNG")
 g=fixture();g.tick_projectiles(.2);check(is_equal_approx(g.enemy_shield_time,.2),"direct projectile call advances shield clock once")
 var invalid=fixture();var invalid_shot:Dictionary=beam(invalid);invalid_shot.target={};invalid.tick_projectiles(1)
 check(invalid_shot.ticks==0 and invalid.enemies[0].shield_hit_at==0,"lost lock cancels every queued period without refreshing recovery delay")
 g=fixture();e=g.enemies[0];e.shield=5;e.hp=5;shot=beam(g);g.tick(1)
 check(shot.ticks==1 and e.hp==0 and g.projectiles.is_empty(),"first kill cancels later scheduled periods immediately")
 g=fixture();beam(g);g.paused=true;g.tick(1)
 check(g.enemy_shield_time==0 and g.projectiles[0].ticks==0,"paused public tick freezes clock and scheduled damage")
 print("Enemy shield timing: %d checks, %d failures" %[checks,failures])
 for sample in games:
  for connection in sample.event.get_connections():sample.event.disconnect(connection.callable)
  sample.projectiles.clear()
  sample.enhancement_attack_contexts.clear()
 games.clear()
 call_deferred("quit",1 if failures else 0)
