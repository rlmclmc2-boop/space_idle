extends Control
## Static snapshots of the live toon hulls. Module identity and capacity remain BattleGame-owned.
const LAYOUT := preload("res://dev/toon_ship/hybrid_layout.gd")
const PREVIEW_MANIFEST := "res://assets/ui/ships/manifest.json"
const CARD_FONT := preload("res://scripts/equipment_card.gd")
const NAVY := Color("243d50")
const PAPER := Color("ecebdc")
const TEAL := Color("83cfcb")
const MUTED := Color("546c74")
static var preview_data: Dictionary = {}
static var preview_textures: Dictionary = {}
var drone_texture: Texture2D
var drone_strip: Control
var drone_cards: Array[Button] = []
var drone_titles: Array[Label] = []
var drone_page_label: Label
var drone_previous: Button
var drone_next: Button
var drone_empty: Label
var drone_page := 0
var drone_context := ""

var preview_state: Label
var choice_titles: Dictionary = {}
var choice_capacities: Dictionary = {}
var choice_states: Dictionary = {}

static func hull_texture(key: String) -> Texture2D:
	if preview_data.is_empty():
		preview_data = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_MANIFEST))
	if not preview_textures.has(key):
		preview_textures[key] = load(str(preview_data.hulls[key].texture))
	return preview_textures[key]

func label(parent: Control, text: String, rect: Rect2, size: int, color := NAVY) -> Label:
	var field: Label = host.equipment_card_label(parent,text,rect,size,color)
	field.add_theme_font_override("font",CARD_FONT.face(600))
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return field

func skin(button: Button, primary := false) -> void:
	host.equipment_panel.skin_button(button,primary)
	button.add_theme_font_override("font",CARD_FONT.face(600))

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
	label(self,UIText.t("ship.refit.title"),Rect2(24,10,600,36),24,TEAL)
	information.append(label(self,UIText.t("ship.refit.hint"),Rect2(24,48,1260,28),18,Color("cbdcd9")))
	for region in [Rect2(16,94,250,1060),Rect2(274,94,776,1060),Rect2(1060,94,272,1060)]:
		var frame:=Panel.new()
		frame.position=region.position
		frame.size=region.size
		frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel",host.equipment_panel.panel_style(PAPER))
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
		choice.custom_minimum_size = Vector2(226,154)
		skin(choice)
		# Child labels own the visible ink; native text preserves accessibility.
		for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]:
			choice.add_theme_color_override(state,Color.TRANSPARENT)
		choice.add_theme_font_override("font",host.font)
		choice.add_theme_font_size_override("font_size",15)
		choice.pressed.connect(func():candidate=str(key); refresh())
		choice_list.add_child(choice)
		choices[key] = choice
		var thumbnail := TextureRect.new()
		thumbnail.position = Vector2(6,42)
		thumbnail.size = Vector2(78,78)
		thumbnail.texture = hull_texture(key)
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		choice.add_child(thumbnail)
		locked_previews[key] = thumbnail
		choice_titles[key] = label(choice,"",Rect2(86,40,134,34),22)
		choice_capacities[key] = label(choice,"",Rect2(86,78,134,72),21,MUTED)
		choice_capacities[key].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_capacities[key].text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		choice_states[key] = label(choice,"",Rect2(12,4,204,32),21,NAVY)
		var gate_label: Label = label(choice,"",Rect2(86,64,134,68),21,MUTED)
		gate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		locked_labels[key] = gate_label
	preview = Control.new()
	preview.position = Vector2(280,170)
	preview.size = Vector2(760,980)
	add_child(preview)
	picture = TextureRect.new()
	picture.position=Vector2(40,150)
	picture.size = Vector2(680,680)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(picture)
	setup_drone_strip()
	heading = label(self,"",Rect2(300,112,730,56),26)
	preview_state = label(preview,"",Rect2(32,846,700,44),22)
	var source_hint := label(preview,UIText.t("ship.refit.static_hint"),Rect2(32,906,700,56),19,MUTED)
	source_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	information.append(source_hint)
	information.append(label(self,UIText.t("ship.refit.mounts"),Rect2(1080,120,240,52),21))
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
	result = label(self,"",Rect2(1080,770,240,90),22)
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	confirm = Button.new()
	confirm.position = Vector2(1080,1032)
	confirm.size = Vector2(240,96)
	confirm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm.add_theme_font_override("font",host.font)
	confirm.add_theme_font_size_override("font_size",17)
	skin(confirm,true)
	confirm.add_theme_font_size_override("font_size",17)
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
	# TabContainer visibility is committed after its tab signal/input callback.
	# Refresh first once visible so a newly expanded slot exists before selection.
	host.equipment_panel.call_deferred("refresh")
	host.equipment_panel.call_deferred("select_item",id)

