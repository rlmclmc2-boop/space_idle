class_name UIText
extends RefCounted
## Display-only catalog. Parameter contracts are independent of editable prose.
static var entries: Dictionary = {}
static var contracts: Dictionary = {}
static var bindings: Dictionary = {}
static var deleted: Dictionary = {}
static var loaded := false
static var parameter_pattern: RegEx

static func pattern() -> RegEx:
	if parameter_pattern == null:
		parameter_pattern = RegEx.new()
		parameter_pattern.compile("\\{([^{}]*)\\}")
	return parameter_pattern

static func reload_catalog() -> PackedStringArray:
	var errors := PackedStringArray()
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_text.json"))
	var contract = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_text_contract.json"))
	if not source is Array or not contract is Dictionary:
		errors.append("UI text catalog or contract is invalid JSON")
		return errors
	var next: Dictionary = {}
	var next_deleted: Dictionary = {}
	for row in source:
		if not row is Dictionary or not row.get("key") is String or not row.get("text") is String or not row.get("deleted", false) is bool:
			errors.append("Invalid UI text row")
			continue
		var key: String = row.key
		if next.has(key) or not contract.entries.has(key):
			errors.append("Duplicate or unknown UI key: " + key)
			continue
		var required: Array = contract.entries[key].params
		var actual := parameters(row.text)
		var expected: Array = required.duplicate()
		expected.sort()
		actual.sort()
		if actual != expected:
			errors.append("UI parameter mismatch: " + key + " expected " + str(expected) + " got " + str(actual))
		next[key] = row.text
		if row.get("deleted", false): next_deleted[key] = true
	for key in contract.entries:
		if not next.has(key): errors.append("Missing UI key: " + key)
	if errors.is_empty():
		entries = next
		deleted = next_deleted
		contracts = contract.entries
		bindings = contract.get("bindings", {})
		loaded = true
	return errors

static func parameters(value: String) -> Array:
	var regex := pattern()
	var result: Array = []
	for found in regex.search_all(value): result.append(found.get_string(1))
	# Stray braces must also fail validation.
	var stripped := regex.sub(value,"",true)
	if stripped.contains("{") or stripped.contains("}"): result.append("!invalid_braces")
	return result

static func t(key: String, values: Dictionary = {}) -> String:
	if not loaded:
		var errors := reload_catalog()
		if not errors.is_empty():
			push_error("\n".join(errors))
			return "[" + key + "]"
	if not entries.has(key):
		push_error("Missing UI key: " + key)
		return "[" + key + "]"
	var required: Array = contracts[key].params
	if required.is_empty() and values.is_empty(): return "" if deleted.has(key) else entries[key]
	for name in required:
		if not values.has(name):
			push_error("Missing UI parameter: " + key + " {" + name + "}")
			return "[" + key + "]"
	for name in values:
		if not required.has(name):
			push_error("Unknown UI parameter: " + key + " {" + str(name) + "}")
			return "[" + key + "]"
	# Single pass: values containing braces must never become template syntax.
	if deleted.has(key): return ""
	var regex := pattern()
	var template: String = entries[key]
	var result := ""
	var cursor := 0
	for found in regex.search_all(template):
		result += template.substr(cursor, found.get_start()-cursor) + str(values[found.get_string(1)])
		cursor = found.get_end()
	return result + template.substr(cursor)

static func data_key(section: String, id: String, field := "name") -> String:
	if not loaded: reload_catalog()
	return str(bindings.get(section, {}).get(id, {}).get(field, ""))

static func data_text(section: String, id: String, field := "name", fallback := "") -> String:
	var key := data_key(section,id,field)
	return t(key) if not key.is_empty() else (fallback if not fallback.is_empty() else id)

static func formulas(key: String) -> Array:
	if not loaded: reload_catalog()
	return contracts.get(key, {}).get("formulas", [])
