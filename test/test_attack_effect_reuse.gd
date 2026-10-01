extends SceneTree
class Observed extends "res://scripts/presented_battle_game.gd":
	var original:=false
	var effect_calls:=0
	func jewel_effects(entry:Dictionary)->Array:
		effect_calls+=1
		return super.jewel_effects(entry)
	func jewel_attack(index: int, multiplier := 1.0) -> Dictionary:
		if not original:return super.jewel_attack(index,multiplier)
		var entry := slot_entry("weapons",index)
		var critical := jewel_critical(entry)
		var context: Dictionary=enhancement_attack_contexts.get(index,{})
		var raw = N.multiply(N.multiply(jewel_equipment_stat(entry),multiplier),float(context.get("next_multiplier",1.0)))
		var is_critical := rng.randf() < critical.x
		var critical_bonus_applied := is_critical
		if is_critical:
			if enhancement_branches.active(self,entry,"critical",3,"B"):
				critical_bonus_applied=rng.randf()<enhancement_branches.underlying_critical_rate(self,entry)
			if critical_bonus_applied:raw=N.multiply(raw,critical.y)
			if not context.is_empty() and not context.get("derived",false):context.critical=true
		var effects := jewel_effects(entry)
		for effect in effects:
			effect.source = index
			effect.weapon_key=str(entry.key)
			if enhancement_branches.active(self,entry,"proficiency",3,"B"):effect.enemy_resistance=enhancement_parameter("proficiency_b3_resistance")
			if effect.kind=="repeat" and enhancement_branches.active(self,entry,"repeat",1,"B") and not context.get("derived",false):effect.chain=true
		return {"damage":raw,"effects":effects,"critical":is_critical,"critical_bonus_applied":critical_bonus_applied}

var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(original:bool,choices:String):
	var g=Observed.new(ShipDatabase.new(),false);g.original=original;g.stat_cache_enabled=true;g.speed=1
	g.profile.cleared=range(1,101);g.rebuild_unlocks();g.pending_unlocks.clear()
	g.profile.enhancementLevel=30
	g.profile.loadout={"weapons":[{"key":"missile","level":150},{"key":"missile","level":150}],"defence":[{"key":"shield","level":150},{"key":"armour","level":150}]}
	g.reset_player();g.spawn_group();g.refresh_missile_target_registry()
	for enemy in g.enemies:enemy.hp=1e100;enemy.max_hp=1e100;enemy.equipment=[]
	if choices!="none":
		for effect in ["proficiency","repeat","critical"]:
			var letters="AAA" if choices=="mixed" and effect=="critical" else "AAB" if choices=="mixed" else "BBB"
			for node in [1,2,3]:check(g.set_enhancement_branch("weapons",effect,node,letters[node-1]),"branch fixture")
	g.rng.seed=1701
	return g
func _initialize()->void:call_deferred("run")
func run()->void:
	# These branch fixtures are regression coverage, not a claim about the user build.
	for choices in ["none","mixed","B"]:
		var a=fixture(true,choices);var b=fixture(false,choices)
		for g in [a,b]:g.begin_enhancement_attack(0,g.enemies[0])
		var previous=[]
		for shot in 10:
			a.effect_calls=0;b.effect_calls=0
			var x=a.jewel_attack(0);var y=b.jewel_attack(0)
			check(x==y and a.rng.state==b.rng.state,"exact payload and RNG "+choices)
			check(a.effect_calls==3 and b.effect_calls==1,"one effect array per attack")
			if not previous.is_empty():check(not is_same(previous,y.effects) and not is_same(previous[0],y.effects[0]),"shots own independent payloads")
			previous=y.effects
		for g in [a,b]:g.finish_enhancement_attack(0)
		check(a.enhancement_branches.weapons==b.enhancement_branches.weapons,"branch attack state")
		for g in [a,b]:
			var weapon=g.player_weapon_row(g.slot_entry("weapons",0))
			check(int(weapon.para1)==5,"official five round salvo")
			g.begin_enhancement_attack(0,g.enemies[0]);g.record_enhancement_attack()
			for i in 5:g.jewel_fire(0,g.enemies[0],weapon,g.player_weapon_offset(0),1.0,g.missile_visual_spread(i,5),i,5)
			g.finish_enhancement_attack(0)
		check(a.missile_queue.size()==5 and b.missile_queue.size()==5 and a.missile_queue==b.missile_queue,"five unchanged delayed packets")
		for step in 120:
			for g in [a,b]:g.motion_clock+=1.0/60.0;g.tick_projectiles(1.0/60.0)
			check(a.projectiles==b.projectiles and a.missile_queue==b.missile_queue and a.rng.state==b.rng.state,"flight/queue/RNG step")
		check(a.launch_records.size()==5 and b.launch_records.size()==5 and a.launch_records==b.launch_records,"five exact launches")
		check(a.hit_records==b.hit_records and a.enemies==b.enemies and a.player==b.player,"damage and hit records")
		var pa=a.profile.duplicate(true);var pb=b.profile.duplicate(true)
		pa.erase("hightechSavedAt");pb.erase("hightechSavedAt")
		check(pa==pb and a.save_dirty==b.save_dirty,"profile and save-dirty semantics")
	# The shared attack builder also serves bullets and beam ticks.
	for key in ["laser","cannon","longLaser"]:
		var a=fixture(true,"none");var b=fixture(false,"none")
		for g in [a,b]:g.profile.loadout.weapons[0].key=key;g.invalidate_stat_cache();g.begin_enhancement_attack(0,g.enemies[0])
		for i in 5:check(a.jewel_attack(0)==b.jewel_attack(0) and a.rng.state==b.rng.state,key+" shared payload/RNG")
	print("ATTACK EFFECT REUSE: ",checks," checks, ",failures," failures")
	call_deferred("quit",1 if failures else 0)
