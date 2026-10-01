extends SceneTree

class ObservedPanel extends "res://scripts/reactor_panel.gd":
	var refreshes := 0
	func page_active() -> bool:return true
	func refresh_animation_state() -> void:pass
	func refresh() -> void:
		refreshes+=1
		dirty=false
		refresh_elapsed=0.0
class Host extends Node:
	var game: BattleGame

var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(label)
func _initialize() -> void:
	var host := Host.new()
	host.game=BattleGame.new(ShipDatabase.new(),false)
	host.game.paused=false
	host.game.speed=1.0
	var panel := ObservedPanel.new()
	panel.host=host
	panel.refresh()
	panel.invalidate()
	panel.refresh_pending(0.25)
	check(panel.refreshes==1,"Automatic UI refresh waits one game second, not 0.2 seconds")
	panel.refresh_pending(0.74)
	check(panel.refreshes==1,"Automatic UI refresh remains pending before its deadline")
	panel.refresh_pending(0.01)
	check(panel.refreshes==2,"Automatic UI refresh reaches one game second")
	host.game.speed=2.0
	panel.invalidate()
	panel.refresh_pending(0.25)
	check(panel.refreshes==2,"Accelerated UI refresh waits half the game-second budget")
	panel.invalidate()
	panel.refresh_pending(0.25)
	check(panel.refreshes==3,"Repeated change retains first game-second deadline")
	panel.invalidate()
	host.game.paused=true
	panel.refresh_pending(2.0)
	check(panel.refreshes==3,"Pause freezes automatic game-time refresh budget")
	panel.refresh()
	check(panel.refreshes==4 and not panel.dirty,"Explicit manual/reveal refresh remains immediate while paused")
	panel.free()
	host.free()
	print("REACTOR DIRTY DEADLINE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
