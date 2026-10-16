extends Control
## Current-stage route projection. No combat actors or RNG are created here.
var host: Node
var route_stage := -1
var route_builds := 0
var detail_builds := 0
var entries: Array[Dictionary] = []
var selected := -1
var list: ItemList
var detail: VBoxContainer
var heading: Label
var image: TextureRect
var detail_lines: Array[Label] = []
var detail_cursor := 0

func setup(owner: Node) -> void:
	host = owner
	name = "EnemyIntel"
	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation",20)
	add_child(layout)
	list = ItemList.new()
	list.custom_minimum_size.x = 420
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_font_size_override("font_size",22)
	list.add_theme_constant_override("v_separation",16)
	list.item_selected.connect(show_entry)
	layout.add_child(list)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(detail_scroll)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",14)
	detail_scroll.add_child(detail)
	heading = add_label(detail,"",30)
	image = TextureRect.new()
	image.custom_minimum_size = Vector2(300,280)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(image)
	for index in 10:
		var line := add_label(detail,"",19 if index==0 else 22)
		line.visible = false
		detail_lines.append(line)
	visibility_changed.connect(refresh_if_needed)

func add_label(parent: Node, value: String, size: int = 22) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func refresh_if_needed() -> void:
	if not visible or not is_instance_valid(host) or host.game == null:return
	if route_stage == host.game.stage:return
	route_builds += 1
	route_stage = host.game.stage
	entries.clear()
	selected = -1
	var level: Dictionary = host.db.levels[route_stage-1]
	for point in level.groups.size():
		var group: Dictionary = host.db.groups[str(int(level.groups[point].id))]
		var counts: Dictionary = {}
		for id in group.slots:
			if id != null:counts[str(int(id))] = int(counts.get(str(int(id)),0))+1
		for id in counts:
			entries.append({"id":id,"point":point,"count":counts[id]})
	list.clear()
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var row: Dictionary = host.db.enemies[entry.id]
		list.add_item(UIText.t("enemy.intel.list_item",{"point":str(int(entry.point)+1),"name":str(row.get("intelName",row.des)),"count":str(entry.count)}))
	if not entries.is_empty():list.select(0)
	show_entry(0 if not entries.is_empty() else -1)

func show_entry(index: int) -> void:
	if index==selected:return
	detail_builds += 1
	selected = index
	detail_cursor = 0
	for line in detail_lines:line.visible = false
	if index<0:
		heading.text = UIText.t("enemy.intel.empty")
		image.visible = false
		return
	var entry: Dictionary = entries[index]
	var row: Dictionary = host.db.enemies[entry.id]
	heading.text = str(row.get("intelName",row.des))
	image.visible = true
	var visual_ref := str(row.get("intelVisualRef",row.get("archetype_id","")))
	var visual_source := {"archetype_id":visual_ref,"armourType":row.armourType,"size":row.size}
	image.texture = host.ship_hull_texture(host.enemy_visual_identity.resolve(visual_source,host.visual_config))
	add_detail_line(UIText.t("enemy.intel.identity",{"point":str(int(entry.point)+1),"count":str(entry.count)}))
	var summary := str(row.get("intelTrait",""))
	add_detail_line(summary if not summary.is_empty() else UIText.t("enemy.intel.missing"))
	if summary.is_empty():push_warning("Enemy intelligence missing for mon "+str(entry.id))
	var stage := route_stage
	var point := int(entry.point)
	var health = host.db.enemy_encounter_capacity(row,stage,point,"health")
	add_detail_line(UIText.t("enemy.intel.armour",{"health":host.number(health),"resistance":resistance_text(int(row.armourType))}))
	var shield = host.db.enemy_encounter_capacity(row,stage,point,"shield")
	add_detail_line(UIText.t("enemy.intel.shield",{"capacity":host.number(shield),"resistance":resistance_text(int(row.get("shieldType",0)))}))
	var attacks: Dictionary = {}
	for mount in row.equipment:
		attacks[str(mount.name)] = int(attacks.get(str(mount.name),0))+1
	for key in attacks:
		var weapon: Dictionary = host.db.enemy_weapon(str(key))
		var base_key := str(key).replace("_mon", "").replace("-mon", "")
		var weapon_name := UIText.t("weapon."+base_key+"_name") if base_key in ["laser","cannon","missile","longLaser"] else str(key)
		add_detail_line(UIText.t("enemy.intel.attack",{"name":weapon_name,"count":str(attacks[key]),"damage":host.number(host.db.enemy_attack_damage(row,weapon,stage,point)),"type":resistance_text(int(weapon.dmgtype)),"cooldown":duration_text(float(weapon.cd))}))
	var mechanics: Array = row.get("intelMechanics",[])
	if mechanics.is_empty():add_detail_line(UIText.t("enemy.intel.no_mechanic"))
	for mechanic in mechanics:
		match str(mechanic):
			"reactiveReduction":
				add_detail_line(UIText.t("enemy.intel.reactive",{"stacks":str(host.game.REACTIVE_STACK_LIMIT),"reduction":host.number(host.game.REACTIVE_STACK_REDUCTION*100.0),"window":duration_text(host.game.REACTIVE_RESET_SECONDS)}))
			"shieldRecovery":
				add_detail_line(UIText.t("enemy.intel.recovery",{"delay":duration_text(float(row.shieldDelay)),"rate":host.number(float(row.shieldRecovery)*100.0)}))

func duration_text(seconds: float) -> String:
	# Every authored enemy timer and the reactive reset interval is in whole milliseconds.
	return str(roundi(seconds*1000.0))+" 毫秒"

func add_detail_line(value: String) -> void:
	if detail_cursor == detail_lines.size():
		var line := add_label(detail,"",22)
		line.visible = false
		detail_lines.append(line)
	var line := detail_lines[detail_cursor]
	line.text = value
	line.visible = true
	detail_cursor += 1

func resistance_text(value: int) -> String:
	return UIText.t("battle.enemy_defence.neutral") if value==0 else UIText.t("equipment.energy" if value==1 else "equipment.physical")
