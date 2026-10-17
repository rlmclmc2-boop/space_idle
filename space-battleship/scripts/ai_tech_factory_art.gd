extends Control
## First-generation factory art. Static layers stay cached by Godot; only the probe moves.

const BACKDROP_PATH := "res://assets/ai_tech_factory/workshop-background-v2.png"
const PROBE_PATH := "res://assets/ai_tech_factory/inspection-probe-v2.png"
const CONTACT_SHADOW := preload("res://assets/ai_tech_factory/contact-shadow.svg")
const MACHINE_PATHS := {
	"ai_singularity": "res://assets/ai_tech_factory/ai-singularity-v2.png",
	"weapon_accuracy": "res://assets/ai_tech_factory/weapon-accuracy-v2.png",
	"equipment_reinforcement": "res://assets/ai_tech_factory/equipment-reinforcement-v2.png",
	"resource_refining": "res://assets/ai_tech_factory/resource-refining-v2.png",
	"fragment_condensation": "res://assets/ai_tech_factory/fragment-condensation-v2.png",
	"equipment_precision": "res://assets/ai_tech_factory/equipment-precision-v2.png",
	"uranium_extraction": "res://assets/ai_tech_factory/uranium-extraction-v2.png",
	"joint_integration": "res://assets/ai_tech_factory/joint-integration-v2.png",
}

# Placement is in the 1284 x 701 art panel, not in the 2048 x 1280 game viewport.
const BASE_SIZE := Vector2(1284, 701)
const MACHINE_BOUNDS := {
	"ai_singularity": Rect2(430, 132, 424, 397),
	"weapon_accuracy": Rect2(382, 90, 520, 520),
	"equipment_reinforcement": Rect2(344, 92, 596, 491),
	"resource_refining": Rect2(374, 89, 536, 530),
	"fragment_condensation": Rect2(345, 141, 594, 474),
	"equipment_precision": Rect2(335, 63, 614, 515),
	"uranium_extraction": Rect2(350, 117, 584, 484),
	"joint_integration": Rect2(315, 142, 654, 460),
}
const WORK_POINTS := {
	"ai_singularity": Vector2(642, 309),
	"weapon_accuracy": Vector2(642, 269),
	"equipment_reinforcement": Vector2(642, 332),
	"resource_refining": Vector2(642, 353),
	"fragment_condensation": Vector2(642, 352),
	"equipment_precision": Vector2(642, 340),
	"uranium_extraction": Vector2(642, 335),
	"joint_integration": Vector2(642, 342),
}

var technology_id := "weapon_accuracy"
var level := 0
var researching := false
var progress := 0.0
var icon_mode := false
var obscured := false
var phase := 0.0

var backdrop: TextureRect
var contact_shadow: TextureRect
var machine: TextureRect
var probe: TextureRect
var probe_home := Vector2.ZERO
var work_point := Vector2.ZERO
var work_effect: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_make_layers()
	_layout_layers()
	_update_process()

func _make_layers() -> void:
	if machine != null:
		return
	if icon_mode:
		machine = _texture_layer(load(MACHINE_PATHS[technology_id]) as Texture2D)
		machine.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return
	backdrop = _texture_layer(load(BACKDROP_PATH) as Texture2D)
	contact_shadow = _texture_layer(CONTACT_SHADOW)
	machine = _texture_layer(load(MACHINE_PATHS[technology_id]) as Texture2D)
	machine.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	probe = _texture_layer(load(PROBE_PATH) as Texture2D)
	probe.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	work_effect = Control.new()
	work_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	work_effect.draw.connect(_draw_work_effect)
	add_child(work_effect)

func _texture_layer(texture: Texture2D) -> TextureRect:
	var layer := TextureRect.new()
	layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer

func set_display(id: String, current_level: int, is_researching: bool, fraction: float, as_icon := false) -> void:
	var next_id := id if MACHINE_PATHS.has(id) else "ai_singularity"
	var next_level := maxi(0, current_level)
	progress = clampf(fraction, 0.0, 1.0)
	if technology_id == next_id and level == next_level and researching == is_researching and icon_mode == as_icon:
		return
	if technology_id != next_id:phase = 0.0
	technology_id = next_id
	level = next_level # Generation and refit artwork can be selected here in later passes.
	researching = is_researching
	icon_mode = as_icon
	if machine != null:
		machine.texture = load(MACHINE_PATHS[technology_id]) as Texture2D
		_layout_layers()
	_update_process()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and machine != null:
		_layout_layers()
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_update_process()