func refresh() -> void:
	if not is_visible_in_tree():return
	var current := str(host.game.profile.selectedShip)
	for key in choices:
		var row: Dictionary = host.db.ship(key)
		var text: String = UIText.data_text("ship",key,"des")+"\n"+UIText.t("ship.refit.capacity",{"weapons":str(int(row.weaponSlots)),"defence":str(int(row.defenseSlots))})
		var locked: bool = not host.game.ship_unlocked(key)
		if locked:text = ""
		host.set_ui_value(locked_previews[key],"material",silhouette if locked else null)
		host.set_ui_value(choice_titles[key],"visible",not locked)
		host.set_ui_value(choice_capacities[key],"visible",not locked)
		host.set_ui_value(choice_titles[key],"text",UIText.data_text("ship",key,"des"))
		host.set_ui_value(choice_capacities[key],"text",UIText.t("ship.refit.capacity_summary",{"weapons":str(int(row.weaponSlots)),"defence":str(int(row.defenseSlots))}))
		host.set_ui_value(choice_states[key],"text",UIText.t("ship.refit.active_badge") if current==key else UIText.t("ship.refit.preview_badge") if candidate==key else "")
		var has_state: bool=current==key or candidate==key
		var top := 32.0 if has_state else 0.0
		host.set_ui_value(choice_states[key],"visible",has_state)
		host.set_ui_value(choices[key],"custom_minimum_size",Vector2(226,122+top))
		host.set_ui_value(locked_previews[key],"position",Vector2(6,10+top))
		host.set_ui_value(choice_titles[key],"position",Vector2(86,8+top))
		host.set_ui_value(choice_capacities[key],"position",Vector2(86,46+top))
		host.set_ui_value(locked_labels[key],"position",Vector2(86,32+top))
		host.set_ui_value(locked_labels[key],"visible",locked)
		host.set_ui_value(locked_labels[key],"text",unlock_hint(key) if locked else "")
		host.set_ui_value(choices[key],"text",text)
		if host.ui_state_changed(choices[key],[candidate==key,current==key]):
			choices[key].add_theme_stylebox_override("normal",host.equipment_panel.panel_style(Color("d2ece5") if candidate==key else PAPER,Color("519caa") if candidate==key else NAVY))
	host.set_ui_value(picture,"texture",hull_texture(candidate))
	var hull: Dictionary = preview_data.hulls[candidate]
	var assignments: Dictionary = {}
	for item in LAYOUT.assign(host.game.module_entries("weapons"),host.game.active_slot_count("weapons",candidate),hull.mounts.size()):
		assignments[int(item.slot)] = item
	var locked: bool = not host.game.ship_unlocked(candidate)
	host.set_ui_value(picture,"material",silhouette if locked else null)
	host.set_ui_value(heading,"text",unlock_hint(candidate) if locked else UIText.data_text("ship",candidate,"des"))
	host.set_ui_value(preview_state,"visible",not locked)
	host.set_ui_value(preview_state,"text",UIText.t("ship.refit.active_preview" if candidate==current else "ship.refit.candidate_preview"))
	for control in information:host.set_ui_value(control,"visible",not locked)
	host.set_ui_value(result,"visible",not locked)
	host.set_ui_value(mount_scroll,"visible",not locked)
	host.set_ui_value(confirm,"visible",not locked)
	refresh_drone_strip(assignments,locked,current)
	if locked:
		for mount in mounts.values():host.set_ui_value(mount,"visible",false)
		return
	for id in mounts:
		var category: String = str(id).get_slice("_",0)
		var count: int = host.game.active_slot_count(category,candidate)
		host.set_ui_value(mounts[id],"visible",int(str(id).get_slice("_",1))<count)
	var active := 0
	for category in ["weapons","defence"]:
		var capacity: int = host.game.active_slot_count(category,candidate)
		active+=capacity
		var list_index := 0
		for index in capacity:
			var id: String = "%s_%d" % [category,index] # Candidate hull uses permanent module slots, not active combat sources.
			if not mounts.has(id):
				var mount := Button.new()
				mount.add_theme_font_override("font",host.font)
				skin(mount)
				mount.add_theme_font_size_override("font_size",21)
				mount.set_meta("slot_id",id)
				mount.pressed.connect(func():open_module(id))
				preview.add_child(mount)
				mounts[id]=mount
			var button: Button = mounts[id]
			var entry: Dictionary = host.game.module_entry(category,index)
			var key := str(entry.get("key",""))
			var prefix := ("W" if category=="weapons" else "D")+str(index+1).pad_zeros(2)
			var text: String = prefix+" · Lv."+str(entry.get("level",1))
			var assignment: Dictionary = assignments.get(index,{}) if category=="weapons" else {}
			var on_hull: bool = assignment.get("carrier","")=="hull"
			var target_parent: Control = preview if on_hull else mount_lists[category]
			if button.get_parent()!=target_parent:button.reparent(target_parent,false)
			host.set_ui_value(button,"autowrap_mode",TextServer.AUTOWRAP_OFF if on_hull else TextServer.AUTOWRAP_WORD_SMART)
			host.set_ui_value(button,"clip_text",not on_hull)
			host.set_ui_value(button,"custom_minimum_size",Vector2.ZERO if on_hull else Vector2(0,48))
			if on_hull:
				text=prefix
				host.set_ui_value(button,"text",text)
				var point: Array = hull.mounts[int(assignment.mount)]
				var center: Vector2 = picture.position+Vector2(float(point[0]),float(point[1]))*picture.size.x/float(preview_data.canvas[0])
				host.set_ui_value(button,"position",center-Vector2(44,28))
				# Godot may round fractional positions back into Control.size. Avoid no-op writes.
				if not button.size.is_equal_approx(Vector2(88,56)):host.set_ui_value(button,"size",Vector2(88,56))
			else:
				if button.get_index()!=list_index:mount_lists[category].move_child(button,list_index)
				list_index+=1
				# Active carrier and empty logical slots retain their exact IDs.
				text+="\n"+host.NAMES.get(key,UIText.t("equipment.vacant"))
				if assignment.get("carrier","")=="drone":text+=" · "+UIText.t("ship.refit.carrier")
			host.set_ui_value(button,"text",text)
			var module_hint:=UIText.t("ship.refit.module",{"slot":prefix,"name":host.NAMES.get(key,UIText.t("equipment.vacant")),"level":str(entry.get("level",1))})
			if assignment.get("carrier","")=="drone":module_hint+="\n"+UIText.t("ship.refit.carrier_hint")
			host.set_ui_value(button,"tooltip_text",module_hint)
			host.set_ui_value(button,"disabled",candidate!=current)
			if host.ui_state_changed(button,[key]):button.add_theme_stylebox_override("normal",host.equipment_panel.panel_style(TEAL))
	host.set_ui_value(result,"text",UIText.t("ship.refit.active_count",{"active":str(active)}))
	host.set_ui_value(confirm,"text",UIText.t("ship.refit.current" if candidate==current else ("ship.refit.apply" if host.game.ship_unlocked(candidate) else "ship.refit.locked")))
	host.set_ui_value(confirm,"tooltip_text",confirm.text)
	host.set_ui_value(confirm,"disabled",not host.game.ship_unlocked(candidate))

