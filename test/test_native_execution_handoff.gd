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
	var db=ShipDatabase.new();db.equipment.shield[0].para2=0.0;db.ships.Heavy_Battleship.defenseSlots=4
	var g=SharedCommandGame.new(db,false) if shared_command else preload("res://scripts/presented_battle_game.gd").new(db,false)
	g.profile.cleared=range(1,101);g.rebuild_unlocks()
	g.economy.credit_many({"1":1e30,"2":1e30})
	var equipment:Dictionary=g.equipment.save_data();equipment.selectedShip="Heavy_Battleship"
	equipment.loadout=preload("res://scripts/equipment_state.gd").empty_loadout(db,equipment.selectedShip)
	equipment.loadout.weapons[0].key=key
	equipment.loadout.defence=[{"key":"shield","level":1},{"key":"armour","level":1},{"key":"shield","level":1},{"key":"armour","level":1}]
	check(g.equipment.install_snapshot(equipment,db),"handoff fixture installs current loadout")
	if beam_chain:
		var enhancement:Dictionary=g.enhancement_growth.save_data();enhancement.enhancementLevel=40
		check(g.enhancement_growth.install_snapshot(enhancement),"handoff growth fixture installs")
		g.rebuild_unlocks();g.set_enhancement_branch("weapons","repeat",1,"B")
		if key=="missile":g.set_enhancement_branch("weapons","repeat",3,"B")
	g.configuration_committed();g.reset_player();g.state=BattleGame.State.COMBAT
	g.enemies.assign([{"uid":100,"slot":4,"x":286.0,"y":150.0,"hp":1e8,"max_hp":1e8,"armourType":1,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0},{"uid":101,"slot":3,"x":240.0,"y":150.0,"hp":1e8,"max_hp":1e8,"armourType":1,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
	g.cooldowns[g.slot_id("weapons",0)]=0.0
	var desc=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_low_contract")
	if desc.has("error"):printerr("ADMISSION: ",desc)

	check(g.admit_native_compiled_execution("native_low_contract"),"fixture native admission")
	g.tick(1.0/60.0)
	return g
func _initialize()->void:call_deferred("run")
func run()->void:
	var g=fixture();var owner=g.native_execution;var core=owner.kernel
	var exported=core.export_handoff()
	check(exported.ejections.size()>0,"pending missile tubes present")
	var shot=g.projectiles[0];var position=g.projectile_position(shot);var hp=g.enemies[0].hp;var rng_before=g.rng.state
	var cd=exported.cooldowns[0].remaining
	var costs=g.slot_upgrade_cost("weapons",0,1)
	for id in costs:g.economy.credit(id,N.multiply(costs[id],10.0))
	var resource=g.economy.balance("1");var level=g.weapon_entries()[0].level
	check(g.upgrade_slot("weapons",0,1),"upgrade while missile packets pending")
	g.notify_configuration_changed()
	check(g.native_execution==null and g.native_handoff_count==1,"one whole-owner handoff")
	check(g.weapon_entries()[0].level==level+1 and N.compare(g.economy.balance("1"),N.subtract(resource,costs.get("1",0)))==0,"level and spend applied exactly once")
	check(is_equal_approx(g.cooldowns[g.slot_id("weapons",0)],cd),"upgrade keeps exact remaining cooldown")
	check(is_same(g.projectiles[0],shot) and g.projectile_position(shot)==position and g.enemies[0].hp==hp and g.rng.state==rng_before,"handoff preserves shot identity/position/hp/RNG without settlement")
	check(g.missile_queue.size()==exported.ejections.size(),"all pending tubes imported")
	check(is_same(g.missile_queue[0].attack.effects,shot.jewelEffects),"active and pending salvo share one imported attack instance")
	var committed=g.missile_queue[0].attack.damage
	g.tick(0.2)
	check(g.projectiles.size()>1,"pending native tubes continue under old owner")
	var found=false
	for s in g.projectiles:
		if s.serial!=shot.serial and is_equal_approx(float(s.damage),float(committed)):found=true
	check(found,"delayed tube retains birth damage across upgrade")
	check(core.metrics().steps==exported.revision,"retired native owner cannot advance")
	g=fixture();owner=g.native_execution;exported=owner.kernel.export_handoff();shot=g.projectiles[0]
	check(g.equip_slot("weapons",0,"laser"),"refit while tubes pending")
	check(g.native_handoff_count==1 and is_same(g.projectiles[0],shot) and not shot.dead,"refit handoff preserves already-fired damage")
	check(is_equal_approx(g.cooldowns[g.slot_id("weapons",0)],float(g.db.equip("laser",int(g.weapon_entries()[0].level)).cd)),"only original refit command resets cooldown")
	g.tick(0.6)
	check(g.missile_queue.is_empty(),"original refit invalidates pending old-entry tubes at their due times")
	g=fixture("missile",false,true);owner=g.native_execution;core=owner.kernel
	var time_before=g.production_time();var motion_before=g.motion_clock;var native_before=core.metrics().steps
	g.command_due=true;g.tick(1.0/60.0)
	check(g.command_ok and g.native_handoff_count==1,"shared-stage command transfers before its mutation")
	check(is_equal_approx(g.production_time()-time_before,1.0/60.0) and is_equal_approx(g.motion_clock-motion_before,1.0/60.0),"shared and battle clocks consume current substep once")
	check(core.metrics().steps==native_before,"unexecuted native combat phase not run after shared-stage transfer")
	g=fixture("missile",true);owner=g.native_execution;core=owner.kernel
	exported=core.export_handoff();shot=g.projectiles[0]
	var native_chain:Dictionary=shot.attack_instance.chain
	var expected_count=int(owner.weapons[0].chain_count)
	check(expected_count>0 and exported.flights[0].instance.chain.count==expected_count,"enhanced missile exports typed chain allowance")
	check(not native_chain.has("count") and not native_chain.used,"cold export does not mutate native published instance")
	check(g.upgrade_slot("weapons",0,1),"enhanced missile upgrade transfers pending salvo")
	g.notify_configuration_changed()
	var missile_chain:Dictionary=shot.attack_instance.chain
	check(missile_chain.count==expected_count and not missile_chain.used,"unused missile allowance survives transfer")
	check(is_same(missile_chain,g.missile_queue[0].attack.effects.filter(func(e):return e.get("chain",false))[0].chain_state),"pending tubes share chain allowance")
	var target:Dictionary=shot.target
	var before_count=g.projectiles.size()
	g.hit_enemy(target,shot.damage,int(shot.type),shot.jewelEffects,false,shot.combat_context)
	check(missile_chain.used and g.projectiles.size()==before_count+mini(expected_count,g.enemies.size()-1),"first legacy hit spends inherited allowance once")
	before_count=g.projectiles.size()
	g.hit_enemy(target,shot.damage,int(shot.type),shot.jewelEffects,false,shot.combat_context)
	check(g.projectiles.size()==before_count,"same-salvo hit cannot rearm chain")
	g=fixture("missile",true);owner=g.native_execution;core=owner.kernel;shot=g.projectiles[0]
	for i in 240:
		if shot.attack_instance.chain.used:break
		g.tick(1.0/60.0)
	check(shot.attack_instance.chain.used,"native first missile arrival already spends chain allowance")
	exported=core.export_handoff()
	var spent_id=int(shot.attack_instance.id)
	check(g.upgrade_slot("weapons",0,1),"spent enhanced salvo transfers remaining carriers")
	g.notify_configuration_changed()
	var spent_effects:Array=[]
	for carrier in g.projectiles:
		if int(carrier.attack_instance_id)==spent_id:spent_effects=carrier.jewelEffects;break
	if spent_effects.is_empty():
		for pending in g.missile_queue:
			if int(pending.attack.attack_instance_id)==spent_id:spent_effects=pending.attack.effects;break
	check(not spent_effects.is_empty(),"spent salvo still owns active or pending carriers")
	if not spent_effects.is_empty():
		var spent_chain:Dictionary=spent_effects.filter(func(e):return e.get("chain",false))[0].chain_state
		check(spent_chain.used,"spent allowance remains spent after transfer")
		before_count=g.projectiles.size()
		g.hit_enemy(g.enemies[0],shot.damage,int(shot.type),spent_effects,false,shot.combat_context)
		check(g.projectiles.size()==before_count,"transferred spent salvo does not spawn another chain")
	g=fixture("longLaser",true);owner=g.native_execution;core=owner.kernel
	var beam=g.projectiles[0];var chain=beam.attack_instance.chain
	check(chain.links.size()==1,"beam linked target exists")
	var age=float(beam.elapsed);var before=g.enemies[0].hp
	check(g.set_enhancement_branch("weapons","critical",1,"B"),"unsupported branch accepted by original public rule after handoff")
	check(g.native_execution==null and not g.paused and g.native_handoff_count==1,"unsupported configuration does not pause player")
	check(is_same(g.projectiles[0],beam) and is_equal_approx(float(beam.elapsed),age) and beam.attack_instance.chain.links.size()==1 and g.enemies[0].hp==before,"beam age/links and health survive without extra hit")
	g=fixture("laser");owner=g.native_execution;core=owner.kernel
	# Last enemy dies while an already-fired hostile carrier is still valid.
	var hostile={"kind":0,"type":2,"slot":0,"source":0,"hostile":true,"damage":10.0,"interval":10.0,"remaining":0.0,"speed":720.0,"muzzle":Vector2(286,150),"entry":{"name":"laser_mon"},"row":{"name":"laser_mon","cd":10.0,"dmgtype":2,"para1":30.0,"para2":0.0,"dmg":10.0}}
	g.native_execution=null;g.native_execution_requested=false;owner.cancel(g);g.projectile_clear()
	var descriptor=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_low_contract");descriptor.weapons=[hostile];descriptor.enemies=descriptor.enemies.slice(0,1)
	descriptor.enemies[0].equipment=[{"name":"laser_mon"}];descriptor.enemies[0].cooldowns=[10.0]
	check(g.admit_native_execution(descriptor),"last-enemy carrier fixture admission")
	owner=g.native_execution;core=owner.kernel;g.tick(1.0/60.0);shot=g.projectiles[0]
	core.hit_handle(core.actor_handle(100),1e12,1);owner.consume_feedback(g)
	g.tick(1.0/60.0)
	check(g.native_execution==null and g.state==BattleGame.State.TRAVEL and g.projectiles.has(shot) and not shot.dead,"nonfinal wave retains already-fired hostile carrier")
	g.group_index=g.db.levels[g.stage-1].groups.size() # Hold travel without starting another encounter.
	var armour=g.player.armour;var shield=g.player.shield
	for i in 45:g.tick(1.0/60.0)
	check(N.compare(g.player.armour,armour)<0 or N.compare(g.player.shield,shield)<0,"carried hostile projectile still pays its committed damage")
	g.begin_retreat()
	check(g.native_execution==null,"exit has no native owner residual")
	print("NATIVE HANDOFF: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
