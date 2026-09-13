class_name BattleGame
extends RefCounted

signal event(kind: String, payload: Dictionary)

enum State { MAIN_MENU, LEVEL_SELECT, TRAVEL, COMBAT, LEVEL_CLEAR, DEFEAT, UPGRADE, RETREAT }
const EQUIPMENT := ["armour", "shield", "laser", "missile", "cannon"]
const SAVE_PATH := "user://progress.json"
var db: ShipDatabase
var profile: Dictionary
var state: State = State.MAIN_MENU
var stage := 1
var distance := 0.0
var group_index := 0
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var player: Dictionary = {}
var cooldowns: Dictionary = {}
var since_hit := 100.0
var paused := false
var speed := 1.0
var clear_timer := 0.0
var first_clear := false
var run_resources := {"1": 0.0, "2": 0.0}
var uid := 0
var save_enabled := true
var pending_unlocks: Array[String] = []
var retreat_from := 0.0
var retreat_target := 0.0
var retreat_elapsed := 0.0
var retreat_boss_pending := false
var rng := RandomNumberGenerator.new()

func _init(database: ShipDatabase, persist := true) -> void:
	db = database
	save_enabled = persist
	rng.randomize()
	profile = fresh_profile()
	if persist:
		load_progress()
	reset_player()

func fresh_profile() -> Dictionary:
	return {"version":1, "highestLevel":1, "cleared":[], "bossSeen":[], "levels":{"armour":1,"shield":1,"laser":1,"missile":1,"cannon":1}, "resources":{"1":ceilf(float(db.defaults.startingIron)),"2":ceilf(float(db.defaults.startingTitanium))}, "unlocked":str(db.config.startEquip).split(","), "loop":false}

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var raw = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not raw is Dictionary or raw.get("version") != 1:
		return
	if raw.get("cleared") is Array:
		for n in raw.cleared:
			if (n is float or n is int) and n == int(n) and n >= 1 and n <= db.levels.size() and not profile.cleared.has(int(n)):
				profile.cleared.append(int(n))
	profile.bossSeen = profile.cleared.duplicate()
	if raw.get("bossSeen") is Array:
		for n in raw.bossSeen:
			if (n is float or n is int) and n == int(n) and n >= 1 and n <= db.levels.size() and not profile.bossSeen.has(int(n)):
				profile.bossSeen.append(int(n))
	for key in EQUIPMENT:
		var value = raw.get("levels", {}).get(key, 1) if raw.get("levels") is Dictionary else 1
		if value is float or value is int:
			profile.levels[key] = clampi(int(value), 1, db.max_equipment_level(key))
	for id in ["1", "2"]:
		var value = raw.get("resources", {}).get(id, 0) if raw.get("resources") is Dictionary else 0
		if (value is float or value is int) and is_finite(float(value)):
			profile.resources[id] = ceilf(maxf(0, float(value)))
	profile.loop = raw.get("loop", false) == true
	rebuild_unlocks()
	var selected = raw.get("loopLevel", 0)
	profile.loopLevel = int(selected) if (selected is int or selected is float) and profile.cleared.has(int(selected)) else 0
	profile.loop = profile.loop and int(profile.loopLevel) > 0

func rebuild_unlocks() -> void:
	profile.highestLevel = 1
	profile.unlocked = []
	for n in profile.cleared:
		profile.highestLevel = mini(db.levels.size(), maxi(profile.highestLevel, int(n) + 1))
	for key in EQUIPMENT:
		if db.unlock_level(key) == 0 or profile.cleared.has(db.unlock_level(key)):
			profile.unlocked.append(key)