func unlock_hint(key: String) -> String:
	return UIText.t("ship.refit.unlock_estimate",{"level":str(int(host.db.unlock_row("ship",key).get("level",-1)))})

func setup_drone_strip() -> void:
	drone_strip=Control.new()
	drone_strip.size=Vector2(760,144)
	preview.add_child(drone_strip)
	drone_texture=load(str(preview_data.drone.texture))
	for index in 3:
		var card:=Button.new()
		card.position=Vector2(52+index*220,2)
		card.size=Vector2(216,114)
		skin(card)
		card.pressed.connect(func():open_module(str(card.get_meta("slot_id",""))))
		drone_strip.add_child(card)
		var image:=TextureRect.new()
		image.position=Vector2(54,0)
		image.size=Vector2(108,84)
		image.texture=drone_texture
		image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card.add_child(image)
		drone_cards.append(card)
		drone_titles.append(label(card,"",Rect2(4,84,208,28),18))
		drone_titles.back().horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	drone_previous=Button.new()
	drone_previous.position=Vector2(0,34)
	drone_previous.size=Vector2(42,44)
	drone_previous.text="‹"
	skin(drone_previous)
	drone_previous.pressed.connect(func():drone_page-=1;refresh())
	drone_strip.add_child(drone_previous)
	drone_next=Button.new()
	drone_next.position=Vector2(718,34)
	drone_next.size=Vector2(42,44)
	drone_next.text="›"
	skin(drone_next)
	drone_next.pressed.connect(func():drone_page+=1;refresh())
	drone_strip.add_child(drone_next)
	drone_page_label=label(drone_strip,"",Rect2(52,118,656,26),18,MUTED)
	drone_page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	drone_empty=label(drone_strip,UIText.t("ship.refit.carrier_empty"),Rect2(52,34,656,48),21,MUTED)
	drone_empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func refresh_drone_strip(assignments: Dictionary, locked: bool, current: String) -> void:
	host.set_ui_value(drone_strip,"visible",not locked)
	if locked:return
	if drone_context!=candidate:
		drone_context=candidate
		drone_page=0
	var slots: Array[int]=[]
	for slot in assignments:
		if assignments[slot].carrier=="drone":slots.append(int(slot))
	slots.sort()
	var pages:=maxi(1,ceili(float(slots.size())/3.0))
	drone_page=clampi(drone_page,0,pages-1)
	host.set_ui_value(drone_empty,"visible",slots.is_empty())
	host.set_ui_value(drone_page_label,"visible",not slots.is_empty())
	host.set_ui_value(drone_page_label,"text",UIText.t("ship.refit.carrier_page",{"page":str(drone_page+1),"pages":str(pages),"count":str(slots.size())}))
	host.set_ui_value(drone_previous,"visible",pages>1)
	host.set_ui_value(drone_next,"visible",pages>1)
	host.set_ui_value(drone_previous,"disabled",drone_page==0)
	host.set_ui_value(drone_next,"disabled",drone_page==pages-1)
	for index in drone_cards.size():
		var card:=drone_cards[index]
		var ordinal:=drone_page*3+index
		host.set_ui_value(card,"visible",ordinal<slots.size())
		if ordinal>=slots.size():continue
		var slot:=slots[ordinal]
		var id:String="weapons_%d" % slot
		if card.get_meta("slot_id","")!=id:card.set_meta("slot_id",id)
		var entry:Dictionary=host.game.module_entry("weapons",slot)
		var prefix:="W"+str(slot+1).pad_zeros(2)
		var name:String=host.NAMES.get(str(entry.get("key","")),UIText.t("equipment.vacant"))
		host.set_ui_value(drone_titles[index],"text",prefix+" · "+name)
		host.set_ui_value(card,"tooltip_text",UIText.t("ship.refit.module",{"slot":prefix,"name":name,"level":str(entry.get("level",1))})+"\n"+UIText.t("ship.refit.carrier_hint"))
		host.set_ui_value(card,"disabled",candidate!=current)
