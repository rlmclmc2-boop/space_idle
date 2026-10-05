extends SceneTree
const Loader=preload("res://scripts/hyperspace_route_loader.gd")
const CC=preload("res://scripts/combat_context.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func fixture() -> Dictionary:
	var candidates: Dictionary={"schema_version":1,"scope":"space_only","status":"accepted_all40","groups":{},"enemies":{},"acceptance":{"accepted_under_original_limits":40,"unaccepted_group_ids":[]}}
	var binding: Dictionary={"schema_version":1,"scope":"space_only","data_status":"accepted_all40","candidate_config":Loader.CANDIDATES_PATH,"routes":{},"acceptance":{"status":"accepted_all40","verified_under_specified_seed":40,"pending_group_ids":[]},"selected_mainline_level_policy":{"atkRatio":"inherit_selected_mainline_level","lifeRatio":"inherit_selected_mainline_level","resRatio":"inherit_latest_cleared_mainline_level","jewelRatio":"inherit_latest_cleared_mainline_level","enemy_tier_offset":0}}
	var id:=9100
	for weapon in ["laser","missile","cannon","longLaser"]:
		binding.routes[weapon]={"normal":[],"elite":[],"boss":[],"ultimate":[]}
		for layer in 10:
			id+=1;var enemy_id:=id+900000;var tier: String="normal" if layer<4 else "elite" if layer<8 else "boss" if layer==8 else "ultimate"
			binding.routes[weapon][tier].append(id)
			candidates.groups[str(id)]={"slots":[enemy_id],"combatTier":tier,"formation_positions":[[200.0,150.0]]}
			candidates.enemies[str(enemy_id)]={"id":enemy_id,"size":1,"health":500.0,"armourType":99,"shield":0.0,"shieldType":0,"shieldRecovery":0.0,"shieldDelay":0.0,"equipment":[],"drops":[{"resourceId":1,"chance":1.0,"amount":10.0}],"dmgMultiple":1.0}
	return {"binding":binding,"candidates":candidates}
func _initialize() -> void:
	var db:=ShipDatabase.new();db.config.offlineMax=0
	var g:=BattleGame.new(db,false);g.profile.cleared=range(1,7);g.rebuild_unlocks()
	var f:=fixture();var groups_before:=JSON.stringify(db.groups);var enemies_before:=JSON.stringify(db.enemies)
	check(not g.hyperspace.snapshot(g).manual_ready,"absent production files stay disabled")
	var live_binding:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/space_enemy_routes.json")) if FileAccess.file_exists("res://data/space_enemy_routes.json") else null
	var live_loaded:bool=g.load_hyperspace_routes()
	if live_binding is Dictionary and live_binding.get("data_status")=="accepted_all40":
		check(live_loaded and g.hyperspace.snapshot(g).manual_ready,"accepted production includes reward readiness")
	else:check(not live_loaded and g.manual_hyperspace.last_error in ["space_data_missing","space_data_not_accepted"],"missing or unaccepted review cannot enable production")
	var review: Dictionary=f.binding.duplicate(true);review.data_status="review_candidate_not_all40_accepted"
	check(not g.load_hyperspace_routes(review,f.candidates) and not g.hyperspace.snapshot(g).manual_ready,"review candidate never enables production")
	var energy: float=g.profile.hyperspace.energy
	check(not g.start_hyperspace("alpha",5) and g.profile.hyperspace.energy==energy,"unaccepted start spends no ticket")
	check(g.load_hyperspace_routes(f.binding,f.candidates) and g.hyperspace.snapshot(g).manual_ready,"synthetic accepted manifest enables isolated routes")
	check(g.manual_hyperspace.route_ids.alpha==f.binding.routes.laser.normal+f.binding.routes.laser.elite+f.binding.routes.laser.boss+f.binding.routes.laser.ultimate,"weapon route maps to configured Greek route")
	check(JSON.stringify(db.groups)==groups_before and JSON.stringify(db.enemies)==enemies_before,"loader never registers candidates in mainline")
	check(g.start_hyperspace("alpha",5) and not is_same(g.db.enemies,db.enemies),"manual session switches to independent enemy registry")
	g.spawn_group();check(g.enemies.size()==1 and g.enemies[0].id==909101 and g.enemies[0].drops.size()==1,"spawn uses candidate enemies and authored ordinary drops")
	var probe:=RandomNumberGenerator.new();probe.seed=112233
	var first:=probe.randf();var second:=probe.randf();var chance: float=(first+second)*0.5
	var expected: Array=[]
	if first<chance:expected.append("1")
	if second<chance:expected.append("2")
	var victim: Dictionary=g.enemies[0];victim.jewelDropChecked=true
	victim.drops=[{"resourceId":1,"chance":chance,"amount":10.0},{"resourceId":2,"chance":chance,"amount":20.0}]
	g.rng.seed=112233;var reward_rng: String=g.profile.hyperspace.random_state
	g.hit_enemy(victim,1e30,0,[],false,CC.root(1,"resource_fixture",""))
	check(expected.size()==1 and g.drops.map(func(drop):return drop.id)==expected,"iron and uranium use separate rolls even with same chance")
	check(g.rng.state==probe.state,"ordinary resources consume exactly their two independent rolls")
	check(g.profile.hyperspace.random_state==reward_rng,"ordinary loot never advances drone reward random stream")
	check(not g.load_hyperspace_routes(f.binding,f.candidates),"active session cannot replace its registry")
	g.manual_hyperspace.finish(g,false)
	check(is_same(g.db,db) and JSON.stringify(db.groups)==groups_before and JSON.stringify(db.enemies)==enemies_before,"return restores original registries unchanged")
	var bad: Dictionary=f.binding.duplicate(true);bad.routes.missile.normal[0]=bad.routes.laser.normal[0]
	check(not g.load_hyperspace_routes(bad,f.candidates) and not g.hyperspace.snapshot(g).manual_ready,"duplicate accepted IDs rejected and readiness cleared")
	bad=f.binding.duplicate(true);bad.selected_mainline_level_policy.enemy_tier_offset=1
	check(not g.load_hyperspace_routes(bad,f.candidates),"tier offset forbidden")
	var broken: Dictionary=f.candidates.duplicate(true);broken.enemies.erase("909101")
	check(not g.load_hyperspace_routes(f.binding,broken),"missing slot enemy rejects registry")
	broken=f.candidates.duplicate(true);broken.acceptance.unaccepted_group_ids=[9137]
	check(not g.load_hyperspace_routes(f.binding,broken),"pending acceptance cannot be overridden by status text")
	broken=f.candidates.duplicate(true);broken.groups["9101"]=[]
	check(not g.load_hyperspace_routes(f.binding,broken),"malformed accepted group rejects without engine error")
	broken=f.candidates.duplicate(true);broken.groups["9101"].slots=[null]
	check(not g.load_hyperspace_routes(f.binding,broken),"empty accepted encounter rejected")
	check(JSON.stringify(db.groups)==groups_before and JSON.stringify(db.enemies)==enemies_before,"rejected data never mutates mainline")
	print("HYPERSPACE_ROUTE_LOADER ",checks," checks ",failures," failures; synthetic acceptance only")
	quit(1 if failures else 0)
