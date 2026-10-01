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
 g.stat_cache_enabled=true;g.speed=1
 g.reset_player()
 g.state=BattleGame.State.COMBAT
 return g
func _initialize() -> void:call_deferred("run")
func run()->void:
 for sample in [[50,50,10],[100,0,10],[105,0,5],[110,0,0]]:
  var g=fixture();g.profile.enhancementLevel=0;g.invalidate_stat_cache();g.player.armour=10
  g.hit_player(sample[0],0)
  check(g.player.shield==sample[1] and g.player.armour==sample[2],"ordinary shield first "+str(sample[0]))
  check((g.state==BattleGame.State.RETREAT)==(sample[2]==0),"only zero HP dies")
 var g=fixture();g.player.shield=0;g.player.armour=10;g.profile.enhancementLevel=0;g.invalidate_stat_cache()
 g.hit_player(10,0)
 check(g.player.armour==0 and g.state==BattleGame.State.RETREAT,"no shield lethal hit still kills")
 g=fixture();g.player.armour=0;g.hit_player(0,0)
 check(g.player.shield==100 and g.state==BattleGame.State.RETREAT,"zero HP never survives on remaining shield")
 for sample in [[100,50,10,50],[200,0,10,100],[210,0,5,105],[220,0,0,110]]:
  g=fixture();g.player.armour=10;g.hit_player(sample[0],0)
  check(g.player.shield==sample[1] and g.player.armour==sample[2] and g.enhancement_deferred_total()==sample[3],"deferral capacity is actual immediate payment "+str(sample[0]))
  check((g.state==BattleGame.State.RETREAT)==(sample[2]==0),"deferral retains zero-HP death")
 # Every debt source pays through current shields, without mitigation or requeue.
 for origin in ["shield","armour"]:
  g=fixture();g.player.armour=10;g.db.config.dmgReduce=.99
  var hits=g.profile.enhancementHits;var state=g.rng.state
  g.apply_enhancement_deferred(origin,105)
  check(g.player.shield==0 and g.player.armour==5,"debt uses current shield then HP "+origin)
  check(g.enhancement_deferred_total()==0 and g.profile.enhancementHits==hits and g.rng.state==state,"debt never re-mitigates, re-defers, rerolls or recounts")
 g=fixture();g.player.armour=10;g.player.shield=0
 g.queue_enhancement_deferred("armour",20)
 g.player.shield=5 # recovery between incoming damage and first installment
 g.advance_enhancement_deferred_tick()
 check(g.player.shield==3 and g.player.armour==10 and g.enhancement_deferred_total()==18,"first due installment uses recovered shield")
 g.player.shield=1 # current shield can change again between installments
 g.advance_enhancement_deferred_tick()
 check(g.player.shield==0 and g.player.armour==9 and g.enhancement_deferred_total()==16,"later installment rereads reduced shield and overflows once")
 g.profile.loadout.defence[0].key="";g.invalidate_stat_cache();g.apply_enhancement_deferred("shield",2)
 check(g.player.armour==7,"removed shield no longer absorbs old shield-source debt")
 # Body mitigation happens once before split; later debt is already mitigated.
 g=fixture();g.player.armour=10;g.db.config.dmgReduce=.5
 g.hit_player(200,int(g.db.equip("shield",50).dmgtype))
 check(g.player.shield==50 and g.player.armour==10 and g.enhancement_deferred_total()==50,"shield resistance precedes one immediate/deferred split")
 g.advance_jewel_repair(2)
 check(is_zero_approx(float(g.player.shield)) and g.player.armour==10 and N.compare(g.enhancement_deferred_total(),0)==0,"already reduced debt pays exactly once")
 # Shield modules can differ in delay eligibility; no raw overflow may skip spare shield.
 g=fixture();g.profile.selectedShip="Heavy_Battleship"
 g.profile.loadout.defence=[{"key":"shield","level":1},{"key":"shield","level":50},{"key":"armour","level":50}]
 g.invalidate_stat_cache();g.reset_player();g.player.armour=10;g.hit_player(250,0)
 check(g.player.shield==25 and g.player.armour==10 and g.enhancement_deferred_total()==75,"redistribute capped module overflow within shield before HP")
 # Preserve cover -> neutral temporary protection -> ordinary shield ordering.
 g=fixture();g.profile.loadout.defence[0].level=150;g.invalidate_stat_cache();g.reset_player();g.player.armour=10
 var entry=g.slot_entry("defence",0)
 g.enhancement_branches.defense(g,0).cover=5
 g.enhancement_buffers[0]=5.;g.enhancement_buffer_owners[0]={"entry":entry,"key":"shield"}
 g.apply_enhancement_deferred("armour",15)
 check(g.enhancement_branches.defense(g,0).cover==0 and g.enhancement_protection_current()==0 and g.player.shield==95 and g.player.armour==10,"debt preserves both extra layers ahead of ordinary shield")
 # Zero-HP death is evaluated before same-tick repair, and clear chance stays global.
 g=fixture();g.player.shield=0;g.player.armour=1;g.queue_enhancement_deferred("armour",10);g.advance_enhancement_deferred_tick()
 check(g.player.armour==0 and g.state==BattleGame.State.RETREAT,"fatal installment still kills at zero HP")
 g=fixture();g.db.data.enhance_config.deferred_clear_probability.value=1
 g.queue_enhancement_deferred("shield",10);g.queue_enhancement_deferred("armour",10)
 var expected=RandomNumberGenerator.new();expected.state=g.rng.state;expected.randf()
 g.advance_enhancement_deferred_tick()
 check(g.player.shield==98 and g.enhancement_deferred_total()==0 and g.rng.state==expected.state,"both source buckets pay then one shared clear roll")
 check_mixed_shield_rounding()
 print("SHIELD FIRST: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)

func check_mixed_shield_rounding()->void:
 for delayed in [false,true]:
  var g=fixture();g.profile.selectedShip="Heavy_Battleship"
  g.profile.enhancementLevel=30
  g.profile.enhancementOrder.defence=["adaptation","memory_material","delayed_damage"]
  g.profile.loadout.defence=[{"key":"shield","level":1},{"key":"shield","level":150 if delayed else 50},{"key":"armour","level":1}]
  check(g.set_enhancement_branch("defence","adaptation",3,"B"),"mixed shield resistance fixture")
  g.db.config.dmgReduce=.5
  g.invalidate_stat_cache();g.reset_player();g.player.armour=10
  var incoming=401.0
  var factor=1.0-g.enhancement_branches.resistance(g,g.slot_entry("defence",1),.5)
  # First module consumes raw200. The remaining raw201 crosses only the second
  # module's resistance once; split debt only after that one reduction.
  var second_damage=(incoming-200.0)*factor
  var fraction=g.enhancement_deferred_fraction() if delayed else 0.0
  var expected_payment=100.0+second_damage*(1.0-fraction)
  if not delayed:expected_payment=ceilf(expected_payment)
  g.hit_player(incoming,int(g.db.equip("shield",1).dmgtype))
  check(is_equal_approx(float(g.player.shield),200.0-expected_payment) and g.player.armour==10,"mixed shields round once and never bypass spare shield")
  check(is_equal_approx(float(g.enhancement_deferred_total()),second_damage*fraction),"redistributed raw receives resistance and deferral exactly once")
