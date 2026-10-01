extends SceneTree
const N=preload("res://scripts/growth_number.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture() -> BattleGame:
 var db:=ShipDatabase.new()
 for key in ["armour","shield"]:
  db.equipment[key][0].para1=100
  db.equipment[key][0]["para2" if key=="armour" else "para4"]=0
 db.equipment.shield[0].para2=0
 db.config.dmgReduce=0
 db.data.enhance_config.deferred_clear_probability.value=0
 var g:=BattleGame.new(db,false)
 g.profile.grantedUnlocks=[db.unlock_id("feature","jewels")]
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.profile.enhancementLevel=1
 g.profile.enhancementOrder.defence=["delayed_damage","adaptation","memory_material"]
 g.profile.loadout={"weapons":[{"key":"laser","level":1}],"defence":[{"key":"shield","level":50},{"key":"armour","level":50}]}
 g.reset_player()
 g.state=BattleGame.State.COMBAT
 return g
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var g:=fixture()
 for pair in [[0,0],[1,.5],[3,.75],[5,.83],[2147483647,.99]]:
  check(is_equal_approx(g.enhancement_deferred_fraction(pair[0]),pair[1]),"integer percent curve "+str(pair[0]))
 g.hit_player(20,0)
 check(g.player.shield==90 and g.enhancement_deferred_total()==10,"immediate plus deferred equals mitigated hit")
 g.advance_jewel_repair(.2)
 check(g.player.shield==89 and g.enhancement_deferred_total()==9,"first scheduled tenth")
 g.advance_jewel_repair(1.8)
 check(is_equal_approx(g.player.shield,80) and N.compare(g.enhancement_deferred_total(),0)==0,"ten payments conserve total")
 check(g.profile.enhancementHits==1,"payments never recount or recursively buffer")
 g=fixture();g.db.config.dmgReduce=.5
 g.hit_player(40,int(g.db.equip("shield",50).dmgtype));g.advance_jewel_repair(2)
 check(is_equal_approx(g.player.shield,80),"typed mitigation only before split")
 g=fixture();g.profile.enhancementLevel=5
 g.hit_player(20,0);g.advance_jewel_repair(2)
 check(is_equal_approx(g.player.shield,80),"fractional immediate and ten portions conserve total")
 g=fixture();g.hit_player(20,0);g.advance_jewel_repair(.1);g.hit_player(20,0)
 check(g.enhancement_deferred.size()==11,"overlapping source schedules coalesce bounded buckets")
 g.advance_jewel_repair(.1)
 check(g.player.shield==79,"new source cannot reset old first payment")
 g.advance_jewel_repair(1.8)
 check(is_equal_approx(g.player.shield,61) and is_equal_approx(float(g.enhancement_deferred_total()),1),"phase quantization retains newer final portion")
 g.advance_jewel_repair(.2)
 check(is_equal_approx(g.player.shield,60) and N.compare(g.enhancement_deferred_total(),0)==0,"quantized source completes under one tick late")
 g=fixture();g.advance_jewel_repair(.01);g.hit_player(20,0)
 var state=g.rng.state
 g.advance_jewel_repair(.19)
 check(g.rng.state==state and g.player.shield==90,"no roll or damage before first scheduled payment")
 g=fixture();g.hit_player(20,0);var balance=g.enhancement_deferred_total();g.paused=true;g.tick(5)
 check(g.player.shield==90 and g.enhancement_deferred_total()==balance,"pause freezes queue and memory")
 g.paused=false;g.advance_jewel_repair(2)
 check(is_equal_approx(g.player.shield,80),"unpause resumes conserved debt")
 var coarse:=fixture();var fine:=fixture();coarse.hit_player(20,0);fine.hit_player(20,0)
 coarse.advance_jewel_repair(2)
 for i in 10:fine.advance_jewel_repair(.2)
 check(is_equal_approx(coarse.player.shield,fine.player.shield) and coarse.enhancement_deferred_total()==fine.enhancement_deferred_total(),"low fps equals discrete steps")
 g=fixture();g.hit_player(20,0);g.set_enhancement_order("defence",["adaptation","memory_material","delayed_damage"])
 check(g.enhancement_deferred_total()==10,"reorder does not forgive debt")
 g.unequip_slot("defence",0);g.advance_jewel_repair(2)
 check(is_equal_approx(g.player.armour,90),"removed shield debt falls through without new mitigation")
 g=fixture();g.hit_player(20,0);g.db.data.enhance_config.deferred_clear_probability.value=1;g.advance_jewel_repair(.2)
 check(g.player.shield==89 and g.enhancement_deferred.is_empty(),"certain clear pays due then clears remaining")
 g=fixture();g.rng.seed=123;g.db.data.enhance_config.deferred_clear_probability.value=.25
 g.queue_enhancement_deferred("shield",10);g.queue_enhancement_deferred("armour",10)
 var expected:=RandomNumberGenerator.new();expected.state=g.rng.state;expected.randf()
 g.advance_jewel_repair(.2)
 check(g.rng.state==expected.state,"one global roll across multiple layers and hits")
 g=fixture();g.advance_jewel_repair(.01)
 var started=Time.get_ticks_usec()
 for i in 10000:g.queue_enhancement_deferred("shield",1)
 print("Deferred burst10000us=",Time.get_ticks_usec()-started)
 check(g.enhancement_deferred.size()==10 and is_equal_approx(float(g.enhancement_deferred_total()),10000),"10000 events bounded storage and exact accumulated debt")
 g=fixture();g.profile.enhancementOrder.defence=["memory_material","adaptation","delayed_damage"];g.profile.loadout.defence[1].level=150;g.invalidate_stat_cache()
 g.player.shield=0;g.player.armour=.1;g.queue_enhancement_deferred("armour",2);g.advance_jewel_repair(.2)
 check(g.state==BattleGame.State.RETREAT and g.player.armour==0,"fatal due payment runs before same-tick memory")
 g=fixture();g.hit_player(20,0);g.state=BattleGame.State.LEVEL_CLEAR;g.pending_unlocks=["test"];g.tick(.2)
 check(g.player.shield==89,"level clear continues deferred payment")
 g=fixture();g.hit_player(20,0);g.reset_player()
 check(g.enhancement_deferred.is_empty() and g.enhancement_defense_time==0,"battle reset clears transient debt")
 for delay_on in [false,true]:
  g=fixture();g.profile.enhancementLevel=30;g.profile.loadout.defence[0].key="";g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT
  if not delay_on:g.profile.enhancementLevel=0
  g.hit_player(800,0)
  if delay_on:
   check(is_equal_approx(g.player.armour,68) and is_equal_approx(float(g.enhancement_deferred_total()),768),"large8xburst conservesfullincurreddebtandimmediate")
   check(is_equal_approx(100-g.player.armour+float(g.enhancement_deferred_total()),800),"immediateplusdebt equalsfullpostmitigationburst")
  else:check(g.player.armour==0 and g.state==BattleGame.State.RETREAT,"delayoff8xburst remainslethal")
 g=fixture();g.profile.enhancementLevel=30;g.profile.loadout.defence[0].key="";g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT
 g.hit_player(10000,0)
 check(g.player.armour==0 and g.state==BattleGame.State.RETREAT and is_equal_approx(float(g.enhancement_deferred_total()),9600),"hugeburstqueuesfull96%whileimmediate4%stillkills")

 print("DEFERRED ENHANCEMENTS: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
