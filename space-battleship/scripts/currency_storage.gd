extends RefCounted
## Exact tokens are restored only at resource/material/equipment-level boundaries.
const Ledger = preload("res://scripts/currency_ledger.gd")
const I = preload("res://scripts/currency_integer.gd")

class Outcome extends RefCounted:
	var status: String
	var data: Dictionary
	func _init(state: String, candidate: Dictionary = {}) -> void:
		status = state
		data = candidate

class TokenReader extends RefCounted:
	var source: String
	var at := 0
	var error := ""
	func _init(text: String) -> void:
		source = text
	func _space() -> void:
		while at < source.length() and source[at] in [" ","\t","\r","\n"]:
			at += 1
	func _string() -> String:
		var begin := at
		at += 1
		var escaped := false
		while at < source.length():
			var c := source[at]
			at += 1
			if escaped:
				escaped = false
			elif c == "\\":
				escaped = true
			elif c == '"':
				return str(JSON.parse_string(source.substr(begin, at-begin)))
		error = "invalid_string"
		return ""
	func _integer_kind(path: Array) -> String:
		if path.size() == 2 and path[0] == "resources":
			return "resource"
		if path.size() == 3 and path[0] == "hyperspace" and path[1] == "materials":
			return "material"
		if path.size() == 4 and path[0] == "loadout" and path[1] in ["weapons","defence"] and path[3] == "level":
			return "level"
		if path.size() == 2 and path[0] == "levels":
			return "level"
		return ""
	func _guard_duplicate(path: Array, key: String) -> bool:
		return (path.is_empty() and key in ["resources","hyperspace","loadout"]) or path == ["resources"] or path == ["hyperspace","materials"] or (path == ["hyperspace"] and key == "materials") or (path.size() == 3 and path[0] == "loadout" and key == "level")
	func read(path: Array, depth: int) -> Variant:
		if depth > 48:
			error = "depth"
			return null
		_space()
		if at >= source.length():
			error = "incomplete"
			return null
		if source[at] == "{":
			at += 1
			var object := {}
			_space()
			if source[at] == "}":
				at += 1
				return object
			while error.is_empty():
				_space()
				var key := _string()
				if object.has(key) and _guard_duplicate(path, key):
					error = "duplicate_boundary"
					return null
				_space()
				at += 1 # Full JSON syntax was validated before this reader.
				var child := path.duplicate()
				child.append(key)
				object[key] = read(child, depth+1)
				_space()
				if at >= source.length():
					break
				var delimiter := source[at]
				at += 1
				if delimiter == "}":
					return object
			error = "incomplete" if error.is_empty() else error
			return null
		if source[at] == "[":
			at += 1
			var array := []
			_space()
			if source[at] == "]":
				at += 1
				return array
			while error.is_empty():
				var child := path.duplicate()
				child.append(array.size())
				array.append(read(child, depth+1))
				_space()
				if at >= source.length():
					break
				var delimiter := source[at]
				at += 1
				if delimiter == "]":
					return array
			error = "incomplete" if error.is_empty() else error
			return null
		if source[at] == '"':
			return _string()
		var begin := at
		while at < source.length() and source[at] not in [",","}","]"," ","\t","\r","\n"]:
			at += 1
		var token := source.substr(begin, at-begin)
		var kind := _integer_kind(path)
		if not kind.is_empty() and I._canonical(token):
			var integer = I.make(token)
			if kind == "resource":
				return I.encode(integer)
			if I.compare(integer, I.make(I.MAX_INT)) > 0:
				error = "integer_transport"
				return null
			return int(token)
		return JSON.parse_string(token)

static func parse_source(source: String) -> Outcome:
	var parser := JSON.new()
	if parser.parse(source) != OK or not parser.data is Dictionary:
		return Outcome.new("format")
	var reader := TokenReader.new(source)
	var candidate: Variant = reader.read([], 0)
	if not reader.error.is_empty() or not candidate is Dictionary:
		return Outcome.new(reader.error if not reader.error.is_empty() else "format")
	return Outcome.new("ok", candidate)

static func valid_resource(raw: Variant) -> bool:
	return Ledger.decode(raw).status == "ok"

static func valid_int64(raw: Variant, minimum: int = 0) -> bool:
	if not (raw is int or raw is float) or not is_finite(float(raw)) or raw < minimum or float(raw) != floorf(float(raw)):
		return false
	var exact: Variant = I.command_floor(raw)
	return exact != null and I.compare(exact,I.make(I.MAX_INT))<=0

