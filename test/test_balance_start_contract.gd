extends SceneTree

const Lab = preload("res://scripts/balance_game.gd")
const Generator = preload("res://scripts/player_loadout_generator.gd")
const FleetRunner = preload("res://scripts/fleet_battle_runner.gd")
const AnalysisPanel = preload("res://scripts/fleet_analysis_panel.gd")
const Metrics = preload("res://scripts/balance_metrics.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	var db := ShipDatabase.new()
	var generator = Generator.new(db)
	var runner = FleetRunner.new(db)
	var panel = AnalysisPanel.new()
	check(generator != null and runner != null and panel != null, "Loadout, fleet runner and analysis consumers compile and instantiate")
	panel.free()
	var game = Lab.new(db)
	game.pending_hits.append({"sentinel":true})
	game.fresh_shots.append({"sentinel":true})
	check(game.start(1, false, {}, true), "Lab accepts parent's four-argument start")
	check(game.paused and game.pending_hits.is_empty() and game.fresh_shots.is_empty(), "Paused start still clears lab-owned pending shots")
	var before = [game.production_time(), game.simulated_time, game.distance, game.group_index, game.rng.state]
	game.tick(1.0)
	check(before == [game.production_time(), game.simulated_time, game.distance, game.group_index, game.rng.state], "Paused tick advances neither simulation, production, travel nor RNG")
	var checkpoint = {"state":BattleGame.State.TRAVEL, "distance":42.0, "groupIndex":0, "retreatBossPending":false}
	check(game.start(1, false, checkpoint, true) and game.paused and game.distance == 42.0, "Checkpoint and pause arguments both reach parent")
	check(game.start(1, false, checkpoint) and not game.paused and game.distance == 42.0, "Existing three-argument callers retain resume intent")
	game.profile.highestLevel = 2
	game.state = BattleGame.State.LEVEL_CLEAR
	game.pending_unlocks.clear()
	game.paused = true
	check(game.advance_after_clear() and game.stage == 2 and game.paused, "Inherited clear advance preserves pause through lab override")
	check(game.start(2, false) and not game.paused, "Existing two-argument callers resume normally")
	game.pending_hits.append({"sentinel":true})
	game.fresh_shots.append({"sentinel":true})
	check(not game.start(0, false, {}, true) and game.pending_hits.size() == 1 and game.fresh_shots.size() == 1, "Rejected start does not discard pending lab state")
	check(game.start(2, false) and game.pending_hits.is_empty() and game.fresh_shots.is_empty(), "Next accepted start clears pending lab state")
	game.metrics = Metrics.new()
	var earned = game.settle_jewel_fragments(1.5, "refund", 1.0)
	check(is_equal_approx(earned, 1.5) and is_equal_approx(game.metrics.income.jewel_fragments, earned), "Dynamic parent return remains usable by lab fragment bookkeeping")
	print("Balance start contract: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
