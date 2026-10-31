extends SceneTree
var app
var host
var panel
var failures: Array=[]
var records: Array=[]
const OUT="/tmp/space-idle-workbench-rebuild/main-entry-check/"
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
    var untouched: Dictionary=state()
    for expected in [1,2,0]:
        await click(panel._global_quantity)
        check(panel._batch_mode==expected and host.economy.budget()==untouched.wallet and host.equipment_slot_facts()==untouched.slots,"main global quantity is quote only")
    wallet("0","0");await flush()
    var refused_before: Dictionary=state()
    await click(panel._cards["weapon:0"].purchase)
    check(panel.last_result.get("reason")=="InsufficientResources" and panel._toast_text.text=="资源不足" and not panel._cards["weapon:0"].purchase.disabled,"main business shortage clickable feedback")
    check(host.economy.budget()==refused_before.wallet and host.equipment_slot_facts()==refused_before.slots,"main rejection preserves owner")
    wallet("1000000","1000");await flush()
    var expected_payment: Dictionary=host.economy.payment(panel._cards["weapon:0"].comparison.quote.costs)
    var configuration_before: int=host.battle.configuration_commits
    var structure_before: int=panel.presentation_counts.refreshes
    await click(panel._cards["weapon:0"].purchase)
    check(panel.last_result.get("ok",false) and host.economy.budget()==expected_payment.wallet,"main accepted quote exact payment")
    check(host.battle.configuration_commits==configuration_before and panel.presentation_counts.refreshes==structure_before,"main numerical purchase does not rebuild configuration or equipment layout")
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
    var resource_manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("/tmp/space-idle-workbench-rebuild/main-runtime-resources.json"))
    var cached: Array=[]
    for path in resource_manifest.paths:
        var full: String="res://"+str(path)
        if ResourceLoader.has_cached(full):cached.append({"path":str(path),"sha256":FileAccess.get_sha256(full)})
    records.append({"case":"actual main candidate resource binding","candidate":resource_manifest.candidate,"working_source":resource_manifest.source,"cached":cached,"config_sha256":FileAccess.get_sha256("res://generated/config.json"),"note":"original art workspace preserved; external validator must confirm every cached project source/asset belongs to candidate tree with identical bytes"})
    var failed: Dictionary=host.equipment.buy_levels("weapon:0",1,host.equipment_inputs(),host.economy.payment,func(_budget):
        host.run_state.fail("InjectedPublishFailure")
        return {"ok":false,"fault":true,"reason":"InjectedPublishFailure"})
    panel._accept_result(failed,true);await flush()
    check(panel._toast_text.text=="操作失败，当前游戏已停止。" and panel._global_quantity.disabled and panel._cards["weapon:0"].purchase.disabled and panel._cards["weapon:0"].compare.disabled,"main injected unknown keeps player feedback and duplicate-payment freeze")
    panel._show_comparison("weapon:0","");check(not is_instance_valid(panel._popup),"main stopped comparison guard")
    await shot("05-main-stopped")
    var file=FileAccess.open(OUT+"operations.json",FileAccess.WRITE);file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"failures":failures,"records":records},"  "));file.close()
    print("MAIN_ENTRY_COMPLETE failures=",failures.size())
    if host.save_files!=null:host.save_files.close(2000)
    app.queue_free();await flush();quit(0 if failures.is_empty() else 1)
