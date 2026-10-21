extends "res://max_resumable_probe.gd"

# Fixed ten-revision sustained change sequence: one exact mutation between
# slices, old cursor invalidated, fresh cursor started. After changes stop,
# the new query must actually complete and preserve the live wallet.
var schedule: Array = [3,-2,3,-2,3,-2,3,-2,3,-2]
var invalidations: Array = []
var cursor_id := 0

func _before_tick() -> void:
	if not (profile is Dictionary and phase == "scan" and prices.size() > 0 and not schedule.is_empty()):
		return
	var change: int = int(schedule.pop_front())
	var old_target := last_quoted_target
	var old_work := scan_prices_completed
	var current: CurrencyValue = decode(profile.resources["1"])
	var delta: CurrencyValue = currency_from_integer(absi(change))
	var changed: CurrencyValue = add(current, delta) if change > 0 else subtract(current, delta)
	profile.resources["1"] = encode(changed)
	revision += 1
	expected_delta += change
	invalidations.append({"old_cursor":cursor_id,"old_revision":revision-1,"new_revision":revision,"mutation":change,"old_work_units":old_work,"old_last_target":old_target})
	cursor_id += 1
	starting_revision = revision
	original_json = JSON.stringify(profile)
	phase = "decode"
	level = initial_level
	material_wallet = int(profile.hyperspace.materials.degenerate_matter)
	pending.clear()
	prices.clear()
	material_due = 0
	replay_index = 0
	fallback_job = null
	overflow_domain = false
	last_quoted_target = 0

func _finish() -> void:
	print(JSON.stringify({"kind":"exploratory_sustained_changes","mutations":invalidations,"mutations_remaining":schedule.size(),"net_delta":expected_delta,"total_quoted_prices":scan_prices_completed,"repeated_prefix_work":scan_prices_completed-50016,"final_cursor":cursor_id,"final_state":result_state,"final_level":level,"final_material":material_wallet,"live_equals_final_external_state":JSON.stringify(profile)==original_json}))
	super._finish()
