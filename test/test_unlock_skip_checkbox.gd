extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
 checks += 1
 if not value: failures += 1; printerr("FAIL: ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var scene = load("res://main.tscn").instantiate()
 scene.automation_args = ["--capture"]
 root.add_child(scene)
 scene.set_process(false)
 scene.game.save_enabled = false
 scene.set_tutorial_auto_skip(false)
 scene.game.paused = false
 var keys: Array = scene.db.data.unlock.keys()
 scene.game.pending_unlocks.assign([str(keys[0]),str(keys[1])])
 scene.refresh_navigation()
 await process_frame
 check(scene.unlock_skip_checkbox.visible,"Checkbox visible on unlock panel")
 check(scene.unlock_skip_checkbox.text == "跳过","Short label")
 check(not scene.unlock_skip_checkbox.button_pressed,"Defaults unchecked")
 check(scene.game.paused,"Manual reading holds game")
 scene.unlock_notice_started_ms = Time.get_ticks_msec()-9000
 scene.unlock_skip_checkbox.button_pressed = true
 var start: int = scene.unlock_notice_started_ms
 check(Time.get_ticks_msec()-start<100,"Enabling resets expired timer")
 check(scene.tutorial_auto_skip and scene.tutorial_skip_button.button_pressed,"Help and unlock settings synchronized")
 scene.advance_unlock_notice(start+2999)
 check(scene.game.pending_unlocks.size()==2,"No skip before 3 seconds")
 scene.advance_unlock_notice(start+3000)
 check(scene.game.pending_unlocks.size()==1,"Exactly one page after 3 seconds")
 var second: int = scene.unlock_notice_started_ms
 scene.advance_unlock_notice(second+2999)
 check(scene.game.pending_unlocks.size()==1,"Next page has full interval")
 scene.unlock_skip_checkbox.button_pressed = false
 scene.advance_unlock_notice(second+9000)
 check(scene.game.pending_unlocks.size()==1 and scene.game.paused,"Uncheck cancels timer and holds notice")
 scene.game.acknowledge_unlocks()
 scene.refresh_navigation()
 check(not scene.unlock_skip_checkbox.visible,"Checkbox hidden without notice")
 check(not scene.game.paused,"Prior pause restored")
 print("unlock skip checkbox: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
