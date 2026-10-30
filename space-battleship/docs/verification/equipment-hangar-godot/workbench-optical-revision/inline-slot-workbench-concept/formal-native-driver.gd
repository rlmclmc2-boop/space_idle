extends SceneTree
var app
var host
var panel
var failures: Array=[]
var records: Array=[]
const OUT="/tmp/space-idle-workbench-rebuild/formal/"
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
func move_mouse(position: Vector2) -> void:
    var event=InputEventMouseMotion.new();event.position=position;event.global_position=position;Input.parse_input_event(event)
func cell(id: String, resource: String) -> Dictionary:
    for fee in panel._cards[id].fee_cells:
        if fee.resource==resource:return fee
    return {}
func check_geometry(label: String) -> void:
    var cards: Array=[]
    for fact in panel._active:
        var item: Dictionary=panel._cards[str(fact.id)]
        if not item.panel.visible:continue
        var rectangle: Rect2=item.panel.get_global_rect()
        if str(fact.equipment_id).is_empty():
            check(not item.level.visible and not item.attribute.visible and not item.fees.visible and not item.cost_title.visible and not item.quantity.visible and not item.purchase.visible and not item.compare.visible,label+" empty slot only has equipment choice "+str(fact.id))
            cards.append({"slot":fact.id,"empty":true,"fact":fact,"owner_slot_quote":host.equipment.quote_slot(str(fact.id),1),"upgrade_controls_visible":false})
            continue
        check(rectangle.encloses(item.purchase.get_global_rect()),label+" purchase contained "+str(fact.id))
        check(rectangle.encloses(item.attribute.get_global_rect()),label+" attribute contained "+str(fact.id))
        var width: float=item.attribute.get_theme_font("font").get_string_size(item.attribute.text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
        check(width<=item.attribute.size.x,label+" actual18px single-line ink width "+str(fact.id))
        var fees: Array=[]
        for fee in item.fee_cells:
            check(rectangle.encloses(fee.control.get_global_rect()),label+" whole fee contained "+str(fact.id))
            check(fee.control.get_global_rect().end.x+10<=item.quantity.global_position.x,label+" fee/action clearance "+str(fact.id))
            fees.append({"resource":fee.resource,"poor":fee.poor,"name_omitted":fee.name_omitted,"full_text":fee.full_text,"rect":fee.control.get_global_rect()})
        cards.append({"slot":fact.id,"rect":rectangle,"attribute":item.attribute.text,"attribute_ink_width":width,"attribute_box":item.attribute.get_global_rect(),"fees":fees,"purchase_enabled":not item.purchase.disabled})
    records.append({"case":label,"cards":cards,"state":state()})
func run() -> void:
    root.size=Vector2i(1440,900);root.position=Vector2i.ZERO
    app=load("res://src/main.tscn").instantiate();root.add_child(app)
    host=app.session;panel=app.equipment_scene
    check(app.startup_error.is_empty(),"real main/native/config startup")
    if host==null or panel==null:quit(1);return
    host.set_pause("user",true);await flush()
    await click(app._zone_shell._route_buttons["equipment"])
    check(app._zone_shell._active_route=="equipment" and app._zone_shell._context.text=="装备" and panel.visible,"formal title navigation and equipment agree")
    check(not panel._fallback_header.visible and not app._bridge_open.visible,"shared host replaces duplicate equipment and bridge headers")
    check(not app._zone_shell.is_route_available("reactor") and not app._zone_shell.is_route_available("planet"),"isolated host imports no new reactor or planet page")
    var surface: Control=app._battle_viewport.get_parent()
    check(surface.position==Vector2(855.875,0) and surface.scale==Vector2(.9375,.9375),"unchanged authored battle visual and input projection")
    records.append({"case":"formal shared host attachment","surface_position":surface.position,"surface_scale":surface.scale,"viewport_size":app._battle_viewport.size,"title":app._zone_shell._context.text})
    # The pause button lives in the original SubViewport: transform the real input point.
    var pause_point: Vector2=surface.position+app._pause_button.get_global_rect().get_center()*surface.scale
    for expected_pause in [false,true]:
        var press=InputEventMouseButton.new();press.position=pause_point;press.global_position=pause_point;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;Input.parse_input_event(press);await process_frame
        press=InputEventMouseButton.new();press.position=pause_point;press.global_position=pause_point;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=false;Input.parse_input_event(press);await flush()
        check(host.pause_reasons.has("user")==expected_pause,"real transformed battle pause button input")
    records.append({"case":"battle visual/input use the same retained transform","root_click":pause_point,"paused_restored":host.pause_reasons.has("user")})
    await click(app._zone_shell._route_buttons["ship"])
    check(app.growth_panel.visible and not panel.visible and app._zone_shell._active_route=="ship","real public ship navigation")
    await click(app._zone_shell._route_buttons["equipment"])
    check(panel.visible and not app.growth_panel.visible and app._zone_shell._active_route=="equipment","real public equipment return")
    check(host.run_state.is_running(),"owner remains running")
    check(panel._active.size()==2,"natural early two slots")
    var early: Dictionary=panel._cards["weapon:0"]
    check(not early.purchase.disabled,"insufficient-funds purchase stays clickable")
    var before: Dictionary=state()
    await click(early.purchase)
    check(not panel.last_result.get("ok",true) and panel.last_result.get("reason")=="InsufficientResources","real owner resource rejection")
    check(host.equipment_slot_facts()==before.slots and host.economy.budget()==before.wallet,"rejection changes neither levels nor wallet")
    check(panel._toast.visible and panel._toast_text.text=="资源不足","click triggers transient resource message")
    root.get_texture().get_image().save_png(OUT+"inline-native-early-feedback.png")
    await create_timer(2.0).timeout;await flush()
    check(not panel._toast.visible,"resource message clears; no history area")
    root.get_texture().get_image().save_png(OUT+"inline-native-early.png")
    records.append({"case":"natural early rejection and transient feedback","state":state(),"cards":panel._cards.keys()})
    check_geometry("natural early rectangular cards")
    # Same real Owner/configuration; later states use explicit validated restoration.
    var equipment: Dictionary=host.equipment.save_state()
    for slot in equipment.slots:
        if slot.id=="weapon:0":slot.paid_level=19
    check(host.equipment.restore_state(equipment,host.campaign_system.ship_facts().mounts).ok,"controlled early paidLv19 validates")
    check(host.publish_equipment_refit(host.economy.budget(),"refit","",null,false).ok,"controlled levels published to real native")
    panel._structure_dirty=true;await flush()
    check(panel._cards["weapon:0"].purchase.disabled,"true evolution admission disabled")
    check(panel._cards["weapon:0"].fee_reason.text=="进化材料尚未开放","material gate shows exact domain reason without generic overflow")
    await shot("inline-native-material-locked")
    await click(panel._cards["weapon:0"].quantity);await click(panel._cards["weapon:0"].quantity)
    check(panel._cards["weapon:0"].purchase.disabled,"MAX zero from true material gate is not mislabelled resource shortage")
    await click(panel._cards["weapon:0"].quantity)
    var campaign: Dictionary=host.campaign_system.save_state()
    campaign.state.highest_reached=100;campaign.cycle_reached=100;campaign.state.state="menu";campaign.departure_remaining=0.0;campaign.state.speed=0.0;campaign.state.cleared_stages={}
    for stage in range(1,100):campaign.state.cleared_stages[stage]=true
    check(host.campaign_system.restore_state(campaign).ok,"controlled progress validates")
    host.equipment.refresh_availability(host.campaign_system.available,100)
    wallet("1000000","1000");await flush()
    var time_before: float=host.game_time
    var paid_before: int=host.equipment_slot_facts()[0].paid_level
    var wallet_before: Dictionary=host.economy.budget().duplicate(true)
    await click(panel._cards["weapon:0"].select)
    var missile: Button=button_with_equipment(panel._popup,"missile")
    check(missile!=null,"local available missile option")
    if missile!=null:await click(missile)
    check(panel.last_result.get("ok",false) and host.equipment_slot_facts()[0].equipment_id=="missile","candidate click immediately commits real missile")
    await click(panel._cards["weapon:0"].select)
    var laser: Button=button_with_equipment(panel._popup,"laser")
    if laser!=null:await click(laser)
    check(panel.last_result.get("ok",false) and host.equipment_slot_facts()[0].equipment_id=="laser","immediate same-game-time switch back accepted")
    check(host.game_time==time_before and host.equipment_slot_facts()[0].cooldown_remaining==0.0,"no same-slot gameplay lock")
    check(host.equipment_slot_facts()[0].paid_level==paid_before and host.economy.budget()==wallet_before,"switches free and preserve paid level")
    records.append({"case":"actual GUI immediate free switch and back, paused game time","state":state()})
    await click(panel._cards["weapon:0"].purchase)
    check(panel.last_result.get("ok",false) and panel.last_result.get("purchase_receipt",{}).get("commit_status")=="accepted","real purchase accepted receipt")
    check(host.equipment_slot_facts()[0].paid_level==paid_before+1,"paid level refreshed from accepted owner")
    check(panel._cards["weapon:0"].level.text=="Lv."+str(host.equipment_slot_facts()[0].paid_level),"same-frame accepted slot label agrees")
    check(get_root().gui_get_focus_owner()==panel._cards["weapon:0"].purchase,"purchase focus retained through local refresh")
    await shot("inline-native-success")
    check(host.campaign_system.change_ship("Cruiser",host.commit_ship_refit).ok,"actual owner ship refit to middle")
    await flush();check(panel._active.size()==5 and panel._content_height==508,"middle5 same screen")
    check_geometry("middle5 real state with true empty slots");await shot("inline-native-middle-empty")
    var empty_before: Dictionary=state()
    # Clicking the old upgrade target in the empty card must have no command.
    var empty_point: Vector2=panel._cards["weapon:1"].panel.global_position+Vector2(380,70)
    var event=InputEventMouseButton.new();event.position=empty_point;event.global_position=empty_point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;Input.parse_input_event(event);await process_frame
    event=InputEventMouseButton.new();event.position=empty_point;event.global_position=empty_point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false;Input.parse_input_event(event);await flush()
    check(host.equipment_slot_facts()==empty_before.slots and host.economy.budget()==empty_before.wallet,"true empty slot has no stale invisible purchase target")
    await click(panel._cards["weapon:1"].select)
    await shot("inline-native-empty-choice")
    var empty_missile: Button=button_with_equipment(panel._popup,"missile")
    check(empty_missile!=null,"true empty weapon offers actual available equipment")
    if empty_missile!=null:await click(empty_missile)
    check(host.equipment_slot_facts().filter(func(f):return f.id=="weapon:1")[0].equipment_id=="missile" and host.economy.budget()==empty_before.wallet,"true empty slot installs available missile free")
    check(panel._cards["weapon:1"].purchase.visible and panel._cards["weapon:1"].attribute.visible,"accepted nonempty object restores upgrade controls")
    records.append({"case":"actual empty-slot click, free installation and upgrade object restoration","before":empty_before,"after":state()})
    await shot("inline-native-middle-installed")
    check(host.campaign_system.change_ship("Heavy_Battleship",host.commit_ship_refit).ok,"actual owner ship refit to late")
    await flush();check_geometry("late true empty slots before loadout restoration");await shot("inline-native-late-empty")
    equipment=host.equipment.save_state()
    for slot in equipment.slots:
        slot.paid_level=19 if slot.id=="weapon:0" else 1
        slot.equipment_id=["laser","missile","cannon","longLaser","laser"][slot.index] if slot.category=="weapon" else ["armour","shield","shield"][slot.index]
    check(host.equipment.restore_state(equipment,host.campaign_system.ship_facts().mounts).ok,"controlled late loadout validates")
    check(host.publish_equipment_refit(host.economy.budget(),"refit","",null,false).ok,"controlled late loadout publishes native")
    wallet("1000000","0");panel._structure_dirty=true;await flush()
    check(not cell("weapon:0","1").poor and cell("weapon:0","degenerate_matter").poor,"only deficient matter is red")
    check(not panel._cards["weapon:0"].purchase.disabled,"dual-resource shortage remains clickable")
    check_geometry("late only matter insufficient");await shot("inline-native-late-matter-poor")
    wallet("0","1000");await flush()
    check(cell("weapon:0","1").poor and not cell("weapon:0","degenerate_matter").poor,"only deficient iron is red")
    await shot("inline-native-late-iron-poor")
    wallet("1234567890123456789012345678901234567890","9999999999999999999999");await flush()
    await click(panel._cards["weapon:0"].quantity);await click(panel._cards["weapon:0"].quantity)
    check(int(panel._cards["weapon:0"].mode)==2,"real quantity cycle reaches MAX")
    var comparison: Dictionary=host.equipment_comparison("weapon:0","laser",1,true)
    check(panel._cards["weapon:0"].comparison==comparison,"real longMAX uses exact owner comparison")
    check(comparison.quote.count==444,"actual known historical wallet gives444 levels")
    check(cell("weapon:0","degenerate_matter").name_omitted,"crowded quote omits names, retains icon and whole numeric amount")
    check_geometry("late actual longMAX");await shot("inline-native-long-max")
    var hover: Control=cell("weapon:0","degenerate_matter").control
    move_mouse(hover.get_global_rect().get_center());await create_timer(.2).timeout
    check(not panel._tooltip.visible,"resource tooltip not immediate")
    await create_timer(.4).timeout;await flush()
    check(panel._tooltip.visible,"resource tooltip after .5second delay")
    await shot("inline-native-resource-tooltip")
    move_mouse(Vector2(900,100));await flush();check(not panel._tooltip.visible,"resource tooltip clears on exit")
    panel._scroll.scroll_vertical=60;await flush()
    check(not panel._cards["weapon:0"].panel.visible and panel._cards["weapon:0"].fragment.visible,"partial row only passive identity")
    var untouched: Dictionary=state()
    var hidden_point=panel._scroll.global_position+Vector2(350,30)
    var down=InputEventMouseButton.new();down.position=hidden_point;down.global_position=hidden_point;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;Input.parse_input_event(down);await process_frame
    down=InputEventMouseButton.new();down.position=hidden_point;down.global_position=hidden_point;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=false;Input.parse_input_event(down);await flush()
    check(host.equipment_slot_facts()==untouched.slots and host.economy.budget()==untouched.wallet,"clipped row cannot purchase via visible strip")
    panel._scroll.scroll_vertical=int(panel._content_height-panel._view_height);await flush()
    check(panel._cards["defence:2"].panel.visible,"late bottom complete third defence")
    check_geometry("late bottom");await shot("inline-native-bottom")
    await click(panel._cards["defence:1"].select);await shot("inline-native-defence-dropdown")
    for texture in panel._popup.find_children("*", "TextureRect", true, false):
        check(texture.size.x<=44 and texture.size.y<=54,"local choice icon respects declared bounds")
    check(panel.has_exclusive_ui(),"local choice reports host input exclusivity")
    check(app._zone_shell._route_buttons["ship"].disabled,"local choice blocks shared navigation")
    check(not panel.prepare_host_hide(),"host route cannot hide active choice without resolution")
    panel.prepare_host_hide(true);await flush();check(not panel.has_exclusive_ui(),"forced hide clears local overlay")
    panel._scroll.scroll_vertical=0;await flush()
    wallet("1000000","1000");await flush()
    var before_fault: Dictionary=state()
    var failed: Dictionary=host.equipment.buy_levels("weapon:1",1,host.equipment_inputs(),host.economy.payment,func(_budget):
        host.run_state.fail("InjectedPublishFailure")
        return {"ok":false,"fault":true,"reason":"InjectedPublishFailure"})
    check(failed.get("purchase_receipt",{}).get("commit_status")=="fault_unknown","real owner creates unknown receipt under explicit fault-injected publisher")
    panel._accept_result(failed,true);await flush()
    check(not host.run_state.is_running() and panel._cards["weapon:1"].purchase.disabled,"unknown receipt disables further payment")
    check(host.equipment_slot_facts()==before_fault.slots and host.economy.budget()==before_fault.wallet,"unknown publisher never pretends accepted levels or balance")
    records.append({"case":"Owner-generated fault_unknown with explicit injected publisher, not a native fault claim","result":failed,"state":state()})
    await shot("inline-native-unknown-receipt")
    var file=FileAccess.open(OUT+"inline-native-operations.json",FileAccess.WRITE)
    file.store_string(JSON.stringify({"source":"formal isolated host same-thread native equipment integration; controlled later states explicit","engine":Engine.get_version_info(),"failures":failures,"records":records},"  "));file.close()
    print("INLINE_NATIVE_TARGETED_COMPLETE failures=",failures.size())
    if host.save_files!=null:host.save_files.close(2000)
    panel=null;host=null
    app.queue_free();app=null
    await flush()
    quit(0 if failures.is_empty() else 1)
