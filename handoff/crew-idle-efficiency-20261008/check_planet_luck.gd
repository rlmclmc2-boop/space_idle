extends SceneTree
const Buffs = preload("res://scripts/planet_buffs.gd")
class Fixture extends RefCounted:
 var db: Dictionary
 var profile := {"planets":{}}
 func planet_progress(id: String) -> Dictionary:return profile.planets.get(id,{})
func _initialize() -> void:
 var g := Fixture.new()
 g.db={"data":JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))}
 var buffs=Buffs.new()
 assert(buffs.totals(g).hyperspace_luck==0.0)
 for id in g.db.data.planet:g.profile.planets[id]={"conquered":false}
 assert(buffs.totals(g).hyperspace_luck==0.0)
 g.profile.planets["1"].conquered=true
 assert(buffs.totals(g).hyperspace_luck==100.0)
 var before: String=JSON.stringify(g.profile)
 for i in 20:assert(buffs.totals(g).hyperspace_luck==100.0)
 assert(JSON.stringify(g.profile)==before)
 g.profile.planets["2"].conquered=true
 assert(buffs.totals(g).hyperspace_luck==200.0)
 for id in g.db.data.planet:g.profile.planets[id].conquered=true
 assert(buffs.totals(g).hyperspace_luck==600.0)
 g.db.data.planet_buff["36"].value=125
 assert(buffs.totals(g).hyperspace_luck==625.0)
 assert(buffs.description(g.db.data.planet_buff["36"])=="永久幸运 +125")
 var loaded := Fixture.new()
 loaded.db=g.db;loaded.profile=JSON.parse_string(JSON.stringify(g.profile))
 assert(buffs.totals(loaded).hyperspace_luck==625.0)
 print("planet permanent luck: inactive, conquered old-state, additive, pure reads, reload, configured description PASS")
 quit(0)
