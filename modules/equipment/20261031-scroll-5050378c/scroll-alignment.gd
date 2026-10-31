extends SceneTree
var app
var host
var panel
var failures: Array=[]
var records: Array=[]
const OUT="/tmp/space-idle-workbench-rebuild/scroll-alignment/"
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
func wheel(direction: int) -> void:
    var point: Vector2=panel._scroll.global_position+Vector2(410,200)
    var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion)
    var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=direction;event.pressed=true;Input.parse_input_event(event);await process_frame
    event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=direction;event.pressed=false;Input.parse_input_event(event);await flush()
func alignment(label: String) -> void:
    var visible: Array=[]
    for fact in panel._active:
        var row: Dictionary=panel._cards[str(fact.id)]
        if row.panel.visible:visible.append({"id":fact.id,"rect":row.panel.get_global_rect()})
    visible.sort_custom(func(a,b):return a.rect.position.y<b.rect.position.y)
    check(not visible.is_empty(),label+" at least one complete row")
    if visible.is_empty():return
    check(is_equal_approx(visible[0].rect.position.y,panel._body_top+panel.CONTENT_PAD),label+" first complete row uses fixed top inset")
    for row in visible:
        check(row.rect.position.y>=panel._scroll.global_position.y and row.rect.end.y<=panel._scroll.get_global_rect().end.y,label+" visible rows wholly within scroll area")
    check(panel._scroll_stops.has(panel._scroll.scroll_vertical),label+" actual scroll is a real row stop")
    records.append({"case":label,"visible":visible,"scroll":panel._scroll.scroll_vertical,"stops":panel._scroll_stops.duplicate(),"viewport":panel._scroll.get_global_rect(),"content_height":panel._content_height,"button":panel._global_quantity.get_global_rect(),"first_card_gap":visible[0].rect.position.y-panel._global_quantity.get_global_rect().end.y,"identity":panel._identity.get_global_rect()})
func run() -> void:
    root.size=Vector2i(1440,900);root.position=Vector2i.ZERO
    app=load("res://src/main.tscn").instantiate();root.add_child(app);host=app.session;panel=app.equipment_scene
    check(app.startup_error.is_empty(),"real main/native/config startup")
    if host==null:quit(1);return
    host.set_pause("user",true);await flush();await click(app._zone_shell._route_buttons["equipment"])
    wallet("1000000","1000");await flush()
    alignment("early short top");await shot("01-short-top")
    await wheel(MOUSE_BUTTON_WHEEL_DOWN);alignment("early short wheel endpoint")
    var campaign: Dictionary=host.campaign_system.save_state()
    campaign.state.highest_reached=100;campaign.cycle_reached=100;campaign.state.state="menu";campaign.departure_remaining=0.0;campaign.state.speed=0.0;campaign.state.cleared_stages={}
    for stage in range(1,100):campaign.state.cleared_stages[stage]=true
    check(host.campaign_system.restore_state(campaign).ok,"controlled progress")
    host.equipment.refresh_availability(host.campaign_system.available,100)
    check(host.campaign_system.change_ship("Cruiser",host.commit_ship_refit).ok,"real middle refit")
    await flush();alignment("middle mixed no scroll");await shot("02-middle-empty")
    for id in ["weapon:1","weapon:2"]:
        check(host.equipment.equip_slot(id,"missile",host.equipment_inputs(),host.publish_equipment_refit).ok,"real middle install")
    await flush();alignment("middle mixed top");await shot("03-middle-mixed-top")
    await wheel(MOUSE_BUTTON_WHEEL_DOWN);alignment("middle mixed bottom");await shot("04-middle-mixed-bottom")
    await wheel(MOUSE_BUTTON_WHEEL_UP);alignment("middle mixed return top")
    check(host.campaign_system.change_ship("Heavy_Battleship",host.commit_ship_refit).ok,"real late refit")
    await flush();alignment("late mixed top");await shot("05-late-mixed-top")
    for fact in host.equipment_slot_facts():
        var key: String=["laser","missile","cannon","longLaser","laser"][int(fact.index)] if fact.category=="weapon" else ["armour","shield","shield"][int(fact.index)]
        if str(fact.equipment_id)!=key:check(host.equipment.equip_slot(str(fact.id),key,host.equipment_inputs(),host.publish_equipment_refit).ok,"real late install")
    wallet("1234567890123456789012345678901234567890","9999999999999999999999");await flush()
    await click(panel._global_quantity);await click(panel._global_quantity)
    alignment("late full long MAX top");await shot("06-long-max-top")
    var previous: int=-1
    for i in 12:
        if previous==panel._scroll.scroll_vertical:break
        previous=panel._scroll.scroll_vertical
        await wheel(MOUSE_BUTTON_WHEEL_DOWN);alignment("late full wheel down "+str(i))
    alignment("late full long MAX bottom");await shot("07-long-max-bottom")
    check(panel._cards["defence:2"].panel.visible,"bottom defence complete")
    previous=-1
    for i in 12:
        if previous==panel._scroll.scroll_vertical:break
        previous=panel._scroll.scroll_vertical
        await wheel(MOUSE_BUTTON_WHEEL_UP);alignment("late full wheel up "+str(i))
    check(panel._scroll.scroll_vertical==0,"real wheel returns to zero")
    await shot("08-long-max-return-top")
    # Exercise the scrollbar's direct endpoint using its real current bounds.
    panel._scroll.get_v_scroll_bar().value=panel._scroll.get_v_scroll_bar().max_value
    await flush();alignment("actual scrollbar bottom endpoint");await shot("09-scrollbar-bottom")
    var before: Dictionary=state();await click(panel._global_quantity)
    check(host.equipment_slot_facts()==before.slots and host.economy.budget()==before.wallet,"top mode remains quote only")
    alignment("bottom quantity change retains aligned rows")
    var level_before: int=host.equipment_slot_facts().filter(func(f):return f.id=="defence:2")[0].paid_level
    await click(panel._cards["defence:2"].purchase)
    check(panel.last_result.get("ok",false) and host.equipment_slot_facts().filter(func(f):return f.id=="defence:2")[0].paid_level==level_before+1,"visible bottom row buys its own real slot")
    alignment("accepted bottom slot keeps layout")
    var failed: Dictionary=host.equipment.buy_levels("weapon:0",1,host.equipment_inputs(),host.economy.payment,func(_budget):
        host.run_state.fail("InjectedPublishFailure")
        return {"ok":false,"fault":true,"reason":"InjectedPublishFailure"})
    panel._accept_result(failed,true);await flush()
    check(panel._toast_text.text=="操作失败，当前游戏已停止。" and panel._cards["weapon:0"].compare.disabled and panel._global_quantity.disabled,"fault logging/player/freeze/compare guard retained")
    alignment("stopped aligned bottom");await shot("10-stopped-bottom")
    var file=FileAccess.open(OUT+"operations.json",FileAccess.WRITE);file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"failures":failures,"records":records},"  "));file.close()
    print("SCROLL_ALIGNMENT_COMPLETE failures=",failures.size())
    if host.save_files!=null:host.save_files.close(2000)
    app.queue_free();await flush();quit(0 if failures.is_empty() else 1)
