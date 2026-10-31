extends SceneTree
var app
var host
var panel
var failures: Array=[]
var records: Array=[]
const OUT="/tmp/space-idle-workbench-rebuild/resource-rail-confirm/"
func _initialize() -> void:call_deferred("run")
func check(value: bool, message: String) -> void:
    if not value:failures.append(message);printerr("FAIL: ",message)
func flush() -> void:
    for i in 5:await process_frame
    await RenderingServer.frame_post_draw
func click(button: Control) -> void:
    var point: Vector2=button.get_global_rect().get_center()
    var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true;Input.parse_input_event(event);await process_frame
    event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=false;Input.parse_input_event(event);await flush()
func wheel(button_index: int) -> void:
    var point: Vector2=panel._scroll.global_position+Vector2(420,250)
    var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=button_index;event.factor=1.0;event.pressed=true;Input.parse_input_event(event);await process_frame
    event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=button_index;event.pressed=false;Input.parse_input_event(event);await flush()
func wallet(iron: String, matter: String) -> void:
    var state: Dictionary=host.economy.save_state()
    state.wallet={"1":host.amount_api.apply("from_decimal",[iron]).value,"2":host.amount_api.apply("from_decimal",["1000"]).value,"degenerate_matter":host.amount_api.apply("from_decimal",[matter]).value}
    check(host.economy.restore_state(state).ok,"existing owner validates controlled wallet")
    host.economy.publish_budget_change()
func shot(name: String) -> void:
    await flush()
    check(app._zone_shell._active_route=="equipment" and app._zone_shell._context.text=="装备" and panel.visible,"confirmation title navigation and body agree")
    var balances: Array=[]
    for label in app._zone_shell._balances:
        var width: float=label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
        check(width<=label.size.x,"official amount visible ink fits rail cell")
        balances.append({"text":label.text,"full_official_line":label.tooltip_text,"font_size":label.get_theme_font_size("font_size"),"ink_width":width,"box":label.get_global_rect()})
    records.append({"case":name,"balances":balances,"owner_rows":host.economy.balance_rows(),"wallet":host.economy.budget(),"slots":host.equipment_slot_facts(),"comparison":panel._cards["weapon:0"].comparison,"scroll":panel._scroll.scroll_vertical})
    root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
    root.size=Vector2i(1440,900);root.position=Vector2i.ZERO
    app=load("res://src/main.tscn").instantiate();root.add_child(app);host=app.session;panel=app.equipment_scene
    check(app.startup_error.is_empty(),"normal main/native/config startup")
    if host==null or panel==null:quit(1);return
    host.set_pause("user",true);await flush();await click(app._zone_shell._route_buttons["equipment"])
    check(panel._active.size()==2,"natural early2")
    await shot("resource-rail-early2")
    var campaign: Dictionary=host.campaign_system.save_state()
    campaign.state.highest_reached=100;campaign.cycle_reached=100;campaign.state.state="menu";campaign.departure_remaining=0.0;campaign.state.speed=0.0;campaign.state.cleared_stages={}
    for stage in range(1,100):campaign.state.cleared_stages[stage]=true
    check(host.campaign_system.restore_state(campaign).ok,"existing owner validates controlled progress")
    host.equipment.refresh_availability(host.campaign_system.available,100)
    wallet("99900","1000")
    check(host.campaign_system.change_ship("Cruiser",host.commit_ship_refit).ok,"real owner changes to Cruiser")
    await flush()
    check(app._zone_shell._balances[0].text=="9.99万","normal amount magnitude directly visible")
    check(app._zone_shell._balances[0].tooltip_text=="铁：9.99万","normal official resource line preserved")
    check(panel._active.size()==5,"middle5")
    await shot("resource-rail-middle5-empty")
    check(host.campaign_system.change_ship("Heavy_Battleship",host.commit_ship_refit).ok,"real owner changes to HeavyBattleship")
    for fact in host.equipment_slot_facts():
        var key: String=["laser","missile","cannon","longLaser","laser"][int(fact.index)] if fact.category=="weapon" else ["armour","shield","shield"][int(fact.index)]
        if str(fact.equipment_id)==key:continue
        check(host.equipment.equip_slot(str(fact.id),key,host.equipment_inputs(),host.publish_equipment_refit).get("ok",false),"real owner installs loadout "+str(fact.id))
    var equipment: Dictionary=host.equipment.save_state()
    for slot in equipment.slots:slot.paid_level=19 if slot.id=="weapon:0" else 1
    check(host.equipment.restore_state(equipment,host.campaign_system.ship_facts().mounts).ok,"existing owner validates controlled paid levels only")
    check(host.publish_equipment_refit(host.economy.budget(),"refit","",null,false).ok,"paid levels publish without replacing accepted geometry")
    panel._structure_dirty=true;await flush();check(panel._active.size()==8,"late8")
    await shot("resource-rail-late8-top")
    for step in 12:
        if panel._scroll.scroll_vertical>=int(panel._content_height-panel._view_height):break
        await wheel(MOUSE_BUTTON_WHEEL_DOWN)
    check(panel._scroll.scroll_vertical==280,"real wheel reaches late bottom")
    await shot("resource-rail-late8-bottom")
    for step in 12:
        if panel._scroll.scroll_vertical<=0:break
        await wheel(MOUSE_BUTTON_WHEEL_UP)
    wallet("1234567890123456789012345678901234567890","9999999999999999999999");await flush()
    await click(panel._cards["weapon:0"].quantity);await click(panel._cards["weapon:0"].quantity)
    check(panel._cards["weapon:0"].comparison.quote.count==444,"unchanged owner longMAX444")
    check(app._zone_shell._balances[0].text=="1.235e39","long amount exponent directly visible")
    check(app._zone_shell._balances[0].tooltip_text=="铁：1.235×10^39","long official resource line preserved")
    await shot("resource-rail-long-max")
    var file=FileAccess.open(OUT+"operations.json",FileAccess.WRITE);file.store_string(JSON.stringify({"source":"narrow shared resource rail confirmation, no full workflow rerun","failures":failures,"records":records,"engine":Engine.get_version_info()},"  "));file.close()
    print("RESOURCE_RAIL_CONFIRM_COMPLETE failures=",failures.size())
    if host.save_files!=null:host.save_files.close(2000)
    panel=null;host=null;app.queue_free();app=null;await flush()
    quit(0 if failures.is_empty() else 1)
