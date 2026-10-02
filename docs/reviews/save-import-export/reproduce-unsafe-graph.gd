extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var db:=ShipDatabase.new()
 var transfer:=preload("res://scripts/save_transfer.gd").new()
 var demo: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SAVE_TRANSFER_DEMO")))
 for kind in ["edge", "type"]:
  var raw:=demo.duplicate(true)
  var data: Dictionary=raw.galaxies.galaxy_1
  if kind=="edge":data.blueprint.edges[0].to="node_999"
  else:
   data.blueprint.nodes[0].type="unknown_construct"
   data.blueprint.nodes[0].planned_type="unknown_construct"
   data.slots[0].type="unknown_construct"
  var prepared: Dictionary=transfer.prepare_data(raw,db)
  print("UNSAFE "+kind+" accepted before confirmation: "+str(prepared.error.is_empty()))
  if not prepared.error.is_empty():continue
  var game:=BattleGame.new(db,false);game.load_progress_data(prepared.data)
  var region=game.galaxy.regions.galaxy_1
  if kind=="edge":
   var transit:=preload("res://scripts/galaxy_transit.gd").new();root.add_child(transit)
   transit.rebuild(region.layout_snapshot());transit.queue_free()
  else:
   var map:=preload("res://scripts/galaxy_map.gd").new();map.region=region
   map.fit_size();map.free()
 await process_frame
 quit()
