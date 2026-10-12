extends SceneTree
const State=preload("res://scripts/simulation_battle_state.gd")
const Kernel=preload("res://scripts/simulation_enemy_settlement.gd")
const N=preload("res://scripts/growth_number.gd")
var checks=0
var captured:Array=[]
func _initialize()->void:call_deferred("run")
func observe(kind:String,payload:Dictionary)->void:
	if kind=="hit" and not payload.player:captured.append(payload.amount)
func run()->void:
	var db=ShipDatabase.new();var game=BattleGame.new(db,false)
	game.start(1,false);game.spawn_group()
	game.profile.loadout=game.empty_loadout(game.profile.selectedShip)
	var base:Dictionary=game.enemies[0].duplicate(true)
	base.equipment=[];base.cooldowns=[];base.drops=[]
	game.event.connect(observe)
	var kernel=Kernel.new()
	for health in [0.0,100.0,1e100]:
		for shield in [0.0,20.0]:
			for resistance in [0.0,0.25,0.5,1.0]:
				for kind in [0,1,2]:
					for raw in [0.0,0.2,1.0,40.0,60.0,200.0]:
						for due in [-1.0,0.2,0.6]:
							var original=base.duplicate(true)
							original.hp=health;original.max_hp=health;original.shield=shield/2;original.max_shield=shield
							original.armourType=2;original.shieldType=1;original.shieldRecovery=0.5;original.shieldDelay=0.3
							original.shield_updated_at=0.1;original.shield_hit_at=0.0;original.interference=0.1
							game.enemies.assign([original]);game.enemy_shield_time=0.8;game.enemy_shield_hit_time=due
							var state=State.new();var target=state.import_enemy(original,game.enemy_shield_time)
							var result=kernel.hit(target,raw,kind,resistance,game.enemy_shield_time,due,false)
							captured.clear();game.hit_enemy(original,raw,kind,[{"enemy_resistance":resistance}],false,{"source_id":"slice-test","trigger_depth":1})
							assert(N.compare(original.hp,target.health.value())==0 and N.compare(original.shield,target.shield.value())==0)
							assert(original.shield_hit_at==target.shield_hit_at and original.shield_updated_at==target.shield_updated_at)
							assert(captured.is_empty() if not result.applied else captured.size()==1 and N.compare(captured[0],result.amount)==0)
							checks+=1
	game.event.disconnect(observe)
	print("SIMULATION_ENEMY_SETTLEMENT_PASS cases=",checks,"; actual_BattleGame_reference; HP_shield_timestamps_amount_exact; no_battle_worker")
	quit()
