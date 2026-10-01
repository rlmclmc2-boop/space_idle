extends Control
## Read-only hull preview. Mount buttons reuse the authoritative module identities.
var host: Node
var candidate := ""
var choices: Dictionary = {}
var mounts: Dictionary = {}
var picture: TextureRect
var heading: Label
var result: Label
var confirm: Button
var preview: Control
var silhouette: ShaderMaterial
var locked_previews: Dictionary = {}
var locked_labels: Dictionary = {}
var information: Array[Control] = []
var choice_scroll: ScrollContainer
var mount_scroll: ScrollContainer
var mount_lists: Dictionary = {}

func setup(owner_ui: Node) -> void:
	host = owner_ui
	candidate = str(host.game.profile.selectedShip)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { vec4 pixel = texture(TEXTURE, UV); COLOR = vec4(vec3(0.16, 0.22, 0.28), pixel.a); }"
	silhouette = ShaderMaterial.new()
	silhouette.shader = shader
	host.equipment_card_label(self,UIText.t("ship.refit.title"),Rect2(24,10,600,36),24,host.CYAN)
	information.append(host.equipment_card_label(self,UIText.t("ship.refit.hint"),Rect2(24,48,1260,28),14,host.MUTED))
	for region in [Rect2(16,94,250,1060),Rect2(274,94,776,1060),Rect2(1060,94,272,1060)]:
		var frame:=Panel.new()
		frame.position=region.position
		frame.size=region.size
		frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel",host.style(host.PANEL,host.LINE))
		add_child(frame)
	choice_scroll=ScrollContainer.new()
	choice_scroll.position=Vector2(24,105)
	choice_scroll.size=Vector2(234,1038)
	choice_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(choice_scroll)
	var choice_list:=VBoxContainer.new()
	choice_list.add_theme_constant_override("separation",10)
	choice_scroll.add_child(choice_list)
	for key in host.db.ships:
		var choice := Button.new()
		choice.custom_minimum_size = Vector2(226,82)
		choice.add_theme_font_override("font",host.font)
		choice.add_theme_font_size_override("font_size",15)
		choice.pressed.connect(func():candidate=str(key); refresh())
		choice_list.add_child(choice)
		choices[key] = choice
		var thumbnail := TextureRect.new()
		thumbnail.position = Vector2(8,6)
		thumbnail.size = Vector2(80,58)
		thumbnail.texture = host.ship_hull_texture(key)
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.material = silhouette
		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		choice.add_child(thumbnail)
		locked_previews[key] = thumbnail
		var gate_label: Label = host.equipment_card_label(choice,"",Rect2(92,14,130,44),12,host.MUTED)
		gate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		locked_labels[key] = gate_label
	preview = Control.new()
	preview.position = Vector2(280,170)
	preview.size = Vector2(760,880)
	add_child(preview)
	picture = TextureRect.new()
	picture.position=Vector2(0,160)
	picture.size = Vector2(760,500)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(picture)
	heading = host.equipment_card_label(self,"",Rect2(300,112,730,56),18,host.CYAN)
	information.append(host.equipment_card_label(self,UIText.t("ship.refit.mounts"),Rect2(1080,120,240,52),13,host.MUTED))
	mount_scroll = ScrollContainer.new()
	mount_scroll.position = Vector2(1080,200)
	mount_scroll.size = Vector2(240,550)
	mount_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(mount_scroll)
	var mount_list := VBoxContainer.new()
	mount_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mount_list.add_theme_constant_override("separation",18)
	mount_scroll.add_child(mount_list)
	for category in ["defence","weapons"]:
		var rows := VBoxContainer.new()
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_theme_constant_override("separation",8)
		mount_list.add_child(rows)
		mount_lists[category] = rows
	result = host.equipment_card_label(self,"",Rect2(1080,770,240,74),16,host.CYAN)
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	confirm = Button.new()
	confirm.position = Vector2(1080,1032)
	confirm.size = Vector2(240,56)
	confirm.add_theme_font_override("font",host.font)
	confirm.add_theme_font_size_override("font_size",17)
	host.skin_equipment_button(confirm,true)
	confirm.pressed.connect(func():
		if candidate==str(host.game.profile.selectedShip):open_module("weapons_0")
		else:host.game.switch_ship(candidate)
		refresh())
	add_child(confirm)
	visibility_changed.connect(func():
		if is_visible_in_tree():refresh())
	refresh()

func open_module(id: String) -> void:
	if candidate!=str(host.game.profile.selectedShip):return
	host.equipment_tabs.current_tab=0
	host.equipment_panel.refresh()
	host.equipment_panel.select_item(id)

