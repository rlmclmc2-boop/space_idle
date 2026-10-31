extends RefCounted
## Runtime side of the single source-space port contract used by Blender.
const PATH := "res://assets/ui/reactor/b01/reactor_ports.json"
static var _data: Dictionary = {}

static func device(id: String) -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		assert(parsed is Dictionary and parsed.has("devices"))
		_data = parsed
	assert(_data.devices.has(id))
	return _data.devices[id]

static func route(id: String) -> Array[Vector2]:
	var data: Dictionary = device(id)
	return [Vector2(data.core_port[0],data.core_port[1]),
		Vector2(data.controls[0][0],data.controls[0][1]),
		Vector2(data.controls[1][0],data.controls[1][1]),
		Vector2(data.device_port[0],data.device_port[1])]

static func source_rect(id: String) -> Rect2:
	var r: Array = device(id).rect
	return Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3]))

static func work_rect(id: String) -> Rect2:
	var r: Array = device(id).work_rect
	return Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3]))
