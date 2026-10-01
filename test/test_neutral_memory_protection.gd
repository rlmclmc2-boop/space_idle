extends SceneTree
const N=preload("res://scripts/growth_number.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(deferred := false) -> BattleGame:
 var db:=ShipDatabase.new()
 for key in ["armour","shield"]:
  db.equipment[key][0].para1=100
  db.equipment[key][0]["para2" if key=="armour" else "para4"]=0
 db.equipment.shield[0].para2=0
 db.equipment.shield[0].dmgtype=1;db.equipment.armour[0].dmgtype=2
 db.config.dmgReduce=.5
 db.data.enhance_config.deferred_clear_probability.value=0
 var g:=BattleGame.new(db,false)
 g.profile.grantedUnlocks=[db.unlock_id("feature","jewels")]
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.profile.enhancementLevel=1
 g.profile.enhancementOrder.defence=["memory_material","delayed_damage","adaptation"]
 var level := 100 if deferred else 50
 g.profile.loadout={"weapons":[{"key":"laser","level":1}],"defence":[{"key":"shield","level":level},{"key":"armour","level":level}]}
 g.reset_player();g.state=BattleGame.State.COMBAT
 g.advance_jewel_repair(2)
 # Freeze only the in-memory healing fixture so due-debt assertions isolate damage.
 db.data.enhance_config.memory_heal_fraction.value=0
 return g
func _initialize() -> void:call_deferred("run")
func run() -> void:
 for type in [0,1,2]:
  var g:=fixture()
  check(g.enhancement_protection_current()==20 and g.enhancement_protection_capacity()==20,"neutral aggregate current/cap type"+str(type))
  g.hit_player(15,type)
  check(g.enhancement_protection_current()==5 and g.player.shield==100 and g.player.armour==100,"full absorption costs identical raw15 type"+str(type))
  check(g.profile.enhancementHits==1,"full neutral absorption counts incoming event type"+str(type))
  check(g.enhancement_deferred_total()==0,"absorbed protection never queues debt type"+str(type))
  g.hit_player(25,type)
  check(g.enhancement_protection_current()==0,"overflow spends remaining neutral5 type"+str(type))
  check(g.player.shield==(90 if type==1 else 80) and g.player.armour==100,"only raw20 overflow gets shield resistance type"+str(type))
 for type in [1,2]:
  var g:=fixture()
  g.player.shield=20;g.sync_jewel_defence_damage()
  g.hit_player(80,type)
  check(g.enhancement_protection_current()==0 and g.player.shield==0,"neutral20 consumed before shield overflow type"+str(type))
  check(g.player.armour==80,"remaining raw follows separate normal layers type"+str(type))
 for type in [1,2]:
  var g:=fixture(true)
  g.hit_player(60,type)
  var incurred := 20.0 if type==1 else 40.0
  check(g.enhancement_protection_current()==0,"deferred incoming spends raw20 protection type"+str(type))
  check(g.enhancement_deferred_total()==incurred*.5 and g.player.shield==100-incurred*.5,"only incurred body damage deferred after resistance type"+str(type))
  var history=g.profile.enhancementHits
  g.advance_jewel_repair(2)
  check(is_equal_approx(g.player.shield,100-incurred) and g.profile.enhancementHits==history,"due debt is never remitigated or recounted type"+str(type))
 var g:=fixture(true)
 g.queue_enhancement_deferred("armour",20)
 g.apply_enhancement_deferred("armour",15)
 check(g.enhancement_protection_current()==5 and g.player.armour==100,"armour debt uses whole neutral pool including shield contribution")
 g.apply_enhancement_deferred("shield",15)
 check(g.enhancement_protection_current()==0 and g.player.shield==90,"postmitigation debt overflow receives no body resistance")
 check(g.profile.enhancementHits==0,"direct due settlement never records incoming event")
 g=fixture(true);g.hit_player(15,1)
 check(g.enhancement_protection_current()==5 and g.enhancement_deferred.is_empty(),"fully protected eligible delayed hit creates no installments")
 g.set_enhancement_order("defence",["delayed_damage","adaptation","memory_material"])
 check(g.enhancement_protection_current()==0 and g.enhancement_protection_capacity()==0,"aggregate reflects eligibility removal")
 print("NEUTRAL MEMORY PROTECTION: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
