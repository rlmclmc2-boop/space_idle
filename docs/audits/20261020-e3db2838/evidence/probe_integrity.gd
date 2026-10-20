extends SceneTree
const Transfer=preload("res://scripts/save_transfer.gd")
const Writer=preload("res://scripts/progress_writer.gd")
func _initialize():call_deferred("run")
func run():
 var db=ShipDatabase.new()
 var g=BattleGame.new(db,false)
 g.profile.cleared=range(1,40);g.rebuild_unlocks()
 var tech=str(db.data.ai_tech_tree.keys()[0])
 g.profile.aiTechLevels[tech]=3
 g.profile.aiTechProgress[tech]=12.5
 g.profile.aiTechActive=tech
 g.profile.aiTechInput={"1":100,"2":200}
 g.profile.aiIncomePeak={"1":1000.0,"2":2000.0,"jewel":30.0}
 g.profile.productionElapsed=100.0
 g.profile.equipmentSwitchUntil={"weapons:0":130.0}
 var raw=g.portable_save_data()
 var cleaned=Transfer.clean(raw,Transfer.schema())
 var missing=[]
 for key in raw:
  if not cleaned.has(key):missing.append(key)
 print("MISSING_PORTABLE_FIELDS=",missing)
 var prepared=Transfer.new().prepare_data(raw,db)
 var restored=BattleGame.new(db,false)
 restored.load_progress_data(prepared.data)
 print("EXPORT_ROUNDTRIP tech=",tech," before=",g.profile.aiTechLevels," after=",restored.profile.aiTechLevels," error=",prepared.error)
 var path=ProjectSettings.globalize_path("user://probe-progress.json")
 var writer=Writer.new();writer.path=path
 FileAccess.open(path+".bak",FileAccess.WRITE).store_string(JSON.stringify(raw))
 FileAccess.open(path,FileAccess.WRITE).store_string('{"version":5}')
 var accepted=Writer.read_progress(path)
 print("TRUNCATED_SEMANTIC_SAVE_ACCEPTED=",accepted," BACKUP_IGNORED=",not accepted.has("resources"))
 var primary=ProjectSettings.globalize_path("user://progress.json")
 FileAccess.open(primary+".bak",FileAccess.WRITE).store_string(JSON.stringify(raw))
 FileAccess.open(primary,FileAccess.WRITE).store_string('{"version":5}')
 var live=BattleGame.new(db,true)
 print("CORRUPT_START save_enabled=",live.save_enabled," startup_error=",live.startup_error)
 live.save_progress()
 print("AFTER_SAVE backup=",FileAccess.get_file_as_string(primary+".bak"))
 var saved_game=BattleGame.new(db,false);saved_game.load_progress_data(accepted)
 print("TRUNCATED_LOAD startup_error=",saved_game.startup_error," highest=",saved_game.profile.highestLevel," resources=",saved_game.profile.resources)
 for key in ["laser","armour"]:
  for level in range(2,10000):
   var costs=db.equipment_cost(key,level)
   if costs.values().any(func(v):return not is_finite(float(v))):
    print("COST_OVERFLOW key=",key," level=",level," costs=",costs)
    break
 var n=GrowthNumber
 var tiny={"m":1.0,"e":-400.0}
 print("TINY valid=",n.valid(tiny)," ratio=",n.ratio(tiny,1.0)," mul_zero=",n.multiply(tiny,0.0))
 quit()
