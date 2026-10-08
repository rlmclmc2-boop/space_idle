extends Button
## One persistent card and interaction map for every weapon/defence module.
signal equip_requested
signal equipment_selected(key: String)
signal upgrade_requested
const MIN_SIZE := Vector2(310,176)
const ACTION_SIZE := Vector2(246,56)
const INK := Color("243d50")
const MUTED := Color("546c74")
const Chrome := preload("res://scripts/dialog_presentation.gd")
static var fonts: Dictionary = {}
var host: Node
var panel: Control
var fields: Dictionary = {}
var picture: TextureRect
var last_state: Array = []
var normal_style_key := -1
var upgrade_button: Button
var equip_button: Button
var name_button: OptionButton
var equipment_options: Array = []
var options_state: Array = []
var slot_id := ""
var is_locked := false
var is_equipped := false
var is_weapon := false

static func face(weight: int) -> Font:
	if not fonts.has(weight):
		var variant := FontVariation.new()
		variant.base_font = preload("res://assets/fonts/NotoSansSC.ttf")
		variant.variation_opentype = {2003265652:float(weight)}
		variant.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"):1}
		fonts[weight] = variant
	return fonts[weight]

func text_field(parent: Control, rect: Rect2, font_size: int, weight: int, color: Color) -> Label:
	var field: Label = host.equipment_card_label(parent,"",rect,font_size,color)
	field.add_theme_font_override("font",face(weight))
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return field

func setup(owner_ui: Node, equipment_panel: Control) -> void:
	host = owner_ui
	panel = equipment_panel
	custom_minimum_size = MIN_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	picture = TextureRect.new()
	picture.position = Vector2(14,10)
	picture.size = Vector2(64,64)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	fields.title = text_field(self,Rect2(88,8,208,34),23,650,INK)
	fields.title.hide()
	name_button = OptionButton.new()
	name_button.flat = true
	name_button.fit_to_longest_item = false
	Chrome.option(name_button,false)
	var menu := name_button.get_popup()
	menu.add_theme_font_override("font",face(500))
	menu.add_theme_font_size_override("font_size",23)
	menu.add_theme_color_override("font_disabled_color",MUTED)
	menu.add_theme_constant_override("v_separation",12)
	menu.about_to_popup.connect(func():call_deferred("place_refit_menu"))
	name_button.set_meta("action_id","swap_module")
	name_button.tooltip_text = UIText.t("equipment.swap")
	name_button.add_theme_font_override("font",face(650))
	name_button.add_theme_font_size_override("font_size",23)
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color"]:
		name_button.add_theme_color_override(state,INK)
	name_button.item_selected.connect(func(index: int):
		if index>=0 and index<equipment_options.size():equipment_selected.emit(str(equipment_options[index])))
	add_child(name_button)
	fields.level = text_field(self,Rect2(88,43,208,31),21,500,MUTED)
	fields.caption = text_field(self,Rect2(14,80,76,32),21,500,MUTED)
	fields.stat = text_field(self,Rect2(92,74,204,44),30,650,INK)
	fields.stat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fields.status = text_field(self,Rect2(14,80,282,32),21,500,MUTED)
	fields.type = text_field(self,Rect2(),21,500,MUTED)
	fields.upgrade = text_field(self,Rect2(),21,500,MUTED)
	fields.type.hide()
	fields.upgrade.hide()
	upgrade_button = panel.action_button(self,"equipment.action.upgrade","upgrade_action",func():upgrade_requested.emit(),true)
	upgrade_button.custom_minimum_size = ACTION_SIZE
	upgrade_button.size = ACTION_SIZE
	upgrade_button.clip_text = true
	# Keep native button text for accessibility and semantic tooling; children own ink.
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_disabled_color","font_focus_color"]:
		upgrade_button.add_theme_color_override(state,Color.TRANSPARENT)
	fields.action = text_field(upgrade_button,Rect2(16,0,50,56),21,500,INK)
	fields.action.text = UIText.t("equipment.upgrade_cost",{"cost":""}).strip_edges()
	fields.action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fields.cost = text_field(upgrade_button,Rect2(66,0,164,56),24,650,INK)
	fields.cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fields.cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equip_button = panel.action_button(self,"equipment.free_equip","empty_module",func():equip_requested.emit(),true)
	equip_button.add_theme_font_override("font",face(500))
	equip_button.add_theme_font_size_override("font_size",21)
	# Empty slots retain both actions without overlapping the shared bottom button.
	for state in ["normal","hover","pressed","disabled"]:
		var box: StyleBox = equip_button.get_theme_stylebox(state).duplicate()
		# Resource.duplicate does not preserve the source style's signal link.
		# This copy also needs its draw commands invalidated after tile freezing.
		if box is StyleBoxTexture and box.texture is AtlasTexture:
			if not box.texture.changed.is_connected(box.emit_changed):
				box.texture.changed.connect(box.emit_changed)
		box.content_margin_top = 2
		box.content_margin_bottom = 2
		equip_button.add_theme_stylebox_override(state,box)
	equip_button.custom_minimum_size = Vector2(246,36)
	equip_button.size = Vector2(246,36)
	resized.connect(layout_contents)
	add_theme_stylebox_override("hover",panel.textured_panel_style(Color("f8f7e9"),Color("519caa")))
	add_theme_stylebox_override("pressed",panel.textured_panel_style(Color("d8e6de")))
	add_theme_stylebox_override("focus",panel.textured_panel_style(Color.TRANSPARENT,panel.TEAL))
	layout_contents()