func _layout_layers() -> void:
	if machine == null:
		return
	var scale := Vector2(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
	if icon_mode:
		if backdrop != null: backdrop.visible = false
		if contact_shadow != null: contact_shadow.visible = false
		if probe != null: probe.visible = false
		if work_effect != null: work_effect.visible = false
		machine.position = Vector2.ZERO
		machine.size = size
		return
	backdrop.visible = true
	backdrop.position = Vector2.ZERO
	backdrop.size = size
	contact_shadow.visible = true
	if technology_id == "ai_singularity":
		contact_shadow.position = Vector2(390, 465) * scale
		contact_shadow.size = Vector2(504, 100) * scale
	else:
		contact_shadow.position = Vector2(330, 494) * scale
		contact_shadow.size = Vector2(624, 142) * scale
	var bounds: Rect2 = MACHINE_BOUNDS[technology_id]
	machine.position = bounds.position * scale
	machine.size = bounds.size * scale
	probe.visible = researching
	probe.size = Vector2(106, 106) * scale
	probe.pivot_offset = probe.size * 0.5
	probe_home = Vector2(1086, 348) * scale
	work_point = WORK_POINTS[technology_id] * scale
	probe.position = probe_home-probe.size*0.5
	work_effect.position = Vector2.ZERO
	work_effect.size = size

func _update_process() -> void:
	var animate := is_visible_in_tree() and researching and not icon_mode and not obscured
	set_process(animate)
	if probe != null:
		probe.visible = animate
	if work_effect != null:
		work_effect.visible = animate

func set_obscured(value: bool) -> void:
	if obscured == value:
		return
	obscured = value
	_update_process()

func _process(delta: float) -> void:
	phase = fmod(phase + minf(delta, 0.05) / 3.4, 1.0)
	var scale := Vector2(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
	var approach := work_point-Vector2(0,117)*scale
	var center := probe_home
	if phase<0.22:
		center=probe_home.lerp(approach,_ease(phase/0.22))
	elif phase<0.72:
		var sweep:float=(phase-0.22)/0.50
		center=approach+Vector2(-19.0+38.0*sweep,8.0+sin(sweep*TAU*3.0)*3.0)*scale
	else:
		center=approach.lerp(probe_home,_ease((phase-0.72)/0.28))
	probe.position=center-probe.size*0.5
	probe.rotation=sin(phase*TAU*2.0)*0.035 if phase>=0.22 and phase<0.72 else 0.0
	work_effect.queue_redraw()

func _ease(value: float) -> float:
	var t:=clampf(value,0.0,1.0)
	return t*t*(3.0-2.0*t)

func _draw_work_effect() -> void:
	if phase<0.22 or phase>=0.72 or not researching:return
	var scale := Vector2(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
	var intensity:=sin(PI*clampf((phase-0.22)/0.50,0.0,1.0))
	var tip:=probe.position+Vector2(probe.size.x*0.5,probe.size.y*0.80)
	work_effect.draw_line(tip,work_point,Color(0.38,0.93,0.97,0.45+0.25*intensity),2.0*scale.x,true)
	var grip:=Vector2(16.0-7.0*intensity,8.0)*scale
	for side in [-1.0,1.0]:
		var edge:=work_point+Vector2(grip.x*side,grip.y)
		work_effect.draw_line(edge,work_point+Vector2(6.0*side,-6.0)*scale,Color(0.94,0.74,0.36,0.68),2.0*scale.x,true)
	for i in 3:
		var angle:=phase*TAU*9.0+float(i)*TAU/3.0
		var spark:=work_point+Vector2(cos(angle),sin(angle))*Vector2(15,9)*scale
		work_effect.draw_circle(spark,1.7*scale.x,Color(1.0,0.81,0.42,0.32+0.42*intensity))
