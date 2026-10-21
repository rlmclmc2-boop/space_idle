extends "res://max_resumable_probe.gd"

var material_case := 0

func _initialize() -> void:
	source_path = "res://generated_wallets/MAX-MATERIAL-%d.json" % material_case
	expected_path = "res://generated_wallets/MAX-MATERIAL-%d.manifest.json" % material_case
	super._initialize()

func _finish() -> void:
	stop_us = Time.get_ticks_usec()
	var success: bool = result_state == "complete" and level == 19 + int(expected.expected_count) and material_wallet == int(expected.remaining_material) and stop_reason == expected.stop_reason and JSON.stringify(profile) == original_json
	print(JSON.stringify({"kind":"exploratory_material_stop","material_initial":material_case,"success":success,"state":result_state,"level":level,"count":level-19,"remaining_material":material_wallet,"stop_reason":stop_reason,"first_failed_price_expected":expected.first_unaffordable_price,"live_unchanged":JSON.stringify(profile)==original_json,"ticks":tick_count,"max_tick_us":max_tick_us,"total_us":stop_us-total_started}))
	quit(0 if success else 1)
