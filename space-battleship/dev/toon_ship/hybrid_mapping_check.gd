extends SceneTree
## Focused contract check; no profile loading, rendering or combat simulation.
const LAYOUT = preload("res://dev/toon_ship/hybrid_layout.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dev/toon_ship/hybrid_manifest.json"))
	var expected := {"Frigate":3,"Destroyer":3,"Cruiser":4,"Battleship":4,"Heavy_Battleship":5}
	for key in expected:
		var capacity := int(data.ship[key].weaponSlots)
		var budget := int(manifest.hulls[key].hull_mount_budget)
		check(budget == expected[key],key+": approved visual budget")
		check(manifest.hulls[key].drone_offsets.size() == capacity-budget,key+": complete carrier formation")
		var entries: Array = []
		for index in capacity+2: entries.append({"key":"missile","level":index+1})
		var before := JSON.stringify(entries)
		var full := LAYOUT.assign(entries,capacity,budget)
		check(full.size()==capacity,key+": no inactive tail")
		check(full.filter(func(item): return item.carrier=="hull").size()==budget,key+": hull count")
		check(full.filter(func(item): return item.carrier=="drone").size()==capacity-budget,key+": drone count")
		for index in full.size():
			check(full[index].slot==index and full[index].key=="missile",key+": repeats retain slot")
		check(JSON.stringify(entries)==before,key+": assignment read-only")
		check(full==LAYOUT.assign(entries,capacity,budget),key+": deterministic assignment")
		entries[0].key=""
		entries[capacity-1].key=""
		var sparse := LAYOUT.assign(entries,capacity,budget)
		check(sparse.size()==capacity-2,key+": no empty visuals")
		for index in sparse.size(): check(sparse[index].slot==index+1,key+": sparse slot identity")
		check(sparse.filter(func(item): return item.carrier=="drone").size()==maxi(0,capacity-2-budget),key+": no empty carriers")
		for entry in entries: entry.key=""
		check(LAYOUT.assign(entries,capacity,budget).is_empty(),key+": all-empty")
		# Independent alternative visual budget: assignment must not contain hardcoded capacities.
		entries[1].key="cannon"
		var alternate := LAYOUT.assign(entries,capacity,0)
		check(alternate.size()==1 and alternate[0].carrier=="drone" and alternate[0].slot==1,key+": configurable budget")
	if not failures.is_empty():
		for failure in failures: printerr("FAIL ",failure)
		quit(1)
	else:
		print("PASS hybrid assignment: five hulls, repeated/sparse/empty/inactive/configurable/read-only cases")
		quit()
