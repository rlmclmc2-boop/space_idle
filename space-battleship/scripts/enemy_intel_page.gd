extends Control
## Current-stage route projection. No combat actors or RNG are created here.
var host: Node
var route_stage := -1
var route_builds := 0
var detail_builds := 0
var entries: Array[Dictionary] = []
var selected := -1
var list: VBoxContainer
var detail: VBoxContainer
var heading: Label

func setup(owner: Node) -> void:
	host = owner
	name = "EnemyIntel"
	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation",20)
	add_child(layout)
	var route_scroll := ScrollContainer.new()
	route_scroll.custom_minimum_size.x = 420
	route_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	route_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(route_scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",9)
	route_scroll.add_child(list)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(detail_scroll)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",14)
	detail_scroll.add_child(detail)
	heading = add_label(detail,"",30)
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
	for child in list.get_children():child.queue_free()
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var row: Dictionary = host.db.enemies[entry.id]
		var button := Button.new()
		button.text = UIText.t("enemy.intel.list_item",{"point":str(int(entry.point)+1),"name":str(row.des),"count":str(entry.count)})
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(390,64)
		button.pressed.connect(show_entry.bind(index))
		list.add_child(button)
	show_entry(0 if not entries.is_empty() else -1)

func show_entry(index: int) -> void:
	if index==selected:return
	detail_builds += 1
	selected = index
	for child in detail.get_children():
		if child != heading:child.queue_free()
	if index<0:
		heading.text = UIText.t("enemy.intel.empty")
		return
	var entry: Dictionary = entries[index]
	var row: Dictionary = host.db.enemies[entry.id]
	heading.text = str(row.des)
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(300,280)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = host.ship_hull_texture(host.enemy_visual_identity.resolve(row,host.visual_config))
	detail.add_child(image)
	add_label(detail,UIText.t("enemy.intel.identity",{"id":str(entry.id),"point":str(int(entry.point)+1),"count":str(entry.count)}),19)
	var summary := str(row.get("intelTrait",""))
	add_label(detail,summary if not summary.is_empty() else UIText.t("enemy.intel.missing"))
	if summary.is_empty():push_warning("Enemy intelligence missing for mon "+str(entry.id))
	var stage := route_stage
	var point := int(entry.point)
	var health = host.db.enemy_encounter_capacity(row,stage,point,"health")
	add_label(detail,UIText.t("enemy.intel.armour",{"health":host.number(health),"resistance":resistance_text(int(row.armourType))}))
	var shield = host.db.enemy_encounter_capacity(row,stage,point,"shield")
	add_label(detail,UIText.t("enemy.intel.shield",{"capacity":host.number(shield),"resistance":resistance_text(int(row.get("shieldType",0)))}))
	var attacks: Dictionary = {}
	for mount in row.equipment:
		attacks[str(mount.name)] = int(attacks.get(str(mount.name),0))+1
	for key in attacks:
		var weapon: Dictionary = host.db.enemy_weapon(str(key))
		var base_key := str(key).replace("_mon", "").replace("-mon", "")
		var weapon_name := UIText.t("weapon."+base_key+"_name") if base_key in ["laser","cannon","missile","longLaser"] else str(key)
		add_label(detail,UIText.t("enemy.intel.attack",{"name":weapon_name,"count":str(attacks[key]),"damage":host.number(host.db.enemy_attack_damage(row,weapon,stage,point)),"type":resistance_text(int(weapon.dmgtype)),"cooldown":host.number(float(weapon.cd))}))
	var mechanic := str(row.get("intelMechanicRef",""))
	match mechanic:
		"none":add_label(detail,UIText.t("enemy.intel.no_mechanic"))
		"reactiveReduction":
			if int(row.get("reactiveReduction",0))==1:add_label(detail,UIText.t("enemy.intel.reactive"))
			else:add_label(detail,UIText.t("enemy.intel.missing"))
		"shieldRecovery":
			if float(row.get("shieldRecovery",0))>0 and shield>0:
				add_label(detail,UIText.t("enemy.intel.recovery",{"delay":host.number(float(row.shieldDelay)),"rate":host.number(float(row.shieldRecovery)*100.0)}))
			else:add_label(detail,UIText.t("enemy.intel.missing"))
		_:add_label(detail,UIText.t("enemy.intel.missing"))

func resistance_text(value: int) -> String:
	return UIText.t("battle.enemy_defence.neutral") if value==0 else UIText.t("equipment.energy" if value==1 else "equipment.physical")
