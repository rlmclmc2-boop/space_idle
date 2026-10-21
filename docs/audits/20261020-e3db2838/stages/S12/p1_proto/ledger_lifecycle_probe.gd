extends "res://bench_sparse.gd"

# Audit-only boundary model. Profile remains a Dictionary; this transient
# session owns a validated typed value and never returns its mutable arrays.
# The only untrusted inputs are encoded dictionaries at load/quote boundaries.
class HostState:
	extends RefCounted
	var profile: Dictionary
	var generation := 0
	func _init(source: Dictionary) -> void:
		profile = source.duplicate(true)
	func replace_profile(next_profile: Dictionary) -> void:
		profile = next_profile.duplicate(true)
		generation += 1
	func replace_wallet(encoded: Variant) -> void:
		var next_profile: Dictionary = profile.duplicate(true)
		next_profile.resources["1"] = encoded
		replace_profile(next_profile)

class LedgerSession:
	extends RefCounted
	var _codec
	var _balance
	var _prepared
	var _revision := 0
	var _prepared_revision := -1
	var _host: HostState
	var _host_generation := -1
	var _source_profile_json := ""

	func _init(codec) -> void:
		_codec = codec

	func load_host(host: HostState) -> bool:
		# An attempted import invalidates the previous binding even on failure.
		_balance = null
		_prepared = null
		_prepared_revision = -1
		_host = null
		_host_generation = -1
		_source_profile_json = ""
		_revision += 1
		if host == null or not (host.profile.get("resources") is Dictionary):
			return false
		var encoded: Variant = host.profile.resources.get("1")
		var decoded = _codec.decode(encoded)
		if decoded == null:
			return false
		_balance = decoded
		_host = host
		_host_generation = host.generation
		_source_profile_json = JSON.stringify(host.profile)
		return true

	func _current_host(host: HostState) -> bool:
		return _balance != null and host != null and host == _host and host.generation == _host_generation and host.profile.get("resources") is Dictionary and JSON.stringify(host.profile) == _source_profile_json

	func prepare_untrusted(encoded: Variant) -> bool:
		var decoded = _codec.decode(encoded)
		if decoded == null or _balance == null:
			_prepared = null
			_prepared_revision = -1
			return false
		_prepared = decoded
		_prepared_revision = _revision
		return true

	func compare_prepared(host: HostState) -> int:
		if not _current_host(host) or _prepared == null or _revision != _prepared_revision:
			return -2
		return _codec.compare(_balance, _prepared)

	func debit_prepared(host: HostState) -> bool:
		if compare_prepared(host) < 0:
			return false
		var replacement = _codec.subtract(_balance, _prepared)
		if replacement == null:
			return false
		return _commit(host, replacement)

	func credit_trusted_unit(host: HostState) -> bool:
		if not _current_host(host):
			return false
		var unit = _codec.decode({"v":4,"blocks":[["0",1]]})
		var replacement = _codec.add(_balance, unit)
		if replacement == null:
			return false
		return _commit(host, replacement)

	func credit_untrusted(host: HostState, encoded: Variant) -> bool:
		if not _current_host(host):
			return false
		var amount = _codec.decode(encoded)
		if amount == null:
			return false
		var replacement = _codec.add(_balance, amount)
		if replacement == null:
			return false
		return _commit(host, replacement)

	func _commit(host: HostState, replacement) -> bool:
		if not _current_host(host):
			return false
		var next_profile: Dictionary = host.profile.duplicate(true)
		next_profile.resources["1"] = _codec.encode(replacement)
		host.replace_profile(next_profile)
		_balance = replacement
		_host_generation = host.generation
		_source_profile_json = JSON.stringify(host.profile)
		_revision += 1
		_prepared = null
		_prepared_revision = -1
		return true

	func snapshot_encoded() -> Dictionary:
		return _codec.encode(_balance) if _balance != null else {}

	func save_profile_json(host: HostState) -> String:
		if not _current_host(host):
			return ""
		var output: Dictionary = host.profile.duplicate(true)
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
	var host := HostState.new(parsed)
	var loaded: bool = session.load_host(host)
	var validated_us := Time.get_ticks_usec() - started
	if not loaded:
		quit(1)
		return
	var before_alias := JSON.stringify(session.snapshot_encoded())
	var host_wallet_before_alias := JSON.stringify(host.profile.resources["1"])
	parsed.resources["1"].blocks[0][1] = 4999
	var load_alias_safe: bool = JSON.stringify(session.snapshot_encoded()) == before_alias and JSON.stringify(host.profile.resources["1"]) == host_wallet_before_alias
	var cost := {"v":4,"blocks":[["0",1]]}
	started = Time.get_ticks_usec()
	var prepared: bool = session.prepare_untrusted(cost)
	var prepare_us := Time.get_ticks_usec() - started
	cost.blocks[0][1] = 4999
	started = Time.get_ticks_usec()
	var affordable: int = session.compare_prepared(host)
	var hot_compare_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var debited: bool = session.debit_prepared(host)
	var hot_debit_us := Time.get_ticks_usec() - started
	var expected_balance = subtract(decode(initial_profile.resources["1"]),decode({"v":4,"blocks":[["0",1]]}))
	var cost_alias_safe: bool = compare(decode(session.snapshot_encoded()),expected_balance) == 0 and compare(decode(host.profile.resources["1"]),expected_balance) == 0
	var repeated_debit_rejected: bool = not session.debit_prepared(host)
	var fake_cost_rejected: bool = not session.prepare_untrusted({"v":4,"blocks":[["0",1]],"forged":true})
	var forged_typed_rejected: bool = not session.prepare_untrusted(decode({"v":4,"blocks":[["0",1]]}))
	var valid_before_bad: bool = session.prepare_untrusted({"v":4,"blocks":[["0",1]]})
	var bad_quote_rejected: bool = not session.prepare_untrusted({"v":4,"blocks":[["0",1]],"forged":true}) and not session.debit_prepared(host)
	var state_after_rejections := JSON.stringify(session.snapshot_encoded())
	var cost_again := {"v":4,"blocks":[["0",1]]}
	var prepared_again: bool = session.prepare_untrusted(cost_again)
	var credited: bool = session.credit_trusted_unit(host)
	var stale_rejected: bool = not session.debit_prepared(host)
	var changed_after_credit: bool = JSON.stringify(session.snapshot_encoded()) != state_after_rejections
	started = Time.get_ticks_usec()
	var saved_json: String = session.save_profile_json(host)
	var save_us := Time.get_ticks_usec() - started
	var reloaded = JSON.parse_string(saved_json)
	var second := LedgerSession.new(self)
	var exact_roundtrip: bool = reloaded is Dictionary and second.load_host(HostState.new(reloaded)) and compare(decode(second.snapshot_encoded()),decode(session.snapshot_encoded())) == 0
	var profile_dictionary: bool = reloaded is Dictionary and reloaded.resources is Dictionary and reloaded.resources["1"] is Dictionary and int(reloaded.laser_level) == 1 and int(reloaded.hyperspace.materials.degenerate_matter) == 10
	# Change only the external host. The real transaction method must refuse
	# before any session or host debit, even for an equal-value replacement.
	var stale_host := HostState.new(initial_profile)
	var stale_session := LedgerSession.new(self)
	var stale_setup: bool = stale_session.load_host(stale_host) and stale_session.prepare_untrusted({"v":4,"blocks":[["0",1]]})
	stale_host.replace_profile(stale_host.profile.duplicate(true))
	var stale_host_before := JSON.stringify(stale_host.profile)
	var stale_host_debit_rejected: bool = not stale_session.debit_prepared(stale_host) and JSON.stringify(stale_host.profile) == stale_host_before
	var stale_host_save_rejected: bool = stale_session.save_profile_json(stale_host) == ""
	var foreign_host := HostState.new(initial_profile)
	var foreign_session := LedgerSession.new(self)
	var foreign_setup: bool = foreign_session.load_host(stale_host) and foreign_session.prepare_untrusted({"v":4,"blocks":[["0",1]]})
	var wrong_host_rejected: bool = not foreign_session.debit_prepared(foreign_host)
	var in_place_host := HostState.new(initial_profile)
	var in_place_session := LedgerSession.new(self)
	var in_place_setup: bool = in_place_session.load_host(in_place_host) and in_place_session.prepare_untrusted({"v":4,"blocks":[["0",1]]})
	in_place_host.profile.resources["1"].blocks[0][1] = 2
	var in_place_before := JSON.stringify(in_place_host.profile)
	var in_place_edit_rejected: bool = not in_place_session.debit_prepared(in_place_host) and JSON.stringify(in_place_host.profile) == in_place_before
	var level_host := HostState.new(initial_profile)
	var level_session := LedgerSession.new(self)
	var level_setup: bool = level_session.load_host(level_host) and level_session.prepare_untrusted({"v":4,"blocks":[["0",1]]})
	level_host.profile.laser_level = 2
	var level_before := JSON.stringify(level_host.profile)
	var in_place_level_rejected: bool = not level_session.debit_prepared(level_host) and JSON.stringify(level_host.profile) == level_before
	# A failed new import invalidates the old binding; old host cannot be used.
	var failed_load_session := LedgerSession.new(self)
	var failed_setup: bool = failed_load_session.load_host(host) and failed_load_session.prepare_untrusted({"v":4,"blocks":[["0",1]]})
	var bad_host := HostState.new({"resources":{"1":{"v":4,"blocks":[["0",-1]]}}})
	var host_before_failed_import := JSON.stringify(host.profile)
	var failed_import_invalidates: bool = not failed_load_session.load_host(bad_host) and not failed_load_session.debit_prepared(host) and JSON.stringify(host.profile) == host_before_failed_import
	# A second, dense equal-value transaction exposes the true 10,000-block hot
	# comparison and full cancellation cost. It must round-trip canonical zero.
	var dense := LedgerSession.new(self)
	var dense_host := HostState.new(initial_profile)
	var dense_loaded: bool = dense.load_host(dense_host)
	started = Time.get_ticks_usec()
	var dense_prepared: bool = dense.prepare_untrusted(initial_profile.resources["1"])
	var dense_prepare_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var dense_comparison: int = dense.compare_prepared(dense_host)
	var dense_compare_us := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var dense_debited: bool = dense.debit_prepared(dense_host)
	var dense_debit_us := Time.get_ticks_usec() - started
	var zero_json: String = dense.save_profile_json(dense_host)
	var zero_parsed = JSON.parse_string(zero_json)
	var zero_roundtrip: bool = zero_parsed is Dictionary and decode(zero_parsed.resources["1"]) != null and compare(decode(zero_parsed.resources["1"]),decode({"v":4,"blocks":[]})) == 0
	var max_position := "9223372036854775807"
	var min_position := "-9223372036854775808"
	var zero_value = decode({"v":4,"blocks":[]})
	var high_value = decode({"v":4,"blocks":[[max_position,1]]})
	var low_value = decode({"v":4,"blocks":[[min_position,1]]})
	var max_value = decode({"v":4,"blocks":[[max_position,4999]]})
	var position_ends_valid: bool = zero_value != null and high_value != null and low_value != null and max_value != null
	var endpoint_arithmetic: bool = position_ends_valid and compare(high_value,zero_value) > 0 and compare(zero_value,high_value) < 0 and compare(low_value,zero_value) > 0 and compare(zero_value,low_value) < 0 and compare(add(high_value,zero_value),high_value) == 0 and compare(add(zero_value,low_value),low_value) == 0 and compare(subtract(low_value,zero_value),low_value) == 0
	var outside_v4_position_rejected: bool = decode({"v":4,"blocks":[["9223372036854775808",1]]}) == null
	var edge_host := HostState.new({"resources":{"1":{"v":4,"blocks":[[max_position,4999]]}}})
	var edge_session := LedgerSession.new(self)
	var edge_loaded: bool = edge_session.load_host(edge_host)
	var edge_before := JSON.stringify(edge_host.profile)
	var carry_overflow_rejected: bool = edge_loaded and not edge_session.credit_untrusted(edge_host,{"v":4,"blocks":[[max_position,1]]}) and JSON.stringify(edge_host.profile) == edge_before and compare(decode(edge_session.snapshot_encoded()),max_value) == 0
	var correct: bool = loaded and load_alias_safe and prepared and affordable > 0 and debited and cost_alias_safe and repeated_debit_rejected and fake_cost_rejected and forged_typed_rejected and valid_before_bad and bad_quote_rejected and prepared_again and credited and stale_rejected and changed_after_credit and exact_roundtrip and profile_dictionary and stale_setup and stale_host_debit_rejected and stale_host_save_rejected and foreign_setup and wrong_host_rejected and in_place_setup and in_place_edit_rejected and level_setup and in_place_level_rejected and failed_setup and failed_import_invalidates and dense_loaded and dense_prepared and dense_comparison == 0 and dense_debited and zero_roundtrip and endpoint_arithmetic and outside_v4_position_rejected and carry_overflow_rejected
	print(JSON.stringify({"kind":"exploratory_verified_ledger_lifecycle","correct":correct,"blocks":10000,"source_bytes":source_json.to_utf8_buffer().size(),"saved_bytes":saved_json.to_utf8_buffer().size(),"cold_json_parse_us":parsed_us,"cold_host_clone_validation_us":validated_us,"cold_total_us":parsed_us+validated_us,"quote_validation_us":prepare_us,"hot_typed_compare_with_host_us":hot_compare_us,"hot_committed_debit_us":hot_debit_us,"save_clone_encode_json_us":save_us,"dense_quote_validation_us":dense_prepare_us,"dense_compare_with_host_us":dense_compare_us,"dense_committed_debit_us":dense_debit_us,"load_alias_safe":load_alias_safe,"cost_alias_safe":cost_alias_safe,"repeated_debit_rejected":repeated_debit_rejected,"fake_cost_rejected":fake_cost_rejected,"forged_typed_rejected":forged_typed_rejected,"bad_quote_rejected":bad_quote_rejected,"stale_rejected":stale_rejected,"stale_host_debit_rejected":stale_host_debit_rejected,"stale_host_save_rejected":stale_host_save_rejected,"wrong_host_rejected":wrong_host_rejected,"in_place_edit_rejected":in_place_edit_rejected,"in_place_level_rejected":in_place_level_rejected,"failed_import_invalidates":failed_import_invalidates,"exact_roundtrip":exact_roundtrip,"zero_roundtrip":zero_roundtrip,"profile_dictionary":profile_dictionary,"position_ends_valid":position_ends_valid,"endpoint_arithmetic":endpoint_arithmetic,"outside_v4_position_rejected":outside_v4_position_rejected,"carry_overflow_rejected":carry_overflow_rejected}))
	quit(0 if correct else 1)
