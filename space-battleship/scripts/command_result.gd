extends RefCounted
## A detached statement of one concrete command; never a second state owner.
static func make(status: String, reason := "", domains: Array = [], resources: Array = [], slots: Array = [], facts: Dictionary = {}, contributions: Dictionary = {}) -> Dictionary:
	var result: Dictionary={"status":status,"reason":reason,"domains":domains.duplicate(),"resources":resources.duplicate(),"slots":slots.duplicate(),"facts":facts.duplicate(true),"contributions":contributions.duplicate(true)}
	freeze(result)
	return result

static func succeeded(result: Dictionary) -> bool:
	return result.status in ["committed","no_change"]

static func freeze(value: Variant) -> void:
	if value is Dictionary:
		for item in value.values():freeze(item)
		value.make_read_only()
	elif value is Array:
		for item in value:freeze(item)
		value.make_read_only()
