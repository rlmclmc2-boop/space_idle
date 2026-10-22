extends SceneTree
const N=preload("res://scripts/growth_number.gd")
class SharedCommandGame extends "res://scripts/presented_battle_game.gd":
	var command_due:=false
	var command_ok:=false
	func advance_shared_clock_and_economy(dt:float)->void:
		super.advance_shared_clock_and_economy(dt)
		if command_due:
			command_due=false;command_ok=equip_slot("weapons",0,"laser")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(key:String="missile",beam_chain:bool=false,shared_command:bool=false):
	var db=ShipDatabase.new();db.equipment.shield[0].para2=0.0
	# This fixture explicitly exercises three host slots followed by one drone.
	db.ships[db.ships.keys()[0]].weaponSlots=3
	db.ships[db.ships.keys()[0]].defenseSlots=4
	var g=SharedCommandGame.new(db,false) if shared_command else preload("res://scripts/presented_battle_game.gd").new(db,false)
	g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();fund(g,{"1":1e30,"2":1e30})
	var equipment=g.equipment.save_data();equipment.loadout.weapons[0].key=key
	equipment.loadout.defence=[{"key":"shield","level":1},{"key":"armour","level":1},{"key":"shield","level":1},{"key":"armour","level":1}]
	check(g.equipment.install_snapshot(equipment,db),"Equipment fixture validates")
	if beam_chain:
		var enhancement=g.enhancement_growth.save_data();enhancement.enhancementLevel=40;g.enhancement_growth.install_snapshot(enhancement);g.profile.cleared=range(1,61);g.profile.highestLevel=61
		g.rebuild_unlocks();g.set_enhancement_branch("weapons","repeat",1,"B")
		if key=="missile":g.set_enhancement_branch("weapons","repeat",3,"B")
	g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT
	g.enemies.assign([{"uid":100,"slot":4,"x":286.0,"y":150.0,"hp":1e8,"max_hp":1e8,"armourType":1,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0},{"uid":101,"slot":3,"x":240.0,"y":150.0,"hp":1e8,"max_hp":1e8,"armourType":1,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
	if key=="laser":
		var hurt_key=str(g.slot_entry("defence",0).key)
		g.player[hurt_key]=N.subtract(g.player[hurt_key],1.0);g.jewel_defence_damage[0]=1.0
	g.cooldowns[g.slot_id("weapons",0)]=0.0
	var desc=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_low_contract")
	if desc.has("error"):printerr("ADMISSION: ",desc)

	check(g.admit_native_compiled_execution("native_low_contract"),"fixture native admission")
	g.tick(1.0/60.0)
	return g

func fund(game: BattleGame, resources: Dictionary) -> void:
	var snapshot := game.economy.save_data()
	snapshot.resources = resources.duplicate(true)
	check(game.economy.install_snapshot(snapshot), "Fixture funds are valid")

func _initialize()->void:call_deferred("run")
func run()->void:
	var g=fixture("missile",true);var owner=g.native_execution;var core=owner.kernel
	var old=core.export_handoff();var born=old.flights[0].snapshot;var position=g.projectile_position(g.projectiles[0]);var rng_state=g.rng.state
	check(old.ejections.size()>0,"upgrade fixture has committed pending missile tubes")
	var cost=g.slot_upgrade_cost("weapons",0,1);var balance=g.economy.resources().duplicate(true)
	var old_cd=float(old.cooldowns[0].remaining)
	check(g.upgrade_slot("weapons",0,1),"ordinary numeric upgrade succeeds")
	var after=core.export_handoff()
	check(g.native_execution==owner and g.native_handoff_count==0,"numeric upgrade keeps original native owner")
	check(g.projectile_position(g.projectiles[0])==position and g.rng.state==rng_state and after.revision==old.revision,"upgrade does not move, advance or reroll")
	check(after.cooldowns[0].remaining==old_cd and after.ejections.size()==old.ejections.size() and after.repeats.size()==old.repeats.size(),"upgrade keeps deadlines and pending queues")
	check(after.flights[0].snapshot.damage==born.damage and after.flights[0].snapshot.weapon==born.weapon,"active attack birth values stay frozen")
	check(after.ejections[0].snapshot.damage==born.damage and after.ejections[0].snapshot.weapon==born.weapon,"pending attack birth values stay frozen")
	check(cost.keys().all(func(id):return N.compare(g.economy.balance(id),N.subtract(balance[id],cost[id]))==0),"upgrade spends original cost once")
	var first_id=int(born.id);var newer=false
	for i in 300:
		g.tick(1.0/60.0)
		for flight in core.export_handoff().get("flights",[]):
			if int(flight.snapshot.id)>first_id and int(flight.weapon_index)==0:
				check(flight.snapshot.weapon==g.player_weapon_row(g.combat_entry(0)),"future attack uses refreshed birth configuration")
				newer=true;break
		if newer:break
	check(newer,"next native attack starts after upgrade")
	var serials=core.export_handoff()
	g.begin_retreat()
	check(g.projectile_serial==int(serials.projectile_serial) and g.main_attack_serial==int(serials.attack_serial) and g.attack_instance_serial==int(serials.instance_serial),"exit preserves global attack and flight serials")
	g=fixture("laser",true);owner=g.native_execution;core=owner.kernel
	var invalid=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_low_contract")
	var previous=core.export_handoff();invalid.weapons[0].damage*=2.0;invalid.defences[-1].base=-1.0
	check(not core.update_configuration(invalid),"invalid late defence rejects complete update")
	check(core.export_handoff().flights[0].snapshot==previous.flights[0].snapshot and core.export_handoff().player==previous.player,"rejected update changes no attack/player state")
	var shield=g.player.shield;var hp=g.player.armour
	var defence=g.slot_entry("defence",0);var delta=N.subtract(g.jewel_equipment_stat(defence,int(defence.level)+1),g.jewel_equipment_stat(defence))
	var loss=g.jewel_defence_damage.duplicate(true)
	check(g.upgrade_slot("defence",0,1),"native defensive numeric upgrade succeeds")
	check(g.native_execution==owner and N.compare(g.player.shield,N.add(shield,delta if defence.key=="shield" else 0.0))==0 and N.compare(g.player.armour,N.add(hp,delta if defence.key=="armour" else 0.0))==0,"defensive upgrade adds only normal capacity difference")
	check(g.jewel_defence_damage==loss,"defensive upgrade preserves incurred module damage")
	g.begin_retreat()
	g=fixture("missile",true);g.native_execution_auto=true
	check(g.equip_slot("weapons",0,"laser") and g.native_execution==null and g.native_handoff_count==1,"structural refit still transfers whole encounter")
	g.projectile_clear();g.missile_queue.clear();g.jewel_repeats.clear();g.group_index=0;g.state=BattleGame.State.TRAVEL;g.spawn_group(true)
	check(g.native_execution!=null,"next clean supported encounter selects native again")
	g.begin_retreat();g.set_enhancement_branch("weapons","critical",1,"B");g.group_index=0;g.state=BattleGame.State.TRAVEL;g.spawn_group(true)
	check(g.native_execution==null and not g.paused,"unsupported next encounter selects legacy before attack")
	g.begin_retreat()
	g=fixture("missile",true);g.native_before_configuration_change();g.projectile_clear();g.missile_queue.clear();g.jewel_repeats.clear();g.native_handoff_count=0
	# Real production crew scheduler, assigned before the fresh native owner.
	check(g.assign_crew("navigator","equipment_upgrade","equipment"),"normal equipment crew enabled")
	check(g.admit_native_compiled_execution("native_low_contract"),"automatic upgrade fixture readmitted")
	owner=g.native_execution;var levels=0
	for entry in g.loadout_entries("weapons")+g.loadout_entries("defence"):levels+=int(entry.level)
	var clock=g.production_time();var motion=g.motion_clock
	for i in 180:g.tick(1.0/60.0)
	var bought=0
	for entry in g.loadout_entries("weapons")+g.loadout_entries("defence"):bought+=int(entry.level)
	check(bought-levels==3*(g.loadout_entries("weapons")+g.loadout_entries("defence")).size() and g.native_execution==owner and g.native_handoff_count==0,"three main batch sweeps keep native residence")
	check(is_equal_approx(g.production_time()-clock,3.0) and is_equal_approx(g.motion_clock-motion,3.0),"shared economy and native logic advance exactly once")
	g.begin_retreat()
	g=fixture("missile",true);g.economy.credit_fragments(1e30)
	check(g.upgrade_enhancement(1)==1 and g.native_execution==null and g.native_handoff_count==1,"shared enhancement buys once after whole-owner handoff")
	g.begin_retreat()
	g=fixture("missile",true)
	check(g.upgrade_reactor(1) and g.native_execution==null and g.native_handoff_count==1,"reactor purchase transfers before cost/state mutation")
	g.begin_retreat()
	g=fixture("missile",true)
	var order=g.enhancement_order("weapons");order.reverse()
	check(g.set_enhancement_order("weapons",order) and g.native_execution==null and g.native_handoff_count==1,"effect order changes transfer once")
	g.begin_retreat()
	g=fixture("missile",true)
	check(g.assign_crew("navigator","equipment_upgrade","equipment") and g.native_execution==null and g.native_handoff_count==1,"new crew assignment transfers before modifier mutation")
	g.begin_retreat()
	g=fixture("missile",true);g.native_before_configuration_change();g.projectile_clear();g.missile_queue.clear();g.jewel_repeats.clear();g.native_handoff_count=0
	g.enemies[0].equipment=[{"name":"laser_mon"}];g.enemies[0].cooldowns=[10.0];g.enemies[0].dmgMultiple=1.0
	check(g.admit_native_compiled_execution("native_low_contract"),"armed enemy fixture admits legal default fields")
	owner=g.native_execution
	check(g.upgrade_slot("weapons",0,1) and g.native_execution==owner and g.native_handoff_count==0,"armed enemy default factor does not reject ordinary upgrade")
	g.begin_retreat()
	g=fixture("missile",true);owner=g.native_execution;owner.kernel.cancel()
	var tech="singularity";var research=g.research.save_data();research.aiTechActive=tech;research.aiTechProgress[tech]=g.research.required(g,tech)-0.5;g.research.install_snapshot(research,g.db.data.ai_tech_tree)
	var points_before=g.research.progress(tech);var tech_level=g.hightech_level(tech)
	g.advance_hightech(1.0)
	check(g.research.progress(tech)==points_before and g.hightech_level(tech)==tech_level,"failed research completion handoff spends no progress or level")
	var growth_before=g.enhancement_growth.save_data();g.economy.credit_fragments(10000.0);var fragments_before=g.economy.balance("jewel")
	check(g.upgrade_enhancement(1)==0 and g.enhancement_growth.save_data()==growth_before and g.economy.balance("jewel")==fragments_before,"Failed native preparation changes no enhancement or fragments")
	var reactor_level=g.reactor.level();var uranium=g.economy.balance("2")
	check(not g.upgrade_reactor(1) and g.reactor.level()==reactor_level and N.compare(g.economy.balance("2"),uranium)==0,"failed reactor handoff spends no resources or level")
	g.begin_retreat()
	g=fixture("laser",true);owner=g.native_execution
	check(not g.start(0,false) and g.native_execution==owner,"invalid start retains current owner")
	g.begin_retreat()
	g=fixture("laser");g.native_before_configuration_change();g.projectile_clear();g.missile_queue.clear();g.jewel_repeats.clear()
	var drone_equipment=g.equipment.save_data();drone_equipment.loadout.weapons=[{"key":"laser","level":2},{"key":"laser","level":9},{"key":"missile","level":20}]
	check(g.equipment.install_snapshot(drone_equipment,g.db),"Drone host fixture validates")
	var drone={"id":"main_max","weapon":"laser","ultimate":false,"blue_source_bonus":false,"legendary":false,"origin_quality":"blue","level":1,"affixes":[],"hangings":[]}
	g.profile.hyperspace.inventory.drones[drone.id]=drone;g.profile.hyperspace.inventory.equipped=[drone.id]
	g.invalidate_stat_cache();g.reset_player();g.native_handoff_count=0
	var bonus=int(g.hyperspace.config.weapon_level_bonuses.blue)
	check(int(g.combat_entry(3).level)==9+bonus,"drone inherits same-weapon maximum, ignores stronger different weapon")
	check(int(g.projected_combat_entry(3,{0:3}).level)==9+bonus,"nonmaximum same-weapon purchase retains drone level")
	check(int(g.projected_combat_entry(3,{0:11}).level)==11+bonus,"maximum-crossing purchase raises drone level")
	check(g.admit_native_compiled_execution("native_low_contract"),"main maximum drone contract admitted")
	owner=g.native_execution
	check(g.upgrade_equipment_batch("1") and g.native_execution==owner and g.native_handoff_count==0,"main batch with drone retains native residence")
	var expected=g.combat_entry(3)
	var compiled=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_low_contract")
	var actual:Dictionary={}
	for weapon in owner.weapons:
		if not bool(weapon.hostile) and int(weapon.slot)==3:actual=weapon
	check(int(expected.level)==10+bonus and actual.entry==expected,"committed main batch and native drone entry agree")
	check(actual.damage==g.equipment_stat("laser",10+bonus) and actual.damage==compiled.weapons[3].damage,"kernel next-birth damage equals canonical Game after batch")
	g.begin_retreat()
	g=fixture("missile",true);owner=g.native_execution;owner.kernel.cancel()
	var inventory_before=g.profile.hyperspace.duplicate(true)
	check(not g.hyperspace.set_equipped(g,[]) and g.profile.hyperspace==inventory_before,"failed structural drone handoff leaves configuration unchanged")
	g.begin_retreat()
	for mode in ["1","10","max"]:
		g=fixture("missile",true);owner=g.native_execution;g.enable_compiled_combat_rules()
		var quote=g.slot_upgrade_cost("weapons",0,1)
		fund(g,{"1":float(quote.get("1",0))*2.5,"2":float(quote.get("2",0))*2.5})
		var legacy=preload("res://scripts/presented_battle_game.gd").new(g.db,false)
		legacy.profile=g.profile.duplicate(true);legacy.enhancement_growth.install_snapshot(g.enhancement_growth.save_data());legacy.equipment.install_snapshot(g.equipment.save_data(),g.db);legacy.research.install_snapshot(g.research.save_data(),g.db.data.ai_tech_tree);legacy.economy.install_snapshot(g.economy.save_data());legacy.reactor.install_snapshot(g.reactor.save_data(),g.db.config);legacy.player=g.player.duplicate(true);legacy.state=g.State.COMBAT
		legacy.enable_compiled_combat_rules();legacy.invalidate_stat_cache()
		var expected_ok=legacy.upgrade_equipment_batch(mode)
		var actual_ok=g.upgrade_equipment_batch(mode)
		check(actual_ok==expected_ok and g.equipment.save_data()==legacy.equipment.save_data() and g.economy.resources()==legacy.economy.resources(),"main ordered partial-budget batch preserved: "+mode)
		check(N.compare(g.player.armour,legacy.player.armour)==0 and N.compare(g.player.shield,legacy.player.shield)==0,"main sequential defence deltas preserved: "+mode)
		check(g.native_execution==owner and g.native_handoff_count==0,"one prepared batch retains native owner: "+mode)
		g.begin_retreat()
	g=fixture("missile",true);owner=g.native_execution;fund(g,{"1":0.0,"2":0.0})
	check(not g.upgrade_equipment_batch("1") and g.native_execution==owner and g.native_handoff_count==0,"unaffordable batch leaves native owner intact")
	g.begin_retreat()
	g=fixture("missile",true);owner=g.native_execution;owner.kernel.cancel()
	var batch_profile=g.equipment.save_data()
	var batch_resources=g.economy.save_data()
	check(not g.upgrade_equipment_batch("1") and g.equipment.save_data()==batch_profile and g.economy.save_data()==batch_resources,"failed whole-batch validation spends nothing and runs no purchase")
	g.begin_retreat()
	print("NATIVE NUMERIC UPGRADE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
