extends SceneTree
## Read-only static projections from isolated QA portable checkpoints.
## Excludes timed attack buffs, battle geometry, temporary protection and win claims.
const Game=preload("res://qa/presented_balance_game.gd")
func _initialize():
 var request:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_PACING_PROJECTION")))
 var result=[]
 for path in request.paths:
  var payload:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
  var raw:Dictionary=payload.save.duplicate(true)
  raw.chronoSavedAt=Time.get_unix_time_from_system()
  var g=Game.new(ShipDatabase.new())
  g.simulated_time=float(payload.state.t)
  g.load_progress_data(raw);g.resume_progress();g.paused=true
  var weapons=[]
  for entry in g.combat_weapon_entries():
   weapons.append({"key":entry.key,"level":entry.level,"static_damage":g.jewel_equipment_stat(entry,-1,null,false)})
  result.append({"checkpoint":path,"stage":payload.state.stage,"t":payload.state.t,"armour":g.stat("armour"),"shield":g.stat("shield"),"weapons":weapons,"reactor_weapons":g.reactor_multiplier("weapons"),"reactor_defence":g.reactor_multiplier("defence"),"reactor_smelting":g.reactor_multiplier("smelting"),"furnace_level":g.effective_hightech_level(g.FURNACE)})
 FileAccess.open(request.output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("PACING_STATIC_PROJECTIONS ",result.size())
 quit()
