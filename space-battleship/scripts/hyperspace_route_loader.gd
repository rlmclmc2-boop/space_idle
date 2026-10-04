extends RefCounted
## Production data is a separate, accepted registry; never merge into mainline.
const C=preload("res://scripts/hyperspace_config.gd")
const ROUTES_PATH="res://data/space_enemy_routes.json"
const CANDIDATES_PATH="res://data/space_enemy_candidates.json"
const ACCEPTED="accepted_all40"
var last_error:=""
func fail(code: String) -> Dictionary:
	last_error=code;return {}
func read_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
func load_files(g) -> Dictionary:
	return prepare(g,read_file(ROUTES_PATH),read_file(CANDIDATES_PATH))
func prepare(g,binding: Variant,candidate: Variant) -> Dictionary:
	if not binding is Dictionary or not candidate is Dictionary:return fail("space_data_missing")
	if binding.get("schema_version")!=1 or candidate.get("schema_version")!=1 or binding.get("scope")!="space_only" or candidate.get("scope")!="space_only":return fail("space_schema_invalid")
	if binding.get("candidate_config")!=CANDIDATES_PATH:return fail("space_registry_binding_invalid")
	var review=binding.get("acceptance",{});var acceptance=candidate.get("acceptance",{})
	if not review is Dictionary or not acceptance is Dictionary:return fail("space_acceptance_invalid")
	if binding.get("data_status")!=ACCEPTED or candidate.get("status")!=ACCEPTED or review.get("status")!=ACCEPTED or review.get("verified_under_specified_seed")!=40 or acceptance.get("accepted_under_original_limits")!=40:return fail("space_data_not_accepted")
	if review.get("pending_group_ids")!=[] or acceptance.get("unaccepted_group_ids")!=[]:return fail("space_data_not_accepted")
	if not binding.get("routes") is Dictionary or binding.routes.size()!=4 or not candidate.get("groups") is Dictionary or candidate.groups.size()!=40 or not candidate.get("enemies") is Dictionary:return fail("space_registry_invalid")
	if candidate.enemies.is_empty():return fail("space_registry_invalid")
	for id in candidate.groups:
		var row=candidate.groups[id]
		if not id is String or not id.is_valid_int() or str(int(id))!=id or int(id)<=0 or not row is Dictionary or not row.get("slots") is Array or not row.slots.any(func(slot):return slot!=null):return fail("space_group_invalid")
	var policy=binding.get("selected_mainline_level_policy",{})
	if not policy is Dictionary or policy.get("enemy_tier_offset")!=0:return fail("space_multiplier_policy_invalid")
	for key in ["atkRatio","lifeRatio","resRatio"]:
		if policy.get(key)!="inherit_selected_mainline_level":return fail("space_multiplier_policy_invalid")
	for id in candidate.enemies:
		if not id is String or not id.is_valid_int() or str(int(id))!=id or int(id)<=0 or g.db.enemies.has(id):return fail("space_enemy_id_invalid")
		var row=candidate.enemies[id]
		if not row is Dictionary or row.get("id")!=int(id) or not C.number(row.get("health")) or row.health<=0 or not C.integer(row.get("size")) or row.size<1 or not row.get("equipment") is Array or not row.get("drops") is Array:return fail("space_enemy_invalid")
		if not C.integer(row.get("armourType")) or not C.number(row.get("dmgMultiple")) or row.dmgMultiple<0:return fail("space_enemy_invalid")
		for weapon in row.equipment:
			if not weapon is Dictionary or not weapon.get("name") is String or g.db.enemy_weapon(weapon.name).is_empty():return fail("space_enemy_weapon_invalid")
		for drop in row.drops:
			if not drop is Dictionary or not C.integer(drop.get("resourceId")) or not g.db.data.resources.has(str(int(drop.resourceId))) or not C.number(drop.get("amount")) or drop.amount<0 or not C.number(drop.get("chance")) or drop.chance<0 or drop.chance>1:return fail("space_enemy_drop_invalid")
	var routes: Dictionary={}
	for route in g.hyperspace.config.routes:
		var weapon: String=g.hyperspace.config.routes[route].weapon
		var row=binding.routes.get(weapon)
		if not row is Dictionary or row.size()!=4:return fail("space_route_binding_invalid")
		routes[route]=[]
		for tier in ["normal","elite","boss","ultimate"]:
			var ids=row.get(tier)
			if not ids is Array or ids.size()!=(4 if tier in ["normal","elite"] else 1):return fail("space_route_binding_invalid")
			for id in ids:
				if not C.integer(id) or candidate.groups.get(str(int(id)),{}).get("combatTier")!=tier:return fail("space_route_tier_invalid")
				routes[route].append(int(id))
	last_error=""
	return {"routes":routes,"groups":candidate.groups.duplicate(true),"enemies":candidate.enemies.duplicate(true)}
