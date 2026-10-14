extends "res://scripts/presented_battle_game.gd"
func upgrade_slot(category: String, index: int, levels := 1) -> bool:
	if not can_upgrade_slot(category, index, levels):
		return false
	var entry = slot_entry(category, index)
	var key = str(entry.key)
	var costs = slot_upgrade_cost(category, index, levels)
	var batch_update=native_execution!=null and not native_upgrade_batch.is_empty()
	if batch_update:
		var expected:Dictionary=native_upgrade_batch.planned.get(slot_id(category,index),{})
		if expected.get("levels",-1)!=levels or expected.get("before",-1)!=int(entry.level):
			if not native_before_configuration_change():return false
			native_upgrade_batch={};batch_update=false
	var native_updated=batch_update
	if native_execution!=null and not batch_update:
		native_updated=native_execution.upgrade_numeric_configuration(self,category,index,levels)
		if not native_updated and not native_before_configuration_change():return false
	native_numeric_update=native_updated
	for id in costs:
		profile.resources[id] = N.subtract(profile.resources[id],costs[id])
	var before = jewel_equipment_stat(entry)
	profile.loadout[category][index].level = int(entry.level) + levels
	resources_changed(costs.keys())
	invalidate_stat_cache()
	var after = jewel_equipment_stat(entry)
	# Preserve existing damage and cooldowns; upgrading a weapon never heals the ship.
	if (not native_updated or batch_update) and key == "armour" and state != State.RETREAT:
		player.armour = N.add(player.armour,N.subtract(after,before))
	elif (not native_updated or batch_update) and key == "shield" and state != State.RETREAT:
		player.shield = N.add(player.shield,N.subtract(after,before))
	native_numeric_update=false
	if _upgrade_batch:
		_upgrade_slots.append(slot_id(category,index))
	else:
		save_dirty = true
	event.emit("upgrade", {"key":key,"slot":slot_id(category,index),"levels":levels,"cost":costs,"batch":_upgrade_batch})
	return true