func save_progress() -> void:
	if not save_enabled:
		return
	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		event.emit("save_error", {})
		return
	file.store_string(JSON.stringify(profile, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	if err != OK:
		event.emit("save_error", {})

func stat(key: String) -> float:
	var row := db.equip(key, int(profile.levels[key]))
	return float(row.para1 if key in ["armour", "shield"] else row.dmg)

func max_shield() -> float:
	return stat("shield") if profile.unlocked.has("shield") else 0.0

func reset_player() -> void:
	player = {"x":280.0, "y":405.0, "armour":stat("armour"), "shield":max_shield()}
	since_hit = 100

func change_state(next: State) -> void:
	state = next
	event.emit("state", {"state":state})

func select_loop_level(level: int) -> bool:
	if not profile.cleared.has(level):
		return false
	profile.loopLevel = level
	if profile.loop:
		return start(level, true)
	save_progress()
	return true

func toggle_loop() -> void:
	if profile.loop:
		profile.loop = false
		save_progress()
	elif profile.cleared.has(int(profile.get("loopLevel", 0))):
		start(int(profile.loopLevel), true)

func next_stage() -> int:
	return int(profile.get("loopLevel", stage)) if profile.loop else mini(stage + 1, db.levels.size())

func start(level: int, loop_mode: bool) -> bool:
	if level < 1 or level > int(profile.highestLevel):
		return false
	settle_drops()
	stage = level
	distance = 0
	group_index = 0
	retreat_boss_pending = false
	enemies.clear()
	projectiles.clear()
	cooldowns.clear()
	pending_unlocks.clear()
	reset_player()
	paused = false
	profile.loop = loop_mode
	run_resources = {"1":0.0,"2":0.0}
	change_state(State.TRAVEL)
	save_progress()
	return true

func is_active() -> bool:
	return state in [State.TRAVEL, State.COMBAT]

func ratio(kind: String) -> float:
	return db.ratio(stage, distance / float(db.levels[stage - 1].length), kind)

func spawn_group(keep_distance := false) -> void:
	var encounter: Dictionary = db.levels[stage - 1].groups[group_index]
	if not keep_distance:
		distance = float(encounter.position) * float(db.levels[stage - 1].length)
	group_index += 1
	enemies.clear()
	var slots: Array = db.groups[str(int(encounter.id))].slots
	for slot in range(slots.size()):
		if slots[slot] == null:
			continue
		var row: Dictionary = db.enemies[str(int(slots[slot]))]
		var enemy := row.duplicate(true)
		uid += 1
		enemy.uid = uid
		enemy.slot = slot
		enemy.x = 1130.0
		enemy.y = 198.0 + (slot + (float(row.size) - 1.0) / 2.0) * 44.0
		enemy.hp = ceilf(float(row.health) * ratio("lifeRatio"))
		enemy.max_hp = enemy.hp
		enemy.res_ratio = ratio("resRatio")
		enemy.boss = float(row.size) > 1
		enemy.cooldowns = []
		for entry in row.equipment:
			enemy.cooldowns.append(float(db.enemy_weapon(entry.name, int(entry.level)).cd))
		enemies.append(enemy)
	if enemies.any(func(e):return e.boss) and not profile.bossSeen.has(stage):
		profile.bossSeen.append(stage)
		save_progress()
	change_state(State.COMBAT)
	event.emit("encounter", {"boss":enemies.any(func(e): return e.boss)})

func boss_info() -> String:
	if not profile.get("bossSeen", []).has(stage) and not profile.cleared.has(stage):
		return "？？？"
	var descriptions: Array[String] = []
	for encounter in db.levels[stage - 1].groups:
		for id in db.groups[str(int(encounter.id))].slots:
			if id == null:
				continue
			var row: Dictionary = db.enemies[str(int(id))]
			if float(row.size) > 1 and not descriptions.has(str(row.des)):
				descriptions.append(str(row.des))
	return " / ".join(descriptions) if not descriptions.is_empty() else "？？？"

func targets() -> Array[Dictionary]:
	var alive: Array[Dictionary] = []
	for e in enemies:
		if e.hp > 0:
			alive.append(e)
	alive.sort_custom(func(a,b):
		if a.x != b.x:
			return a.x < b.x
		var ac := absf(float(a.slot) + (float(a.size)-1)/2 - 4.5)
		var bc := absf(float(b.slot) + (float(b.size)-1)/2 - 4.5)
		return ac < bc if ac != bc else a.slot < b.slot)
	return alive

func reduced_damage(raw: float, type: int, resistance: int) -> float:
	return maxf(1, ceilf(raw * (1.0 - float(db.config.dmgReduce) if type == resistance else 1.0)))

func fire(source: Dictionary, target: Dictionary, weapon: Dictionary, raw: float, hostile: bool, key: String) -> void:
	var speed_parameter = weapon.para2 if key.begins_with("missile") else weapon.para1
	projectiles.append({"x":float(source.x) + (-45 if hostile else 70),"y":float(source.y), "target":target,"damage":raw,"type":int(weapon.dmgtype),"speed":float(speed_parameter)*float(db.defaults.projectilePixelsPerUnit),"hostile":hostile,"key":key,"dead":false})
	var shot: Dictionary = projectiles.back()
	shot.direction = Vector2(target.x - shot.x, target.y - shot.y).normalized()
	event.emit("fire", {"x":source.x,"y":source.y,"type":int(weapon.dmgtype)})

func hit_player(raw: float, type: int) -> void:
	since_hit = 0
	var rest := raw
	var shield_loss := 0.0
	var armour_loss := 0.0
	if player.shield > 0:
		var factor := 1.0 - float(db.config.dmgReduce) if type == int(db.equip("shield", 1).dmgtype) else 1.0
		shield_loss = minf(player.shield, reduced_damage(raw, type, int(db.equip("shield", 1).dmgtype)))
		player.shield = maxf(0, player.shield - shield_loss)
		rest = maxf(0, raw - shield_loss / factor)
	if rest > 0:
		armour_loss = reduced_damage(rest, type, int(db.equip("armour", 1).dmgtype))
		player.armour = maxf(0, player.armour - armour_loss)
	event.emit("hit", {"x":player.x,"y":player.y,"amount":ceilf(shield_loss + armour_loss),"player":true,"type":type})
	if player.armour <= 0:
		event.emit("explode", {"x":player.x,"y":player.y,"boss":true})
		begin_retreat()

func begin_retreat() -> void:
	var original_stage := stage
	retreat_boss_pending = false
	retreat_from = distance
	retreat_target = distance - float(db.config.backRange)
	while retreat_target < 0 and stage > 1:
		stage -= 1
		var previous_length := float(db.levels[stage - 1].length)
		retreat_target += previous_length
		retreat_from += previous_length
	retreat_target = maxf(0, retreat_target)
	retreat_elapsed = 0
	enemies.clear()
	cooldowns.clear()
	group_index = 0
	var level: Dictionary = db.levels[stage - 1]
	while group_index < level.groups.size() and float(level.groups[group_index].position)*float(level.length) < retreat_target - 0.001:
		group_index += 1
	if stage < original_stage:
		for index in range(group_index - 1, -1, -1):
			var slots: Array = db.groups[str(int(level.groups[index].id))].slots
			if slots.any(func(id):return id != null and float(db.enemies[str(int(id))].size) > 1):
				group_index = index
				retreat_boss_pending = true
				break
	change_state(State.RETREAT)
	event.emit("retreat", {"from":retreat_from,"to":retreat_target})
	save_progress()

func acknowledge_unlocks() -> void:
	pending_unlocks.clear()
	event.emit("state", {"state":state})

func hit_enemy(enemy: Dictionary, raw: float, type: int) -> void:
	if enemy.hp <= 0:
		return
	var amount := reduced_damage(raw, type, int(enemy.armourType))
	enemy.hp = maxf(0, enemy.hp - amount)
	event.emit("hit", {"x":enemy.x,"y":enemy.y,"amount":amount,"player":false,"type":type})
	if enemy.hp <= 0:
		event.emit("explode", enemy)
		for drop in enemy.drops:
			if rng.randf() < float(drop.chance):
				uid += 1
				drops.append({"uid":uid,"x":enemy.x - 40,"y":enemy.y,"age":0.0,"id":str(int(drop.resourceId)),"amount":ceilf(float(drop.amount)*float(enemy.res_ratio))})

func collect(drop: Dictionary, manual: bool) -> void:
	if not drops.has(drop):
		return
	drops.erase(drop)
	# Auto-collection loss is a separate calculation on the integer drop amount.
	var amount := ceilf(float(drop.amount) * (1.0 if manual else 1.0 - float(db.config.autoCollectReduce)))
	profile.resources[drop.id] += amount
	run_resources[drop.id] += amount
	var info := drop.duplicate()
	info.amount = amount
	info.manual = manual
	event.emit("collect", info)
	save_progress()

func settle_drops() -> void:
	for drop in drops.duplicate():
		collect(drop, false)

func collect_near(pos: Vector2) -> void:
	if paused:
		return
	for drop in drops.duplicate():
		if Vector2(drop.x, drop.y).distance_to(pos) < 55:
			collect(drop, true)

func clear_level() -> void:
	var previous: Array = Array(profile.unlocked).duplicate()
	first_clear = not profile.cleared.has(stage)
	if first_clear:
		profile.cleared.append(stage)
	rebuild_unlocks()
	for key in profile.unlocked:
		if not previous.has(key):
			pending_unlocks.append(key)
	clear_timer = float(db.defaults.loopDelay)
	change_state(State.LEVEL_CLEAR)
	save_progress()
	if not pending_unlocks.is_empty():
		event.emit("unlock", {"equipment":pending_unlocks.duplicate()})

func upgrade_cost(key: String) -> Dictionary:
	var next := db.equip(key, int(profile.levels[key]) + 1)
	var cost := {}
	for field in next:
		if str(field).begins_with("res_") and next[field] != null:
			var suffix := str(field).trim_prefix("res_")
			var amount = next.get("cost_" + suffix)
			if amount != null:
				cost[str(int(next[field]))] = ceilf(float(amount))
	return cost

func can_upgrade(key: String) -> bool:
	if not profile.unlocked.has(key) or int(profile.levels[key]) >= db.max_equipment_level(key):
		return false
	for id in upgrade_cost(key):
		if float(profile.resources.get(id, 0)) < float(upgrade_cost(key)[id]):
			return false
	return true

func upgrade(key: String) -> bool:
	if not can_upgrade(key):
		return false
	for id in upgrade_cost(key):
		profile.resources[id] -= upgrade_cost(key)[id]
	var before := stat(key)
	profile.levels[key] += 1
	# Preserve existing damage and cooldowns; upgrading a weapon never heals the ship.
	if key == "armour" and state != State.RETREAT:
		player.armour += stat(key) - before
	elif key == "shield" and state != State.RETREAT:
		player.shield += stat(key) - before
	save_progress()
	event.emit("upgrade", {"key":key})
	return true

func leave(next: State) -> void:
	settle_drops()
	projectiles.clear()
	enemies.clear()
	paused = false
	change_state(next)

func tick(dt: float) -> void:
	if paused:
		return
	for drop in drops.duplicate():
		drop.age += dt
		if drop.age >= float(db.defaults.autoCollectDelay):
			collect(drop, false)
	if state == State.LEVEL_CLEAR:
		tick_projectiles(dt)
		if state != State.LEVEL_CLEAR:
			return
		if not pending_unlocks.is_empty():
			return
		clear_timer -= dt
		if clear_timer <= 0:
			start(next_stage(), profile.loop)
		return
	if state == State.RETREAT:
		tick_projectiles(dt)
		retreat_elapsed += dt
		var duration := float(db.defaults.get("deathRetreatDuration", 1.2))
		distance = lerpf(retreat_from, retreat_target, clampf(retreat_elapsed / duration, 0, 1))
		if retreat_elapsed >= duration:
			distance = retreat_target
			reset_player()
			change_state(State.TRAVEL)
		return
	if not is_active():
		return
	since_hit += dt
	var shield := db.equip("shield", int(profile.levels.shield))
	if since_hit >= float(shield.para3):
		player.shield = minf(max_shield(), player.shield + max_shield() * float(shield.para2) * dt)
	if state == State.TRAVEL:
		tick_projectiles(dt)
		if state != State.TRAVEL:
			return
		if retreat_boss_pending:
			retreat_boss_pending = false
			spawn_group(true)
			return
		distance += float(db.config.movement) * dt
		var level: Dictionary = db.levels[stage - 1]
		if group_index < level.groups.size() and distance >= float(level.groups[group_index].position)*float(level.length):
			spawn_group()
		return
	for key in profile.unlocked:
		var weapon := db.equip(key, int(profile.levels[key]))
		if float(weapon.cd) <= 0:
			continue
		cooldowns[key] = maxf(0, float(cooldowns.get(key, 0)) - dt)
		if cooldowns[key] <= 0:
			var candidates := targets()
			var count := mini(candidates.size(), int(weapon.para1) if key == "missile" else 1)
			for i in range(count):
				fire(player, candidates[i], weapon, stat(key), false, key)
			if count > 0:
				cooldowns[key] = float(weapon.cd)
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		for i in range(enemy.equipment.size()):
			enemy.cooldowns[i] -= dt
			if enemy.cooldowns[i] <= 0:
				var entry: Dictionary = enemy.equipment[i]
				var weapon := db.enemy_weapon(entry.name, int(entry.level))
				var raw := ceilf(float(weapon.dmg) * float(enemy.dmgMultiple) * ratio("atkRatio"))
				fire(enemy, player, weapon, raw, true, entry.name)
				enemy.cooldowns[i] = float(weapon.cd)
	tick_projectiles(dt)
	if state == State.COMBAT and targets().is_empty():
		if enemies.any(func(e): return e.boss):
			clear_level()
		else:
			change_state(State.TRAVEL)
			event.emit("wave_clear", {})

func tick_projectiles(dt: float) -> void:
	for shot in projectiles.duplicate():
		if not shot.target.is_empty():
			var target_dead: bool = shot.target.armour <= 0 if shot.hostile else shot.target.hp <= 0 or not enemies.has(shot.target)
			if target_dead:
				var candidates: Array[Dictionary] = []
				if not shot.hostile and shot.key == "missile":
					candidates = targets()
				shot.target = candidates[0] if not candidates.is_empty() else {}
		if not shot.target.is_empty():
			var delta := Vector2(shot.target.x - shot.x, shot.target.y - shot.y)
			shot.direction = delta.normalized()
			if delta.length() <= shot.speed*dt:
				shot.dead = true
				if shot.hostile:
					hit_player(shot.damage, shot.type)
				else:
					hit_enemy(shot.target, shot.damage, shot.type)
				continue
		var move: Vector2 = shot.direction * float(shot.speed) * dt
		shot.x += move.x
		shot.y += move.y
		# Include the rendered trail before removing an off-screen projectile.
		if shot.x < -32 or shot.x > 1472 or shot.y < -32 or shot.y > 842:
			shot.dead = true
	projectiles = projectiles.filter(func(p): return not p.dead)
