extends SceneTree
func _initialize()->void:
 var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 var retired:Array=[]
 g.event.connect(func(kind,info):
  if kind=="prototype_missile_retired":retired.append(info.duplicate(true))
 )
 for level in [20,200]:
  var shot:Dictionary={"serial":level,"x":100.0,"y":100.0,"direction":Vector2.UP,"speed":200.0,"entry":{"key":"missile","level":level}}
  g._retire_missile(shot,"qa_payload",false)
 assert(retired.size()==2)
 assert(int(retired[0].tier)==1 and int(retired[1].tier)==10)
 print("QA_RETIRED_TIER_OK payload=[",retired[0].tier,",",retired[1].tier,"]")
 quit()
