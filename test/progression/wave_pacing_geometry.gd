extends SceneTree
## Actual scene footprint audit, including caption/protection and independent yaw.
## Coordinate overrides are explicitly declared in the private request, never progression evidence.
const Game=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
func _initialize():call_deferred("run")
func run():
 var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_PACING_GEOMETRY")))
 var p:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(r.save))
 var raw:Dictionary=p.save.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system()
 var g=Game.new(ShipDatabase.new());g.load_progress_data(raw);g.resume_progress();g.paused=true;g.rng.state=int(str(p.rng_state))
 var driver=Driver.new();driver.setup(self,g)
 await process_frame;await process_frame
 if g.event.is_connected(driver.scene.on_event):g.event.disconnect(driver.scene.on_event)
 var result=[];var failed=false
 for wave in r.get("waves",[6,7,8,9]):
  g.stage=14;g.group_index=int(wave)-1;g.spawn_group()
  var override:Dictionary=r.get("positions",{}).get(str(wave),{})
  for e in g.enemies:
   if override.has(str(e.slot)):
    var pos=override[str(e.slot)];e.x=float(pos[0]);e.y=float(pos[1])
  driver.scene.enemy_poses.clear();driver.scene.fx_time=0.0
  var errors=driver.scene.validate_explicit_formation()
  result.append({"wave":wave,"errors":errors,"actors":g.enemies.map(func(e):return {"slot":e.slot,"id":e.id,"size":e.size,"x":e.x,"y":e.y})})
  failed=failed or not errors.is_empty()
 FileAccess.open(r.output,FileAccess.WRITE).store_string(JSON.stringify({"data_sha256":FileAccess.get_sha256("res://data/game_data.json"),"script_sha256":FileAccess.get_sha256(get_script().resource_path),"request":r,"result":result,"scope":"Actual rendering footprint audit at7 animation samples and independent yaw extremes; explicit coordinate hypotheses only if requested. No combat ticks or balance/duration acceptance."},"\t"))
 print("PACING_GEOMETRY ","FAIL" if failed else "PASS"," ",result.map(func(x):return {"wave":x.wave,"errors":x.errors.size()}))
 driver.close();quit(1 if failed else 0)
