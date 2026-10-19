extends SceneTree
const GRID=preload("res://scripts/enemy_grid_layout.gd")
func _initialize()->void:
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
 var counts:Dictionary={};var overflow:Array=[]
 for id in data.groups:
  var group:Dictionary=data.groups[id];var rows:Array=[];var leader_index:=-1;var largest:=-1
  for slot in group.slots.size():
   if group.slots[slot]==null:continue
   var actor={"uid":slot+1,"slot":slot,"size":int(data.enemies[str(int(group.slots[slot]))].size),"encounter_leader":false}
   rows.append(actor)
   if int(actor.size)>largest:largest=int(actor.size);leader_index=rows.size()-1
  var tier:String=str(group.get("combatTier","unspecified"))
  if tier in ["boss","ultimate"] and leader_index>=0:rows[leader_index].encounter_leader=true
  var plan:Dictionary=GRID.pack(rows)
  var key:String=tier+"/"+("overflow" if plan.overflow else "fit");counts[key]=int(counts.get(key,0))+1
  if plan.overflow:overflow.append({"group":id,"tier":tier,"actors":rows.size(),"required_cells":plan.required_cells})
 var result={"counts":counts,"overflow":overflow,"policy":"No actor/count/stat changes. An overloaded encounter retains the complete original display layout atomically. Multi-cell ranks use size>=4 as elite and the existing persisted encounter_leader as boss.","unspecified_tier_note":"Legacy groups without combatTier are audited without final-checkpoint promotion; actual game encounter_leader remains authoritative."}
 FileAccess.open(OS.get_environment("GRID_OUTPUT").path_join("source-group-audit.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("GRID_SOURCE_AUDIT ",JSON.stringify(counts));quit()
