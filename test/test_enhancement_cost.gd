extends SceneTree
const N=preload("res://scripts/growth_number.gd")
class ObservedGame extends BattleGame:
 var cost_queries:=0
 func enhancement_purchase_cost(count:int)->Variant:
  cost_queries+=1
  return super.enhancement_purchase_cost(count)
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func close(a,b)->bool:return absf(N.ratio(a,b)-1.0)<1e-12
func _initialize()->void:
 var db:=ShipDatabase.new()
 var g:=ObservedGame.new(db,false)
 g.profile.grantedUnlocks=[db.unlock_id("feature","jewels")]
 check(g.enhancement_cost(0)==0,"Target zero costs nothing")
 for item in [[1,100.0],[2,200.0],[3,400.0],[10,51200.0],[20,52428800.0]]:
  check(g.enhancement_cost(item[0])==item[1],"Target exponential price "+str(item[0]))
 check(close(g.enhancement_cost(474),2.438866054934369e+144),"474 price matches independent decimal 100x2^473")
 check(g.enhancement_purchase_cost(0)==0 and g.enhancement_purchase_cost(-1)==0,"Nonpositive quantity costs nothing")
 check(g.enhancement_purchase_cost(3)==700 and g.enhancement_purchase_cost(10)==102300,"Bulk geometric sum starts with first100")
 g.profile.enhancementLevel=2
 check(g.enhancement_purchase_cost(3)==2800,"Bulk starts after already purchased levels")
 check(g.enhancement_purchase_cost(1)==g.enhancement_cost(),"Single and one-level bulk identical")
 g.profile.enhancementLevel=473
 var next=g.enhancement_cost()
 g.profile.planets["1"].conquered=true;g.invalidate_stat_cache()
 check(g.enhancement_level_bonus()==1 and g.enhancement_cost()==next,"Gift levels do not change charged purchase level")
 g.profile.planets["1"].conquered=false;g.invalidate_stat_cache()
 g.profile.enhancementLevel=1100
 check(N.valid(g.enhancement_cost()) and g.enhancement_cost() is Dictionary,"Power beyond float remains valid GrowthNumber")
 check(g.enhancement_purchase_cost(1)==g.enhancement_cost(),"GrowthNumber one-level charge stays identical")
 check(close(g.enhancement_purchase_cost(2),N.multiply(g.enhancement_cost(),3)),"Huge consecutive prices sum geometrically")
 g.profile.enhancementLevel=0;g.profile.jewelFragments=102300.0
 check(g.enhancement_max_upgrades(3)==3,"Explicit purchase bound limits MAX")
 check(g.upgrade_enhancement(10)==10 and g.enhancement_level()==10 and g.profile.jewelFragments==0,"x10 charges exact geometric total")
 g.profile.enhancementLevel=0;g.profile.jewelFragments=700.0
 check(g.enhancement_max_upgrades()==3,"Exact whole-fragment budget boundary")
 g.profile.jewelFragments=699.0
 check(g.enhancement_max_upgrades()==2,"One fragment short cannot buy third")
 g.profile.jewelFragments={"m":1.0,"e":200.0};g.cost_queries=0
 check(g.enhancement_max_upgrades()==657,"1e200 budget affords657 from exact independent integer sum")
 check(g.cost_queries<=53,"MAX remains bounded binary search")
 var huge=g.enhancement_purchase_cost(1200)
 check(N.valid(huge) and huge is Dictionary,"Thousand-level total survives float overflow")
 g.profile.jewelFragments=huge;g.cost_queries=0
 check(g.enhancement_max_upgrades()==1200 and g.cost_queries<=53,"GrowthNumber exact bulk budget/MAX agree")
 g.profile.enhancementLevel=0;g.profile.jewelFragments=4e15
 check(g.enhancement_max_upgrades()==45,"4Qa affords exactly45 purchased levels")
 check(g.enhancement_purchase_cost(45)==3518437208883100.0 and g.enhancement_purchase_cost(46)==7036874417766300.0,"Independent integer sums for45 and46 levels")
 check(g.upgrade_enhancement(-1)==45 and g.profile.jewelFragments==481562791116900.0,"MAX deducts45-level total without refund or reset")
 db.data.enhance_config.cost_growth.value=1
 g.profile.enhancementLevel=123456789
 check(g.enhancement_cost()==100 and g.enhancement_purchase_cost(987654321)==98765432100.0,"Growth1 constant level cost and direct count total")
 g.profile.jewelFragments=1250.0;g.cost_queries=0
 check(g.enhancement_max_upgrades()==12 and g.cost_queries<=53,"Growth1 bounded MAX without division by zero")
 db.data.enhance_config.cost_base.value=7;db.data.enhance_config.cost_growth.value=3
 g.profile.enhancementLevel=2
 check(g.enhancement_cost()==63 and g.enhancement_purchase_cost(4)==2520,"Alternative authored base/growth both drive costs")
 var raw=g.profile.duplicate(true)
 raw.enhancementLevel=473;raw.jewelFragments={"m":4.5,"e":350.0};raw.enhancementOrder.weapons=["critical","repeat","proficiency"]
 raw.enhancementBranches.weapons.critical={"1":"A","2":"B","3":"B"}
 g.load_jewels(raw)
 check(g.enhancement_level()==473 and g.profile.jewelFragments==raw.jewelFragments and g.profile.enhancementOrder==raw.enhancementOrder and g.profile.enhancementBranches==raw.enhancementBranches,"Current save state survives cost change with no reset or refund")
 print("Enhancement exponential costs: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
