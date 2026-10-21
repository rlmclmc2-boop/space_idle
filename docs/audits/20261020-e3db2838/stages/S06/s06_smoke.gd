extends SceneTree
const Analyzer = preload("res://scripts/fleet_result_analyzer.gd")
func _initialize() -> void:
    call_deferred("run")
func put(path: String, value: Variant) -> void:
    var file = FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.stringify(value))
func run() -> void:
    var directory = ProjectSettings.globalize_path("user://s06-minimal-analysis")
    DirAccess.make_dir_recursive_absolute(directory)
    put(directory.path_join("inputs.json"), {"enemy_fleets":[{"signature":"s06","primary_tags":[],"secondary_tags":[]}], "player_loadouts":[{"loadout_id":"p1","ship":"Frigate","tags":[],"weapons":[]}]})
    put(directory.path_join("summary.json"), {"status":"completed","completed_count":1,"aggregate":{"battle_count":1}})
    var pairs = FileAccess.open(directory.path_join("pairs.jsonl"), FileAccess.WRITE)
    pairs.store_line(JSON.stringify({"enemy_index":0,"player_index":0,"battle_count":1,"wins":1,"attempted_count":1,"avg_battle_time":1.0,"avg_player_hp_ratio":0.5,"avg_enemy_hp_ratio":0.3,"time_m2":0.0}))
    pairs.close()
    var result = Analyzer.new().analyze(directory)
    if result.has("error") or result.get("tests", -1) != 1 or result.get("level_candidates", []).size() != 1:
        printerr("S06_ANALYSIS_FAIL ", result.get("error", "unexpected report"))
        quit(1)
        return
    print("S06_ANALYSIS_PASS tests=1 candidates=1")
    quit(0)
