extends "res://bench_sparse.gd"

# Audit-only boundary model. Profile remains a Dictionary; this transient
# session owns a validated typed value and never returns its mutable arrays.
# The only untrusted inputs are encoded dictionaries at load/quote boundaries.
class LedgerSession:
	extends RefCounted
	var _codec
	var _balance
	var _prepared
	var _revision := 0
	var _prepared_revision := -1
	var _host_revision := -1

	func _init(codec) -> void:
		_codec = codec

	func load_untrusted(encoded: Variant, host_revision: int = 0) -> bool:
		var decoded = _codec.decode(encoded)
		if decoded == null:
			return false
		_balance = decoded
		_host_revision = host_revision
		_revision += 1
		_prepared = null
		_prepared_revision = -1
		return true

	func prepare_untrusted(encoded: Variant) -> bool:
		var decoded = _codec.decode(encoded)
		if decoded == null or _balance == null:
			_prepared = null
			_prepared_revision = -1
			return false
		_prepared = decoded
		_prepared_revision = _revision
		return true

	func compare_prepared() -> int:
		if _balance == null or _prepared == null or _revision != _prepared_revision:
			return -2
		return _codec.compare(_balance, _prepared)

	func debit_prepared() -> bool:
		if compare_prepared() < 0:
			return false
		var replacement = _codec.subtract(_balance, _prepared)
		if replacement == null:
			return false
		_balance = replacement
		_revision += 1
		_prepared = null
		_prepared_revision = -1
		return true

	func credit_trusted_unit() -> bool:
		if _balance == null:
			return false
		var unit = _codec.decode({"v":4,"blocks":[["0",1]]})
		var replacement = _codec.add(_balance, unit)
		if replacement == null:
			return false
		_balance = replacement
		_revision += 1
		_prepared = null
		_prepared_revision = -1
		return true

	func snapshot_encoded() -> Dictionary:
		return _codec.encode(_balance) if _balance != null else {}

	func save_profile_json(current_profile: Dictionary, host_revision: int = 0) -> String:
		if _balance == null or _host_revision != host_revision or not (current_profile.get("resources") is Dictionary):
			return ""
		var output: Dictionary = current_profile.duplicate(true)
		output.resources["1"] = _codec.encode(_balance)
		return JSON.stringify(output)