func refresh() -> void:
	if not is_visible_in_tree():return
	var current := str(host.game.profile.selectedShip)
	for key in choices:
		var row: Dictionary = host.db.ship(key)
		var text: String = UIText.data_text("ship",key,"des")+"\n"+UIText.t("ship.refit.capacity",{"weapons":str(int(row.weaponSlots)),"defence":str(int(row.defenseSlots))})
		var locked: bool = not host.game.ship_unlocked(key)
		if locked:text = ""
		host.set_ui_value(locked_previews[key],"visible",locked)
		host.set_ui_value(locked_labels[key],"visible",locked)
		host.set_ui_value(locked_labels[key],"text",unlock_hint(key) if locked else "")
		host.set_ui_value(choices[key],"text",text)
		if host.ui_state_changed(choices[key],[candidate==key,current==key]):
			choices[key].add_theme_stylebox_override("normal",host.style(Color("183341") if candidate==key else Color("0c1c2b"),host.CYAN if candidate==key else Color("87caa8") if current==key else host.LINE))
	host.set_ui_value(picture,"texture",host.ship_hull_texture(candidate))
	var preview_scale: float = host.player_art_scale_for(candidate)/0.36*1.3
	var preview_size := Vector2(760,500)*preview_scale
	host.set_ui_value(picture,"size",preview_size)
	host.set_ui_value(picture,"position",Vector2(380,410)-preview_size*0.5)
	var locked: bool = not host.game.ship_unlocked(candidate)
	host.set_ui_value(picture,"material",silhouette if locked else null)
	host.set_ui_value(heading,"text",unlock_hint(candidate) if locked else UIText.data_text("ship",candidate,"des"))
	for control in information:host.set_ui_value(control,"visible",not locked)
	host.set_ui_value(result,"visible",not locked)
	host.set_ui_value(mount_scroll,"visible",not locked)
	host.set_ui_value(confirm,"visible",not locked)
	if locked:
		for mount in mounts.values():host.set_ui_value(mount,"visible",false)
		return
	for id in mounts:
		var category: String = str(id).get_slice("_",0)
		var count: int = maxi(host.game.active_slot_count(category,candidate),host.game.module_entries(category).size())
		host.set_ui_value(mounts[id],"visible",int(str(id).get_slice("_",1))<count)
	var active := 0
	var dormant := 0
	for category in ["weapons","defence"]:
		var capacity: int = host.game.active_slot_count(category,candidate)
		active+=capacity
		dormant+=maxi(0,host.game.module_entries(category).size()-capacity)
		for index in maxi(capacity,host.game.module_entries(category).size()):
			var id: String = host.game.slot_id(category,index)
			if not mounts.has(id):
				var mount := Button.new()
				mount.add_theme_font_override("font",host.font)
				mount.add_theme_font_size_override("font_size",11)
				mount.pressed.connect(func():open_module(id))
				preview.add_child(mount)
				mounts[id]=mount
			var button: Button = mounts[id]
			var entry: Dictionary = host.game.module_entry(category,index)
			var key := str(entry.get("key",""))
			var prefix := ("W" if category=="weapons" else "D")+str(index+1).pad_zeros(2)
			var text: String = prefix+" · Lv."+str(entry.get("level",1))
			var enabled := index<capacity
			var on_hull: bool = category=="weapons" and enabled
			var target_parent: Control = preview if on_hull else mount_lists[category]
			if button.get_parent()!=target_parent:button.reparent(target_parent,false)
			host.set_ui_value(button,"autowrap_mode",TextServer.AUTOWRAP_OFF if on_hull else TextServer.AUTOWRAP_WORD_SMART)
			host.set_ui_value(button,"clip_text",not on_hull)
			host.set_ui_value(button,"custom_minimum_size",Vector2.ZERO if on_hull else Vector2(0,48))
			if on_hull:
				var center: Vector2 = host.player_mount_center(candidate,index).rotated(-PI/2)*preview_size.y/(1774.0*float(host.battle_visual.player_core_scale))+Vector2(380,410)
				host.set_ui_value(button,"position",center-Vector2(36,16))
				host.set_ui_value(button,"size",Vector2(72,32))
			else:
				# The column owns row height and width; long names wrap and overflow scrolls.
				text+="\n"+host.NAMES.get(key,UIText.t("equipment.vacant"))
			if not enabled:text+=" · "+UIText.t("equipment.state.locked")
			host.set_ui_value(button,"text",text)
			host.set_ui_value(button,"tooltip_text",UIText.t("ship.refit.module",{"slot":prefix,"name":host.NAMES.get(key,UIText.t("equipment.vacant")),"level":str(entry.get("level",1))}))
			host.set_ui_value(button,"disabled",candidate!=current)
			if host.ui_state_changed(button,[enabled,key]):button.add_theme_stylebox_override("normal",host.style(Color("123746") if enabled else Color("17202a"),host.CYAN.darkened(0.5) if enabled else host.LINE))
	host.set_ui_value(result,"text",UIText.t("ship.refit.result",{"active":str(active),"dormant":str(dormant)}))
	host.set_ui_value(confirm,"text",UIText.t("ship.refit.current" if candidate==current else ("ship.refit.apply" if host.game.ship_unlocked(candidate) else "ship.refit.locked")))
	host.set_ui_value(confirm,"disabled",not host.game.ship_unlocked(candidate))

func unlock_hint(key: String) -> String:
	return UIText.t("ship.refit.unlock_estimate",{"level":str(int(host.db.unlock_row("ship",key).get("level",-1)))})
