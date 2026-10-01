extends SceneTree
const N=preload("res://scripts/growth_number.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(key := "laser"):
 var db:=ShipDatabase.new()
 for weapon in ["laser","missile","cannon","longLaser"]:
  db.equipment[weapon][0].dmg=100;db.equipment[weapon][0].dmgMulti=0;db.equipment[weapon][0].cri=0;db.equipment[weapon][0].criDmg=0
 db.equipment.longLaser[0].para3=.2
 for defense in ["armour","shield"]:
  db.equipment[defense][0].para1=100;db.equipment[defense][0]["para2" if defense=="armour" else "para4"]=0
 db.equipment.shield[0].para2=0;db.equipment.shield[0].dmgtype=1;db.equipment.armour[0].dmgtype=2
 db.config.dmgReduce=.5;db.data.enhance_config.repeat_probability.value=0;db.data.enhance_config.deferred_clear_probability.value=0
 var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
 g.stat_cache_enabled=true;g.speed=1
 g.profile.cleared=range(1,41);g.rebuild_unlocks()
 g.profile.enhancementLevel=50
 g.profile.loadout={"weapons":[{"key":key,"level":150},{"key":key,"level":150}],"defence":[{"key":"shield","level":150},{"key":"armour","level":150}]}
 g.reset_player();g.spawn_group()
 for enemy in g.enemies:enemy.hp=1e10;enemy.max_hp=1e10;enemy.cooldowns=enemy.cooldowns.map(func(_cd):return 999.0)
 g.refresh_missile_target_registry()
 return g
func choose(g,effect: String,node: int,choice := "B") -> void:
 check(g.set_enhancement_branch("weapons" if effect in ["proficiency","repeat","critical"] else "defence",effect,node,choice),"choose "+effect+str(node)+choice)
func _initialize() -> void:call_deferred("run")
func salvo(g,index:=0):
 var entry=g.slot_entry("weapons",index);var weapon=g.player_weapon_row(entry)
 g.begin_enhancement_attack(index,g.enemies[0]);g.record_enhancement_attack()
 var count=int(weapon.para1) if entry.key=="missile" else 1
 for i in count:g.jewel_fire(index,g.enemies[i%g.enemies.size()],weapon,g.player_weapon_offset(index),1,0,i,count)
 var snapshot=g.enhancement_attack_contexts[index].snapshot
 g.launch_enhancement_secondary(index,g.enemies[0],weapon,1)
 g.queue_jewel_repeats(index,1)
 g.finish_enhancement_attack(index)
 return snapshot
func run()->void:
 var g=fixture("missile")
 for node in [1,2,3]:choose(g,"repeat",node)
 choose(g,"critical",1);choose(g,"critical",2)
 g.db.data.enhance_config.base_critical_rate.value=1
 g.db.data.enhance_config.repeat_probability.value=1
 g.db.data.enhance_config.repeat_b3_probability.value=1
 var history=g.profile.enhancementAttacks
 var snapshot=salvo(g)
 check(g.profile.enhancementAttacks==history+1,"five missiles plus secondary count one primary attack")
 check(g.missile_queue.size()==10,"one secondary decision copies exactly one five-missile salvo")
 check(g.jewel_repeats.size()==2,"bounded extra generation planned at launch")
 check(g.enhancement_branches.weapon(g,0).next==3 and g.enhancement_branches.weapon(g,0).stacks==1,"critical buffs applied once after full primary salvo")
 for packet in g.missile_queue:
  check(packet.attack.main_attack_id==snapshot.id and packet.attack.critical and packet.attack.damage==snapshot.damage,"batch and secondary inherit primary outcome")
 var rng_state=g.rng.state
 g.advance_jewel_repeats(10)
 check(g.profile.enhancementAttacks==history+3,"primary and two extra salvos each count once, secondary does not")
 check(g.rng.state==rng_state and g.missile_queue.size()==20 and g.jewel_repeats.is_empty(),"two derived full salvos execute without rerolls or recursive queue")
 check(g.enhancement_branches.weapon(g,0).next==3 and g.enhancement_branches.weapon(g,0).stacks==1,"derived salvos neither consume next-three nor retrigger stacks")
 for packet in g.missile_queue:check(packet.attack.main_attack_id==snapshot.id,"derived trace retains root attack id")
 var chains=[]
 g.event.connect(func(kind,payload):
  if kind=="enhancement_chain":chains.append(payload))
 for i in 5:
  var attack=g.missile_queue[i].attack
  g.hit_enemy(g.enemies[0],attack.damage,1,attack.effects,attack.critical)
 check(chains.size()==int(g.enhancement_parameter("repeat_b1_targets")),"five damage carriers share one configured chain fanout")
 var previous=chains.size()
 var same=g.missile_queue[0].attack
 g.hit_enemy(g.enemies[0],same.damage,1,same.effects,same.critical)
 check(chains.size()==previous,"same damage carrier cannot chain twice")
 for i in range(5,10):
  var copy=g.missile_queue[i].attack
  g.hit_enemy(g.enemies[1],copy.damage,1,copy.effects,copy.critical)
 check(chains.size()==previous,"secondary copies share the spent chain allowance")
 var repeated=g.missile_queue[10].attack
 check(repeated.attack_instance_id!=same.attack_instance_id,"repeat salvo owns an independent attack instance")
 g.hit_enemy(g.enemies[0],repeated.damage,1,repeated.effects,repeated.critical)
 check(chains.size()==previous*2,"first valid repeat hit can chain independently")
 var other=salvo(g,1);var later=salvo(g,0)
 check(other.id!=snapshot.id and later.id!=other.id,"different mounts and later primary attacks have independent identities")
 # Main attack charges consume once, never per component.
 g=fixture("missile");choose(g,"critical",1)
 g.db.data.enhance_config.base_critical_rate.value=1;salvo(g)
 g.db.data.enhance_config.base_critical_rate.value=0
 for expected in [2,1,0]:
  salvo(g)
  check(g.enhancement_branches.weapon(g,0).next==expected,"next-three consumes one per full salvo")
 # Beam launch owns one frozen attack; scheduled damage is not an attack.
 g=fixture("longLaser")
 var entry=g.slot_entry("weapons",0);var row=g.player_weapon_row(entry)
 g.db.data.enhance_config.base_critical_rate.value=0
 history=g.profile.enhancementAttacks
 g.lock_long_laser(g.player,row,false,0,entry)
 var beam=g.projectiles.back();var frozen=beam.attack_snapshot
 check(g.profile.enhancementAttacks==history+1,"beam counts at startup")
 var hits=[]
 g.event.connect(func(kind,payload):
  if kind=="hit" and not payload.player:hits.append(payload))
 rng_state=g.rng.state
 g.tick_long_laser(beam,float(beam.charge))
 check(hits.size()==1,"beam respects configured initial charge")
 entry.level+=10000;g.invalidate_stat_cache()
 g.db.equipment.longLaser[0].para1=.01;g.db.equipment.longLaser[0].para2=100
 g.db.equipment.longLaser[0].cd=.001;g.db.data.enhance_config.base_critical_rate.value=1
 g.tick_long_laser(beam,.4)
 check(hits.size()==3 and g.profile.enhancementAttacks==history+1 and g.rng.state==rng_state,"two periodic damage events keep frozen cadence and do not attack/reroll")
 for i in hits.size():
  var ramp=g.long_laser_multiplier(frozen.weapon,float(i)*float(frozen.weapon.cd))
  var resistance=1.-float(g.db.config.dmgReduce) if int(beam.target.armourType)==int(frozen.weapon.dmgtype) else 1.
  check(N.compare(hits[i].amount,N.maximum(1,N.ceiling(N.multiply(frozen.damage,ramp*resistance))))==0,"beam damage retains launch attributes and growth parameters")
 beam.target.armourType=int(frozen.weapon.dmgtype)
 g.db.config.dmgReduce=.75
 g.tick_long_laser(beam,.2)
 check(N.compare(hits.back().amount,N.maximum(1,N.ceiling(N.multiply(frozen.damage,g.long_laser_multiplier(frozen.weapon,.6)*.25))))==0,"target reduction remains evaluated at damage time")
 beam.dead=true
 g.lock_long_laser(g.player,g.player_weapon_row(entry),false,0,entry)
 check(g.projectiles.back().attack_snapshot.id!=frozen.id and g.projectiles.back().attack_snapshot.critical and N.compare(g.projectiles.back().attack_snapshot.damage,frozen.damage)>0,"new beam after interruption reads upgraded attributes")
 # Derived beams inherit the root attributes even when released after upgrading.
 g=fixture("longLaser");choose(g,"repeat",2)
 g.db.data.enhance_config.repeat_probability.value=1
 entry=g.slot_entry("weapons",0)
 g.lock_long_laser(g.player,g.player_weapon_row(entry),false,0,entry)
 beam=g.projectiles.back();frozen=beam.attack_snapshot
 g.tick_long_laser(beam,float(beam.charge))
 entry.level+=10000;g.invalidate_stat_cache();rng_state=g.rng.state
 history=g.profile.enhancementAttacks
 g.advance_jewel_repeats(10)
 check(g.profile.enhancementAttacks==history+2,"each extra beam startup counts one attack")
 check(g.projectiles.size()==3 and g.rng.state==rng_state,"bounded derived beams launch without new attack rolls")
 for derived in g.projectiles:
  check(derived.main_attack_id==frozen.id and is_same(derived.attack_snapshot,frozen),"derived beams inherit root snapshot")
  g.tick_long_laser(derived,.4)
 check(g.jewel_repeats.is_empty() and g.rng.state==rng_state,"periodic derived beam damage cannot recursively schedule attacks")
 # If a parent extra salvo is cancelled, its preplanned descendant cannot appear later.
 g=fixture("missile");choose(g,"repeat",2)
 g.db.data.enhance_config.repeat_probability.value=1;salvo(g)
 var delay=float(g.enhancement_parameter("repeat_delay"))
 for enemy in g.enemies:enemy.hp=0
 g.advance_jewel_repeats(delay)
 for enemy in g.enemies:enemy.hp=1e10
 g.advance_jewel_repeats(delay)
 check(g.missile_queue.size()==5 and g.jewel_repeats.is_empty(),"cancelled parent suppresses planned descendants")
 # Valid alternate configured cap still bounds generation at source.
 g=fixture("missile");choose(g,"repeat",2)
 g.db.data.enhance_config.repeat_probability.value=1
 g.db.data.enhance_config.repeat_b2_repeats.value=2
 snapshot=salvo(g)
 check(snapshot.repeat_plan.size()==3,"alternate configured repeat cap preplans three bounded generations")
 # Configured cooldown reduction freezes the current beam interval at startup.
 g=fixture("longLaser");choose(g,"proficiency",2)
 entry=g.slot_entry("weapons",0)
 g.lock_long_laser(g.player,g.player_weapon_row(entry),false,0,entry)
 beam=g.projectiles.back();frozen=beam.attack_snapshot
 check(is_equal_approx(float(frozen.weapon.cd),.14),"configured .2 interval receives .7 cooldown multiplier")
 g.set_enhancement_branch("weapons","proficiency",2,"A")
 g.apply_jewel_charge(0,3.)
 g.tick_long_laser(beam,.48)
 check(beam.ticks==3 and beam.charged_multiplier==1. and g.jewel_charged.get(g.slot_id("weapons",0))==3.,"current beam keeps interval and charge after new attacker buffs")
 beam.dead=true
 g.lock_long_laser(g.player,g.player_weapon_row(entry),false,0,entry)
 check(is_equal_approx(float(g.projectiles.back().attack_snapshot.weapon.cd),.2) and g.projectiles.back().charged_multiplier==3.,"next beam reads changed interval and queued charge")
 # Shared path also covers ordinary single-shot laser/cannon.
 for key in ["laser","cannon"]:
  g=fixture(key);var root=salvo(g)
  check(g.projectiles.size()==1 and g.projectiles[0].main_attack_id==root.id,"single-shot weapon uses shared snapshot "+key)
 check_snapshot_boundaries()
 print("MAIN ATTACK SNAPSHOT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)

func check_snapshot_boundaries()->void:
 # Use real growth with fixed critical outcome, so the level change is observable.
 var g=fixture("longLaser")
 g.db.equipment.longLaser[0].dmgMulti=ShipDatabase.new().equipment.longLaser[0].dmgMulti
 g.db.data.enhance_config.base_critical_rate.value=0
 for enemy in g.enemies:enemy.hp=1e100;enemy.max_hp=1e100
 var entry=g.slot_entry("weapons",0)
 g.lock_long_laser(g.player,g.player_weapon_row(entry),false,0,entry)
 var beam=g.projectiles.back();var frozen=beam.attack_snapshot
 entry.level+=10000;g.invalidate_stat_cache()
 var grown=g.jewel_equipment_stat(entry)
 check(N.valid(grown) and grown is Dictionary and N.compare(grown,frozen.damage)>0,"real level growth changes the next attack projection without float overflow")
 g.stat_cache_enabled=false
 check(g.jewel_equipment_stat(entry)==grown,"large combat projection agrees with and without stat cache")
 g.stat_cache_enabled=true
 g.tick_long_laser(beam,.4)
 check(not beam.dead and is_same(beam.attack_snapshot,frozen) and not frozen.critical,"active beam retains fixed noncritical snapshot after 10000 levels")
 beam.dead=true
 g.lock_long_laser(g.player,g.player_weapon_row(entry),false,0,entry)
 check(not g.projectiles.back().attack_snapshot.critical and N.compare(g.projectiles.back().attack_snapshot.damage,frozen.damage)>0,"new noncritical beam reads real upgraded damage")
 # Interruption cancels damage and pending derived runtime.
 g=fixture("longLaser");choose(g,"repeat",2)
 g.db.data.enhance_config.repeat_probability.value=1
 entry=g.slot_entry("weapons",0)
 g.lock_long_laser(g.player,g.player_weapon_row(entry),false,0,entry)
 beam=g.projectiles.back();g.tick_long_laser(beam,.2)
 check(not g.jewel_repeats.is_empty(),"interruption fixture has planned derived beams")
 check(g.unequip_slot("weapons",0),"actual unequip succeeds")
 check(beam.dead and g.jewel_repeats.is_empty(),"unequip cancels beam and its planned derived runtime")
 for cause in ["target","player"]:
  g=fixture("longLaser");entry=g.slot_entry("weapons",0)
  g.lock_long_laser(g.player,g.player_weapon_row(entry),false,0,entry)
  beam=g.projectiles.back();var before=beam.ticks
  if cause=="target":beam.target.hp=0
  else:g.player.armour=0
  g.tick_long_laser(beam,.4)
  check(beam.dead and beam.ticks==before,cause+" loss prevents further periodic damage")
 # A real saved profile restores progression, never in-flight snapshots/queues.
 g=fixture("longLaser");choose(g,"repeat",2)
 g.db.data.enhance_config.repeat_probability.value=1
 entry=g.slot_entry("weapons",0)
 g.lock_long_laser(g.player,g.player_weapon_row(entry),false,0,entry)
 beam=g.projectiles.back();g.tick_long_laser(beam,.2)
 var history=g.profile.enhancementAttacks
 g.save_enabled=true;g.save_progress();g.save_enabled=false
 check(g.last_save_error==OK,"isolated profile save succeeds with active snapshot")
 var restored=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),true)
 restored.save_enabled=false
 check(restored.profile.enhancementAttacks==history and restored.slot_entry("weapons",0).key=="longLaser","saved attack history and loadout survive reopening")
 check(restored.projectiles.is_empty() and restored.missile_queue.is_empty() and restored.jewel_repeats.is_empty() and restored.enhancement_attack_contexts.is_empty(),"reopening rebuilds empty attack runtime")
 restored.start(1,false);restored.spawn_group()
 entry=restored.slot_entry("weapons",0)
 restored.lock_long_laser(restored.player,restored.player_weapon_row(entry),false,0,entry)
 check(restored.projectiles.size()==1 and restored.profile.enhancementAttacks==history+1 and not is_same(restored.projectiles[0].attack_snapshot,beam.attack_snapshot),"reopened game starts a fresh beam snapshot once")
