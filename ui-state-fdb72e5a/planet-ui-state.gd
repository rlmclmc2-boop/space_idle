extends SceneTree

class FakePlanet:
    extends RefCounted
    signal availability_changed
    signal status_changed(ids: Array)
    signal buildings_changed(ids: Array)
    signal conquest_changed(ids: PackedStringArray, cumulative: bool)
    var row: Dictionary
    var claims: Array = []
    var stops: Array = []
    var cancels: Array = []
    var states := {"1": "ready", "2": "ready"}
    var automatic := {"1": true, "2": true}
    var running := {"1": true, "2": true}
    var deny_claim := false
    func planet_options() -> Array:
        return [{"id":"1","name":"星球一"},{"id":"2","name":"星球二"}]
    func visual_snapshot(id: String) -> Dictionary:
        var current := row.duplicate(true)
        current["name"] = "星球" + id
        current["visualFacilities"] = []
        return {"row":current,"running":running[id],"automatic":automatic[id],"exploration":8,"elapsed":2.0,"duration":10.0}
    func facility_facts(id: String, _explorers: Dictionary, _builders: Dictionary) -> Array:
        var ready: String = str(states[id])
        var first := {"id":"station" + id,"name":"空间站","type":"auto_explore","state":ready,"work":3,"required_work":3,"work_fraction":1.0,"unlock_exploration":2,"extra_crew_required":1,"builders_present":1 if id == "1" else 0,"pause_reason":"","claim_allowed":ready == "ready" and not deny_claim,"claim_reason":"PlanetBuildingNotReady" if deny_claim else "","source_factor":null}
        var second := {"id":"forge" + id,"name":"工坊","type":"equipment","state":"building","work":1,"required_work":4,"work_fraction":0.25,"unlock_exploration":6,"extra_crew_required":1,"builders_present":0,"pause_reason":"MissingBuilders","claim_allowed":false,"claim_reason":"PlanetBuildingNotReady","source_factor":null}
        return [first,second]
    func assignment_options(ids: Array = []) -> Array:
        var id := str(ids[0])
        return [{"label":"探索 · 星球" + id,"kind":"planet_explore","group":id,"target":id}]
    func conquest_facts(_id: String) -> Dictionary:
        return {"ok":false,"reason":"PlanetConquestSourceUnavailable"}
    func claim_build(id: String, building: String, _publish: Callable) -> Dictionary:
        claims.append([id,building])
        states[id] = "built"
        buildings_changed.emit([id])
        return {"ok":true}
    func set_automatic(id: String, value: bool) -> Dictionary:
        stops.append([id,value])
        automatic[id] = value
        status_changed.emit([id])
        return {"ok":true}
    func cancel(id: String) -> Dictionary:
        cancels.append(id)
        running[id] = false
        status_changed.emit([id])
        return {"ok":true}

class FakeCrew:
    extends RefCounted
    signal members_changed(ids: Array)
    signal options_changed
    var coordinates: Array = []
    func step_assignments() -> Dictionary:
        return {"explorers":{"1":["pilot"],"2":[]},"builders":{"1:station1":["worker"],"2:station2":[]}}
    func member_options() -> Array:
        return [{"id":"worker","name":"工人"}]
    func member_facts(_ids: Array) -> Array:
        return [{"kind":"planet_build","target":"1:station1"}]
    func coordinate(member: String, kind: String, target: String) -> Dictionary:
        coordinates.append([member,kind,target])
        return {"ok":true}

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var planet := FakePlanet.new()
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/config.json"))
    planet.row = config["planet"]["planet"][0]
    var crew := FakeCrew.new()
    var panel: Control = load("res://src/ui/planet_panel.gd").new(planet, Callable(planet,"cancel"), Callable(), Callable(), Callable(), crew, Callable(crew,"coordinate"))
    panel.size = Vector2(808,900)
    root.add_child(panel)
    await process_frame
    panel._read_selected()
    panel._toggle_section("crew")
    var release: Button
    for child in panel._drawer_body.get_children():
        if child is Button and child.text == "撤回本星球人员": release = child
    assert(release != null and not release.disabled, "Accepted ready-site worker must remain withdrawable")
    release.pressed.emit()
    assert(crew.coordinates == [["worker","",""]])
    assert(panel._feedback.text == "人员已撤回")
    print("CREW_READY_WITHDRAW_OK")
    panel._toggle_section("facilities")
    assert(panel._facility_button.text == "设施 · 1待领")
    assert(panel._crew_button.text == "人员 2")
    panel._selected_facility = "forge1"
    panel._rebuild_drawer()
    assert(panel._work_text.text == "施工 1 / 4 次探索")
    assert(panel._work_bar.value == 25.0)
    assert(panel._claim_button == null)
    var pause_found := false
    for child in panel._drawer_body.get_children():
        if child is Label and child.text == "缺少额外施工人员，施工暂停": pause_found = true
    assert(pause_found)
    print("BUILDING_PROGRESS_AND_PAUSE_OK")
    panel._selected_facility = "station1"
    panel._rebuild_drawer()
    assert(panel._claim_button != null and not panel._claim_button.disabled)
    panel._claim_button.pressed.emit()
    assert(planet.claims == [["1","station1"]])
    assert(panel._feedback.text == "设施已领取")
    print("CLAIM_ID_AND_FEEDBACK_OK")
    panel._read_selected()
    assert(panel._facility_button.text == "设施")
    assert(panel._claim_button == null)
    print("BUILT_STATE_REBINDS_OK")
    planet.deny_claim = true
    panel.select_planet("2")
    assert(panel._feedback.text == "")
    assert(panel._selected_facility == "station2")
    assert(panel._crew_button.text == "人员 0")
    assert(panel._facility_button.text == "设施 · 1待领")
    assert(panel._claim_button.disabled)
    planet.deny_claim = false
    panel._read_selected()
    assert(not panel._claim_button.disabled)
    panel._claim_button.pressed.emit()
    assert(planet.claims == [["1","station1"],["2","station2"]])
    print("OWNER_CLAIM_ADMISSION_OK")
    print("SWITCH_REBINDS_CLAIM_OK")
    panel._stop_button.pressed.emit()
    assert(planet.stops == [["2",false]])
    assert(panel._feedback.text == "本次完成后停止自动探索")
    panel._read_selected()
    assert(not panel._stop_button.visible and panel._cancel_button.visible)
    panel._cancel_button.pressed.emit()
    assert(planet.cancels == ["2"])
    assert(panel._feedback.text == "已取消本次探索")
    panel._read_selected()
    assert(not panel._cancel_button.visible and panel._task_button.text == "探索 · 未派遣")
    print("STOP_CANCEL_CURRENT_ID_OK")
    quit()
