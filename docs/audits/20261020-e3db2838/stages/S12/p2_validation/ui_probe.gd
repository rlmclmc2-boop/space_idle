extends SceneTree
const L=preload("res://scripts/currency_ledger.gd")
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		printerr("P2_FAIL ",label)
		quit(1)
		assert(false,label)
func _initialize()->void:
	Engine.max_fps=60
	call_deferred("_run")
func _run()->void:
	var loaded:int=GDExtensionManager.load_extension("res://space_native.gdextension")
	check(loaded in [0,2],"UI DLL loaded")
	var scene:PackedScene=load("res://main.tscn")
	var actor=scene.instantiate()
	root.add_child(actor)
	current_scene=actor
	actor.automation_args.erase("--capture")
	var game=actor.game
	game.paused=true
	game.state=game.State.RETREAT
	game.profile.highestLevel=int(game.hyperspace.config.unlock_stage)
	game.profile.resources["1"]={"m":1.0,"e":3800.0}
	game.profile.hyperspace.materials[game.db.evolution_material_id()]=9007199254740991
	game.profile.loadout.weapons[0].key="laser"
	game.profile.loadout.weapons[0].level=1
	actor.build_ui()
	actor.select_system(0)
	await process_frame
	var panel=actor.equipment_panel
	panel.set_upgrade_amount(0)
	var item_id:String=panel.module_card_id("weapons",0)
	check(panel.items.has(item_id),"actual equipment card exists")
	var request_id:int=int(panel._max_ui_requests["weapons:0"])
	var outcome=game.poll_max_upgrade(request_id)
	while outcome.status=="pending":
		await process_frame
		game.currency_income("1",1)
		panel.refresh_pending()
		outcome=game.poll_max_upgrade(request_id)
	check(outcome.status=="complete" and outcome.quote.count==47959,"actual UI pending becomes quote")
	check(panel.items[item_id].direct_upgradeable and panel.items[item_id].cost.begins_with("约 "),"actual UI approximate label")
	var before=L.decode(game.profile.resources["1"])
	panel.upgrade_card(item_id)
	check(L.compare(before.value,L.decode(game.profile.resources["1"]).value).order==0,"opening confirmation has no debit")
	var dialog:ConfirmationDialog
	for child in actor.get_children():
		if child is ConfirmationDialog and child.visible:
			dialog=child
			break
	check(dialog!=null,"actual MAX confirmation dialog")
	if OS.get_cmdline_user_args().has("--gpu"):
		await process_frame
		RenderingServer.force_draw()
		var image:Image=root.get_texture().get_image()
		check(not image.is_empty(),"GPU UI image")
		image.save_png("user://p2-ui-max.png")
	dialog.confirmed.emit()
	await process_frame
	check(game.profile.loadout.weapons[0].level==47960,"actual dialog confirmed purchase")
	var fee=L.decode(outcome.quote.resource_debit["1"])
	var debit=L.subtract(before.value,L.decode(game.profile.resources["1"]).value)
	check(L.compare(debit.value,fee.value).order==0,"actual dialog debit equals preview")
	game.shutdown_equipment_queries()
	actor.queue_free()
	await process_frame
	await process_frame
	print("P2_UI_COMPLETE checks=",checks)
	quit(0)

