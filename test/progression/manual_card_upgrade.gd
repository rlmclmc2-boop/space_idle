extends SceneTree
const Policy=preload("res://qa/sparse_policy.gd")
func fixture():
 var g=BattleGame.new(ShipDatabase.new(),false)
 g.profile.resources={"1":1e12,"2":1e12};g.profile.selectedShip="Destroyer"
 g.profile.grantedUnlocks=[g.db.unlock_id("ship","Destroyer")];g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.profile.loadout={"weapons":[{"key":"laser","level":1},{"key":"missile","level":1},{"key":"cannon","level":1},{"key":"longLaser","level":1}],"defence":[{"key":"armour","level":1},{"key":"shield","level":1}]}
 g.reset_player();return g
func _initialize():
 var a=fixture();var b=fixture();var events:Array=[]
 b.event.connect(func(kind,payload):
  if kind=="upgrade" and not payload.get("batch",false):events.append(payload))
 assert(a.upgrade_equipment_batch("10"));assert(Policy.new().manual_upgrade_sweep(b,10))
 assert(a.profile.resources==b.profile.resources);assert(a.profile.loadout==b.profile.loadout);assert(a.player==b.player)
 assert(events.size()==6)
 print("MANUAL_CARD_UPGRADE_PASS same_resources_loadout_player=true actual_card_actions=",events.size()," scope=controlled per-card+10 equivalence to old internal batch; no fictitious manual all-module button")
 quit()
