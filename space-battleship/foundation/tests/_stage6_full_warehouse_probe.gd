extends "res://foundation/tests/_stage6_critical_oracle_probe.gd"
## Full production warehouse and overflow must retain an unclaimed reward.

func _run() -> void:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 127)
	if not ready.ok:
		printerr(ready)
		quit(1)
		return
	var own = session.hyperspace_system
	var prepared: Dictionary = own.prepare_manual("alpha", 8, {"stage": 8, "point": 0, "guard": false, "guard_point": 0})
	if not prepared.ok:
		printerr(prepared)
		quit(1)
		return
	own.accept_manual(prepared.receipt)
	own.advance_manual(10.0)
	var completed: Dictionary = own.finish_manual(true)
	var run_id: int = int(prepared.receipt.run_id)
	var drone: Dictionary = completed.receipt.reward.drone
	if not completed.ok or drone.is_empty():
		printerr("full warehouse reward fixture")
		quit(1)
		return
	for index in own._warehouse_capacity():
		var copy: Dictionary = drone.duplicate(true)
		copy.id = "full-main-" + str(index)
		own._warehouse.append(copy)
	for index in int(own._parameters.overflow_capacity):
		var copy: Dictionary = drone.duplicate(true)
		copy.id = "full-overflow-" + str(index)
		own._overflow.append(copy)
	var before: Dictionary = own.save_state()
	var started: int = Time.get_ticks_usec()
	var rejected: Dictionary = own.prepare_claim(run_id)
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1000.0
	if rejected.get("reason") != "WarehouseFull" or own.save_state() != before:
		printerr("full warehouse mutated pending reward: ", rejected)
		quit(1)
		return
	own._overflow.pop_back()
	var accepted: Dictionary = own.prepare_claim(run_id)
	if not accepted.ok:
		printerr(accepted)
		quit(1)
		return
	own.accept_claim(run_id)
	var count: int = own._overflow.size()
	var duplicate: Dictionary = own.prepare_claim(run_id)
	own.accept_claim(run_id)
	if not duplicate.ok or not duplicate.already_claimed or own._overflow.size() != count:
		printerr("full warehouse duplicate reward")
		quit(1)
		return
	print("STAGE6_FULL_WAREHOUSE_OK main=", own._warehouse.size(), " overflow=", count,
		" blocked_claim_ms=", elapsed, " retained reward, capacity release and duplicate claim checked")
	quit()
