extends SceneTree
var app
var host
var panel
var failures: Array=[]
var records: Array=[]
const OUT="/tmp/space-idle-workbench-rebuild/failure-feedback/"
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
func run() -> void:
    root.size=Vector2i(1440,900);root.position=Vector2i.ZERO
    app=load("res://src/main.tscn").instantiate();root.add_child(app)
    host=app.session;panel=app.equipment_scene
    check(app.startup_error.is_empty(),"real main native startup")
    if host==null:quit(1);return
    host.set_pause("user",true);await flush()
    await click(app._zone_shell._route_buttons["equipment"])
    print("ACTION_READY_MS=",Time.get_ticks_msec())
    wallet("0","0");await flush()
    await click(panel._cards["weapon:0"].purchase)
    check(panel._toast_text.text=="资源不足","real insufficient response")
    await shot("video-early-insufficient")
    wallet("1000000","1000");await flush()
    await click(panel._cards["weapon:0"].purchase)
    check(panel.last_result.get("ok",false) and not panel._toast.visible,"accepted payment clears obsolete refusal")
    await shot("video-early-accepted")
    var campaign: Dictionary=host.campaign_system.save_state()
    campaign.state.highest_reached=100;campaign.cycle_reached=100;campaign.state.state="menu";campaign.departure_remaining=0.0;campaign.state.speed=0.0;campaign.state.cleared_stages={}
    for stage in range(1,100):campaign.state.cleared_stages[stage]=true
    check(host.campaign_system.restore_state(campaign).ok,"controlled progress restore")
    host.equipment.refresh_availability(host.campaign_system.available,100)
    check(host.campaign_system.change_ship("Cruiser",host.commit_ship_refit).ok,"real middle ship refit")
    await flush();await shot("visual-middle-empty")
    for id in ["weapon:1","weapon:2","defence:1"]:
        check(host.equipment.equip_slot(id,"missile" if id.begins_with("weapon") else "shield",host.equipment_inputs(),host.publish_equipment_refit).ok,"real middle slot install")
    await flush();await shot("visual-middle-installed")
    check(host.campaign_system.change_ship("Heavy_Battleship",host.commit_ship_refit).ok,"real heavy ship refit")
    await flush();await shot("visual-late-empty")
    for fact in host.equipment_slot_facts():
        var key: String=["laser","missile","cannon","longLaser","laser"][int(fact.index)] if fact.category=="weapon" else ["armour","shield","shield"][int(fact.index)]
        if str(fact.equipment_id)!=key:check(host.equipment.equip_slot(str(fact.id),key,host.equipment_inputs(),host.publish_equipment_refit).ok,"real late slot install")
    wallet("1234567890123456789012345678901234567890","9999999999999999999999");await flush()
    await click(panel._global_quantity);await click(panel._global_quantity)
    await shot("visual-long-max-top")
    panel._scroll.scroll_vertical=10000;await flush();await shot("visual-long-max-bottom")
    panel._scroll.scroll_vertical=0;await flush()
    await click(panel._global_quantity)
    records.append({"case":"controlled owner progress plus real ship and slot refit for decoration boundaries","state":state(),"scroll_rect":panel._scroll.get_global_rect(),"identity_rect":panel._identity.get_global_rect(),"global_rect":panel._global_quantity.get_global_rect()})

    await click(panel._batch_open)
    await shot("video-all-popup")
    await click(find_text_button(panel._popup,"执行升级"))
    check(panel.last_result.get("ok",false),"real batch accepted")
    await shot("video-all-accepted")
    var before: Dictionary=state()
    var failed: Dictionary=host.equipment.buy_all_levels(1,false,host.equipment_inputs(),host.economy.affordable,host.economy.payment,func(_budget):
        host.run_state.fail("InjectedPublishFailure")
        return {"ok":false,"fault":true,"reason":"InjectedPublishFailure"})
    panel._accept_result(failed,true);await flush()
    check(panel._toast_text.text=="操作失败，当前游戏已停止。" and panel._cards["weapon:0"].purchase.disabled,"unknown fault uses player wording and freezes")
    await shot("video-all-stopped")
    await create_timer(1.0).timeout
    records.append({"case":"recorded batch owner explicit injected fault","before":before,"result":failed,"after":state()})
    var file=FileAccess.open(OUT+"video-operations.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"failures":failures,"records":records},"  "));file.close()
    print("VIDEO_COMPLETE failures=",failures.size()," ACTION_END_MS=",Time.get_ticks_msec())
    if host.save_files!=null:host.save_files.close(2000)
    app.queue_free();await flush();quit(0 if failures.is_empty() else 1)
