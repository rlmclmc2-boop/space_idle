extends SceneTree
## Isolated in-memory UI fixture; no player save is read or written.
class IsolatedUI extends "res://scripts/battlefield.gd":
	var writes:Array=[]
	func set_ui_value(control: Object, property: StringName, value: Variant) -> void:
		if control.get(property)!=value:writes.append([control,property,control.get(property),value])
		super.set_ui_value(control,property,value)
	func create_battle_game(_persist: bool) -> BattleGame:
		return super.create_battle_game(false)
	func show_qa_tools() -> void:pass
const PANEL := preload("res://scripts/ship_panel.gd")
const LAYOUT := preload("res://dev/toon_ship/hybrid_layout.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(label)
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHIP_PREVIEW_EVIDENCE")+"/"+name+".png")
func run() -> void:
	var scene = load("res://main.tscn").instantiate()
	scene.set_script(IsolatedUI)
	root.add_child(scene)
	current_scene=scene
	scene.automation_args=[]
	scene.set_process(false)
	scene.music.stop();scene.music.stream=null
	scene.game.save_enabled=false
	scene.game.paused=true
	scene.game.pending_unlocks.clear()
	scene.game.profile.cleared=range(1,90)
	scene.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	scene.game.profile.resources={"1":1e28,"2":1e28}
	scene.game.profile.onboarding.completed=true
	scene.game.switch_ship("Heavy_Battleship")
	var types := ["laser","missile","cannon","longLaser"]
	for i in scene.game.weapon_entries().size():scene.game.weapon_entries()[i].key=types[i%types.size()]
	scene.equipment_tabs.current_tab=3
	if DisplayServer.get_name()!="headless":
		await process_frame
		root.size=Vector2i(1180,812)
		scene.set_process(true)
	await process_frame
	var panel: Control=scene.ship_controls.page
	check(panel.find_children("*","SubViewport",true,false).is_empty(),"No live preview viewport")
	panel.candidate="Heavy_Battleship"
	panel.refresh()
	var before: String=JSON.stringify(scene.game.profile)
	for key in scene.db.ships:
		before=JSON.stringify(scene.game.profile)
		panel.choices[key].pressed.emit()
		check(JSON.stringify(scene.game.profile)==before,"Candidate remains read-only: "+str(key))
		check(panel.choice_capacities[key].text==UIText.t("ship.refit.capacity_summary",{"weapons":str(scene.game.active_slot_count("weapons",key)),"defence":str(scene.game.active_slot_count("defence",key))}) and panel.choice_capacities[key].get_line_count()==2 and panel.choice_capacities[key].get_visible_line_count()==2,"Both capacity counts remain visible: "+str(key))
		check(panel.picture.texture==PANEL.hull_texture(key),"Actual toon snapshot: "+str(key))
		check(PANEL.preview_data.hulls[key].model==scene.ship_view.manifest.hulls[key].path,"Live GLB source: "+str(key))
		var assignment: Array=LAYOUT.assign(scene.game.weapon_entries(),scene.game.active_slot_count("weapons",key),PANEL.preview_data.hulls[key].mounts.size())
		var hull_slots:Array=[]
		for item in assignment:
			var id:String=scene.game.slot_id("weapons",int(item.slot))
			var button:Button=panel.mounts[id]
			check(button.get_meta("slot_id")==id,"Real slot identity: "+id)
			check(button.disabled==(key!="Heavy_Battleship"),"Current and candidate actions distinct: "+id)
			if item.carrier=="hull":
				hull_slots.append(int(item.slot))
				check(button.get_parent()==panel.preview,"Hull slot follows live assignment: "+id)
				check(panel.picture.get_rect().has_point(button.position+button.size/2),"Hull label stays inside preview: "+id)
			else:check(button.get_parent()==panel.mount_lists.weapons and button.text.contains(UIText.t("ship.refit.carrier")),"Carrier slot stays in bounded list: "+id)
		for id in panel.mounts:
			var category: String = str(id).get_slice("_",0)
			var expected_visible: bool = int(str(id).get_slice("_",1)) < scene.game.active_slot_count(category,key)
			check(panel.mounts[id].visible == expected_visible,"Only candidate capacity is visible: "+str(key)+" "+str(id))
		check(not panel.result.text.contains(UIText.t("equipment.state.locked")),"No dormant summary: "+str(key))
		check(hull_slots.size()==mini(assignment.size(),PANEL.preview_data.hulls[key].mounts.size()),"No capacity invented: "+str(key))
		check(panel.confirm.text==UIText.t("ship.refit.current" if key=="Heavy_Battleship" else "ship.refit.apply"),"Explicit activation: "+str(key))
		await capture(str(key)+("-current" if key=="Heavy_Battleship" else "-candidate"))
	# Sparse occupied slots must follow live visual compaction without being renumbered.
	panel.candidate="Heavy_Battleship"
	scene.game.weapon_entries()[0].key=""
	panel.refresh()
	check(panel.mounts.weapons_0.get_parent()==panel.mount_lists.weapons,"Empty logical slot stays empty in list")
	var p:Array=PANEL.preview_data.hulls.Heavy_Battleship.mounts[0]
	var expected:Vector2=panel.picture.position+Vector2(p[0],p[1])*panel.picture.size.x/float(PANEL.preview_data.canvas[0])
	check((panel.mounts.weapons_1.position+panel.mounts.weapons_1.size/2).distance_to(expected)<0.1,"W02 takes first actual socket without becoming W01")
	await capture("Heavy_Battleship-sparse-current")
	scene.game.weapon_entries()[0].key="laser"
	panel.candidate="Frigate"
	panel.refresh()
	await process_frame
	panel.mount_scroll.scroll_vertical=9999
	await process_frame
	check(panel.mount_scroll.scroll_vertical==0,"Unavailable rows take no space in the compact list")
	var scroll:int=panel.mount_scroll.scroll_vertical
	var mounts:Dictionary=panel.mounts.duplicate()
	panel.refresh()
	scene.writes.clear()
	panel.refresh()
	check(scene.writes.is_empty(),"Unchanged ship refresh performs no property writes")
	check(panel.mount_scroll.scroll_vertical==scroll,"Unchanged refresh preserves scroll")
	for id in mounts:check(is_same(mounts[id],panel.mounts[id]),"Unchanged refresh retains button "+id)
	await capture("Frigate-candidate-compact")
	panel.confirm.pressed.emit()
	check(scene.game.profile.selectedShip=="Frigate","Only explicit activation switches hull")
	panel.mounts.weapons_1.pressed.emit()
	await process_frame
	check(scene.equipment_tabs.current_tab==0 and scene.equipment_panel.selected=="weapons_1","Exact hull slot opens exact equipment module")
	scene.equipment_tabs.current_tab=3
	await process_frame
	panel.mount_scroll.scroll_vertical=0
	var fresh_cleared:Array=scene.game.profile.cleared
	scene.game.profile.cleared=[]
	panel.candidate="Heavy_Battleship"
	panel.refresh()
	check(panel.picture.material==panel.silhouette and not panel.confirm.visible and not panel.mount_scroll.visible,"Locked hull stays silhouette without actions")
	check(not panel.choice_titles.Heavy_Battleship.visible and panel.locked_labels.Heavy_Battleship.visible,"Locked choice retains gate-only semantics")
	await capture("Heavy_Battleship-locked")
	scene.game.profile.cleared=fresh_cleared
	panel.candidate="Heavy_Battleship"
	panel.refresh()
	check(panel.mounts.weapons_4.get_parent()==panel.preview and panel.mounts.weapons_7.text.contains(UIText.t("ship.refit.carrier")),"Larger candidate previews stored dormant modules using its capacity")
	panel.candidate="Frigate"
	panel.refresh()
	# Switching to a smaller active hull must not turn a dormant preview slot into a drone ID.
	check(scene.game.switch_ship("Destroyer"),"Activate four-slot hull for preview transition")
	scene.game.module_entry("weapons",3).key="missile"
	scene.game.module_entry("weapons",3).level=107
	panel.candidate="Destroyer"
	panel.refresh()
	check(scene.game.switch_ship("Frigate"),"Activate three-slot hull for preview transition")
	panel.candidate="Destroyer"
	var smaller_profile := JSON.stringify(scene.game.profile)
	panel.refresh()
	var fourth_rows := 0
	for child in panel.mount_lists.weapons.get_children():
		if child is Button and child.visible and child.text.begins_with("W04"):fourth_rows+=1
	check(fourth_rows==1,"Four-slot candidate has exactly one W04 row after activating three-slot hull")
	check(panel.mounts.weapons_3.get_meta("slot_id")=="weapons_3" and panel.mounts.weapons_3.disabled,"Dormant W04 retains module identity and read-only preview")
	var fourth_card := false
	for card in panel.drone_cards:
		if card.visible and card.get_meta("slot_id","")=="weapons_3":fourth_card=true
	check(fourth_card,"Companion preview card retains the same permanent W04 identity")
	check(JSON.stringify(scene.game.profile)==smaller_profile,"Candidate refresh does not activate or change stored modules")
	panel.candidate="Frigate"
	panel.refresh()
	var cached:Texture2D=panel.picture.texture
	scene.equipment_tabs.current_tab=0
	await process_frame
	scene.equipment_tabs.current_tab=3
	await process_frame
	check(panel.candidate=="Frigate" and panel.picture.texture==cached,"Hide/reveal retains candidate and cached texture")
	check(not scene.game.save_enabled,"Fixture never saves")
	for path in PANEL.preview_data.source_sha256:
		check(FileAccess.get_sha256(path)==PANEL.preview_data.source_sha256[path],"Baked source fingerprint: "+str(path))
	check(PANEL.preview_textures.size()==5,"Exactly five cached textures, no preview rendering loop")
	print("Ship preview: %d checks, %d failures"%[checks,failures])
	if "--interactive" in OS.get_cmdline_user_args():
		panel.candidate="Heavy_Battleship"
		panel.refresh()
		scene.set_process(true)
		await capture("interactive-ready")
	else:
		scene.queue_free()
		await process_frame
		quit(1 if failures else 0)

func _process(_delta: float) -> bool:
	var output:=OS.get_environment("SHIP_PREVIEW_EVIDENCE")
	if output.is_empty():return false
	var request := output+"/request.txt"
	if not is_instance_valid(current_scene) or not FileAccess.file_exists(request):return false
	var label:String=FileAccess.get_file_as_string(request).strip_edges().validate_filename()
	DirAccess.remove_absolute(request)
	capture_input.call_deferred(label)
	return false
func capture_input(label:String) -> void:
	await capture(label)
	var scene=current_scene
	var panel:Control=scene.ship_controls.page
	var file:=FileAccess.open(OS.get_environment("SHIP_PREVIEW_EVIDENCE")+"/"+label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixture":"in-memory synthetic, normal main scene with persistence/QA-window overrides only","root_size":[root.size.x,root.size.y],"candidate":panel.candidate,"active_ship":scene.game.profile.selectedShip,"tab":scene.equipment_tabs.current_tab,"equipment_selected":scene.equipment_panel.selected,"save_enabled":scene.game.save_enabled,"mount_scroll":panel.mount_scroll.scroll_vertical},"  ")+"\n")
