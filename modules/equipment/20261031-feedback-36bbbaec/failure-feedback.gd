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
func measure(label: String, action: int) -> Dictionary:
    var samples: Array=[];var process_samples: Array=[];var command_us: Array=[]
    var counts: Dictionary=panel.presentation_counts.duplicate(true)
    var commits: int=host.battle.configuration_commits
    var nodes: int=get_node_count()
    var initial: Dictionary=state()
    var connection_counts: Array=[]
    for signal_name in ["slots_changed","loadout_changed","options_changed","comparison_changed"]:
        connection_counts.append(host.equipment.get_signal_connection_list(signal_name).size())
    var start: int=Time.get_ticks_usec();var last: int=start;var next_command: int=start
    var commands: int=0;var accepted: int=0
    while Time.get_ticks_usec()-start<4000000:
        await process_frame
        var now: int=Time.get_ticks_usec();samples.append((now-last)/1000.0);last=now
        process_samples.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
        if action>0 and now>=next_command:
            var command_start: int=Time.get_ticks_usec()
            if action==1:panel._buy_slot("weapon:0")
            else:panel._buy_all()
            command_us.append(Time.get_ticks_usec()-command_start)
            commands+=1
            if panel.last_result.get("ok",false):accepted+=1
            next_command=now+125000
    var elapsed: float=(Time.get_ticks_usec()-start)/1000000.0
    await flush()
    var delta: Dictionary={}
    for key in counts:delta[key]=panel.presentation_counts[key]-counts[key]
    samples.sort();process_samples.sort();command_us.sort()
    var final_connections: Array=[]
    for signal_name in ["slots_changed","loadout_changed","options_changed","comparison_changed"]:
        final_connections.append(host.equipment.get_signal_connection_list(signal_name).size())
    check(connection_counts==final_connections,label+" signal counts remain stable")
    check(host.battle.configuration_commits==commits,label+" no native geometry/configuration reinstallation")
    check(delta.refreshes==0 and delta.scene_redraw_requests==0,label+" no structural equipment rebuild or scene redraw")
    check(nodes==get_node_count(),label+" node count stable")
    if action>0:check(commands==accepted and accepted>0,label+" real owner accepts every measured command")
    return {"case":label,"seconds":elapsed,"frames":samples.size(),"fps":samples.size()/elapsed,"frame_ms_p50":samples[int(samples.size()*.5)],"frame_ms_p95":samples[int(samples.size()*.95)],"process_ms_p95":process_samples[int(process_samples.size()*.95)],"commands":commands,"accepted":accepted,"command_ms_p95":command_us[int(command_us.size()*.95)]/1000.0 if not command_us.is_empty() else 0,"target_hz":8 if action>0 else 0,"observed_hz":commands/elapsed,"presentation_delta":delta,"native_configuration_commits":host.battle.configuration_commits-commits,"nodes_before":nodes,"nodes_after":get_node_count(),"signal_counts":final_connections,"before":initial,"after":state()}
