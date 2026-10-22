extends SceneTree
const CC=preload("res://scripts/combat_context.gd")
const Transfer=preload("res://scripts/save_transfer.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func opened(db: ShipDatabase) -> BattleGame:
	var g:=BattleGame.new(db,false);g.profile.cleared=range(1,8);g.rebuild_unlocks();g.pending_unlocks.clear();return g
func _initialize() -> void:
	var db:=ShipDatabase.new();db.config.offlineMax=0
	var routes: Dictionary={};var n:=9000;var mon:=int(db.enemies.keys()[0]);var original: Dictionary=db.levels[4].duplicate(true)
	# New synthetic groups test protocol only. Not final route/balance content.
	for route in ["alpha","beta","gamma","delta"]:
		routes[route]=[]
		for layer in 10:
			n+=1;routes[route].append(n)
			db.groups[str(n)]={"slots":[mon],"combatTier":"normal" if layer<4 else "elite" if layer<8 else "boss" if layer==8 else "ultimate","formation_positions":[[100.0+(n%4)*40,100.0+layer*10]]}
	var g:=opened(db);var base=db;var before: Array=g.profile.cleared.duplicate();var bosses: Array=g.profile.bossSeen.duplicate()
	var hs:Dictionary=g.hyperspace.save_data()
	for route in ["alpha","beta"]:hs.hyperspace.history[route]={"1":1.0,"2":1.0,"3":1.0,"4":1.0}
	check(g.hyperspace.install_snapshot(hs,db),"history fixture installs")
	check(g.configure_hyperspace_routes(routes),"inject forty new fixture IDs with 4/4/1/1 tiers")
	var energy: float=g.hyperspace.state.energy
	check(not g.start_hyperspace("unknown",5) and g.hyperspace.state.energy==energy,"unknown route never spends ticket")
	check(g.start_hyperspace("alpha",5) and g.manual_hyperspace.active and not is_same(g.db,base),"real manual battle uses disposable database view")
	check(db.levels[4]==original and g.db.levels[4].groups.size()==10,"main level row untouched")
	for kind in ["lifeRatio","atkRatio","resRatio"]:check(g.db.ratio(5,0,kind)==original[kind] and g.db.ratio(5,9,kind)==original[kind],"selected stage ratio constant without enemy tier increment")
	check(not g.start(6,false),"ordinary stage switch cannot replace active space battle")
	var saved: Dictionary=g.portable_save_data()
	check(not saved.has("journey") and saved.hyperspace.active.return_target=={"stage":1,"loop":false,"guard_index":0} and Transfer.new().prepare_data(saved,db).error=="","manual save stores fresh return destination and valid transaction")
	var reloaded:=opened(db);reloaded.load_progress_data(saved)
	check(reloaded.hyperspace.state.active.is_empty() and reloaded.hyperspace.state.energy==energy,"interrupted manual session refunds once without offline work")
	g.hyperspace.advance_manual(1.0)
	for layer in 10:
		g.spawn_group()
		check(g.enemies.size()==1 and g.enemies[0].combat_tier==("normal" if layer<4 else "elite" if layer<8 else "boss" if layer==8 else "ultimate"),"actual ten layer spawn fixture")
		g.hit_enemy(g.enemies[0],1e30,0,[],false,CC.root(layer+1,"fixture","laser"));g.tick(0.001)
	check(not g.manual_hyperspace.active and is_same(g.db,base) and g.state==g.State.TRAVEL and g.group_index==0 and g.distance==0,"success starts a fresh sortie at the original stage")
	check(g.profile.cleared==before and g.profile.highestLevel==8 and g.profile.bossSeen==bosses,"space victory cannot clear or advance mainline")
	check(g.hyperspace.state.active.status=="completed_pending" and g.hyperspace.best_x1(g,"alpha",5)>0,"success freezes reward and genuine game-time X1")
	var receipt: Dictionary=g.hyperspace.state.active.duplicate(true)
	check(g.hyperspace_runtime.claim(g,receipt.round_id,receipt.run_id) and not g.hyperspace_runtime.claim(g,receipt.round_id,receipt.run_id),"manual reward claim idempotent")
	hs=g.hyperspace.save_data();hs.hyperspace.energy=216000;check(g.hyperspace.install_snapshot(hs,db),"energy fixture installs")
	var beta_history: Dictionary=g.hyperspace.state.history.beta.duplicate(true)
	check(g.start_hyperspace("beta",5),"new manual run after settlement")
	g.begin_retreat()
	check(not g.manual_hyperspace.active and is_same(g.db,base) and g.hyperspace.state.energy==216000 and g.hyperspace.state.history.beta==beta_history,"actual defeat restores and refunds, no space reward/record")
	var bad: Dictionary=routes.duplicate(true);bad.alpha[0]=int(db.levels[4].groups[0].id)
	check(not g.configure_hyperspace_routes(bad),"mainline groups cannot masquerade as new space encounters")
	print("HYPERSPACE_MANUAL ",checks," checks ",failures," failures; synthetic IDs only; no 60-stage run")
	quit(1 if failures else 0)
