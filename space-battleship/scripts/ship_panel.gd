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

func setup(owner_ui: Node) -> void:
	host = owner_ui
	candidate = str(host.game.profile.selectedShip)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { vec4 pixel = texture(TEXTURE, UV); COLOR = vec4(vec3(0.16, 0.22, 0.28), pixel.a); }"
	silhouette = ShaderMaterial.new()
	silhouette.shader = shader
	host.equipment_card_label(self,UIText.t("ship.refit.title"),Rect2(24,10,600,36),24,host.CYAN)
	information.append(host.equipment_card_label(self,UIText.t("ship.refit.hint"),Rect2(24,48,1260,28),14,host.MUTED))
	var index := 0
	for key in host.db.ships:
		var choice := Button.new()
		choice.position = Vector2(24,98+index*85)
		choice.size = Vector2(230,72)
		choice.add_theme_font_override("font",host.font)
		choice.add_theme_font_size_override("font_size",15)
		choice.pressed.connect(func():candidate=str(key); refresh())
		add_child(choice)
		choices[key] = choice
		var thumbnail := TextureRect.new()
		thumbnail.position = Vector2(8,6)
		thumbnail.size = Vector2(80,58)
		thumbnail.texture = host.SHIP_TEXTURES[key]
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
		index+=1
	preview = Control.new()
	preview.position = Vector2(280,100)
	preview.size = Vector2(760,360)
	add_child(preview)
	picture = TextureRect.new()
	picture.size = Vector2(760,380)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(picture)
	heading = host.equipment_card_label(self,"",Rect2(300,80,740,30),18,host.CYAN)
	information.append(host.equipment_card_label(self,UIText.t("ship.refit.mounts"),Rect2(300,470,740,26),12,host.MUTED))
	result = host.equipment_card_label(self,"",Rect2(300,506,730,30),16,host.CYAN)
	var hint: Label = host.equipment_card_label(self,UIText.t("ship.refit.keep"),Rect2(300,543,730,80),13,host.MUTED)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	information.append(hint)
	confirm = Button.new()
	confirm.position = Vector2(1080,532)
	confirm.size = Vector2(240,48)
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
	host.equipment_panel.set_view_mode("expanded")

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
			choices[key].add_theme_stylebox_override("normal",host.style(Color("183341") if candidate==key else Color("0c1c2b"),host.CYAN if candidate==key else host.LINE))
	host.set_ui_value(picture,"texture",host.SHIP_TEXTURES[candidate])
	var locked: bool = not host.game.ship_unlocked(candidate)
	host.set_ui_value(picture,"material",silhouette if locked else null)
	host.set_ui_value(heading,"text",unlock_hint(candidate) if locked else UIText.data_text("ship",candidate,"des"))
	for control in information:host.set_ui_value(control,"visible",not locked)
	host.set_ui_value(result,"visible",not locked)
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
			if category=="weapons" and enabled:
				var center: Vector2 = host.SHIP_VISUALS.center(candidate,index)*760.0/1774.0+Vector2(380,190)
				host.set_ui_value(button,"position",center-Vector2(36,16))
				host.set_ui_value(button,"size",Vector2(72,32))
			else:
				host.set_ui_value(button,"position",Vector2(800,24+index*39 if category=="defence" else 200+(index-capacity)*32))
				host.set_ui_value(button,"size",Vector2(240,30))
				text+=" · "+host.NAMES.get(key,UIText.t("equipment.vacant"))
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
