extends SceneTree
const Dialog=preload("res://scripts/hyperspace_reforge_dialog.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Permission=preload("res://scripts/hyperspace_permissions.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func labels(node:Node)->String:
 var result:String=node.text+"\n" if node is Label and node.is_visible_in_tree() else ""
 for child in node.get_children():result+=labels(child)
 return result
func show_case(g,label:String)->Dictionary:
 var before:Dictionary=g.profile.duplicate(true)
 var dialog=Dialog.new();root.add_child(dialog);dialog.setup(g,"1","")
 preload("res://scripts/dialog_presentation.gd").dialog(dialog);dialog.popup_centered()
 await process_frame;await process_frame
 var visible_text:=labels(dialog)
 var folder:=OS.get_environment("REFORGE_DISCLOSURE_EVIDENCE")
 if not folder.is_empty() and DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  dialog.get_texture().get_image().save_png(folder.path_join(label+".png"))
  FileAccess.open(folder.path_join(label+".json"),FileAccess.WRITE).store_string(JSON.stringify(before))
 print(label,": ",visible_text.replace("\n"," | "))
 dialog.canceled.emit();await process_frame
 check(g.profile==before,"Opening/cancelling "+label+" leaves progress unchanged")
 return {"text":visible_text}
func run()->void:
 root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
 var g=BattleGame.new(ShipDatabase.new(),false);g.paused=true
 var gate:=int(g.hyperspace.config.unlock_stage)
 g.profile.highestLevel=gate-1
 var locked:Dictionary=await show_case(g,"01-locked-empty")
 check(not locked.text.contains("无人机") and not locked.text.contains("异空间"),"Locked empty profile reveals neither drone retention nor hyperspace resets")
 g.profile.highestLevel=gate
 var open:Dictionary=await show_case(g,"02-exploration-open")
 check(open.text.contains("异空间") and not open.text.contains("无人机"),"Exploration unlock explains resets without exposing the still-locked drone subsystem")
 g.profile.highestLevel=gate-1;g.profile.hyperspace.materials.glueball=5
 var materials:Dictionary=await show_case(g,"03-locked-with-materials")
 check(materials.text.contains("异空间") and not materials.text.contains("无人机"),"Actual materials remain disclosed below the current gate")
 g.profile.hyperspace.materials.glueball=0
 var rng=RandomNumberGenerator.new();rng.seed=12345
 var d:=Rewards.create_drone(rng,g.hyperspace.config,"retention-disclosure","blue","missile",40,Permission.planet_for_level(g.db.data,40))
 Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config)
 var drones:Dictionary=await show_case(g,"04-locked-with-drone")
 check(drones.text.contains("无人机") and drones.text.contains("未选保留"),"Actual drone candidates retain deletion warnings below the current gate")
 g.profile.hyperspace= g.hyperspace.fresh();g.profile.hyperspace.unlocked_drones=true
 var earned:Dictionary=await show_case(g,"05-drones-earned-empty")
 check(earned.text.contains("无人机"),"Previously unlocked drones keep familiar retention information")
 print("REFORGE DISCLOSURE: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
