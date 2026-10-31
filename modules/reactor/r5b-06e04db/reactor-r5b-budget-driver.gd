extends SceneTree
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
 for i in n: await process_frame
func click(point: Vector2) -> void:
 var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=point;down.global_position=point;root.push_input(down,true)
 var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;up.position=point;up.global_position=point;root.push_input(up,true)
func clear_guidance(session, game) -> void:
 var pending:Dictionary=session.pending_guidance();var tries:=0
 while not pending.is_empty() and tries<20:
  assert(session.dismiss_guidance(str(pending.kind),str(pending.id)).ok)
  pending=session.pending_guidance();tries+=1
 game._sync_guidance()
func run() -> void:
 root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
 var game=load("res://src/main.tscn").instantiate();root.add_child(game);await frames(5)
 var session=game.session
 assert(session!=null and game.startup_error.is_empty())
 var saved:Dictionary=session.campaign_system.save_state();saved.grants["feature:reactor"]=true;saved.grants["reactor_module:condensation"]=true
 assert(session.campaign_system.restore_state(saved).ok)
 session.reactor_system.refresh_availability(session.campaign_system.available)
 assert(session.reactor_system.refresh(session.reactor_inputs(),session.publish_reactor).ok)
 clear_guidance(session,game);game._select_left_module("reactor");await frames(6);clear_guidance(session,game)
 var scene=game.reactor_scene
 var amount:Dictionary=session.amount_api.apply("from_decimal",["1000"]);assert(amount.ok)
 assert(session.economy.credit_yield("2",amount.value,session.wall_time,session.game_time).ok)
 await frames(3)
 click(scene._quantity.get_global_rect().get_center());await frames(3)
 click(scene._quantity.get_global_rect().get_center());await frames(4)
 print("FIRST_MAX ",scene._quantity.text," quote=",scene._quote," visible=",scene.visible);assert(scene._quantity.text=="MAX" and scene._quote.can_purchase)
 click(scene._purchase.get_global_rect().get_center());await frames(5)
 assert(scene.last_result.ok)
 print("MAX_BOUGHT ",scene.last_result," wallet=",session.amount_api.apply("to_display",[session.economy._wallet["2"]]).text)
 click(scene._quantity.get_global_rect().get_center());await frames(5)
 assert(scene._quantity.text=="×1" and scene._quote.ok and not scene._quote.can_purchase)
 assert(not scene._purchase.disabled and scene._cost_details.get_theme_color("font_color")==preload("res://src/ui/bridge_theme.gd").number_role_color("insufficient"))
 print("LOW_BUDGET quote=",scene._quote," fee=",scene._cost_details.text," color=",scene._cost_details.get_theme_color("font_color")," button_disabled=",scene._purchase.disabled," notice=",scene._notice.text)
 root.get_texture().get_image().save_png("/tmp/reactor-r5b-insufficient-before.png")
 click(scene._purchase.get_global_rect().get_center());await frames(3)
 assert(not scene.last_result.ok and str(scene.last_result.reason)=="InsufficientResources" and scene._notice.text=="资源不足")
 print("LOW_BUDGET_CLICK result=",scene.last_result," notice=",scene._notice.text)
 root.get_texture().get_image().save_png("/tmp/reactor-r5b-insufficient-click.png")
 click(scene._quantity.get_global_rect().get_center());await frames(2)
 click(scene._quantity.get_global_rect().get_center());await frames(4)
 assert(scene._quantity.text=="MAX" and scene._quote.ok and scene._quote.count==0 and not scene._purchase.disabled)
 print("MAX_ZERO quote=",scene._quote," cost=",scene._cost.text," details=",scene._cost_details.text," disabled=",scene._purchase.disabled)
 root.get_texture().get_image().save_png("/tmp/reactor-r5b-max-zero-before.png")
 click(scene._purchase.get_global_rect().get_center());await frames(2)
 assert(not scene.last_result.ok and str(scene.last_result.reason)=="InsufficientResources" and scene._notice.text=="资源不足")
 print("MAX_ZERO_CLICK result=",scene.last_result," notice=",scene._notice.text)
 quit()
