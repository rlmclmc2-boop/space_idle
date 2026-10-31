extends SceneTree
var app
var host
var panel
var failures: Array=[]
var records: Array=[]
const OUT="/tmp/space-idle-workbench-rebuild/empty-centering/"
func _initialize() -> void:
    call_deferred("run")
func check(value: bool, message: String) -> void:
    if not value:failures.append(message);printerr("FAIL: ",message)
func flush() -> void:
    for i in 5:await process_frame
    await RenderingServer.frame_post_draw
func click(button: Control) -> void:
    var position: Vector2=button.get_global_rect().get_center()
    var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=position;event.global_position=position;event.pressed=true
    Input.parse_input_event(event);await process_frame
    event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=position;event.global_position=position;event.pressed=false
    Input.parse_input_event(event);await flush()
func state() -> Dictionary:
    return {"slots":host.equipment_slot_facts(),"wallet":host.economy.budget().duplicate(true),"running":host.run_state.is_running(),"selected":panel._selected,"last_result":panel.last_result.duplicate(true)}
func wallet(iron: String, material: String) -> void:
    var value: Dictionary=host.economy.save_state()
    value.wallet={"1":host.amount_api.apply("from_decimal",[iron]).value,"2":host.amount_api.apply("from_decimal",["1000"]).value,"degenerate_matter":host.amount_api.apply("from_decimal",[material]).value}
    check(host.economy.restore_state(value).ok,"controlled wallet validates")
    host.economy.publish_budget_change()
func shot(name: String) -> void:
    await flush();root.get_texture().get_image().save_png(OUT+name+".png")
func button_with_equipment(node: Node, id: String) -> Button:
    if node is Button and node.has_meta("equipment_id") and str(node.get_meta("equipment_id"))==id:return node
    for child in node.get_children():
        var found: Button=button_with_equipment(child,id)
        if found!=null:return found
    return null
func find_text_button(node: Node, caption: String) -> Button:
    if node is Button and node.text==caption:return node
    for child in node.get_children():
        var found: Button=find_text_button(child,caption)
        if found!=null:return found
    return null
func find_batch_mode(node: Node) -> Button:
    for caption in ["每槽 ×1","每槽 ×10","逐槽 MAX"]:
        var found: Button=find_text_button(node,caption)
        if found!=null:return found
    return null
func check_cards(label: String) -> void:
    var cards: Array=[]
    for fact in panel._active:
        var row: Dictionary=panel._cards[str(fact.id)]
        var empty: bool=str(fact.equipment_id).is_empty()
        var top: float=row.select.position.y
        var bottom: float=row.panel.size.y-row.select.position.y-row.select.size.y
        if empty:check(is_equal_approx(top,14.0) and is_equal_approx(bottom,10.0),label+" empty picker optical offset for actual painted inner face "+str(fact.id))
        else:check(is_equal_approx(top,10.0),label+" installed header unchanged "+str(fact.id))
        cards.append({"slot":fact.id,"empty":empty,"visible":row.panel.visible,"card":row.panel.get_global_rect(),"select":row.select.get_global_rect(),"top_gap":top,"bottom_gap":bottom})
    records.append({"case":label,"cards":cards,"wallet":host.economy.budget(),"slots":host.equipment_slot_facts()})
func run() -> void:
    root.size=Vector2i(1440,900);root.position=Vector2i.ZERO
    app=load("res://src/main.tscn").instantiate();root.add_child(app);host=app.session;panel=app.equipment_scene
    check(app.startup_error.is_empty(),"real main/native/config startup")
    if host==null:quit(1);return
    host.set_pause("user",true);await flush();await click(app._zone_shell._route_buttons["equipment"])
    var campaign: Dictionary=host.campaign_system.save_state()
    campaign.state.highest_reached=100;campaign.cycle_reached=100;campaign.state.state="menu";campaign.departure_remaining=0.0;campaign.state.speed=0.0;campaign.state.cleared_stages={}
    for stage in range(1,100):campaign.state.cleared_stages[stage]=true
    check(host.campaign_system.restore_state(campaign).ok,"controlled progress")
    host.equipment.refresh_availability(host.campaign_system.available,100)
    check(host.campaign_system.change_ship("Cruiser",host.commit_ship_refit).ok,"real middle refit")
    await flush();check_cards("middle empty slots");await shot("01-middle-empty-centered")
    var before: Dictionary=state()
    await click(panel._cards["weapon:1"].select)
    var option: Button=button_with_equipment(panel._popup,"missile")
    check(option!=null,"real empty picker offers unlocked missile")
    if option!=null:await click(option)
    check(panel.last_result.get("ok",false) and host.economy.budget()==before.wallet,"real free install")
    check_cards("middle installed header restored");await shot("02-middle-mixed-installed")
    var returned: Dictionary=host.equipment.equip_slot("weapon:1","",host.equipment_inputs(),host.publish_equipment_refit)
    panel._accept_result(returned,false);await flush()
    check(returned.get("ok",false) and host.economy.budget()==before.wallet,"real Owner immediate free return empty; no UI unload option claimed")
    check_cards("middle returned empty");await shot("03-middle-return-empty")
    check(host.campaign_system.change_ship("Heavy_Battleship",host.commit_ship_refit).ok,"real heavy refit")
    await flush();check_cards("late mixed empty slots");await shot("04-late-empty-centered")
    var file=FileAccess.open(OUT+"operations.json",FileAccess.WRITE);file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"failures":failures,"records":records},"  "));file.close()
    print("EMPTY_CENTERING_COMPLETE failures=",failures.size())
    if host.save_files!=null:host.save_files.close(2000)
    app.queue_free();await flush();quit(0 if failures.is_empty() else 1)
