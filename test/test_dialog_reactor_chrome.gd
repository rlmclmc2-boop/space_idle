extends SceneTree

const SKIN := preload("res://scripts/dialog_presentation.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.gui_embed_subwindows = true
	var scene = load("res://main.tscn").instantiate()
	scene.automation_args=["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.game.save_enabled=false
	scene.game.profile.cleared=range(1,101)
	scene.game.rebuild_unlocks()
	scene.game.pending_unlocks.clear()
	scene.build_ui()
	scene.equipment_tabs.current_tab=2
	await process_frame
	var panel = scene.reactor_panel
	panel.equalize_button.pressed.emit()
	var saved_allocation: Dictionary=scene.game.profile.reactorAllocation.duplicate(true)
	check(panel.module_controls.size()==4 and scene.game.reactor_allocated()==scene.game.reactor_capacity(),"Four modules share the full pool")
	check(panel.scroll_hint.text.begins_with(UIText.t("reactor.scroll_range",{"first":1,"last":3,"total":4})) and panel.scroll_hint.text.contains(UIText.t("reactor.scroll_more")),"First page explicitly identifies fourth-module overflow")
	check(panel.module_scroll.get_v_scroll_bar().visible and panel.allocation_scroll.get_v_scroll_bar().visible,"Both linked columns expose a scrollbar")
	panel.module_scroll.go_to_slot(1)
	await process_frame
	check(panel.allocation_scroll.current_slot()==1 and panel.scroll_hint.text.begins_with(UIText.t("reactor.scroll_range",{"first":2,"last":4,"total":4})),"Scroll range follows both linked columns")
	check(scene.game.profile.reactorAllocation==saved_allocation,"Scrolling never reallocates power")
	scene.equipment_tabs.current_tab=0
	scene.equipment_tabs.current_tab=2
	await process_frame
	check(panel.module_scroll.current_slot()==1,"Leaving and reopening preserves scroll")
	var popup: PopupMenu = scene.guard_settings.get_popup()
	check(popup.theme.get_stylebox("panel","PopupMenu").bg_color==SKIN.PAPER,"Settings popup uses scoped paper skin")
	var original_page_theme: Theme = scene.ui.theme
	scene.planet_panel.show_bonuses("1")
	await process_frame
	var dialog: AcceptDialog = scene.planet_panel.bonus_dialog
	check(dialog.visible and dialog.ok_button_text==UIText.t("system.confirm"),"Planet bonus opens with Chinese confirmation")
	check(dialog.get_ok_button().get_theme_color("font_color")==SKIN.NAVY,"Dialog confirmation uses legible navy text")
	dialog.hide()
	scene.planet_panel.show_bonuses("2")
	await process_frame
	check(scene.planet_panel.bonus_dialog==dialog and dialog.visible and scene.planet_panel.bonus_planet_id=="2","Bonus close/reopen reuses the modal and updates its target")
	dialog.hide()
	check(scene.ui.theme==original_page_theme,"Scoped popup/dialog styling preserves the dark page theme")
	var confirmation := ConfirmationDialog.new()
	SKIN.dialog(confirmation)
	check(confirmation.ok_button_text==UIText.t("system.confirm") and confirmation.cancel_button_text==UIText.t("system.cancel"),"Engine default confirm/cancel are localized")
	confirmation.free()
	print("Dialog/reactor chrome: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
