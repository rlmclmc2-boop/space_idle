extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
class ChangedDuringShared extends "res://scripts/presented_battle_game.gd":
	var mutation_due:=false
	var mutation_ok:=false
	var mutation_state:Dictionary={}
	var later_shared:=0
	func advance_planets(dt:float)->void:
		super.advance_planets(dt)
		if mutation_due:
			mutation_due=false;mutation_ok=upgrade_slot("defence",1,1)
			mutation_state=native_execution.kernel.export_handoff().duplicate(true)
	func advance_auto_gen(dt:float)->void:
		later_shared+=1;super.advance_auto_gen(dt)
class RefusedLater extends "res://scripts/native_execution_session.gd":
	var refuse:=true
	var refuse_preparation:=false
	func prepare_galaxy_refit(g,values:Dictionary)->Dictionary:return {} if refuse_preparation else super.prepare_galaxy_refit(g,values)
	func handoff_to_legacy(g:RefCounted,reason:String)->bool:return false if refuse else super.handoff_to_legacy(g,reason)
func refit_fixture(key:String="missile",effect:String="equipment_value",shared_change:bool=false,selection:bool=false):
	var db=ShipDatabase.new();db.equipment.shield[0].para2=0.0
	# Preserve this fixture's four-layer refit coverage with an explicit test hull.
	db.ships.Heavy_Battleship.defenseSlots=4
	var g=ChangedDuringShared.new(db,false) if shared_change else preload("res://scripts/presented_battle_game.gd").new(db,false)
	g.profile.cleared=range(1,101);g.rebuild_unlocks()
	g.economy.credit_many({"1":1e30,"2":1e30})
	var equipment:Dictionary=g.equipment.save_data();equipment.selectedShip="Heavy_Battleship"
	equipment.loadout=preload("res://scripts/equipment_state.gd").empty_loadout(db,equipment.selectedShip)
	equipment.loadout.weapons[0].key=key
	equipment.loadout.defence=[{"key":"shield","level":10},{"key":"armour","level":10},{"key":"shield","level":10},{"key":"armour","level":10}]
	check(g.equipment.install_snapshot(equipment,db),"Current native equipment fixture installs")
	var enhancement:Dictionary=g.enhancement_growth.save_data();enhancement.enhancementLevel=40
	check(g.enhancement_growth.install_snapshot(enhancement),"Current native enhancement fixture installs")
	g.set_enhancement_branch("weapons","repeat",1,"B")
	if key=="missile":g.set_enhancement_branch("weapons","repeat",3,"B")
	g.configuration_committed();g.reset_player();g.state=BattleGame.State.COMBAT
	g.enemies.assign([{"uid":100,"slot":4,"x":286.0,"y":150.0,"hp":1e8,"max_hp":1e8,"armourType":1,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0},{"uid":101,"slot":3,"x":240.0,"y":150.0,"hp":1e8,"max_hp":1e8,"armourType":1,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
	g.cooldowns[g.slot_id("weapons",0)]=0.0
	g.profile.cleared=range(1,101);g.rebuild_unlocks();g.galaxy_runtime.refresh_unlocks(g)
	check(g.assign_crew("navigator","galaxy_explore","galaxy_1"),"galaxy assignment before admission")
	var region=g.galaxy.regions.galaxy_1
	var chosen=""
	for build in region.builds.values():
		if build.effect_type==effect:chosen=build.key;break
	check(not chosen.is_empty(),"real effect building exists")
	var galaxy:Dictionary=g.galaxy.save_data();var saved:Dictionary=galaxy.galaxies.galaxy_1
	var slot:Dictionary=saved.slots[0]
	slot.type=chosen;slot.planned_type=chosen;slot.status="constructing";slot.level=1;slot.work=region.work_cost();slot.construction=0.01
	saved.blueprint.nodes[0].type=chosen;saved.blueprint.nodes[0].planned_type=chosen
	saved.explore_work=region.work_cost()
	if selection:
		saved.status="developing";saved.explore_work=region.row.explore_work_total
		for item in saved.slots:item.status="active";item.level=1;item.work=region.work_cost();item.construction=0.0
		var cells:=PackedByteArray();cells.resize(int(region.row.map_w)*int(region.row.map_h));cells.fill(1)
		saved.owned=Marshalls.raw_to_base64(cells.compress(FileAccess.COMPRESSION_DEFLATE))
	check(g.galaxy.install_snapshot(galaxy,db),"Native boundary fixture installs complete galaxy state")
	g.enemies[0].drops=[{"resourceId":1,"chance":1.0,"amount":100000.0}]
	var reactor:Dictionary=g.reactor.save_data();reactor.reactorLevel=20;check(g.reactor.install_snapshot(reactor,db.config),"Reactor fixture installs")
	var planets:Dictionary=g.planets.save_data();planets.merge(g.crew.save_data());planets.planets["1"].conquered=true;check(g.planets.install_snapshot(planets,db),"Planet contribution fixture installs")
	g.configuration_committed();g.reset_player()
	g.player.armour*=0.6;g.player.shield*=0.6;g.sync_jewel_defence_damage()
	# Deliberately uneven damage: preserving prior loss would fail the refit
	# contract even though aggregate HP could still look correct.
	for layer in ["armour","shield"]:
		var remaining=g.stat(layer)-g.player[layer]
		for i in g.defense_entries().size():
			var entry:Dictionary=g.slot_entry("defence",i)
			if entry.key!=layer:continue
			var loss=minf(remaining,g.jewel_equipment_stat(entry))
			g.jewel_defence_damage[i]=loss;remaining-=loss
	for i in g.defense_entries().size():g.enhancement_buffers[i]=g.jewel_equipment_stat(g.slot_entry("defence",i))*0.1
	var desc=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_low_contract")
	if desc.has("error"):printerr("ADMISSION: ",desc)

	check(g.admit_native_compiled_execution("native_low_contract"),"fixture native admission")
	g.tick(1.0/60.0)
	return g

func run()->void:
	# Real noncombat contributions and active->upgrading selections preserve all
	# combat state, even when the session would refuse a descriptor or handoff.
	for effect in ["gem_fragment","crew_exp","iron_auto_ratio","uranium_auto_ratio","selection"]:
		var selection:bool=effect=="selection"
		var g=refit_fixture("missile","equipment_value" if selection else effect,false,selection)
		var owner=g.native_execution;var refused=RefusedLater.new()
		for field in ["kernel","actor_rows","actor_by_uid","execution_scope","weapons","production_seconds","ticks"]:refused.set(field,owner.get(field))
		refused.refuse_preparation=true;g.native_execution=refused;owner=refused
		var region=g.galaxy.regions.galaxy_1
		var before:Dictionary=owner.kernel.export_handoff().duplicate(true)
		var inputs:Array=g.attributes.configuration_inputs(g)
		var stat=g.stat("armour")
		var generation:int=g.galaxy.effect_generation
		var effects:Dictionary=g.galaxy.effects.region_effects(region)
		var notices=[];g.event.connect(func(kind,info):
			if kind in ["galaxy_changed","equipment_stats","reactor_changed"]:notices.append(kind))
		g.galaxy.add_pending("galaxy_1",1.0-1.0/60.0-g.galaxy.pending("galaxy_1"))
		check(g.prepare_logical_step(1.0/60.0),effect+" preflight needs no native configuration")
		check(not g.galaxy_runtime.native_refit.is_empty() and g.galaxy_runtime.native_refit.plan.is_empty(),effect+" prepared region without descriptor")
		g.galaxy.add_pending("galaxy_1",1.0-g.galaxy.pending("galaxy_1"))
		check(g.galaxy_runtime.flush_pending(g,"galaxy_1"),effect+" actual boundary commits")
		check(g.native_execution==owner and g.native_handoff_count==0 and owner.kernel.export_handoff()==before,effect+" keeps exact live native state")
		check(g.attributes.configuration_inputs(g)==inputs and g.stat("armour")==stat,effect+" combat cache remains valid")
		check(notices==["galaxy_changed"],effect+" only galaxy notification after complete commit")
		if selection:
			check(region.slots.any(func(item):return item.status=="upgrading") and g.galaxy.effect_generation==generation,"selection progresses without invalidating any contribution")
			check(g.galaxy.effects.region_effects(region)==effects,"selection leaves exact contributions unchanged")
		else:
			check(region.slots[0].status=="active" and g.galaxy.effect_generation==generation+1,effect+" contribution installed at completion")
			g.galaxy.effects.refresh(g.galaxy)
			check(g.galaxy.effects.totals[effect]>effects[effect],effect+" noncombat cache reflects new contribution")
		g.begin_retreat()
	for key in ["laser","cannon","missile","longLaser"]:
		var g=refit_fixture(key);var owner=g.native_execution;var k=owner.kernel
		var region=g.galaxy.regions.galaxy_1
		var before=k.export_handoff().duplicate(true);var rng=g.rng.state;var galaxy_rng=region.random.state
		var region_before=region.save_data().duplicate(true)
		var shots=g.projectiles.duplicate();var health=g.player.duplicate();var old_max={"armour":g.stat("armour"),"shield":g.stat("shield")}
		var notices=[];g.event.connect(func(kind,info):
			if kind in ["galaxy_changed","equipment_stats","reactor_changed"]:notices.append(kind))
		g.galaxy.add_pending("galaxy_1",10.0-1.0/60.0-g.galaxy.pending("galaxy_1"))
		check(g.prepare_logical_step(1.0/60.0),key+" preflight")
		check(g.native_execution==owner and not g.galaxy_runtime.native_refit.is_empty(),key+" supported boundary retains native")
		if g.galaxy_runtime.native_refit.is_empty():quit(1);return
		check(k.export_handoff()==before and g.rng.state==rng and region.random.state==galaxy_rng and region.save_data()==region_before,key+" prediction and validation pure")
		g.galaxy.add_pending("galaxy_1",10.0-g.galaxy.pending("galaxy_1"))
		check(g.galaxy_runtime.flush_pending(g,"galaxy_1"),key+" commit")
		check(g.native_execution==owner and g.native_handoff_count==0 and region.slots[0].status=="active",key+" actual completion remains native")
		var after=k.export_handoff().duplicate(true)
		for field in ["clock","cooldowns","ejections","repeats","deferred","attack_counter","incoming_counter"]:
			check(after.get(field)==before.get(field),key+" preserves "+field)
		# Source is the live player row: its HP changes, carrier state must not.
		for i in before.flights.size():
			var lhs:Dictionary=before.flights[i].duplicate(true);var rhs:Dictionary=after.flights[i].duplicate(true)
			lhs.view.erase("source");rhs.view.erase("source")
			check(lhs==rhs,key+" carrier and birth snapshot unchanged")
		check(g.rng.state==rng and shots.size()==g.projectiles.size(),key+" preserves RNG and shots")
		for i in shots.size():check(is_same(shots[i],g.projectiles[i]),key+" same live shot")
		for layer in ["armour","shield"]:
			var ratio:float=health[layer]/old_max[layer] if old_max[layer]>0 else g.refit_health_ratios[layer]
			check(is_equal_approx(g.player[layer],g.stat(layer)*ratio),key+" health ratio "+layer)
			for i in g.defense_entries().size():
				var entry:Dictionary=g.slot_entry("defence",i)
				if entry.key==layer:check(is_equal_approx(g.jewel_defence_damage[i],g.jewel_equipment_stat(entry)*(1.0-ratio)),key+" redistributed module loss")
		check(notices==["equipment_stats","equipment_stats","reactor_changed","galaxy_changed"],key+" notifications exactly once")
		var invalid=preload("res://scripts/native_execution_compiler.gd").new().compile(g,owner.execution_scope)
		invalid.refit_token=k.refit_token()
		check(k.can_refit_configuration(invalid),key+" valid descriptor and current token accepted before field rejection")
		invalid.player.armour=0.0;invalid.player.shield=0.0
		check(not k.can_refit_configuration(invalid) and not k.refit_configuration(invalid) and k.export_handoff()==after,key+" zero total health rejects without mutation")
		invalid.player.armour=g.player.armour;invalid.player.shield=g.player.shield;invalid.weapons[0].entry.level+=1
		check(not k.can_refit_configuration(invalid) and not k.refit_configuration(invalid) and k.export_handoff()==after,key+" shape change rejects without mutation")
		var low=owner.prepare_galaxy_refit(g,{"equipment_value":0.000001,"charge_max":g.galaxy.multiplier("charge_max")})
		check(not low.is_empty(),key+" smaller numeric refit accepted")
		var old_buffers=g.enhancement_buffers.duplicate();var clipped:=false
		check(owner.commit_galaxy_refit(g,low),key+" smaller refit commits")
		for i in low.descriptor.defences.size():
			var cap:float=low.descriptor.defences[i].maximum*low.descriptor.defences[i].memory_cap
			clipped=clipped or float(old_buffers[i])>cap
			check(is_equal_approx(g.enhancement_buffers[i],minf(float(old_buffers[i]),cap)),key+" memory buffer clamped")
		check(clipped,key+" fixture exercises buffer clamp")
		g.begin_retreat()
	var g=refit_fixture("missile","charge_max");var owner=g.native_execution;var region=g.galaxy.regions.galaxy_1
	var old_drop:Dictionary=owner.kernel.enemy_views()[0].compiled_drops[0].duplicate()
	g.galaxy.add_pending("galaxy_1",10.0-g.galaxy.pending("galaxy_1"))
	check(g.galaxy_runtime.flush_pending(g,"galaxy_1"),"charge completion commit")
	check(g.native_execution==owner,"charge completion keeps native")
	var current=preload("res://scripts/native_execution_compiler.gd").new().compile(g,owner.execution_scope)
	check(owner.kernel.enemy_views()[0].compiled_drops==current.enemies[0].compiled_drops,"compiled drops match new live reactor configuration")
	check(current.enemies[0].compiled_drops[0].amount>old_drop.amount,"real charge completion increases smelting drop")
	owner.kernel.hit_handle(owner.kernel.actor_handle(100),1e30,1)
	var drops=owner.kernel.take_feedback().filter(func(row):return int(row.kind)==7 and int(row.shot.get("id",-1))==1)
	check(not drops.is_empty(),"death emits resource drop after refit")
	if not drops.is_empty():check(drops[0].shot.amount==current.enemies[0].compiled_drops[0].amount,"death uses updated resource amount")
	g.begin_retreat()
	g=refit_fixture();owner=g.native_execution
	var initial_refusal=RefusedLater.new()
	for field in ["kernel","actor_rows","actor_by_uid","execution_scope","weapons","production_seconds","ticks"]:initial_refusal.set(field,owner.get(field))
	initial_refusal.refuse_preparation=true;g.native_execution=initial_refusal
	var refused_galaxy:Dictionary=g.galaxy.save_data();var refused_wallet:Dictionary=g.economy.save_data();var refused_clock:float=g.production_time()
	check(not g.prepare_logical_step(10.0),"Refused preparation and handoff reject before shared work")
	check(g.galaxy.save_data()==refused_galaxy and g.economy.save_data()==refused_wallet and g.production_time()==refused_clock,"Initial refusal leaves galaxy, wallet and clock unchanged")
	g.begin_retreat()
	# A numeric purchase between preflight and the region commit keeps shape,
	# but invalidates old health, factors and drops. It must never be overwritten.
	g=refit_fixture();owner=g.native_execution
	var plan=owner.prepare_galaxy_refit(g,{"equipment_value":1.1,"charge_max":1.0})
	check(not plan.is_empty(),"stale plan initially valid")
	check(g.upgrade_slot("defence",1,1),"real numeric purchase between prepare and commit")
	var updated=owner.kernel.export_handoff().duplicate(true)
	check(not owner.commit_galaxy_refit(g,plan) and owner.kernel.export_handoff()==updated,"old plan rejected without overwriting accepted numeric update")
	g.begin_retreat()
	g=refit_fixture("missile","equipment_value",true);owner=g.native_execution
	g.galaxy.add_pending("galaxy_1",10.0-1.0/60.0-g.galaxy.pending("galaxy_1"))
	check(g.prepare_logical_step(1.0/60.0),"stale plan fallback preflight")
	g.mutation_due=true;g.tick(1.0/60.0)
	check(g.mutation_ok and g.native_execution==null and g.native_handoff_count==1,"stale plan safely transfers updated state once")
	check(g.galaxy.regions.galaxy_1.slots[0].status=="active" and not g.paused,"legacy finishes actual refit after stale-plan transfer")
	g.begin_retreat()
	g=refit_fixture("missile","equipment_value",true);owner=g.native_execution
	var refused=RefusedLater.new()
	for field in ["kernel","actor_rows","actor_by_uid","execution_scope","weapons","production_seconds","ticks"]:refused.set(field,owner.get(field))
	g.native_execution=refused;owner=refused
	g.galaxy.add_pending("galaxy_1",10.0-1.0/60.0-g.galaxy.pending("galaxy_1"))
	var before_region=g.galaxy.regions.galaxy_1.save_data().duplicate(true)
	check(g.prepare_logical_step(1.0/60.0) and not g.galaxy_runtime.native_refit.is_empty(),"late failure starts with a valid plan")
	g.mutation_due=true;g.later_shared=0
	g.tick(1.0/60.0)
	check(g.mutation_ok and owner.advance_blocked and g.paused and g.native_step_phase=="blocked","stale commit plus refused transfer explicitly blocks")
	check(owner.kernel.export_handoff()==g.mutation_state and g.later_shared==0,"late failure executes neither remaining economy nor combat")
	check(g.galaxy.regions.galaxy_1.save_data()==before_region and is_equal_approx(g.galaxy.pending("galaxy_1"),10.0),"late failure preserves all unconsumed region work")
	refused.refuse=false
	check(not owner.handoff_to_legacy(g,"retry") and g.native_execution==owner,"blocked partial shared step permits cancellation only, never later handoff")
	var clock=g.production_time();g.paused=false
	check(not g.prepare_logical_step(1.0/60.0) and g.production_time()==clock and owner.kernel.export_handoff()==g.mutation_state,"blocked late failure cannot replay shared work on resume")
	g.begin_retreat()
	check(g.native_execution==null and is_equal_approx(g.native_cancelled_step,1.0/60.0),"explicit cancel marks already-started step for scheduler discard")
	print("GALAXY_REFIT_CHECKS ",checks," failures ",failures)
	FileAccess.open("res://.runtime/galaxy-refit-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
	quit(1 if failures else 0)
