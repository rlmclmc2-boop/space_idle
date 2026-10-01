extends SceneTree
var checks := 0
var failures := 0
const N=preload("res://scripts/growth_number.gd")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:
  failures+=1
  printerr("FAIL: ",label)
func fixture() -> BattleGame:
 var db:=ShipDatabase.new()
 for key in ["laser","missile","cannon","longLaser"]:
  db.equipment[key][0].dmg=10
  db.equipment[key][0].dmgMulti=0
  db.equipment[key][0].cri=0
  db.equipment[key][0].criDmg=0
 for key in ["armour","shield"]:
  db.equipment[key][0].para1=100
  db.equipment[key][0]["para2" if key=="armour" else "para4"]=0
 db.equipment.shield[0].para2=0
 var g:=BattleGame.new(db,false)
 g.profile.grantedUnlocks=[db.unlock_id("feature","jewels")]
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.profile.enhancementLevel=1
 g.profile.loadout={"weapons":[{"key":"laser","level":150},{"key":"missile","level":150},{"key":"cannon","level":150}],"defence":[{"key":"shield","level":150},{"key":"armour","level":150},{"key":"armour","level":49}]}
 g.reset_player()
 return g
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var g:=fixture()
 for value in [[49,0],[50,1],[99,1],[100,2],[149,2],[150,3]]:
  var entry={"key":"laser","level":value[0]}
  check(g.available_effect_count(entry)==value[1],"actual equipment threshold "+str(value[0]))
  check(g.enhancement_effects(entry).size()==value[1],"eligible effect count "+str(value[0]))
 check(not g.set_enhancement_order("weapons",["repeat","repeat","critical"]),"duplicate effect rejected")
 check(g.set_enhancement_order("weapons",["critical","repeat","proficiency"]),"free reorder")
 check(g.enhancement_effects({"key":"laser","level":50})[0].kind=="critical","first eligible changes after reorder")
 check(g.enhancement_effects({"key":"armour","level":150}).size()==3,"three unique defense effects")
 check(g.enhancement_cost(1)==100 and g.enhancement_cost(10)==1968300,"target exponential cost")
 g.profile.enhancementLevel=0
 g.profile.jewelFragments=400
 check(g.upgrade_enhancement(10)==2 and g.enhancement_level()==2 and g.profile.jewelFragments==0,"bulk spends each target once")
 var before=g.enhancement_effective_level()
 g.profile.planets["1"].conquered=true
 g.invalidate_stat_cache()
 check(g.enhancement_level_bonus()==1 and g.enhancement_effective_level()==before+1,"planet adds effective level")
 check(g.enhancement_cost()==900,"free planet levels never affect purchase cost")
 g.profile.enhancementLevel=0
 check(g.enhancement_effects({"key":"laser","level":50}).size()==1,"free planet level works at purchased zero")
 g.profile.planets["1"].conquered=false;g.invalidate_stat_cache()
 check(g.enhancement_effects({"key":"laser","level":150}).is_empty(),"zero level no effect")
 g.profile.enhancementLevel=1
 check(g.jewel_critical({"key":"laser","level":49})==Vector2(.25,2),"player base crit before threshold")
 check(g.jewel_critical({"key":"laser","level":150}).is_equal_approx(Vector2(.25,2.3)),"crit increases multiplier not rate")
 var locked:=BattleGame.new(g.db,false)
 locked.profile.enhancementLevel=10
 check(locked.enhancement_effects({"key":"laser","level":150}).is_empty(),"unlock gates effects")
 g=fixture();g.profile.loadout.weapons[0].level=49;g.state=BattleGame.State.COMBAT
 g.spawn_group()
 for enemy in g.enemies:enemy.hp=1000000.0;enemy.max_hp=1000000.0;enemy.cooldowns=enemy.cooldowns.map(func(_cd):return 999.0)
 for i in g.weapon_entries().size():g.cooldowns[g.slot_id("weapons",i)]=999
 g.cooldowns[g.slot_id("weapons",0)]=0
 g.tick(.01)
 check(g.profile.enhancementAttacks==1,"inactive proficiency still counts normal attack")
 g.cooldowns[g.slot_id("weapons",1)]=0
 g.db.data.enhance_config.repeat_probability.value=0
 var old=g.projectiles.size()
 g.tick(.01)
 check(g.profile.enhancementAttacks==2 and g.projectiles.size()-old==int(g.db.equip("missile",150).para1),"missile salvo counts one attack")
 g.db.data.enhance_config.repeat_probability.value=1
 g.cooldowns[g.slot_id("weapons",1)]=0
 g.tick(.01)
 check(g.jewel_repeats.size()==1,"eligible repeat queued")
 g.advance_jewel_repeats(g.enhancement_parameter("repeat_delay"))
 check(g.profile.enhancementAttacks==4 and g.jewel_repeats.is_empty(),"new primary and inherited extra salvo each count once without recursion")
 g.profile.loadout.weapons[0]={"key":"longLaser","level":150}
 g.db.equipment.longLaser[0].para3=.2
 g.lock_long_laser(g.player,g.db.equip("longLaser",150),false,0,g.slot_entry("weapons",0))
 var shot=g.projectiles.back()
 g.tick_long_laser(shot,.4)
 check(g.profile.enhancementAttacks==5,"beam startup counts once and periodic damage does not count attacks")
 check(g.jewel_repeats.size()==1,"beam repeat schedules once from normal source")
 g.advance_jewel_repeats(g.enhancement_parameter("repeat_delay"))
 var repeated_beam=g.projectiles.back()
 check(repeated_beam.get("repeated",false),"beam repeat locks independent continuous source")
 g.tick_long_laser(repeated_beam,.2)
 check(g.profile.enhancementAttacks==6 and g.jewel_repeats.is_empty(),"repeat beam startup counts once without periodic attack counts or recursion")
 g=fixture();g.profile.enhancementAttacks=1000
 var one=g.jewel_equipment_stat(g.slot_entry("weapons",0));var two=g.jewel_equipment_stat(g.slot_entry("weapons",1))
 check(one==ceilf(g.equipment_stat("laser",150)*1.3) and two==ceilf(g.equipment_stat("missile",150)*1.3),"all weapons use same log10 history")
 g=fixture();g.set_enhancement_order("defence",["memory_material","adaptation","delayed_damage"])
 g.advance_jewel_repair(.19)
 check(g.memory_buffer(0)==0,"memory waits interval")
 g.advance_jewel_repair(.01)
 check(g.memory_buffer(0)==1 and g.memory_buffer(1)==1 and g.memory_buffer(2)==0,"own max heal overflows only eligible defense")
 g.advance_jewel_repair(10)
 check(g.memory_buffer(0)==10 and g.memory_buffer(1)==10,"buffers capped without recursive growth")
 g.db.config.dmgReduce=.5
 g.profile.loadout.defence[0].level=100;g.profile.loadout.defence[1].level=100;g.invalidate_stat_cache()
 g.hit_player(10,int(g.db.equip("shield",150).dmgtype))
 check(g.profile.enhancementHits==1,"incoming event counts once for all defenses")
 check(g.memory_buffer(0)==0 and g.enhancement_protection_current()==10 and g.player.shield==100,"neutral protection consumes raw damage and counts")
 g.hit_player(30,int(g.db.equip("shield",150).dmgtype))
 check(g.player.shield==90,"raw protection overflow receives body reduction once")
 g.set_enhancement_order("defence",["adaptation","delayed_damage","memory_material"])
 g.profile.loadout.defence[0].level=50;g.invalidate_stat_cache();g.sync_enhancement_buffers()
 check(g.memory_buffer(0)==0,"reorder below threshold removes buffer")
 g=fixture();g.advance_jewel_repair(2)
 g.unequip_slot("defence",0)
 check(g.memory_buffer(0)==0,"unequip removes protection")
 g=fixture();g.advance_jewel_repair(2)
 g.profile.loadout.defence[0].level=49;g.invalidate_stat_cache()
 check(g.memory_buffer(0)==0,"lower level removes protection")
 g=fixture();g.profile.enhancementLevel=2;g.advance_jewel_repair(2)
 g.profile.enhancementLevel=1;g.invalidate_stat_cache()
 check(g.memory_buffer(0)==10,"cap lowering clamps existing buffer")
 g=fixture();g.player.armour=90;g.sync_jewel_defence_damage();g.advance_jewel_repair(.2)
 check(g.player.armour==91 and g.memory_buffer(1)==0,"own-module memory healing retains damage instead of overflow")
 var legacy={"version":3,"jewelFragments":4321.25,"jewels":[{"id":"4","level":99}],"loadout":{"weapons":[{"key":"laser","level":100,"attacks":999,"sockets":[{"id":"1","level":99}]}],"defence":[{"key":"armour","level":100,"hits":999}]}}
 g=fixture();g.load_jewels(legacy)
 check(g.profile.jewelFragments==4321.25 and g.profile.jewels.is_empty(),"legacy retains fragments only")
 check(g.enhancement_level()==0 and g.profile.enhancementAttacks==0 and g.profile.enhancementHits==0,"legacy new counters start fresh")
 for category in ["weapons","defence"]:
  for entry in g.module_entries(category):check(not entry.has("sockets") and not entry.has("attacks") and not entry.has("hits"),"legacy module gem/history cleared")
 var current=g.profile.duplicate(true);current.enhancementLevel=7;current.enhancementAttacks=987;current.enhancementHits=45;current.enhancementOrder.weapons=["critical","repeat","proficiency"]
 g.load_jewels(current);g.load_jewels(g.profile.duplicate(true))
 check(g.enhancement_level()==7 and g.profile.enhancementAttacks==987 and g.profile.enhancementHits==45 and g.profile.jewelFragments==4321.25,"new save load idempotent")
 check(g.enhancement_order("weapons")==["critical","repeat","proficiency"],"order survives load")
 g.profile.jewelFragments=800;g.crew.auto_jewels(g,{})
 check(g.enhancement_level()==7,"auto enhancement respects affordable balance")
 g.profile.enhancementLevel=0;g.crew.auto_jewels(g,{})
 check(g.enhancement_level()==1 and g.profile.jewelFragments==700,"crew auto buys one shared level")
 var earned=g.settle_jewel_fragments(123,"furnace",1)
 check(earned==123 and g.profile.jewelFragments==823 and g.profile.jewels.is_empty(),"income remains fragments without generation")
 check(g.hightech_unlocked(BattleGame.JEWEL_FURNACE)==false or g.db.data.hightech.has(BattleGame.JEWEL_FURNACE),"furnace identity retained")
 g=fixture();g.profile.enhancementLevel=0
 for growth in [1,2,3,4,17]:
  g.db.data.enhance_config.cost_growth.value=growth
  var independent := 0.0
  var next_cost := 100.0
  for target in range(1,9):
   independent+=next_cost
   next_cost*=growth
  check(g.enhancement_purchase_cost(8)==independent,"geometric sum matches independent per-level spend growth "+str(growth))
  g.profile.jewelFragments=independent
  check(g.enhancement_max_upgrades()==8,"exact budget MAX growth "+str(growth))
  g.profile.jewelFragments=independent-1
  check(g.enhancement_max_upgrades()==7,"one fragment short MAX growth "+str(growth))
 g.db.data.enhance_config.cost_growth.value=3
 g.profile.jewelFragments={"m":1.0,"e":200.0}
 var begun=Time.get_ticks_usec();var purchased=g.upgrade_enhancement(-1)
 print("Enhancement hugeMAXus=",Time.get_ticks_usec()-begun)
 check(purchased==415 and g.enhancement_level()==415,"huge budget follows exponential sum without reaching technical cap")
 var saved=g.profile.duplicate(true);g.load_jewels(saved)
 check(g.profile.jewelFragments==saved.jewelFragments,"growth-number fragment balance loads without legacy dictionary confusion")

 var locked_counters:=BattleGame.new(ShipDatabase.new(),false)
 locked_counters.record_enhancement_attack();locked_counters.record_enhancement_hit()
 check(not locked_counters.enhancement_unlocked() and locked_counters.profile.enhancementAttacks==1 and locked_counters.profile.enhancementHits==1,"global counters accrue before enhancement unlock")
 locked_counters.reset_player()
 check(locked_counters.profile.enhancementAttacks==1 and locked_counters.profile.enhancementHits==1,"ordinary battle reset retains playthrough history")
 var sim=preload("res://scripts/balance_game.gd").new(ShipDatabase.new())
 sim.profile.grantedUnlocks=[sim.db.unlock_id("feature","jewels")];sim.profile.enhancementLevel=1;sim.profile.enhancementAttacks=1000
 var simulated_entry={"key":"laser","level":49}
 check(sim.jewel_effects({"key":"laser","level":150}).size()==3,"simulator enhancement effects without sockets")
 check(sim.jewel_equipment_stat(simulated_entry,50)>sim.equipment_stat("laser",50),"next-level stat preview applies newly eligible shared effect")

 g=fixture()
 var larger := ""
 for key in g.db.ships:
  if int(g.db.ships[key].defenseSlots)>2:larger=key;break
 g.profile.grantedUnlocks.append(g.db.unlock_id("ship",larger))
 g.profile.selectedShip=larger;g.profile.loadout.defence[2].level=150;g.reset_player();g.advance_jewel_repair(2)
 check(g.memory_buffer(2)>0,"larger hull enables tail defense protection")
 check(g.switch_ship(g.first_ship()) and g.memory_buffer(2)==0 and g.module_entry("defence",2).level==150,"hull-disabled tail loses protection but keeps module growth")

 g=fixture();g.profile.enhancementLevel=9
 check(not g.enhancement_branch_unlocked("weapons","critical",1) and not g.set_enhancement_branch("weapons","critical",1,"A"),"branch below effective threshold locked")
 g.profile.planets["1"].conquered=true;g.invalidate_stat_cache()
 check(g.enhancement_branch_unlocked("weapons","critical",1) and g.set_enhancement_branch("weapons","critical",1,"A"),"planet free level unlocks branch at effective10")
 check(not g.set_enhancement_branch("weapons","critical",2,"A") and not g.set_enhancement_branch("weapons","critical",1,"C"),"future node and invalid option rejected")
 var stats=g.jewel_equipment_stat(g.slot_entry("weapons",0))
 check(g.set_enhancement_branch("weapons","critical",1,"B") and g.enhancement_branch_choice("weapons","critical",1)=="B","branch freely switches A/B")
 check(g.jewel_equipment_stat(g.slot_entry("weapons",0))==stats,"placeholder branch does not invent stat effects")
 g.set_enhancement_order("weapons",["critical","repeat","proficiency"])
 check(g.enhancement_branch_choice("weapons","critical",1)=="B" and g.enhancement_branch_choice("weapons","repeat",1)=="","reorder keeps effect-specific choice independent")
 var branch_save=g.profile.duplicate(true);g.load_jewels(branch_save)
 check(g.enhancement_branch_choice("weapons","critical",1)=="B","branch survives new-schema load")
 g.profile.enhancementLevel=30
 for category in g.default_enhancement_order():
  for effect in g.default_enhancement_order()[category]:
   for node in [1,2,3]:check(g.set_enhancement_branch(category,effect,node,"A"),"all six effect branches node"+str(node))
 var branches_copy=g.enhancement_branch_choices("weapons","critical");branches_copy["1"]="B"
 check(g.enhancement_branch_choice("weapons","critical",1)=="A","branch read returns nonmutating copy")

 check(g.enhancement_level_limit()==9007199254740991,"supported level range reflects JSON exact-integer storage")

 for budget in [1e8,1e12,1e20,1e40]:
  g=fixture();g.profile.enhancementLevel=0;g.profile.jewelFragments=budget
  var affordable=g.enhancement_max_upgrades()
  var charge=g.enhancement_purchase_cost(affordable)
  check(N.compare(charge,budget)<=0,"MAX charge remains within large budget "+str(budget))
  check(g.upgrade_enhancement(-1)==affordable and (g.enhancement_at_limit() or not g.can_upgrade_enhancement()),"MAX leaves next level unaffordable "+str(budget))

 print("ENHANCEMENTS: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
