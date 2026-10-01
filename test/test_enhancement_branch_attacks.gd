extends SceneTree
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
 g.profile.cleared=range(1,41);g.rebuild_unlocks();g.profile.enhancementLevel=30
 g.profile.loadout={"weapons":[{"key":key,"level":150}],"defence":[{"key":"armour","level":150}]}
 g.reset_player();g.spawn_group()
 for enemy in g.enemies:enemy.hp=1e12;enemy.max_hp=1e12;enemy.cooldowns=enemy.cooldowns.map(func(_cd):return 999.0)
 g.set_enhancement_branch("weapons","critical",1,"B")
 g.enhancement_branches.weapon(g,0).next=3
 return g
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
 var g:=fixture("missile");g.set_enhancement_branch("weapons","repeat",2,"B");g.db.data.enhance_config.repeat_probability.value=1
 g.cooldowns[g.slot_id("weapons",0)]=0;g.tick(.001)
 check(g.jewel_repeats.size()==2,"primary preplans both bounded repeat generations")
 var original_repeat_multiplier=float(g.jewel_repeats[0].multiplier)
 check(original_repeat_multiplier==7,"ordinaryrepeat derivesconfigured7xsource")
 g.advance_jewel_repeats(.5)
 check(g.profile.enhancementAttacks==2 and g.jewel_repeats.size()==1 and int(g.jewel_repeats[0].depth)==2,"ordinaryextra schedulesoneadditionalrepeat")
 check(g.jewel_repeats[0].multiplier==original_repeat_multiplier,"secondrepeat usesoriginalsource7x not49x")
 g.advance_jewel_repeats(.5)
 check(g.profile.enhancementAttacks==3 and g.jewel_repeats.is_empty() and g.enhancement_branches.weapon(g,0).next==2,"second extra counts attack but inherits root charge without consuming again")
 for key in ["laser","cannon","missile","longLaser"]:
  g=fixture(key);g.set_enhancement_branch("weapons","repeat",1,"B")
  var primary=g.enemies[0];var secondary=g.enemies[1]
  var hp=secondary.hp;var effects=g.enhancement_effects(g.slot_entry("weapons",0))
  for effect in effects:
   if effect.kind=="repeat":effect.chain=true;effect.weapon_key=key
  g.hit_enemy(primary,100,0,effects)
  check(secondary.hp==hp and g.projectiles.size()==1,"chain travels before damage "+key)
  g.advance_chain_projectile(g.projectiles.back(),1.0)
  check(secondary.hp==hp-100,"arrival applies one extra hit "+key)
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
 g.lock_long_laser(g.player,g.player_weapon_row(g.slot_entry("weapons",0)),false,0,g.slot_entry("weapons",0))
 g.tick_long_laser(g.projectiles[0],.2);g.advance_jewel_repeats(.5)
 check(g.projectiles.size()==2,"ordinaryrepeatbeam independentinstance")
 g.tick_long_laser(g.projectiles[1],.2);g.advance_jewel_repeats(.7)
 check(g.projectiles.size()==3,"repeatB20allowsoneadditionalbeamgeneration")
 check(g.projectiles[1].repeat_multiplier==7 and g.projectiles[2].repeat_multiplier==7,"beamsecondrepeat doesnotcompoundoriginal7x")
 g.tick_long_laser(g.projectiles[2],.2)
 check(g.jewel_repeats.is_empty(),"secondbeamgenerationcannotrecurse")
 g=fixture("longLaser");g.set_enhancement_branch("weapons","proficiency",2,"B")
 g.lock_long_laser(g.player,g.player_weapon_row(g.slot_entry("weapons",0)),false,0,g.slot_entry("weapons",0))
 g.tick_long_laser(g.projectiles[0],.2)
 g.set_enhancement_branch("weapons","proficiency",2,"A")
 g.tick_long_laser(g.projectiles[0],.14)
 check(g.profile.enhancementAttacks==1 and g.projectiles[0].ticks==2,"branch switch keeps frozen beam interval and periodic damage does not count attacks")
 print("BRANCH ATTACKS: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
