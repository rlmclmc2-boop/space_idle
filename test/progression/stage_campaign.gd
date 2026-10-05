extends "res://qa/hyperspace_longrun.gd"
## Short native P2 policy continuation, with optional decision-only UI refresh.
const Meter=preload("res://qa/stage_meter.gd")
var stage_variant:=""
var configured:=false
func run()->void:
 stage_variant=OS.get_environment("QA_STAGE_MODE")
 if stage_variant not in ["full","decision-ui","cached"]:printerr("Unknown native stage mode");quit(2);return
 var cached_scene:String="res://qa/vfx_probe_battlefield.tscn" if OS.get_environment("QA_STAGE_VFX_PROBE")=="1" else "res://qa/cached_battlefield.tscn"
 OS.set_environment("QA_STAGE_SCENE",cached_scene if stage_variant=="cached" else "")
 stage_meter=Meter.new()
 await super.run()
func refresh_decision_ui()->void:
 if stage_variant=="full":return
 driver.scene.refresh_visible_cards(0.0);driver.scene.refresh_navigation()
 if is_instance_valid(driver.scene.enhancement_panel) and driver.scene.enhancement_panel.visible:driver.scene.enhancement_panel.refresh()
func action()->Dictionary:
 refresh_decision_ui()
 return super.action()
func click_button(choice:Dictionary)->void:
 refresh_decision_ui()
 if stage_variant!="full":await process_frame
 await super.click_button(choice)
func step_controller()->void:
 if not configured:
  driver.ui_refresh_seconds=3600.0 if stage_variant!="full" else 0.0
  driver.drop_post_vfx=stage_variant=="cached"
  stage_meter.begin(output,stage_variant,game);configured=true
 await super.step_controller()