func layout_contents() -> void:
	if not is_instance_valid(upgrade_button):return
	fields.title.size.x = size.x-102
	name_button.position = Vector2(88,8)
	name_button.size = Vector2(size.x-102,34)
	fields.level.size.x = size.x-102
	host.set_ui_value(fields.caption,"size",Vector2(108 if is_weapon else 76,32))
	host.set_ui_value(fields.stat,"position",Vector2(126 if is_weapon else 92,74))
	host.set_ui_value(fields.stat,"size",Vector2(size.x-(140 if is_weapon else 106),44))
	fields.status.size.x = size.x-28
	upgrade_button.position = Vector2((size.x-ACTION_SIZE.x)/2,118)
	upgrade_button.size = ACTION_SIZE
	equip_button.position = Vector2((size.x-246)/2,76)
	equip_button.size = Vector2(246,36)

func refresh(item: Dictionary, chosen: bool) -> void:
	var state := [item.name,item.level,item.get("levelText",str(item.level)),item.category,item.mainStatLabel,item.mainStatValue,item.status,item.upgradeable,item.locked,chosen,item.tooltip,item.icon,item.get("cost",""),item.get("direct_upgradeable",false),item.get("refit_locked",false)]
	refresh_options(item)
	if last_state == state:return
	last_state = state
	slot_id = item.id
	is_locked = item.locked
	is_equipped = item.equipped
	if is_weapon!=(item.category=="weapons"):
		is_weapon=item.category=="weapons"
		layout_contents()
	set_meta("slot_id",slot_id)
	set_meta("action_id","module_select")
	upgrade_button.set_meta("slot_id",slot_id)
	equip_button.set_meta("slot_id",slot_id)
	name_button.set_meta("slot_id",slot_id)
	host.set_ui_value(name_button,"disabled",item.locked or item.get("refit_locked",false))
	host.set_ui_value(fields.title,"text",item.name)
	host.set_ui_value(fields.level,"text",UIText.t("equipment.level",{"level":item.get("levelText",str(item.level))}))
	host.set_ui_value(fields.type,"text",UIText.t("weapon.tab" if item.category=="weapons" else "defense.tab"))
	host.set_ui_value(fields.caption,"text",item.mainStatLabel)
	host.set_ui_value(fields.stat,"text",item.mainStatValue)
	host.set_ui_value(fields.caption,"visible",item.equipped and not item.locked)
	host.set_ui_value(fields.stat,"visible",item.equipped and not item.locked)
	host.set_ui_value(fields.status,"text",UIText.t("equipment.dormant") if item.locked else "")
	host.set_ui_value(fields.status,"visible",item.locked)
	host.set_ui_value(fields.upgrade,"text",UIText.t("equipment.state.upgradeable") if item.upgradeable else "")
	host.set_ui_value(self,"tooltip_text",item.tooltip)
	host.set_ui_value(picture,"texture",item.icon)
	host.set_ui_value(equip_button,"visible",not item.equipped and not item.locked)
	host.set_ui_value(upgrade_button,"disabled",not item.get("direct_upgradeable",false))
	host.set_ui_value(upgrade_button,"text",UIText.t("equipment.upgrade_cost",{"cost":item.get("cost","—")}))
	host.set_ui_value(upgrade_button,"tooltip_text",upgrade_button.text)
	host.set_ui_value(fields.cost,"text",item.get("cost","—"))
	var style_key := int(item.locked)*2+int(chosen)
	if normal_style_key!=style_key:
		normal_style_key=style_key
		add_theme_stylebox_override("normal",panel.textured_panel_style(Color("acbabd") if item.locked else Color("d2ece5") if chosen else panel.PAPER,Color("64babd") if chosen else panel.NAVY))