func run() -> void:
    root.size=Vector2i(1440,900);root.position=Vector2i.ZERO
    app=load("res://src/main.tscn").instantiate();root.add_child(app)
    host=app.session;panel=app.equipment_scene
    check(app.startup_error.is_empty(),"real main/native/config startup")
    if host==null:quit(1);return
    host.set_pause("user",true);await flush()
    await click(app._zone_shell._route_buttons["equipment"])
    var kind: String=OS.get_cmdline_user_args()[0]
    wallet("0","0");await flush()
    await click(panel._cards["weapon:0"].purchase)
    check(panel.last_result.get("reason")=="InsufficientResources" and panel._toast_text.text=="资源不足","real insufficient purchase response")
    check(not panel._cards["weapon:0"].purchase.disabled,"business shortage remains clickable")
    await shot(kind+"-insufficient")
    await click(panel._batch_open)
    await click(find_text_button(panel._popup,"执行升级"))
    check(panel.last_result.get("reason")=="NoChange" and panel._toast_text.text=="资源不足","real batch no-purchase shortage")
    panel._close_popup()
    wallet("1000000","1000");await flush()
    await click(panel._cards["weapon:0"].purchase)
    check(panel.last_result.get("ok",false),"real paid level purchase accepted")
    await shot(kind+"-accepted")
    var before: Dictionary=state()
    var rejected: Dictionary=host.equipment.equip_slot("defence:0","",host.equipment_inputs(),host.publish_equipment_refit)
    panel._accept_result(rejected,false);await flush()
    check(rejected.get("reason")=="FirstDefenceRequired" and panel._toast_text.text=="首个防御槽需要保留装备。","real equipment admission refusal")
    check(host.equipment_slot_facts()==before.slots and host.economy.budget()==before.wallet,"real refusal preserves owner")
    await shot(kind+"-refused")
    if kind=="single":
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
    if kind=="single":
        host.set_pause("user",false)
        Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
        await flush()
        records.append({"case":"performance conditions","max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":root.size,"campaign":host.campaign_system.save_state(),"note":"same live scene, no recording during measurement; old source/environment baseline unavailable"})
        records.append(await measure("idle-before",0))
        records.append(await measure("single-slot-8hz",1))
        records.append(await measure("all-slots-8hz",2))
        records.append(await measure("idle-after",0))
        await click(app._zone_shell._route_buttons["ship"])
        var hidden_before: Dictionary=panel.presentation_counts.duplicate(true)
        await create_timer(1.0).timeout;await flush()
        check(panel.presentation_counts.comparison_reads==hidden_before.comparison_reads and panel.presentation_counts.refreshes==hidden_before.refreshes,"hidden equipment does not refresh or compare")
        records.append({"case":"hidden equipment","before":hidden_before,"after":panel.presentation_counts.duplicate(true)})
        await click(app._zone_shell._route_buttons["equipment"])
        host.set_pause("user",true);await flush()
    var publish=func(_budget, _mode=""):
        host.run_state.fail("InjectedPublishFailure")
        return {"ok":false,"fault":true,"reason":"InjectedPublishFailure"}
    var failed: Dictionary
    before=state()
    if kind=="batch":
        panel._open_batch()
        failed=host.equipment.buy_all_levels(1,false,host.equipment_inputs(),host.economy.affordable,host.economy.payment,publish)
    elif kind=="equip":
        var campaign: Dictionary=host.campaign_system.save_state()
        campaign.state.highest_reached=100;campaign.cycle_reached=100;campaign.state.cleared_stages={}
        for stage in range(1,100):campaign.state.cleared_stages[stage]=true
        check(host.campaign_system.restore_state(campaign).ok,"controlled switch unlock")
        host.equipment.refresh_availability(host.campaign_system.available,100)
        failed=host.equipment.equip_slot("defence:0","shield",host.equipment_inputs(),publish)
    else:
        failed=host.equipment.buy_levels("weapon:0",1,host.equipment_inputs(),host.economy.payment,publish)
    check(failed.get("fault",false),"explicit injected publisher reaches owner fault")
    panel._accept_result(failed,kind!="equip");await flush()
    check(panel._toast_text.text=="操作失败，当前游戏已停止。" and panel._toast_time<0,"player failure omits technical state and unsafe retry")
    check(not host.run_state.is_running() and panel._cards["weapon:0"].purchase.disabled and panel._cards["weapon:0"].select.disabled and panel._global_quantity.disabled and panel._batch_open.disabled,"all payment and refit controls frozen")
    check(not is_instance_valid(panel._popup),"fault closes popup")
    check(host.equipment_slot_facts()==before.slots and host.economy.budget()==before.wallet,"injected publisher did not accept candidate")
    await shot(kind+"-stopped")
    var again: Dictionary=host.equipment.buy_levels("weapon:0",1,host.equipment_inputs(),host.economy.payment,host.publish_equipment_levels)
    panel._accept_result(again,true);await flush()
    check(again.get("reason")=="SessionUnavailable" and panel._toast_text.text=="操作失败，当前游戏已停止。","repeat command blocked without retry prompt")
    check(host.economy.budget()==before.wallet,"blocked repeat does not pay")
    check(panel._diagnostic_code("/private/token=value")=="redacted","non-symbolic diagnostic content redacted")
    records.append({"case":kind,"fault":failed,"blocked_repeat":again,"before":before,"after":state(),"player_text":panel._toast_text.text,"injection":"explicit publisher, not actual native fault"})
    var file=FileAccess.open(OUT+kind+"-operations.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"failures":failures,"records":records},"  "));file.close()
    print("FAILURE_FEEDBACK_COMPLETE ",kind," failures=",failures.size())
    if host.save_files!=null:host.save_files.close(2000)
    app.queue_free();await flush()
    quit(0 if failures.is_empty() else 1)
