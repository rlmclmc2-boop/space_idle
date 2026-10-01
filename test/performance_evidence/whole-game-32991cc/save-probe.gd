extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 g.profile.cleared=range(1,101);g.profile.highestLevel=101;g.profile.resources={"1":1e80,"2":1e80}
 g.profile.selectedShip="Heavy_Battleship";g.profile.enhancementLevel=30;g.profile.jewelFragments=1e40
 for crew in g.profile.crew:crew.level=103;crew.exp=13159583000.0
 for p in g.profile.planets.values():p.conquered=true
 g.rebuild_unlocks();g.galaxy.refresh_unlocks(g)
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://galaxy_fixture.json"))
 g.galaxy.load_state(g,{"galaxy_1":fixture.save})
 g.save_enabled=true
 var samples=[]
 for i in 8:
  var began=Time.get_ticks_usec();g.save_progress();samples.append(Time.get_ticks_usec()-began)
  assert(g.last_save_error==OK)
 print("SAVE_IO ",JSON.stringify({"samples_us":samples,"bytes":FileAccess.get_file_as_bytes(BattleGame.SAVE_PATH).size(),"scope":"8 explicit manual saves, synthetic crew103/high-balance/30-buildings, isolated Linux storage"}))
 quit()