func refresh_options(item: Dictionary) -> void:
	var options: Array = panel.equipment_choices(item.category,int(item.index))
	var state := [item.category,item.index,item.key,item.locked,options]
	if options_state==state and name_button.selected==equipment_options.find(item.key):
		host.set_ui_value(name_button,"text",item.name)
		return
	options_state=state
	if equipment_options!=options:
		equipment_options = options
		name_button.clear()
		for key in equipment_options:name_button.add_item("")
	for index in equipment_options.size():
		var key: String = equipment_options[index]
		var title := str(host.NAMES.get(key,UIText.t("equipment.vacant")))
		if name_button.get_item_text(index)!=title:name_button.set_item_text(index,title)
		var blocked: bool = item.locked
		if name_button.is_item_disabled(index)!=blocked:name_button.set_item_disabled(index,blocked)
	var current := equipment_options.find(item.key)
	if name_button.selected!=current:name_button.select(current)
	# The card retains its slot identity; native menu rows contain equipment names.
	host.set_ui_value(name_button,"text",item.name)

func place_refit_menu() -> void:
	var menu := name_button.get_popup()
	if not menu.visible:return
	# Same screen space for anchor and playable viewport, including window offset
	# and letterboxing. Native OptionButton still owns selection and radio marks.
	var transform := name_button.get_screen_transform()
	var anchor := transform * Rect2(Vector2.ZERO,name_button.size)
	var viewport_transform := transform * name_button.get_global_transform_with_canvas().affine_inverse()
	var bounds := (viewport_transform * name_button.get_viewport_rect()).grow(-8.0)
	var width := maxf(menu.get_contents_minimum_size().x,size.x*transform.get_scale().x)
	menu.max_size = Vector2i(bounds.size)
	menu.min_size = Vector2i(ceili(minf(width,bounds.size.x)),0)
	menu.size = Vector2i(ceili(minf(width,bounds.size.x)),ceili(minf(menu.get_contents_minimum_size().y,bounds.size.y)))
	var extent := Vector2(menu.size)
	var point := Vector2(anchor.position.x,anchor.end.y+4.0)
	if point.y+extent.y>bounds.end.y:point.y=anchor.position.y-extent.y-4.0
	point.x=clampf(point.x,bounds.position.x,maxf(bounds.position.x,bounds.end.x-extent.x))
	point.y=clampf(point.y,bounds.position.y,maxf(bounds.position.y,bounds.end.y-extent.y))
	menu.position=Vector2i(point)
