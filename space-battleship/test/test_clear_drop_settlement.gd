extends SceneTree

const DB = preload("res://scripts/database.gd")
const GAME = preload("res://scripts/game.gd")
const MAIN = preload("res://scripts/main.gd")

func _initialize() -> void:
	var game = GAME.new(DB.new(),false)
	game.state = GAME.State.COMBAT
	game.stage = 1
	game.drops.append({"uid":101,"x":200.0,"y":200.0,"age":0.0,"id":"1","amount":100.0,"hightech":true})
	game.drops.append({"uid":102,"x":260.0,"y":200.0,"age":0.0,"id":"2","amount":40.0})
	var host = MAIN.new()
	host.game = game
	host.resource_layer = Node2D.new()
	var receipts := {}
	game.event.connect(func(kind, info):
		if kind != "collect":return
		var id := str(info.id)
		receipts[id] = int(receipts.get(id,0)) + 1
		host.on_event(kind,info))
	var before: Dictionary = game.profile.resources.duplicate(true)
	game.clear_level()
	var after: Dictionary = game.profile.resources.duplicate(true)
	var ok: bool = game.drops.is_empty() and receipts.get("1",0)==1 and receipts.get("2",0)==1
	ok = ok and float(after["1"]) > float(before["1"]) and float(after["2"]) > float(before["2"])
	ok = ok and host.resource_pickup_totals.has("1") and host.resource_pickup_totals.has("2")
	ok = ok and host.pickup_effects.size() == 2
	game.settle_drops(true)
	ok = ok and game.profile.resources == after and receipts.get("1",0)==1 and receipts.get("2",0)==1
	host.resource_layer.free()
	host.free()
	if not ok:
		printerr("CLEAR_DROPS_FAIL receipts=", receipts, " before=", before, " after=", after)
		quit(1)
		return
	print("CLEAR_DROPS_OK receipts=", receipts, " top_icons=2 effects=2 repeat=no_change")
	quit()
