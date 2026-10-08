extends SceneTree
const Crew = preload("res://scripts/crew_system.gd")
class Fixture extends RefCounted:
 var db: Dictionary
 var profile := {"crew":[{"crewId":"navigator","level":0}]}
 var levels := true
 var gate := true
 func content_unlocked(_type: String, _id: String) -> bool:return levels
 func unlock_available(_id: String) -> bool:return gate
func _initialize() -> void:
 var g := Fixture.new()
 g.db={"data":JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))}
 var crew= Crew.new()
 var k: float=g.db.data.crew_config.hyperspace_duration_k.value
 for level in [0,1,10,20,2000000,1000000000,9000000000000000000]:
  g.profile.crew[0].level=level
  var actual: float=crew.hyperspace_efficiency(g,"navigator")
  var expected: float=(k+float(level))/k
  assert(is_finite(actual) and actual>=1.0)
  assert(absf(actual/expected-1.0)<1e-12)
  var duration: float=60.0/actual
  assert(duration>0.0)
  if level>=1000000:assert(duration<0.001)
 g.profile.crew[0].level=20
 assert(crew.hyperspace_efficiency(g,"navigator")==(k+20.0)/k)
 g.db.data.crew_config.hyperspace_duration_k.value=40.0
 assert(crew.hyperspace_efficiency(g,"navigator")==1.5)
 g.levels=false
 assert(crew.hyperspace_efficiency(g,"navigator")==1.0)
 g.levels=true;g.gate=false
 assert(crew.hyperspace_efficiency(g,"navigator")==1.0)
 assert(crew.hyperspace_efficiency(g,"unknown")==1.0)
 g.gate=true;g.profile.crew[0].level=100
 assert(crew.hyperspace_luck(g,"navigator")==100.0)
 g.db.data.crew_config.hyperspace_luck_per_level.value=2.0
 assert(crew.hyperspace_luck(g,"navigator")==200.0)
 g.db.data.crew_config.hyperspace_luck_per_level.value=0.0
 assert(crew.hyperspace_luck(g,"navigator")==0.0)
 g.db.data.crew_config.hyperspace_luck_per_level.value=1.0
 g.profile.crew[0].level=9000000000000000000
 assert(is_finite(crew.hyperspace_luck(g,"navigator")))
 g.levels=false
 assert(crew.hyperspace_luck(g,"navigator")==0.0)
 g.levels=true;g.gate=false
 assert(crew.hyperspace_luck(g,"navigator")==0.0)
 assert(crew.hyperspace_luck(g,"unknown")==0.0)
 print("crew hyperspace efficiency + luck: live K, alternate K, gates, extreme levels PASS")
 quit(0)
