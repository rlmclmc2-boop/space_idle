extends RefCounted
## JSON-safe transport for module-owned state. All arbitrary integers stay
## decimal strings; an Amount remains the public {m,e} representation.

static func pack(value) -> Dictionary:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return {"ok": true, "value": value}
		TYPE_STRING_NAME:
			return {"ok": true, "value": str(value)}
		TYPE_INT:
			return {"ok": true, "value": {"$i": str(value)}}
		TYPE_FLOAT:
			return {"ok": is_finite(value), "value": value if is_finite(value) else null}
		TYPE_VECTOR2:
			return {"ok": is_finite(value.x) and is_finite(value.y), "value": {"$v2": [value.x, value.y]}}
		TYPE_PACKED_STRING_ARRAY:
			return {"ok": true, "value": {"$strings": Array(value)}}
		TYPE_ARRAY:
			var rows: Array = []
			for item in value:
				var encoded: Dictionary = pack(item)
				if not encoded.ok:
					encoded["at"] = str(rows.size()) + "/" + str(encoded.get("at", ""))
					return encoded
				rows.append(encoded.value)
			return {"ok": true, "value": rows}
		TYPE_DICTIONARY:
			if value.size() == 2 and value.has("m") and value.has("e") and value.m is String and value.e is String:
				return {"ok": true, "value": {"m": value.m, "e": value.e}}
			var rows: Array = []
			for key in value:
				if typeof(key) not in [TYPE_STRING, TYPE_STRING_NAME, TYPE_INT]: return {"ok": false, "error": "UnsupportedStateKey", "key": str(key), "type": typeof(key)}
				var encoded_key: Dictionary = pack(key)
				var encoded_value: Dictionary = pack(value[key])
				if not encoded_key.ok: return encoded_key
				if not encoded_value.ok:
					encoded_value["at"] = str(key) + "/" + str(encoded_value.get("at", ""))
					return encoded_value
				rows.append([encoded_key.value, encoded_value.value])
			return {"ok": true, "value": {"$map": rows}}
	return {"ok": false, "error": "UnsupportedStateValue", "type": typeof(value)}

static func unpack(value) -> Dictionary:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING, TYPE_FLOAT:
			if value is float and not is_finite(value): return {"ok": false, "error": "InvalidStateFloat"}
			return {"ok": true, "value": value}
		TYPE_ARRAY:
			var rows: Array = []
			for item in value:
				var decoded: Dictionary = unpack(item)
				if not decoded.ok: return decoded
				rows.append(decoded.value)
			return {"ok": true, "value": rows}
		TYPE_DICTIONARY:
			if value.size() == 2 and value.has("m") and value.has("e"):
				if not value.m is String or not value.e is String: return {"ok": false, "error": "InvalidAmount"}
				return {"ok": true, "value": value.duplicate()}
			if value.size() == 1 and value.has("$i"):
				var number = value["$i"]
				if not number is String or not number.is_valid_int() or str(number.to_int()) != number:
					return {"ok": false, "error": "InvalidStateInteger"}
				return {"ok": true, "value": number.to_int()}
			if value.size() == 1 and value.has("$v2"):
				var point = value["$v2"]
				if not point is Array or point.size() != 2 or not point[0] is float or not point[1] is float or not is_finite(point[0]) or not is_finite(point[1]):
					return {"ok": false, "error": "InvalidStateVector"}
				return {"ok": true, "value": Vector2(point[0], point[1])}
			if value.size() == 1 and value.has("$strings"):
				if not value["$strings"] is Array: return {"ok": false, "error": "InvalidStringArray"}
				for item in value["$strings"]:
					if not item is String: return {"ok": false, "error": "InvalidStringArray"}
				return {"ok": true, "value": PackedStringArray(value["$strings"])}
			if value.size() != 1 or not value.has("$map") or not value["$map"] is Array:
				return {"ok": false, "error": "InvalidStateMap"}
			var result: Dictionary = {}
			for pair in value["$map"]:
				if not pair is Array or pair.size() != 2: return {"ok": false, "error": "InvalidStateEntry"}
				var key: Dictionary = unpack(pair[0])
				var item: Dictionary = unpack(pair[1])
				if not key.ok or not item.ok or typeof(key.value) not in [TYPE_STRING, TYPE_INT] or result.has(key.value):
					return {"ok": false, "error": "InvalidStateEntry"}
				result[key.value] = item.value
			return {"ok": true, "value": result}
	return {"ok": false, "error": "InvalidStateValue"}
