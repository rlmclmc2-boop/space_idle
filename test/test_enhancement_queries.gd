extends SceneTree
class ComparedGame extends BattleGame:
	func reference_effects(entry: Dictionary) -> Array:
		var result: Array = []
		if str(entry.get("key","")).is_empty() or not enhancement_unlocked():return result
		var category := "weapons" if WEAPON_KEYS.has(str(entry.key)) else "defence"
		var order := enhancement_order(category)
		for i in available_effect_count(entry):
			var kind := str(order[i])
			if kind.is_empty():continue
			var effect := {"kind":kind,"level":enhancement_effective_level(),"threshold":int(enhancement_parameter("threshold_%d" % (i+1))),"p2":0.0,"p4":0.0,"p5":0.0}
			match kind:
				"proficiency","adaptation":effect.p2=enhancement_parameter(kind+"_growth")
				"repeat":
					effect.p2=enhancement_parameter("repeat_probability")
					effect.p4=enhancement_parameter("repeat_growth")
				"critical":effect.p4=enhancement_parameter("critical_growth")
				"delayed_damage":effect.p2=enhancement_deferred_fraction()
				"memory_material":
					effect.p2=enhancement_parameter("memory_heal_fraction")
					effect.p4=enhancement_parameter("memory_buffer_fraction")
			result.append(effect)
		return result

var checks=0
var failures=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:
	var db=ShipDatabase.new()
	var g=ComparedGame.new(db,false)
	g.profile.grantedUnlocks=[db.unlock_id("feature","jewels")]
	var kinds=["proficiency","repeat","critical","adaptation","delayed_damage","memory_material","missing"]
	for config in [0,1]:
		if config==1:
			for i in [1,2,3]:db.data.enhance_config["threshold_%d"%i].value=i*7
			db.data.enhance_config.memory_heal_fraction.value=.037
			db.data.enhance_config.memory_buffer_fraction.value=.091
		for level in [0,479]:
			g.profile.enhancementLevel=level
			for shift in 3:
				for category in ["weapons","defence"]:
					var order=g.default_enhancement_order()[category].duplicate()
					for ignored in shift:order.append(order.pop_front())
					g.profile.enhancementOrder[category]=order
					var entries=[{}, {"key":""}]
					for threshold in [1,2,3]:
						var gate=int(db.data.enhance_config["threshold_%d"%threshold].value)
						for entry_level in [gate-1,gate,gate+1]:entries.append({"key":"laser" if category=="weapons" else "shield","level":entry_level})
					for entry in entries:
						var expected=g.reference_effects(entry)
						check(g.enhancement_effects(entry)==expected,"effect payload equals original")
						var memory={}
						for effect in expected:
							if effect.kind=="memory_material":memory=effect
						check(g.memory_effect(entry)==memory,"memory payload equals original")
						for kind in kinds:check(g.has_enhancement_effect(entry,kind)==expected.any(func(e):return e.kind==kind),"membership "+kind)
	g.profile.enhancementBranches=g.default_enhancement_branches()
	g.profile.enhancementBranches.weapons.critical["1"]="B"
	var choices=g.enhancement_branch_choices("weapons","critical")
	choices["1"]="A"
	check(g.enhancement_branch_choice("weapons","critical",1)=="B","public choices remain defensive copy")
	g.profile.grantedUnlocks=[]
	check(g.enhancement_effects({"key":"shield","level":150}).is_empty() and g.memory_effect({"key":"shield","level":150}).is_empty(),"locked effects unavailable")
	# Manual/real-clock saves only, isolated user path supplied by the runner.
	g.save_enabled=true
	var events=[]
	g.event.connect(func(kind,_info):events.append(kind))
	g.record_enhancement_attack();g.record_enhancement_hit()
	check(not events.has("save_success"),"battle counters never save immediately")
	g.save_progress()
	var restored=BattleGame.new(db,false);restored.load_progress()
	check(restored.profile.enhancementBranches==g.profile.enhancementBranches and restored.profile.enhancementAttacks==g.profile.enhancementAttacks and restored.profile.enhancementHits==g.profile.enhancementHits,"manual save retains choices and counters")
	g.set_save_interval("2");g.next_timed_save_at=g.save_clock_seconds()+10
	events.clear();g.check_timed_save()
	check(not events.has("save_success"),"save waits for real deadline")
	g.next_timed_save_at=g.save_clock_seconds()-1;g.check_timed_save()
	check(events.count("save_success")==1 and g.save_interval_minutes==2,"configured timer saves exactly once")
	print("ENHANCEMENT QUERY EQUIVALENCE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
