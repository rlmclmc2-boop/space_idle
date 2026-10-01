extends SceneTree
const N=preload("res://scripts/growth_number.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(key := "laser") -> BattleGame:
 var db:=ShipDatabase.new()
 for weapon in ["laser","missile","cannon","longLaser"]:
  db.equipment[weapon][0].dmg=100;db.equipment[weapon][0].dmgMulti=0;db.equipment[weapon][0].cri=0;db.equipment[weapon][0].criDmg=0
 db.equipment.longLaser[0].para3=.2
 for defense in ["armour","shield"]:
  db.equipment[defense][0].para1=100;db.equipment[defense][0]["para2" if defense=="armour" else "para4"]=0
 db.equipment.shield[0].para2=0;db.equipment.shield[0].dmgtype=1;db.equipment.armour[0].dmgtype=2
 db.config.dmgReduce=.5;db.data.enhance_config.repeat_probability.value=0;db.data.enhance_config.deferred_clear_probability.value=0
 var g:=BattleGame.new(db,false)
 g.profile.cleared=range(1,41);g.rebuild_unlocks()
 g.profile.enhancementLevel=30
 g.profile.loadout={"weapons":[{"key":key,"level":150},{"key":key,"level":150}],"defence":[{"key":"shield","level":150},{"key":"armour","level":150}]}
 g.reset_player();g.spawn_group()
 for enemy in g.enemies:enemy.hp=1e10;enemy.max_hp=1e10;enemy.cooldowns=enemy.cooldowns.map(func(_cd):return 999.0)
 return g
func choose(g,effect: String,node: int,choice := "B") -> void:
 check(g.set_enhancement_branch("weapons" if effect in ["proficiency","repeat","critical"] else "defence",effect,node,choice),"choose "+effect+str(node)+choice)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var g:=fixture();var base=g.jewel_equipment_stat(g.slot_entry("weapons",0))
 for node in [1,2,3]:choose(g,"proficiency",node,"A")
 check(g.jewel_equipment_stat(g.slot_entry("weapons",0))==base*2.5,"three damageA add150%")
 g=fixture();choose(g,"proficiency",1)
 g.begin_enhancement_attack(0,g.enemies[0]);g.finish_enhancement_attack(0);g.enhancement_branches.advance_weapons(g,.99)
 check(g.jewel_equipment_stat(g.slot_entry("weapons",0))==base,"dwell waits fullsecond")
 g.enhancement_branches.advance_weapons(g,.01)
 check(is_equal_approx(float(g.jewel_equipment_stat(g.slot_entry("weapons",0))),base*1.2),"dwell fullsecond multiplies20%")
 g.enhancement_branches.advance_weapons(g,1)
 check(is_equal_approx(float(g.jewel_equipment_stat(g.slot_entry("weapons",0))),base*1.44),"dwell compounds bytime")
 check(g.jewel_equipment_stat(g.slot_entry("weapons",1))==base,"dwell independentweapon")
 g.begin_enhancement_attack(0,g.enemies[1]);g.finish_enhancement_attack(0)
 check(g.jewel_equipment_stat(g.slot_entry("weapons",0))==base,"primarytargetchange clearsdwell")
 choose(g,"proficiency",2)
 check(is_equal_approx(float(g.player_weapon_row(g.slot_entry("weapons",0)).cd),float(g.db.equip("laser",150).cd)*.7),"cooldown branch applies sharedweaponrow")
 choose(g,"proficiency",3)
 var target=g.enemies[0];target.armourType=1;var hp=target.hp
 g.hit_enemy(target,100,1,[{"enemy_resistance":.3}])
 check(hp-target.hp==70,"weaponpenetration preservesenemytable andchangesmatchingresistance")
 g=fixture()
 for node in [1,2,3]:choose(g,"repeat",node,"A")
 check(is_equal_approx(g.enhancement_branches.repeat_probability(g,g.slot_entry("weapons",0)),.3),"repeatA probabilitypoints once")
 g=fixture()
 for node in [1,2,3]:choose(g,"critical",node,"A")
 check(is_equal_approx(g.jewel_critical(g.slot_entry("weapons",0)).x,.7),"critA adds45percentagepoints")
 g=fixture();choose(g,"critical",1);g.db.data.enhance_config.base_critical_rate.value=1
 g.begin_enhancement_attack(0,g.enemies[0]);g.jewel_attack(0);g.finish_enhancement_attack(0)
 check(g.enhancement_branches.weapon(g,0).next==3,"criticalarmsnextthree aftertrigger")
 g.db.data.enhance_config.base_critical_rate.value=0
 for remaining in [2,1,0]:
  g.begin_enhancement_attack(0,g.enemies[0]);var attack=g.jewel_attack(0);g.finish_enhancement_attack(0)
  check(attack.damage==base*1.5 and g.enhancement_branches.weapon(g,0).next==remaining,"nextcritbonus consumesonecanonicalevent")
 g.begin_enhancement_attack(0,g.enemies[0]);var normal=g.jewel_attack(0);g.finish_enhancement_attack(0)
 check(normal.damage==base,"fourthattack losesnextthreebonus")
 g=fixture();choose(g,"critical",2);g.db.data.enhance_config.base_critical_rate.value=1
 for i in 5:g.begin_enhancement_attack(0,g.enemies[0]);g.jewel_attack(0);g.finish_enhancement_attack(0)
 check(g.enhancement_branches.weapon(g,0).stacks==3,"criticalstacks cappedthree")
 check(g.jewel_equipment_stat(g.slot_entry("weapons",0))==base*1.3,"criticalstackdamage10% additive")
 g.db.data.enhance_config.base_critical_rate.value=.25
 var critical_summary=g.enhancement_effect_runtime("critical",g.slot_entry("weapons",0))
 check(critical_summary.base_probability_percent==25 and is_equal_approx(critical_summary.underlying_probability_percent,40),"overviewbasechance excludesperweaponstackrates")
 g.enhancement_branches.advance_weapons(g,1.99)
 check(g.enhancement_branches.weapon(g,0).stacks==3,"stacks last2seconds")
 g.enhancement_branches.advance_weapons(g,.01)
 check(g.enhancement_branches.weapon(g,0).stacks==0,"stacks expirewholegroup")
 g=fixture();choose(g,"critical",3);g.db.data.enhance_config.base_critical_rate.value=0
 var guaranteed=g.jewel_attack(0)
 check(guaranteed.critical and not guaranteed.critical_bonus_applied and guaranteed.damage==base,"guaranteedcriticalevent no underlyingbonus usesordinarydamage")
 g.db.data.enhance_config.base_critical_rate.value=1;guaranteed=g.jewel_attack(0)
 check(guaranteed.critical and guaranteed.critical_bonus_applied and guaranteed.damage==base*(2+.3*30),"underlyingcritkeepscriticalmultiplier")
 g.db.data.enhance_config.critical_b3_guaranteed_rate.value=.8
 check(g.enhancement_branch_metadata("weapons","critical",3,"B").parameters.probability_percent==80,"fixedcritdescription followsdebugprobability")
 g=fixture();var armor=g.stat("armour")
 for node in [1,2,3]:choose(g,"adaptation",node,"A")
 check(g.stat("armour")==armor*2.5,"adaptationA add150capacity")
 g=fixture();choose(g,"adaptation",1);var source=int(g.enemies[0].uid)
 var reduced: Array=[]
 for i in 5:reduced.append(g.enhancement_branches.incoming_multiplier(g,source))
 var expected_reduced := [1.0,.8,.6,.4,.4]
 for i in 5:check(is_equal_approx(reduced[i],expected_reduced[i]),"enemyadaptationfirsthitunreduced thenstack20x3")
 check(g.enhancement_branches.incoming_multiplier(g,int(g.enemies[1].uid))==1,"differentenemysourcestartsfresh")
 g.enemies.clear();g.enhancement_branches.advance_defense(g,.2)
 check(g.enhancement_branches.incoming_sources.is_empty(),"wavecleanupprunesenemyUIDhistory")
 g=fixture();choose(g,"adaptation",2);g.enhancement_branches.advance_defense(g,2)
 var cover=g.enhancement_branches.defense(g,0).cover
 check(cover==100+g.enhancement_module_protection_capacity(0),"cover ownrealmax plusownmemorycap")
 check(g.enhancement_branch_metadata("defence","adaptation",2,"B").parameters.capacity_percent==100,"coverdescription exposesconfiguredcapacitymultiplier")
 g.enhancement_branches.advance_defense(g,1)
 check(g.enhancement_branches.defense(g,0).cover==0,"coverexpires1second")
 g.enhancement_branches.advance_defense(g,1)
 check(g.enhancement_branches.defense(g,0).cover==cover,"newcoverexcludesoldcoverrecursion")
 choose(g,"adaptation",3)
 check(g.enhancement_branches.resistance(g,g.slot_entry("defence",0),.5)==.75 and g.enhancement_branches.resistance(g,g.slot_entry("defence",0),0)==0,"sharedresistance boosts50to75butneutralstayszero")
 g=fixture()
 for node in [1,2,3]:choose(g,"memory_material",node,"A")
 check(is_equal_approx(g.enhancement_branches.memory_heal_multiplier(g,g.slot_entry("defence",0)),1.6) and is_equal_approx(g.enhancement_branches.memory_cap_multiplier(g,g.slot_entry("defence",0)),1.6),"memoryA nodesadd60%regenandcap")
 g=fixture();choose(g,"memory_material",3)
 check(is_equal_approx(g.enhancement_branches.memory_charge_multiplier(g,g.slot_entry("defence",0)),1.4) and is_equal_approx(g.enhancement_branches.memory_cap_multiplier(g,g.slot_entry("defence",0)),1.4),"memoryB30 usesenabledshieldandarmorcounts")
 g.player.armour=50;g.sync_jewel_defence_damage();g.advance_jewel_repair(.2)
 check(g.player.armour==80 and g.memory_buffer(1)==0,"shieldcountboost doesnotraiseordinarybodyhealing30")
 g.advance_jewel_repair(.2)
 check(g.player.armour==100 and is_equal_approx(float(g.memory_buffer(1)),14),"only10overflowcharges14temporaryprotection")
 g.advance_jewel_repair(.2)
 check(is_equal_approx(float(g.memory_buffer(1)),56) and is_equal_approx(float(g.enhancement_module_protection_capacity(1)),420),"full30overflowcharges42 andarmorcountcaps420")
 g.profile.loadout.defence.append({"key":"shield","level":150});g.profile.loadout.defence.append({"key":"armour","level":150})
 check(g.equipment_count("shield")==1 and g.equipment_count("armour")==1 and is_equal_approx(g.enhancement_branches.memory_charge_multiplier(g,g.slot_entry("defence",0)),1.4),"inactivehulltail equipmentneverraiseschargeorcap")
 g=fixture();choose(g,"memory_material",2);g.advance_jewel_repair(2)
 g.hit_player(20,1)
 check(g.enhancement_protection_status().mode=="energy" and g.enhancement_protection_status().resistance==.5,"matchingmemorygrantactualenergystate")
 choose(g,"adaptation",3)
 check(g.enhancement_protection_status().resistance==.75,"memorygrantusescommonadaptationresistbonus")
 var buffer=g.enhancement_protection_current();g.hit_player(20,1)
 check(buffer-g.enhancement_protection_current()==5,"matching75%resistanceappliesonce toprotection")
 g.hit_player(20,2)
 check(g.enhancement_protection_status().mode=="neutral" and g.enhancement_protection_status().lockout==2,"mismatchclearsandlocks2sec")
 g.hit_player(20,1)
 check(g.enhancement_protection_status().mode=="neutral","lockoutcannotreacquire")
 g.enhancement_branches.advance_defense(g,2);g.hit_player(20,2)
 check(g.enhancement_protection_status().mode=="physical","afterlockoutphysicalgrantacquires")
 g=fixture();choose(g,"memory_material",1);g.db.data.enhance_config.memory_b1_probability.value=1
 g.enhancement_branches.recovery_pulse(g,false)
 check(g.enhancement_branches.memory_reduction_remaining==0,"fullcappedrecoverycannotgrantfreebuff")
 g.enhancement_branches.recovery_pulse(g,true)
 check(g.enhancement_branches.incoming_multiplier(g,0)==.5,"positiveglobalrecoverygrants50%sharedreduction")
 choose(g,"memory_material",1,"A")
 check(g.enhancement_branches.memory_reduction_remaining==0,"branchremovalremovessharedbuff")
 g=fixture();g.db.data.enhance_config.deferred_clear_probability.value=.25
 for node in [1,2,3]:choose(g,"delayed_damage",node,"A")
 check(is_equal_approx(g.enhancement_branches.clear_probability(g),.55),"globalclearA contributionsoncepermilestone")
 choose(g,"delayed_damage",2)
 check(g.enhancement_branches.clear_probability(g)==0,"delayB20disablesordinaryclear")
 choose(g,"delayed_damage",3)
 check(g.enhancement_branches.clear_probability(g)==1 and is_equal_approx(g.enhancement_branches.clear_underlying_probability(g),.35),"B30overrideclearusesseparateunderlying35%")
 check(is_equal_approx(g.enhancement_branches.incoming_multiplier(g,0),(1-.35*.5)*(1+1-.35)),"B20andB30bothreferenceunderlyingchance")
 choose(g,"delayed_damage",1);g.enhancement_branches.cleared(g)
 check(g.enhancement_branches.clear_reduction_remaining==1,"clearedqueuegrants1sec20%buff")
 var debt=g.enhancement_deferred_total();g.set_enhancement_branch("defence","delayed_damage",1,"A")
 check(g.enhancement_branches.clear_reduction_remaining==0 and g.enhancement_deferred_total()==debt,"branchremovalclearsbuffwithoutforgivingdebt")
 for category in g.default_enhancement_order():
  for effect in g.default_enhancement_order()[category]:
   for node in [1,2,3]:
    for option in ["A","B"]:check(g.enhancement_branch_metadata(category,effect,node,option).implemented,"all36metadataimplemented")
 g=fixture();choose(g,"memory_material",2);choose(g,"adaptation",3)
 g.profile.enhancementOrder.defence=["memory_material","delayed_damage","adaptation"]
 g.profile.loadout.defence[0].level=50;g.invalidate_stat_cache();g.reset_player();g.advance_jewel_repair(2);g.hit_player(20,1)
 var live=g.enhancement_protection_status()
 check(live.mode=="mixed" and live.resistance==0 and live.components[0].resistance==.5 and live.components[1].resistance==.75,"mixedeligiblemodules report50and75 withoutwholepoolclaim")
 check(live.components[0].mode=="energy" and live.components[1].mode=="energy","componentmodes usecore-ownedsemanticmapping")
 check(g.enhancement_damage_type_mode(2)=="physical" and g.enhancement_damage_type_mode(0)=="neutral","physicalandneutralmappingexplicit")
 var metadata=g.enhancement_branch_metadata("defence","memory_material",2,"B")
 check(metadata.parameters.resistance_min_percent==50 and metadata.parameters.resistance_max_percent==75,"memorydescription usescommonresolverrange")
 var before_states=JSON.stringify(g.enhancement_branches.defenses);var before_buffers=JSON.stringify(g.enhancement_buffers)
 g.enhancement_protection_status();g.enhancement_protection_current();g.enhancement_protection_capacity()
 check(JSON.stringify(g.enhancement_branches.defenses)==before_states and JSON.stringify(g.enhancement_buffers)==before_buffers,"HUDderivedreads donotmutategameplaytimersorpools")
 g=fixture();g.db.data.enhance_config.deferred_clear_probability.value=.25
 choose(g,"delayed_damage",1,"A");choose(g,"delayed_damage",2,"A");choose(g,"delayed_damage",3,"A")
 var prospective=g.enhancement_branch_metadata("defence","delayed_damage",2,"B")
 check(is_equal_approx(float(prospective.parameters.reduction_percent),22.5),"prospectiveB20 replacesits10pointA beforeconversion")
 prospective=g.enhancement_branch_metadata("defence","delayed_damage",3,"B")
 check(is_equal_approx(float(prospective.parameters.damage_percent),55),"prospectiveB30 penaltyexcludesdisplacedA")

 for has_remaining in [false,true]:
  g=fixture();choose(g,"delayed_damage",1);g.db.data.enhance_config.deferred_clear_probability.value=1
  if not has_remaining:g.db.data.enhance_config.deferred_duration.value=.2
  g.queue_enhancement_deferred("armour",10)
  var expected_rng:=RandomNumberGenerator.new();expected_rng.state=g.rng.state;expected_rng.randf()
  g.advance_enhancement_deferred_tick()
  check(g.enhancement_deferred.is_empty() and g.enhancement_branches.clear_reduction_remaining==(1.0 if has_remaining else 0.0),"clearbuff requiresactualpositivecleareddebt "+str(has_remaining))
  check(g.rng.state==expected_rng.state,"zero/positiveclear preservesone settlementRNGroll "+str(has_remaining))

 print("ENHANCEMENT BRANCHES: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
