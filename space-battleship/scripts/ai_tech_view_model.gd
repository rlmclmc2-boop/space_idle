extends RefCounted

# Presentation adapter for the art-owned page. All rules and balances stay in
# BattleGame; this file only converts its snapshot to ready-to-display text.
const N = preload("res://scripts/growth_number.gd")
const DISPLAY_IDS := {"singularity":"ai_singularity","equipment_finishing":"equipment_precision","unification":"joint_integration"}
const MODEL_IDS := {"ai_singularity":"singularity","equipment_precision":"equipment_finishing","joint_integration":"unification"}
const BENEFIT_LABELS := {"weapon_accuracy":"ai_tech.benefit.weapon_damage","equipment_reinforcement":"ai_tech.benefit.durability","resource_refining":"ai_tech.benefit.iron","fragment_condensation":"ai_tech.benefit.fragments","equipment_finishing":"ai_tech.benefit.damage_durability","uranium_extraction":"ai_tech.benefit.uranium","unification":"ai_tech.benefit.joint_damage_durability"}

static func model_id(display_id: String) -> String:
	return str(MODEL_IDS.get(display_id,display_id))

static func display_id(model_id: String) -> String:
	return str(DISPLAY_IDS.get(model_id,model_id))

static func duration(seconds: Variant) -> String:
	if seconds is Dictionary:return UIText.t("ai_tech.view.duration_subsecond") if N.compare(seconds,1.0)<0 else UIText.t("ai_tech.view.duration_scientific",{"value_1":N.text(seconds)})
	if not is_finite(seconds):return UIText.t("ai_tech.view.duration_overflow")
	if seconds >= 9.0e18:return UIText.t("ai_tech.view.duration_scientific", {"value_1":String.num_scientific(seconds)})
	if seconds < 1.0:return UIText.t("ai_tech.view.duration_subsecond")
	if seconds < 60.0:return UIText.t("ai_tech.view.duration_seconds", {"value_1":"%d" % (int(ceilf(seconds)))})
	if seconds < 3600.0:return UIText.t("ai_tech.view.duration_minutes", {"value_1":"%d" % (int(seconds/60.0)), "value_2":"%d" % (int(ceilf(fmod(seconds,60.0))))})
	if seconds < 86400.0:return UIText.t("ai_tech.view.duration_hours", {"value_1":"%d" % (int(seconds/3600.0)), "value_2":"%d" % (int(fmod(seconds,3600.0)/60.0))})
	return UIText.t("ai_tech.view.duration_days", {"value_1":"%d" % (int(seconds/86400.0)), "value_2":"%d" % (int(fmod(seconds,86400.0)/3600.0))})

static func requirement(game, id: String, level: int) -> String:
	var row: Dictionary = game.db.data.ai_tech_tree[id]
	var parts := PackedStringArray()
	if str(row.get("unlock","")) == "enhancement":parts.append(UIText.t("ai_tech.view.enhancement"))
	for predecessor in row.get("requirements",{}):
		var condition = row.requirements[predecessor]
		var target := 10*(level+1)+1 if condition is String else int(condition)
		parts.append(UIText.t("ai_tech.view.prerequisite_level", {"value_1":game.db.data.ai_tech_tree[predecessor].name, "value_2":"%d" % (target)}))
	return UIText.t("ai_tech.view.no_prerequisite") if parts.is_empty() else UIText.t("ai_tech.view.unlock_prefix") + UIText.t("ai_tech.view.list_separator").join(parts)

