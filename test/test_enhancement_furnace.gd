extends SceneTree
class ClockGame extends BattleGame:
 var now := 1000.0
 func economy_time() -> float:return now
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:
 var db:=ShipDatabase.new();var g:=ClockGame.new(db,false)
 g.profile.cleared=range(1,41);g.rebuild_unlocks()
 g.profile.hightechLevels[BattleGame.JEWEL_FURNACE]=1
 var row: Dictionary=db.data.hightech[BattleGame.JEWEL_FURNACE]
 var direct=g.settle_jewel_fragments(125,"drop",1)
 check(g.profile.jewelFragments==direct and g.profile.jewels.is_empty(),"direct drops retained as pooled currency")
 check(g.furnace_income_peak(-1,true)==direct,"direct income enters furnace base")
 g.advance_hightech(float(row.para1))
 check(g.drops.size()==1 and g.drops[0].has("jewel"),"existing furnace emits fragment core")
 var core: Dictionary=g.drops[0];var amount=float(core.amount);var before=float(g.profile.jewelFragments)
 check(amount==ceilf(direct*float(row.para2)*g.effective_hightech_level(BattleGame.JEWEL_FURNACE)),"furnace output derives current authored fields")
 g.collect(core,true)
 check(g.profile.jewelFragments==before+amount and g.profile.jewels.is_empty(),"core pickup adds fragments without gem generation")
 check(g.furnace_income_peak(-1,true)==direct,"core income cannot self-feed furnace")
 g.collect(core,true)
 check(g.profile.jewelFragments==before+amount,"duplicate core cannot double-credit")
 var peak=g.profile.jewelFurnaceIncomePeak
 g.profile.jewelFragments=100000;g.upgrade_enhancement(1)
 check(g.profile.jewelFurnaceIncomePeak==peak,"enhancement spending is not production")
 g.paused=true;var elapsed=g.profile.jewelFurnaceElapsed;g.tick(3)
 check(g.profile.jewelFurnaceElapsed==elapsed,"pause freezes unchanged furnace lifecycle")
 print("ENHANCEMENT FURNACE: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
