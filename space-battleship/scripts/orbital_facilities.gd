extends Node
## One on-demand atlas for the selected planet. No autonomous frame processing.
const KINDS := ["auto_explore", "refinery", "equipment", "shipyard"]
const BODY_SPIN := {"auto_explore":0.34,"refinery":0.28,"equipment":-0.30,"shipyard":0.24}
const PATHS := {
 "auto_explore": {"radius":1.52,"ratio":0.46,"tilt":-0.28,"speed":-0.12,"phase":0.32},
 "refinery": {"radius":1.40,"ratio":0.52,"tilt":1.10,"speed":-0.085,"phase":2.1},
 "equipment": {"radius":1.62,"ratio":0.64,"tilt":-0.92,"speed":0.065,"phase":4.6},
 "shipyard": {"radius":1.55,"ratio":0.70,"tilt":0.0,"speed":0.0,"phase":-0.6}
}
var viewport: SubViewport
var models: Dictionary = {}
var parts: Dictionary = {}
var textures: Dictionary = {}
var owned: Array = []
var last_clock := -1.0
static func path_for(kind: String) -> Dictionary:
 return PATHS.get(kind, PATHS.auto_explore)
static func angle_for(kind: String, clock: float) -> float:
 var path := path_for(kind)
 return float(path.phase) + clock * float(path.speed)
func _ready() -> void:
 viewport = SubViewport.new()
 viewport.size = Vector2i(1024,256)
 viewport.transparent_bg = true
 viewport.own_world_3d = true
 viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
 viewport.msaa_3d = Viewport.MSAA_2X
 add_child(viewport)
 var world := Node3D.new()
 viewport.add_child(world)
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_CLEAR_COLOR
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color("7290b4")
 environment.environment.ambient_light_energy = 0.4
 world.add_child(environment)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-38,-40,0)
 light.light_color = Color("fff0d8")
 light.light_energy = 1.7
 world.add_child(light)
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.keep_aspect = Camera3D.KEEP_HEIGHT
 camera.size = 9.0
 camera.position = Vector3(0,0,20)
 world.add_child(camera)
 for index in KINDS.size():
  var kind: String = KINDS[index]
  var packed := load("res://assets/planets/orbital/models/" + kind + ".glb") as PackedScene
  var body := packed.instantiate() as Node3D
  body.position.x = (float(index)-1.5)*9.0
  world.add_child(body)
  models[kind] = body
  parts[kind] = body.find_child("Motion",true,false)
  assert(is_instance_valid(parts[kind]), "Orbital model requires a Motion pivot: " + kind)
  body.visible = false
  var texture := AtlasTexture.new()
  texture.atlas = viewport.get_texture()
  texture.region = Rect2(index*256,0,256,256)
  texture.filter_clip = true
  textures[kind] = texture
func configure(entries: Array) -> void:
 var next: Array = []
 for entry in entries:
  var kind := str(entry.get("type", ""))
  if models.has(kind) and not next.has(kind):next.append(kind)
 if next == owned:return
 owned = next
 for kind in models:models[kind].visible = owned.has(kind)
 last_clock = -1.0
func update_pose(clock: float) -> void:
 if owned.is_empty() or clock == last_clock:return
 last_clock = clock
 for kind in owned:
  # Body attitude is independent of translation, including stationary docks.
  var yaw := float(path_for(kind).phase) + clock * float(BODY_SPIN[kind])
  models[kind].rotation = Vector3(0.56, fposmod(yaw, TAU), 0.10)
  var moving: Node3D = parts[kind]
  if kind == "shipyard":
   moving.position.z = sin(clock*0.35)*0.4
  elif kind == "equipment":
   moving.rotation.z = sin(clock*0.35)*0.2
  else:
   moving.rotation.y = clock * (0.50 if kind == "auto_explore" else 0.28)
 viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
func texture(kind: String) -> Texture2D:
 return textures.get(kind)
