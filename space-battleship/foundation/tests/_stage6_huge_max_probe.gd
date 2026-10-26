extends "res://foundation/tests/_stage6_critical_oracle_probe.gd"
## Production MAX transaction with Amount balances outside machine float range.

func _run() -> void:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 113)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 51)
	if not ready.ok:
		printerr(ready)
		quit(1)
		return
	session.equipment.refresh_availability(session.campaign_system.available, 51, false)
	var huge: Dictionary = session.amount_api.apply("from_decimal", ["1e1000"])
	var wallet: Dictionary = session.economy.budget().duplicate(true)
	var quote: Dictionary = session.equipment._quote_levels(session.equipment._definitions.laser, 1, 1000, session.equipment._evolution, true, session.amount_api)
	if not quote.ok:
		printerr(quote)
		quit(1)
		return
	for key in quote.costs: wallet[key] = huge.value
	for key in wallet: wallet[key] = huge.value
	session.economy.accept_budget(wallet)
	var started: int = Time.get_ticks_usec()
	ready = session.equipment.buy_max_levels("weapon:0", session.equipment_inputs(), session.economy.affordable,
		session.economy.payment, session.publish_equipment_levels)
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1000.0
	var level: int = int(session.equipment.save_state().slots[0].paid_level)
	var extra: Dictionary = session.equipment.buy_levels("weapon:0", 1, session.equipment_inputs(),
		session.economy.payment, session.publish_equipment_levels)
	if not ready.ok or level < 1000 or extra.ok or not session.run_state.is_running():
		printerr("huge MAX transaction: ", ready, " level=", level, " extra=", extra)
		quit(1)
		return
	print("STAGE6_HUGE_MAX_OK budget=1e1000 paid_level=", level, " work_ms=", elapsed, " next_level=", extra.get("reason"))
	quit()