static func snapshot(game) -> Dictionary:
	var source: Dictionary = game.tech_tree_snapshot()
	var active_id := str(source.selected)
	var active: Dictionary = {}
	var technologies := []
	for node in source.nodes:
		var id := str(node.id)
		var can_start := bool(node.eligibility.ok)
		# Hide undiscovered choices; keep earned levels visible when the next
		# level has a new prerequisite. Progress and effects stay in BattleGame.
		if not can_start and int(node.level) == 0:continue
		var is_active := id == active_id
		if is_active:active = node
		var effect := UIText.t("ai_tech.view.effect_multiplier", {"value_1":node.description, "value_2":N.text(node.current_multiplier), "value_3":N.text(node.next_multiplier)})
		if id == "singularity":effect = UIText.t("ai_tech.view.effect_ai", {"value_1":node.description, "value_2":"%d" % (int(node.current_multiplier)), "value_3":"%d" % (int(node.next_multiplier))})
		var generation_text := "Lv.%d · %s ×%s" % [int(node.level),UIText.t(str(BENEFIT_LABELS.get(id,"ai_tech.view.benefit_fallback"))),N.text(node.current_multiplier)]
		if id == "singularity":generation_text = UIText.t("ai_tech.view.generation_ai", {"value_1":"%d" % (int(node.level)), "value_2":"%d" % (int(node.current_multiplier))})
		var state_text := UIText.t("ai_tech.view.enhancement_locked") if str(node.eligibility.get("reason", "")) == "enhancement_locked" else UIText.t("ai_tech.view.prerequisite_locked")
		if str(node.eligibility.get("reason", "")) in ["factory_locked","legacy_locked"]:state_text = UIText.t("ai_tech.view.legacy_locked")
		if can_start:
			var seconds_left = node.remaining_seconds
			state_text = UIText.t("ai_tech.research.active_estimate" if is_active else "ai_tech.research.estimate", {"time":duration(seconds_left)})
		technologies.append({"id":display_id(id),"tier":"final" if node.tier=="ultimate" else node.tier,"name":node.name,"level":node.level,"generation_text":generation_text,"effect_text":effect,"requirement_text":requirement(game,id,int(node.level)),"state_text":state_text,"can_research":can_start,"action_text":UIText.t("ai_tech.view.pause") if is_active else UIText.t("ai_tech.view.start")})
	var iron: Dictionary = source.inputs["1"]
	var uranium: Dictionary = source.inputs["2"]
	var shortage := bool(iron.shortage) or bool(uranium.shortage)
	var progress := float(active.progress_seconds)/float(active.required_seconds) if not active.is_empty() and is_finite(float(active.required_seconds)) else 0.0
	var status_text := UIText.t("ai_tech.view.idle") if active_id.is_empty() else UIText.t("ai_tech.view.active")
	if not active_id.is_empty() and shortage:status_text = UIText.t("ai_tech.view.acceleration_paused")
	var automatic := bool(source.automatic_input)
	return {"automatic_input":automatic,"technologies":technologies,"active_id":display_id(active_id) if not active_id.is_empty() else "","researching":not active_id.is_empty(),"advancing":not active_id.is_empty() and not game.paused,"progress":clampf(progress,0.0,1.0),"remaining_text":duration(source.remaining_seconds) if not active_id.is_empty() else "—","status_text":status_text,"ai_text":UIText.t("ai_tech.view.ai_count", {"value_1":"%d" % (int(source.ai_count))}),"speed_text":UIText.t("ai_tech.view.speed", {"value_1":N.text(source.speed) if source.speed is Dictionary else "%.3f" % float(source.speed)}),"iron_investment":str(float(source.input_ratios["1"])*100.0) if automatic else N.input_text(iron.amount),"uranium_investment":str(float(source.input_ratios["2"])*100.0) if automatic else N.input_text(uranium.amount),"iron_state":input_state(iron,automatic),"uranium_state":input_state(uranium,automatic)}

static func input_state(input: Dictionary, automatic: bool) -> String:
	var effect := UIText.t("ai_tech.view.insufficient_resources") if input.shortage else UIText.t("ai_tech.view.input_factor",{"value_1":"%.3f" % float(input.factor)})
	return UIText.t("ai_tech.investment.current",{"amount":N.text(input.amount),"effect":effect}) if automatic else effect
