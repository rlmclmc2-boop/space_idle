extends "res://foundation/tests/_stage6_critical_oracle_probe.gd"
## Cached MAX quotes must equal the unchanged uncached production policy.

func _run() -> void:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 131)
	if not ready.ok:
		printerr(ready)
		quit(1)
		return
	var checks: int = 0
	for row in [session.equipment._definitions.laser, session.equipment._definitions.armour]:
		for level in [0, 1, 19, 1000]:
			var cache: Dictionary = {}
			# Descending then ascending requests exercise cached extreme boundaries
			# followed by ordinary quotes, evolution thresholds and exact repetitions.
			for count in [12597, 1, 2, 19, 20, 100, 512, 12598, 1]:
				var plain: Dictionary = session.equipment._quote_levels(row, level, count, session.equipment._evolution, true, session.amount_api)
				var cached: Dictionary = session.equipment._quote_levels(row, level, count, session.equipment._evolution, true, session.amount_api, cache)
				if plain != cached:
					printerr("MAX cache changed cost: ", row.name, " ", level, " ", count, " ", plain, " ", cached)
					quit(1)
					return
				checks += 1
	print("STAGE6_MAX_PRICE_CACHE_OK exact cached/uncached cost and extreme flags checks=", checks)
	quit()
