extends SceneTree
const N := preload("res://scripts/growth_number.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(key: String) -> BattleGame:
 var db:=ShipDatabase.new()
 for weapon in ["laser","missile","cannon","longLaser"]:
  db.equipment[weapon][0].dmg=100;db.equipment[weapon][0].dmgMulti=0;db.equipment[weapon][0].cd=.2
 db.equipment.longLaser[0].para3=.2
 db.data.enhance_config.base_critical_rate.value=0;db.data.enhance_config.repeat_probability.value=0
 var g:=BattleGame.new(db,false)
 g.profile.cleared=range(1,41);g.rebuild_unlocks();g.profile.enhancementLevel=50
 g.profile.loadout={"weapons":[{"key":key,"level":150}],"defence":[{"key":"armour","level":150}]}
 g.reset_player();g.spawn_group()
 for enemy in g.enemies:enemy.hp=1e12;enemy.max_hp=1e12;enemy.cooldowns=enemy.cooldowns.map(func(_cd):return 999.0)
 g.set_enhancement_branch("weapons","critical",1,"B")
 g.enhancement_branches.weapon(g,0).next=3
 return g
func observe(g:BattleGame)->Dictionary:
 var counts={"fire":0,"started":0,"period":0,"hit":0,"secondary":0,"damage":0.0}
 g.event.connect(func(kind,payload):
  if kind=="fire":counts.fire+=1
  elif kind=="beam_started":counts.started+=1
  elif kind=="beam_hit":counts.period+=1
  elif kind=="enhancement_secondary":counts.secondary+=1
  elif kind=="hit" and not payload.get("player",false):counts.hit+=1;counts.damage=N.add(counts.damage,payload.amount))
 # Exact settlement fixture: remove shield/resistance from source enemies so
 # expected damage follows the independently computed launch and repeat values.
 for enemy in g.enemies:enemy.shield=0;enemy.max_shield=0;enemy.armourType=-1
 return counts
func _initialize() -> void:call_deferred("run")
func run() -> void:
 for key in ["laser","cannon","missile"]:
  var g:=fixture(key);g.set_enhancement_branch("weapons","repeat",3,"B");g.db.data.enhance_config.repeat_b3_probability.value=1
  g.cooldowns[g.slot_id("weapons",0)]=0;g.tick(.001)
  var count:=int(g.db.equip(key,150).para1) if key=="missile" else 1
  check(g.projectiles.size()==count*2,"secondary clones full canonicalattack "+key)
  check(g.profile.enhancementAttacks==1 and g.enhancement_branches.weapon(g,0).next==2,"primaryplussecondarycountone andchargeone "+key)
  check(g.jewel_repeats.is_empty(),"secondarycannotstartrepeatrecursion "+key)
  var distinct:=false
  for shot in g.projectiles:
   if not is_same(shot.target,g.projectiles[0].target):distinct=true
  check(distinct,"secondarytarget differs "+key)
 # Authorized rule: a root attack may trigger once; a derived attack cannot
 # trigger any effect. The former two-generation assertions contradicted it.
 var g:=fixture("missile");g.set_enhancement_branch("weapons","repeat",2,"B");g.db.data.enhance_config.repeat_probability.value=1
 var missile_events:=observe(g)
 g.cooldowns[g.slot_id("weapons",0)]=0;g.tick(.001)
 var salvo:=int(g.db.equip("missile",150).para1)
 var primary_damage=g.projectiles[0].damage
 check(g.jewel_repeats.size()==1 and int(g.jewel_repeats[0].depth)==1,"root preplans exactly one first-level repeat even with repeat B2 selected")
 var original_repeat_multiplier=float(g.jewel_repeats[0].multiplier)
 var expected_multiplier=1+g.enhancement_parameter("repeat_growth")*g.enhancement_effective_level()
 check(original_repeat_multiplier==expected_multiplier,"first repeat derives configured source multiplier")
 g.advance_jewel_repeats(g.enhancement_parameter("repeat_delay"))
 check(g.profile.enhancementAttacks==2 and g.jewel_repeats.is_empty() and g.projectiles.size()==salvo*2,"first repeat launches a full salvo and queues no descendant")
 var expected_repeat_damage=N.ceiling(N.multiply(primary_damage,expected_multiplier))
 check(g.projectiles.slice(salvo).all(func(shot):return N.compare(shot.damage,expected_repeat_damage)==0 and int(shot.combat_context.trigger_depth)==1),"derived salvo retains source damage multiplier and first-level context")
 for i in 150:g.tick_projectiles(.02)
 check(missile_events.fire==salvo*2 and missile_events.hit==salvo*2 and missile_events.secondary==0 and g.projectiles.is_empty(),"root and first repeat each settle once per missile without another triggered attack")
 check(is_equal_approx(float(missile_events.damage),float(N.add(N.multiply(primary_damage,salvo),N.multiply(expected_repeat_damage,salvo)))),"settled missile damage equals root plus first repeat only")
 g.advance_jewel_repeats(2*g.enhancement_parameter("repeat_delay"))
 check(g.profile.enhancementAttacks==2 and g.jewel_repeats.is_empty() and g.enhancement_branches.weapon(g,0).next==2 and missile_events.fire==salvo*2,"later repeat windows add no attack, event, or root charge consumption")
 for key in ["laser","cannon","missile","longLaser"]:
  g=fixture(key);g.set_enhancement_branch("weapons","repeat",1,"B")
  g.enemies.resize(2) # One explicit secondary avoids authored formation target order.
  var chain_events:=observe(g)
  var primary=g.enemies[0];var secondary=g.enemies[1]
  var hp=secondary.hp;var effects=g.enhancement_effects(g.slot_entry("weapons",0))
  for effect in effects:
   if effect.kind=="repeat":effect.chain=true;effect.weapon_key=key
  g.hit_enemy(primary,100,0,effects)
  check(secondary.hp==hp and g.projectiles.size()==1,"chain travels before damage "+key)
  g.tick_projectiles(1.0)
  check(secondary.hp==hp-100 and chain_events.hit==2 and float(chain_events.damage)==200.0,"arrival applies exactly one extra hit and settles root plus derived damage "+key)
  check(g.projectiles.is_empty() and g.jewel_repeats.is_empty() and chain_events.secondary==0,"derived chain hit cannot launch another triggered effect "+key)
  var after=secondary.hp;g.hit_enemy(primary,100,0,effects)
  check(secondary.hp==after,"sameprojectile/splashcannotchainagain "+key)
  check(g.profile.enhancementAttacks==0 and g.enhancement_branches.weapon(g,0).next==3,"chaindoesnotcountorconsumecrit "+key)
 g=fixture("longLaser");g.set_enhancement_branch("weapons","repeat",3,"B");g.db.data.enhance_config.repeat_b3_probability.value=1
 var events: Array=[];g.event.connect(func(kind,payload):
  if kind=="enhancement_secondary":events.append(payload))
 g.lock_long_laser(g.player,g.player_weapon_row(g.slot_entry("weapons",0)),false,0,g.slot_entry("weapons",0))
 g.tick_long_laser(g.projectiles[0],.2)
 check(g.profile.enhancementAttacks==1 and g.enhancement_branches.weapon(g,0).next==2,"beamsecondarysinglehit shares canonicalevent")
 check(g.projectiles.size()==1 and events.size()==1,"beamsecondarycreatesnoindependentramp/beam")
 g=fixture("longLaser");g.set_enhancement_branch("weapons","repeat",2,"B");g.db.data.enhance_config.repeat_probability.value=1
 var beam_events:=observe(g)
 g.lock_long_laser(g.player,g.player_weapon_row(g.slot_entry("weapons",0)),false,0,g.slot_entry("weapons",0))
 var root_beam:Dictionary=g.projectiles[0]
 g.tick_long_laser(root_beam,.2);g.advance_jewel_repeats(g.enhancement_parameter("repeat_delay"))
 check(g.projectiles.size()==2 and beam_events.started==2,"root triggers one independent first-level repeat beam")
 var repeat_beam:Dictionary=g.projectiles[1]
 var repeat_damage=N.ceiling(N.multiply(root_beam.attack_snapshot.damage,expected_multiplier))
 var before_damage=beam_events.damage
 g.tick_long_laser(repeat_beam,.2)
 check(is_equal_approx(float(N.subtract(beam_events.damage,before_damage)),float(repeat_damage)) and beam_events.hit==2 and beam_events.period==2,"first repeat emission settles expected source-scaled damage exactly once")
 g.advance_jewel_repeats(2*g.enhancement_parameter("repeat_delay"))
 check(g.projectiles.size()==2 and g.jewel_repeats.is_empty() and beam_events.started==2,"derived beam cannot launch a second generation even with repeat B2 selected")
 check(repeat_beam.repeat_multiplier==expected_multiplier and int(repeat_beam.combat_context.trigger_depth)==1,"repeat beam inherits source multiplier and a non-triggering context")
 var row:Dictionary=root_beam.attack_snapshot.weapon
 var ramp=minf(1+(float(row.para2)-1)*float(row.cd)/float(row.para1),float(row.para2))
 var expected_period_damage=N.add(N.ceiling(N.multiply(root_beam.attack_snapshot.damage,ramp)),N.ceiling(N.multiply(root_beam.attack_snapshot.damage,ramp*expected_multiplier)))
 before_damage=beam_events.damage
 g.tick_long_laser(root_beam,.2);g.tick_long_laser(repeat_beam,.2)
 check(is_equal_approx(float(N.subtract(beam_events.damage,before_damage)),float(expected_period_damage)) and beam_events.period==4 and beam_events.hit==4,"root and repeat keep their own ramp with exactly four total period settlements")
 check(g.profile.enhancementAttacks==2 and g.enhancement_branches.weapon(g,0).next==2 and beam_events.started==2 and beam_events.secondary==0 and g.jewel_repeats.is_empty(),"periodic root and derived hits cannot trigger another effect or consume root charge again")
 g=fixture("longLaser");g.set_enhancement_branch("weapons","proficiency",2,"B")
 g.lock_long_laser(g.player,g.player_weapon_row(g.slot_entry("weapons",0)),false,0,g.slot_entry("weapons",0))
 g.tick_long_laser(g.projectiles[0],.2)
 g.set_enhancement_branch("weapons","proficiency",2,"A")
 g.tick_long_laser(g.projectiles[0],.14)
 check(g.profile.enhancementAttacks==1 and g.projectiles[0].ticks==2,"branch switch keeps frozen beam interval and periodic damage does not count attacks")
 print("BRANCH ATTACKS: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
