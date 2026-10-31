extends RefCounted
## Validate configuration data before constructing gameplay systems. The compiler
## reads the same machine-readable contract for workbook publication.

const PATH: String = "res://config_tools/hyperspace_parameter_contract.json"

static func validate(configuration: Dictionary) -> Dictionary:
	var contract = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not contract is Dictionary:
		return {"ok": false, "reason": "HyperspaceContractUnavailable"}
	var hyperspace = configuration.get("hyperspace_config", {})
	var levels = configuration.get("level", {})
	if not hyperspace is Dictionary or not levels is Dictionary:
		return {"ok": false, "reason": "InvalidHyperspaceParameters"}
	var rows = hyperspace.get("基础参数", [])
	var stages = levels.get("level", [])
	if not rows is Array or not stages is Array:
		return {"ok": false, "reason": "InvalidHyperspaceParameters"}
	var allowed: Dictionary = {"amplification_rate": true}
	for group in ["intKeys", "positiveKeys", "nonnegativeKeys", "probabilityKeys"]:
		for key in contract[group]: allowed[str(key)] = true
	var values: Dictionary = {}
	for row in rows:
		if not row is Dictionary or not row.get("key") is String:
			return {"ok": false, "reason": "InvalidHyperspaceParameters"}
		var key: String = row.key
		if not allowed.has(key) or values.has(key):
			return {"ok": false, "reason": "InvalidHyperspaceParameter", "key": key}
		var value = row.get("value")
		var integer: bool = contract.intKeys.has(key)
		if row.get("data_type") != ("int" if integer else "float") or not (value is int or value is float):
			return {"ok": false, "reason": "InvalidHyperspaceParameter", "key": key}
		if not is_finite(float(value)) or absf(float(value)) >= float(contract.magnitudeExclusive):
			return {"ok": false, "reason": "InvalidHyperspaceParameter", "key": key}
		# Godot's JSON parser represents numeric literals as floats, including
		# workbook int fields. Values below 9e15 retain exact integer identity.
		if integer and float(value) != floorf(float(value)):
			return {"ok": false, "reason": "InvalidHyperspaceParameter", "key": key}
		if contract.positiveKeys.has(key) and value <= 0 or contract.nonnegativeKeys.has(key) and value < 0 or contract.probabilityKeys.has(key) and (value < 0 or value > 1) or key == "amplification_rate" and value <= -1:
			return {"ok": false, "reason": "InvalidHyperspaceParameter", "key": key}
		if contract.hardCaps.has(key) and (value > contract.hardCaps[key] or key == "maximum_ultimate" and value != 1):
			return {"ok": false, "reason": "InvalidHyperspaceParameter", "key": key}
		if contract.fixedValues.has(key) and value != contract.fixedValues[key]:
			return {"ok": false, "reason": "FixedRuleChanged", "key": key}
		values[key] = int(value) if integer else float(value)
	if values.size() != allowed.size():
		return {"ok": false, "reason": "InvalidHyperspaceParameters"}
	for pair in contract.capacityRelations:
		if values[pair[0]] > values[pair[1]]:
			return {"ok": false, "reason": "InvalidHyperspaceParameter", "key": pair[0]}
	var stage_ids: Dictionary = {}
	for row in stages:
		if row is Dictionary and (row.get("id") is int or row.get("id") is float): stage_ids[int(row.id)] = true
	for key in contract.stageReferences:
		if not stage_ids.has(values[key]):
			return {"ok": false, "reason": "InvalidHyperspaceParameter", "key": key}
	var precision: float = values.value_precision
	for sheet_name in contract.quantizedRangeSheets:
		var ranges = hyperspace.get(sheet_name)
		if not ranges is Array:
			return {"ok": false, "reason": "InvalidHyperspaceRange", "key": sheet_name}
		for range_row in ranges:
			if not range_row is Dictionary or not (range_row.get("minimum") is int or range_row.get("minimum") is float) or not (range_row.get("maximum") is int or range_row.get("maximum") is float):
				return {"ok": false, "reason": "InvalidHyperspaceRange", "key": sheet_name}
			var low: float = float(range_row.minimum)
			var high: float = float(range_row.maximum)
			if not is_finite(low) or not is_finite(high) or low > high:
				return {"ok": false, "reason": "InvalidHyperspaceRange", "key": sheet_name}
			var lower: float = low / precision - 1e-7
			var upper: float = high / precision + 1e-7
			if not is_finite(lower) or not is_finite(upper) or absf(lower) >= float(contract.magnitudeExclusive) or absf(upper) >= float(contract.magnitudeExclusive):
				return {"ok": false, "reason": "QuantizedIndexOutOfRange", "key": sheet_name}
			var first: int = ceili(lower)
			var last: int = floori(upper)
			if first > last:
				return {"ok": false, "reason": "QuantizedRangeEmpty", "key": sheet_name}
			if first < int(contract.quantizedIndexMinimum) or last > int(contract.quantizedIndexMaximum):
				return {"ok": false, "reason": "QuantizedIndexOutOfRange", "key": sheet_name}
	return {"ok": true}
