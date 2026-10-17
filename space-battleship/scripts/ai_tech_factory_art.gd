extends Control
## First-generation factory art. Static layers stay cached by Godot; only the probe moves.

const BACKDROP_PATH := "res://assets/ai_tech_factory/workshop-background-v2.png"
const PROBE_PATH := "res://assets/ai_tech_factory/inspection-probe-v2.png"
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
	"ai_singularity": Rect2(402, 145, 480, 450),
	"weapon_accuracy": Rect2(382, 90, 520, 520),
	"equipment_reinforcement": Rect2(344, 116, 596, 491),
	"resource_refining": Rect2(374, 83, 536, 530),
	"fragment_condensation": Rect2(345, 141, 594, 474),
	"equipment_precision": Rect2(335, 101, 614, 515),
	"uranium_extraction": Rect2(350, 127, 584, 484),
	"joint_integration": Rect2(315, 142, 654, 460),
}

var technology_id := "weapon_accuracy"
var level := 0
var researching := false
var progress := 0.0
var icon_mode := false
var obscured := false
var phase := 0.0

var backdrop: TextureRect
var machine: TextureRect
var probe: TextureRect
var probe_home := Vector2.ZERO

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
	machine = _texture_layer(load(MACHINE_PATHS[technology_id]) as Texture2D)
	machine.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	probe = _texture_layer(load(PROBE_PATH) as Texture2D)
	probe.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

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
		if probe != null: probe.visible = false
		machine.position = Vector2.ZERO
		machine.size = size
		return
	backdrop.visible = true
	backdrop.position = Vector2.ZERO
	backdrop.size = size
	var bounds: Rect2 = MACHINE_BOUNDS[technology_id]
	machine.position = bounds.position * scale
	machine.size = bounds.size * scale
	probe.visible = researching
	probe.size = Vector2(105, 105) * scale
	probe_home = Vector2(645, 194) * scale - probe.size * 0.5
	probe.position = probe_home

func _update_process() -> void:
	var animate := is_visible_in_tree() and researching and not icon_mode and not obscured
	set_process(animate)
	if probe != null:
		probe.visible = animate

func set_obscured(value: bool) -> void:
	if obscured == value:
		return
	obscured = value
	_update_process()

func _process(delta: float) -> void:
	phase = fmod(phase + minf(delta, 0.05) * 1.9, TAU)
	var scale := Vector2(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
	probe.position = probe_home + Vector2(sin(phase) * 28.0, cos(phase * 1.2) * 9.0) * scale
