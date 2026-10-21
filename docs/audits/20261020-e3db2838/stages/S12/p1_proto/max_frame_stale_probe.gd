extends "res://max_frame_probe.gd"

# External live mutation is made before the query's public step. The old
# query must itself report stale; only the caller may create a fresh query.
var changes: Array = [3, -5, 2, "equal_profile_replace"]
var stale_seen := 0
var stale_price_count := 0
var stale_revision := -1
var receipts: Array = []

func _before_tick() -> void:
	if changes.is_empty() or phase != "scan" or prices.is_empty():
		return
	var change: Variant = changes.pop_front()
	if change is int:
		var current: CurrencyValue = decode(profile.resources["1"])
		var quantity: CurrencyValue = currency_from_integer(absi(change))
		profile.resources["1"] = encode(add(current, quantity) if change > 0 else subtract(current, quantity))
		expected_delta += change
	else:
		profile = JSON.parse_string(JSON.stringify(profile))
	revision += 1
	stale_price_count = scan_prices_completed
	stale_revision = starting_revision
	receipts.append({"change":change,"old_revision":stale_revision,"new_revision":revision,"old_query_prices":prices.size()})

func _finish() -> void:
	if result_state == "stale" and stale_seen < receipts.size():
		stale_seen += 1
		if revision != stale_revision + 1 or phase != "scan":
			result_state = "error"
			super._finish()
			return
		call_deferred("_new_query_after_stale")
		return
	if stale_seen != 4:
		result_state = "error"
	print(JSON.stringify({"kind":"exploratory_public_stale_receipt","stale_seen":stale_seen,"receipts":receipts,"aba_net_delta":expected_delta,"new_query_prices":scan_prices_completed-stale_price_count,"live_unchanged_after_restart":JSON.stringify(profile)==original_json}))
	super._finish()

func _new_query_after_stale() -> void:
	# This is a caller action after receipt, not an invalidation test hook.
	starting_revision = revision
	original_json = JSON.stringify(profile)
	result_state = "pending"
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
	call_deferred("_frame_loop")