func _initialize() -> void:
	var initial_profile := {"laser_level":1,"resources":{"1":candidate(10000,false)},"hyperspace":{"materials":{"degenerate_matter":10}}}
	var source_json := JSON.stringify(initial_profile)
	var session := LedgerSession.new(self)
	var started := Time.get_ticks_usec()
	var parsed = JSON.parse_string(source_json)
	var parsed_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var loaded: bool = parsed is Dictionary and session.load_untrusted(parsed.resources["1"])
	var validated_us := Time.get_ticks_usec() - started
	if not loaded:
		quit(1)
		return
	var before_alias := JSON.stringify(session.snapshot_encoded())
	parsed.resources["1"].blocks[0][1] = 4999
	var load_alias_safe: bool = JSON.stringify(session.snapshot_encoded()) == before_alias
	var cost := {"v":4,"blocks":[["0",1]]}
	started = Time.get_ticks_usec()
	var prepared: bool = session.prepare_untrusted(cost)
	var prepare_us := Time.get_ticks_usec() - started
	cost.blocks[0][1] = 4999
	started = Time.get_ticks_usec()
	var affordable: int = session.compare_prepared()
	var hot_compare_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var debited: bool = session.debit_prepared()
	var hot_debit_us := Time.get_ticks_usec() - started
	var expected_balance = subtract(decode(initial_profile.resources["1"]),decode({"v":4,"blocks":[["0",1]]}))
	var cost_alias_safe: bool = compare(decode(session.snapshot_encoded()),expected_balance) == 0
	var repeated_debit_rejected: bool = not session.debit_prepared()
	var fake_cost_rejected: bool = not session.prepare_untrusted({"v":4,"blocks":[["0",1]],"forged":true})
	var forged_typed_rejected: bool = not session.prepare_untrusted(decode({"v":4,"blocks":[["0",1]]}))
	var valid_before_bad: bool = session.prepare_untrusted({"v":4,"blocks":[["0",1]]})
	var bad_quote_rejected: bool = not session.prepare_untrusted({"v":4,"blocks":[["0",1]],"forged":true}) and not session.debit_prepared()
	var negative_rejected: bool = not session.load_untrusted({"v":4,"blocks":[["0",-1]]})
	var state_after_rejections := JSON.stringify(session.snapshot_encoded())
	var cost_again := {"v":4,"blocks":[["0",1]]}
	var prepared_again: bool = session.prepare_untrusted(cost_again)
	var credited: bool = session.credit_trusted_unit()
	var stale_rejected: bool = not session.debit_prepared()
	var changed_after_credit: bool = JSON.stringify(session.snapshot_encoded()) != state_after_rejections
	var equal_profile_replacement: Dictionary = initial_profile.duplicate(true)
	var stale_profile_save_rejected: bool = session.save_profile_json(equal_profile_replacement,1) == ""
	started = Time.get_ticks_usec()
	var saved_json: String = session.save_profile_json(initial_profile)
	var save_us := Time.get_ticks_usec() - started
	var reloaded = JSON.parse_string(saved_json)
	var second := LedgerSession.new(self)
	var exact_roundtrip: bool = reloaded is Dictionary and second.load_untrusted(reloaded.resources["1"]) and compare(decode(second.snapshot_encoded()),decode(session.snapshot_encoded())) == 0
	var profile_dictionary: bool = reloaded is Dictionary and reloaded.resources is Dictionary and reloaded.resources["1"] is Dictionary and int(reloaded.laser_level) == 1 and int(reloaded.hyperspace.materials.degenerate_matter) == 10
	# A second, dense equal-value transaction exposes the true 10,000-block hot
	# comparison and full cancellation cost. It must round-trip canonical zero.
	var dense := LedgerSession.new(self)
	var dense_loaded: bool = dense.load_untrusted(initial_profile.resources["1"])
	started = Time.get_ticks_usec()
	var dense_prepared: bool = dense.prepare_untrusted(initial_profile.resources["1"])
	var dense_prepare_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var dense_comparison: int = dense.compare_prepared()
	var dense_compare_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var dense_debited: bool = dense.debit_prepared()
	var dense_debit_us := Time.get_ticks_usec() - started
	var zero_json: String = dense.save_profile_json(initial_profile)
	var zero_parsed = JSON.parse_string(zero_json)
	var zero_roundtrip: bool = zero_parsed is Dictionary and decode(zero_parsed.resources["1"]) != null and compare(decode(zero_parsed.resources["1"]),decode({"v":4,"blocks":[]})) == 0
	var correct: bool = loaded and load_alias_safe and prepared and affordable > 0 and debited and cost_alias_safe and repeated_debit_rejected and fake_cost_rejected and forged_typed_rejected and valid_before_bad and bad_quote_rejected and negative_rejected and prepared_again and credited and stale_rejected and stale_profile_save_rejected and changed_after_credit and exact_roundtrip and profile_dictionary and dense_loaded and dense_prepared and dense_comparison == 0 and dense_debited and zero_roundtrip
	print(JSON.stringify({"kind":"exploratory_verified_ledger_lifecycle","correct":correct,"blocks":10000,"source_bytes":source_json.to_utf8_buffer().size(),"saved_bytes":saved_json.to_utf8_buffer().size(),"cold_json_parse_us":parsed_us,"cold_strict_validation_us":validated_us,"cold_total_us":parsed_us+validated_us,"quote_validation_us":prepare_us,"hot_typed_compare_us":hot_compare_us,"hot_new_value_debit_us":hot_debit_us,"save_clone_encode_json_us":save_us,"dense_quote_validation_us":dense_prepare_us,"dense_hot_compare_us":dense_compare_us,"dense_hot_debit_us":dense_debit_us,"load_alias_safe":load_alias_safe,"cost_alias_safe":cost_alias_safe,"repeated_debit_rejected":repeated_debit_rejected,"fake_cost_rejected":fake_cost_rejected,"forged_typed_rejected":forged_typed_rejected,"bad_quote_rejected":bad_quote_rejected,"negative_rejected":negative_rejected,"stale_rejected":stale_rejected,"stale_profile_save_rejected":stale_profile_save_rejected,"exact_roundtrip":exact_roundtrip,"zero_roundtrip":zero_roundtrip,"profile_dictionary":profile_dictionary}))
	quit(0 if correct else 1)
