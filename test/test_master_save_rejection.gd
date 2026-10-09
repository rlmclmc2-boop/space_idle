extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func write_json(path:String,value:Dictionary) -> void:
 var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
func _initialize() -> void:
 for suffix in ["",".bak",".import-prev",".import-active",".import-new"]:
  if FileAccess.file_exists(BattleGame.SAVE_PATH+suffix):printerr("Refuse to replace pre-existing isolated save");quit(1);return
 var db=ShipDatabase.new();var g=BattleGame.new(db,false);g.profile.cleared=range(1,41);g.profile.highestLevel=41;g.rebuild_unlocks();g.pending_unlocks.clear()
 var rng=RandomNumberGenerator.new();rng.seed=717
 var d:Dictionary=Rewards.create_drone(rng,g.hyperspace.config,"boundary-master","legendary","laser",6,g.hyperspace.Permission.planet_for_level(db.data,6));d.legendary_effect={"effect_id":"drone_master","parameters":{"maximum_reduction":0.55}};d.affixes=[]
 check(Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config),"Compatible source fixture inserts through inventory authority")
 var compatible:Dictionary=g.portable_save_data();var transfer=Transfer.new()
 check(transfer.prepare_data(compatible,db).error.is_empty(),"Complete compatible fixture passes production portable validation")
 var invalid:Dictionary=compatible.duplicate(true);invalid.hyperspace.inventory.drones[d.id].legendary_effect.parameters.maximum_reduction=0.553
 check(transfer.prepare_data(invalid,db).error=="format","Portable import rejects the entire invalid save without deleting an effect or drone")
 var target=BattleGame.new(db,false);target.profile.resources["1"]=12345;var before=JSON.stringify(target.profile)
 target.load_progress_data(invalid)
 check(target.hyperspace.last_error=="invalid_hyperspace_save" and JSON.stringify(target.profile)==before,"Direct load rejects before changing any current profile fields")
 write_json(BattleGame.SAVE_PATH,invalid);var original=FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)
 var blocked=BattleGame.new(db,true)
 check(blocked.startup_error=="invalid_progress_save" and not blocked.save_enabled and blocked.paused,"All incompatible copies stop startup and disable saves")
 blocked.save_progress()
 check(FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==original,"Rejected startup cannot overwrite the invalid original with a fresh profile")
 write_json(BattleGame.SAVE_PATH+".bak",compatible)
 var recovered=BattleGame.new(db,true)
 check(recovered.startup_error.is_empty() and recovered.save_enabled and recovered.profile.hyperspace.inventory.drones[d.id].legendary_effect.parameters.maximum_reduction==0.55,"A compatible existing recovery copy follows the original fallback path")
 check(FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH)==original,"Recovery loading itself leaves the incompatible primary untouched")
 recovered.save_progress()
 var installed=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
 check(installed.hyperspace.inventory.drones[d.id].legendary_effect.parameters.maximum_reduction==0.55 and FileAccess.file_exists(BattleGame.SAVE_PATH+".bak"),"Subsequent explicit save installs the recovered profile and retains the good recovery copy")
 for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(BattleGame.SAVE_PATH+suffix)
 print("Master save rejection: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
