extends SceneTree
const Display=preload("res://scripts/equipment_display.gd")
const N=preload("res://scripts/growth_number.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func equal(a,b)->bool:return absf(float(N.divide(a,b))-1)<1e-6
func _initialize():call_deferred("run")
func run():
 var g:=BattleGame.new(ShipDatabase.new(),false)
 g.stat_cache_enabled=true
 var entry:Dictionary=g.module_entry("weapons",0);entry.level=12
 for key in ["laser","cannon","missile","longLaser"]:
  entry.key=key;g.invalidate_stat_cache()
  var before:=JSON.stringify(g.profile);var rng_before:=g.rng.state
  var values:=Display.snapshot(g,entry);var row:=g.player_weapon_row(entry)
  var count:=int(row.para1) if key=="missile" else 1
  if key!="longLaser":check(equal(values.rate.start,N.multiply(values.expected,float(count)/float(row.cd))),key+" uses complete salvo and effective interval")
  check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,key+" read-only projection preserves RNG/profile")
 entry.key="cannon";g.invalidate_stat_cache()
 var totals:Dictionary=g.hyperspace_totals();totals.repeat_chance=0.25
 totals.legendary.higgs_cannon={"parameters":{"damage_bonus":0.5}}
 totals.legendary.strange_matter={"constants":{"spawn_probability":0.2},"parameters":{"damage_multiplier":2.0}}
 var values:=Display.snapshot(g,entry)
 check(equal(values.rate.start,N.multiply(values.expected,1.5*(1+0.25+0.2*2)/float(g.player_weapon_row(entry).cd))),"Fixed direct bonus, ordinary repeat and non-kill additional hit counted once")
 check(values.rate.conditional and values.rate.reasons.has("kills"),"Kill extras remain explicitly conditional")
 entry.key="missile";g.invalidate_stat_cache();totals=g.hyperspace_totals()
 totals.legendary.wild_missile={}
 check(Display.throughput(g,entry).conditional,"Shared missile counter is not advertised as exact total")
 entry.key="longLaser";g.invalidate_stat_cache()
 var source:Dictionary=g.db.equipment.longLaser[0]
 source.cd=0.28;source.para1=2.0;source.para2=3.0;source.para3=1.0
 var rate:=Display.throughput(g,entry)
 check(is_equal_approx(rate.first_hit,1.0) and is_equal_approx(rate.stage_time,3.24),"Explicit charge ramp begins on first hit; discrete terminal tick is3.24")
 check(equal(rate.end,N.multiply(rate.start,3.0)),"Beam range represents only its own ramp")
 source.para3=null
 rate=Display.throughput(g,entry)
 check(is_equal_approx(rate.first_hit,0.28) and is_equal_approx(rate.stage_time,2.24),"Legacy uncharged beam starts ramp before its first settlement")
 check(equal(rate.start,N.multiply(rate.single,g.long_laser_multiplier(g.player_weapon_row(entry),0.28)/0.28)),"Legacy starting value already includes first-hit ramp")
 source.para3=1.0;g.hyperspace_totals().repeat_chance=0.25
 rate=Display.throughput(g,entry)
 check(rate.conditional and rate.reasons.has("beam_repeat"),"Repeated beam transient excluded and flagged")
 var next:=Display.throughput(g,entry,13)
 check(equal(N.divide(next.start,rate.start),N.divide(g.jewel_equipment_stat(entry,13,null,false),g.jewel_equipment_stat(entry,-1,null,false))),"Upgrade uses same rate assumptions")
 g.hyperspace_totals().repeat_chance=0
 g.hyperspace_totals().legendary.endless_beam={"parameters":{"maximum_multiplier_bonus":1.0}}
 check(equal(Display.throughput(g,entry).end,N.multiply(Display.throughput(g,entry).start,4.0)),"Strongest beam includes Endless fixed maximum bonus")
 var other:Dictionary=g.module_entry("weapons",1);other.key="longLaser";other.level=13
 g.stat_cache.erase("hyperspace_endless_source")
 check(equal(Display.throughput(g,entry).end,N.multiply(Display.throughput(g,entry).start,3.0)),"Weaker beam does not borrow the strongest beam bonus")
 var preview:=Display.throughput(g,entry,14)
 check(equal(preview.end,N.multiply(preview.start,4.0)),"Upgrade preview reselects the strongest logical beam")
 g.hyperspace_totals().legendary.prism_tower={"parameters":{"maximum_multiplier_bonus":2.0}}
 check(Display.throughput(g,entry).reasons.has("beam_owner"),"Shared Prism owner is conditional, not a guaranteed per-module bonus")
 entry.key="missile";g.hyperspace_totals().legendary.precise_guidance={}
 check(Display.throughput(g,entry).reasons.has("target_stacks"),"Enemy guidance history is excluded and explained")
 entry.key="longLaser"
 source.cd=0
 check(not Display.throughput(g,entry).valid,"Invalid interval never produces infinite rate")
 print("Equipment throughput: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
