extends SceneTree
var fx_meter=preload("res://fx_tail_meter.gd").new()
class LiveScene extends "res://dev/diagnostics/frame_sample.gd".SampleScene:
 func blocking_reasons()->PackedStringArray:
  var reasons=super.blocking_reasons()
  if not game.stat_cache_enabled:reasons.append("正式属性缓存未开启")
  if equipment_tabs.current_tab!=0:reasons.append("请切回装备页后采样")
  return reasons
 func _process(delta:float)->void:
  var observer_started:=Time.get_ticks_usec()
  var diag=Engine.get_meta("fx_tail")
  if capture_started>0 and not previous.is_empty():previous.fx_detail=diag.snapshot()
  diag.clear()
  var observer_us:=Time.get_ticks_usec()-observer_started
  var was_capturing=capture_started>0
  super._process(delta)
  observer_started=Time.get_ticks_usec()
  diag.enabled=capture_started>0
  if capture_started>0 and not was_capturing:
   var crew_levels=[]
   for crew in game.profile.crew:crew_levels.append(int(crew.level))
   metadata.fx_build={"ship":game.profile.selectedShip,"loadout":game.profile.loadout.duplicate(true),"enhancement_level":game.profile.enhancementLevel,"branches":game.profile.enhancementBranches.duplicate(true),"crew_levels":crew_levels,"hightech_levels":game.profile.hightechLevels.duplicate(true),"stat_cache_enabled":game.stat_cache_enabled}
   metadata.fx_probe_note="FX detail is nested instrumentation. Windows mode records wall time only; do not infer GPU or thread CPU time. Observer costs are reported separately. No speed, FPS, rendering or save-policy changes."
   metadata.fx_source=JSON.parse_string(FileAccess.get_file_as_string("res://fx-provenance.json"))
  if capture_started>0 and not previous.is_empty():
   var mix={}
   var orphans=0
   for shot in game.projectiles:
    var key=("hostile:" if bool(shot.get("hostile",false)) else "own:")+str(shot.get("key",""))
    mix[key]=int(mix.get(key,0))+1
    if bool(shot.get("prototype_missile",false)) and shot.get("target",{}).is_empty():orphans+=1
   previous.projectile_mix=mix;previous.prototype_orphans=orphans
   previous.fx_observer_us=observer_us+Time.get_ticks_usec()-observer_started
func _initialize()->void:
 fx_meter.enabled=false;Engine.set_meta("fx_tail",fx_meter);call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(LiveScene)
 root.add_child(scene);current_scene=scene

func _finalize()->void:
 if Engine.has_meta("fx_tail"):Engine.remove_meta("fx_tail")
