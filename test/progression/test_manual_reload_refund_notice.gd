extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 # Isolated unit fixture; real production charge/load/refund and UI renderer.
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI)
 root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true
 g.profile.highestLevel=8;g.profile.cleared=range(1,8);g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.hyperspace.energy=float(g.hyperspace.config.ticket)*2
 check(g.load_hyperspace_routes(),"Production routes ready")
 g.start(8,false);g.pending_unlocks.clear()
 var initial_energy:float=g.profile.hyperspace.energy
 check(g.start_hyperspace("alpha",8),"Real manual receipt starts and charges")
 var paid=g.portable_save_data();var ticket:float=paid.hyperspace.active.ticket
 check(paid.hyperspace.energy==initial_energy-ticket,"Saved started receipt contains actual debit")
 var bag=paid.hyperspace.inventory.duplicate(true);var materials=paid.hyperspace.materials.duplicate(true)
 g.load_progress_data(paid);g.resume_progress()
 check(g.profile.hyperspace.active.is_empty() and g.profile.hyperspace.energy==initial_energy,"Formal load refunds original ticket exactly once")
 check(g.profile.hyperspace.inventory==bag and g.profile.hyperspace.materials==materials,"Feedback does not alter inventory/materials")
 check(g.manual_hyperspace.last_result.get("reason")=="interrupted_reload" and g.manual_hyperspace.last_result.get("refund")==ticket,"Runtime feedback comes from actual committed refund")
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var panel=scene.hyperspace_panel;panel.refresh_progress()
 check(panel.recent_result.visible and panel.recent_result.text.contains("读档中断") and panel.recent_result.text.contains("已退票 %.0f"%ticket),"Actual home result displays interruption and exact refund")
 var result_control=panel.recent_result;var message:String=panel.recent_result.text
 var refunded_energy:float=g.profile.hyperspace.energy
 panel.refresh_progress();panel.refresh_progress()
 check(panel.recent_result==result_control and panel.recent_result.text==message and g.profile.hyperspace.energy==refunded_energy,"Repeated refresh preserves control/text without another refund")
 var settled=g.portable_save_data()
 check(not settled.has("last_result") and not settled.hyperspace.has("last_result"),"Display feedback is not saved as a refundable receipt")
 g.load_progress_data(settled);g.resume_progress();panel.refresh_progress()
 check(g.profile.hyperspace.energy==refunded_energy and g.manual_hyperspace.last_result.is_empty() and not panel.recent_result.visible,"Reading settled save again neither refunds nor repeats notice")
 check(g.request_hyperspace("alpha",8),"Unpaid request queues without charge")
 var unpaid=g.portable_save_data();g.load_progress_data(unpaid);g.resume_progress();panel.refresh_progress()
 check(g.profile.hyperspace.energy==refunded_energy and g.manual_hyperspace.last_result.is_empty() and not panel.recent_result.visible,"Reloading unpaid queue produces no refund notice")
 print("MANUAL_RELOAD_REFUND_NOTICE ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
