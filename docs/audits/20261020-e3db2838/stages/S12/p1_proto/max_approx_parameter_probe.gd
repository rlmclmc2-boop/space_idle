extends "res://max_approx_probe.gd"

# Audit-only entry for explicit real-equipment inputs. The production profile
# and game config are not loaded or mutated; the checked-in main snapshot is.
func _initialize() -> void:
	requested_equipment = OS.get_environment("S12_EQUIPMENT")
	requested_start_level = int(OS.get_environment("S12_START_LEVEL"))
	requested_material_balance = int(OS.get_environment("S12_MATERIAL"))
	fixture_mode = OS.get_environment("S12_WALLET_MODE")
	if OS.get_environment("S12_MUTATION") == "config":
		mutate_before_commit = true
		mutation_mode = "config"
	var alteration: String = OS.get_environment("S12_CONFIG_ALTERATION")
	if alteration != "":
		var actual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ACTUAL_CONFIG_PATH))
		requested_row = actual.rows.get(requested_equipment,{}).duplicate(true)
		if alteration == "zero":
			requested_row.cost_1 = 0
		elif alteration == "low":
			requested_row.cost_1 = 0.00000001
		elif alteration == "no_multiplier":
			requested_row.costMulti_1 = null
		elif alteration == "second_resource":
			requested_row.res_2 = 2
		else:
			requested_row.costMulti_1 = 0.21
	super._initialize()
