extends SceneTree
class FakePlanet extends RefCounted:
	signal availability_changed
	signal status_changed(ids)
	signal buildings_changed(ids)
	signal conquest_changed(ids, cumulative)
	var refinery_factor := "1.2"
	var equipment_factor := "1.5"
	func planet_options() -> Array:
		return [{"id":"1","name":"Probe"}]
	func visual_snapshot(_id: String) -> Dictionary:
		return {"row":{"name":"Probe","visual":{},"visualFacilities":[]},"running":false,"exploration":10,"elapsed":0.0,"duration":1.0}
	func conquest_facts(_id: String) -> Dictionary:
		return {"ok":true,"conquered":false,"shared_experience":false,"rewards":[]}
	func facility_facts(_id: String, _explorers: Dictionary, _builders: Dictionary) -> Array:
		var rows := []
		for kind in ["refinery", "equipment"]:
			rows.append({"id":kind,"name":kind,"type":kind,"state":"built","work":10,"required_work":10,"unlock_exploration":5,"work_fraction":1.0,"extra_crew_required":0,"source_factor":refinery_factor if kind == "refinery" else equipment_factor,"builders_present":0,"pause_reason":"","claim_allowed":false,"claim_reason":""})
		return rows
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	var fake := FakePlanet.new()
	var panel: Control = load("res://src/ui/planet_panel.gd").new(fake, Callable(), Callable(), Callable())
	root.add_child(panel)
	await process_frame
	panel._toggle_section("facilities")
	panel._process(0.01)
	var factor_label: Label = panel._factor_text
	var picker: OptionButton = panel.world_building_picker
	if factor_label == null or picker == null:
		push_error("No built factor widgets")
		quit(1)
		return
	var label_id := factor_label.get_instance_id()
	var picker_id := picker.get_instance_id()
	fake.refinery_factor = "2.5"
	panel.refresh()
	panel._process(0.01)
	if panel._factor_text.get_instance_id() != label_id or panel.world_building_picker.get_instance_id() != picker_id or not factor_label.text.contains("2.5"):
		push_error("Current factor update rebuilt drawer or missed value")
		quit(1)
		return
	panel._selected_facility = "equipment"
	panel._rebuild_drawer()
	var equipment_label: Label = panel._factor_text
	label_id = equipment_label.get_instance_id()
	picker_id = panel.world_building_picker.get_instance_id()
	fake.refinery_factor = "3.0"
	panel.refresh()
	panel._process(0.01)
	if panel._factor_text.get_instance_id() != label_id or panel.world_building_picker.get_instance_id() != picker_id or not equipment_label.text.contains("1.5"):
		push_error("Other facility factor update rebuilt selected drawer")
		quit(1)
		return
	print("PASS: current and unrelated source-factor updates preserve drawer widgets")
	quit()
