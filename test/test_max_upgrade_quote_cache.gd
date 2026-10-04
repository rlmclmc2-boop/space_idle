extends SceneTree
const N=preload("res://scripts/growth_number.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func reference_max(g:BattleGame,key:String,current:int)->int:
 var available:Dictionary=g.profile.resources.duplicate();var amount:=0
 for level in range(current+1,g.db.max_equipment_level(key)+1):
  var costs:Dictionary=g.db.equipment_cost(key,level);var affordable:=true
  for id in costs:
   if not is_finite(float(costs[id])) or N.compare(available.get(id,0),costs[id])<0:affordable=false;break
  if not affordable:break
  for id in costs:available[id]=N.subtract(available.get(id,0),costs[id])
  amount+=1
 return amount
func reference_cost(g:BattleGame,key:String,current:int,count:int)->Dictionary:
 var result:Dictionary={}
 for level in range(current+1,current+count+1):
  var cost:Dictionary=g.db.equipment_cost(key,level)
  for id in cost:result[id]=float(result.get(id,0))+float(cost[id])
 return result
func _initialize()->void:
 var g:=BattleGame.new(ShipDatabase.new(),false)
 g.profile.loadout={"weapons":[{"key":"laser","level":150}],"defence":[{"key":"armour","level":150}]}
 for category in ["weapons","defence"]:
  for current in [1,40,150]:
   g.profile.loadout[category][0].level=current
   for budget in [0.0,1.0,1e6,1e20,1e100]:
    g.profile.resources={"1":budget,"2":budget}
    var key:String=g.module_cost_key(category);var state:int=g.rng.state
    var expected:int=reference_max(g,key,current);var costs:Dictionary=reference_cost(g,key,current,expected)
    for repeat in 2:
     check(g.max_upgrade_amount_slot(category,0)==expected,"original sequential MAX parity")
     check(g.slot_upgrade_cost(category,0,expected)==costs,"exact float sum parity")
    check(g.rng.state==state,"quotes do not consume RNG")
    if expected>0:
     var public:Dictionary=g.slot_upgrade_cost(category,0,expected);public.clear()
     check(g.slot_upgrade_cost(category,0,expected)==costs,"defensive costs copy")
 g.profile.resources={"1":1e20};g.profile.loadout.weapons[0].level=150
 var before:int=g.max_upgrade_amount_slot("weapons",0)
 var row:Dictionary=g.db.equipment.laser[0];var old=row.cost_1;row.cost_1=float(old)*10
 check(g.max_upgrade_amount_slot("weapons",0)==reference_max(g,"laser",150),"in-place pricing edit invalidates")
 row.cost_1=old
 check(g.max_upgrade_amount_slot("weapons",0)==before,"restored price invalidates")
 g.profile.resources["1"]=0
 check(g.max_upgrade_amount_slot("weapons",0)==0,"wallet change invalidates")
 g.profile.resources={"1":1e20};check(g.upgrade_slot("weapons",0,1),"actual upgrade purchase")
 check(g.max_upgrade_amount_slot("weapons",0)==reference_max(g,"laser",151),"purchase level and wallet invalidates")
 print("MAX_QUOTE_CACHE ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
