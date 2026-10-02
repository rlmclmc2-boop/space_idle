extends SceneTree
const XLSX=preload("res://scripts/mon_group_xlsx.gd")
var checks:=0
func check(value:bool,label:String):
 checks+=1
 assert(value,label)
func _initialize():call_deferred("run")
func run():
 var db:=ShipDatabase.new()
 var game:=BattleGame.new(db,false)
 for slot in 10:
  check(BattleGame.enemy_slot_position(slot)==Vector2(66.0+slot*440.0/9.0,140.0),"legacy ten-slot coordinate")
 for group_id in [1002,1009,1017,1019]:
  db.levels[0].groups=[{"id":group_id,"position":0.0},{"id":group_id,"position":0.99}]
  game.start(1,false);game.spawn_group()
  var positions:Dictionary={}
  for enemy in game.enemies:
   var slot:=int(enemy.slot)
   check(enemy.formation_columns==5,"new five-column flag")
   check(Vector2(enemy.x,enemy.y)==Vector2(66+slot%5*110,94+(slot/5)*144),"row/column combat position")
   check(not positions.has(Vector2(enemy.x,enemy.y)),"one entity per position")
   positions[Vector2(enemy.x,enemy.y)]=true
 var names:Dictionary={}
 for id in db.enemies:names[id]=db.enemies[id].des
 var old_id:=str(db.groups.keys()[0])
 var stages:Array=[{"enemy_group":int(old_id),"group_data":db.groups[old_id]}, {"enemy_group":1002,"group_data":db.groups["1002"]}]
 check(XLSX.export_groups(stages,"res://grid-export.xlsx",db.enemies,names)=="","mixed ten/fifteen-slot workbook export")
 stages[1].group_data=stages[1].group_data.duplicate(true)
 stages[1].group_data.slots.append(null)
 check(XLSX.export_groups(stages,"res://invalid-grid-export.xlsx",db.enemies,names)=="invalid_group","sixteen-slot workbook rejection")
 var scene=load("res://main.tscn").instantiate()
 scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false);scene.game.save_enabled=false
 scene.game.profile.selectedShip="Destroyer"
 scene.game.profile.loadout=scene.game.empty_loadout("Destroyer");scene.game.reset_player()
 for id in [1002,1009,1017,1019]:
  scene.db.levels[0].groups=[{"id":id,"position":0.0}]
  if id<1017:scene.db.levels[0].groups.append({"id":id,"position":0.99})
  scene.game.start(1,false);scene.game.spawn_group();scene.enemy_poses.clear();scene.fx_time=4.0
  for enemy in scene.game.enemies:scene.enemy_pose(enemy).born=0.0
  for enemy in scene.game.enemies:
   var position:Vector2=scene.enemy_render_position(enemy)
   var row:=int(enemy.slot)/5
   check(absf(position.y-(94.0+row*144.0))<65.0,"render keeps all three row centers")
   check(position.y<=scene.enemy_frontline_y_limit(enemy),"player hull clearance retained")
  if DisplayServer.get_name()!="headless":
   scene.battle_layer.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://grid-"+str(id)+".png")
 scene.queue_free();await process_frame;scene=null
 print("Enemy grid: ",checks," checks passed")
 quit()
