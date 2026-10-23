extends RefCounted
## Existing execution models and their actual admission checks, not a rule registry.
const VERSION := 1
const NUMERIC_VERSION := "GrowthNumber-v1"
const N = preload("res://scripts/growth_number.gd")

static func finite(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func result(model: String, reason := "") -> Dictionary:
	return {"ok":reason.is_empty(),"error":reason,"model":model,"version":VERSION,"numeric_version":NUMERIC_VERSION}

static func enemy_state(enemy: Dictionary) -> String:
	# Shared legacy enemy/shield code still converts these values to float.
	for key in ["hp","max_hp","shield","max_shield"]:
		if not finite(enemy.get(key,0)):return "unsupported_lab_enemy_scalar:"+key
	return ""

static func lab(game, mode: String) -> Dictionary:
	if mode not in ["exact","fast"]:return result("unknown","unsupported_execution_model:"+mode)
	var model := "BalanceGame/"+mode
	for key in ["armour","shield"]:
		if not N.valid(game.player.get(key,0)) or not N.valid(game.stat(key)):return result(model,"invalid_lab_player_quantity:"+key)
	for enemy in game.enemies:
		var reason := enemy_state(enemy)
		if not reason.is_empty():return result(model,reason)
	return result(model)

static func encounter(game) -> String:
	if game.stage<1 or game.stage>game.db.levels.size():return "invalid_lab_stage"
	var level: Dictionary=game.db.levels[game.stage-1]
	for kind in ["lifeRatio","atkRatio","resRatio"]:
		if not finite(level.get(kind)):return "unsupported_lab_level_scalar:"+kind
		if game.stage>1 and not finite(game.db.levels[game.stage-2].get(kind)):return "unsupported_lab_level_scalar:"+kind
	if game.group_index<0 or game.group_index>=level.groups.size():return "invalid_lab_encounter"
	var group:Dictionary=game.db.groups[str(int(level.groups[game.group_index].id))]
	for id in group.slots:
		if id==null:continue
		var row:Dictionary=game.db.enemies[str(int(id))]
		for key in ["health","shield","shieldDelay","shieldRecovery","dmgMultiple"]:
			if not finite(row.get(key,0)):return "unsupported_lab_enemy_source:"+key
		for key in ["health","shield"]:
			if not is_finite(game.db.enemy_encounter_capacity(row,game.stage,game.group_index,key)):return "unsupported_lab_enemy_projection:"+key
		for entry in row.equipment:
			var weapon:Dictionary=game.db.enemy_weapon(entry.name)
			if not finite(weapon.get("dmg")):return "unsupported_lab_enemy_weapon:dmg"
			if not is_finite(game.db.enemy_attack_damage(row,weapon,game.stage,game.group_index)):return "unsupported_lab_enemy_projection:damage"
	return ""

static func native_descriptor(game, scope: String, upgrades: Dictionary={}, galaxy: Dictionary={}) -> Dictionary:
	# The existing compiler remains the sole native capability/rule authority.
	return preload("res://scripts/native_execution_compiler.gd").new().compile(game,scope,upgrades,galaxy)
