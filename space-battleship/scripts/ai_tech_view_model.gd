extends RefCounted

# Presentation adapter for the art-owned page. All rules and balances stay in
# BattleGame; this file only converts its snapshot to ready-to-display text.
const N = preload("res://scripts/growth_number.gd")
const DISPLAY_IDS := {"singularity":"ai_singularity","equipment_finishing":"equipment_precision","unification":"joint_integration"}
const MODEL_IDS := {"ai_singularity":"singularity","equipment_precision":"equipment_finishing","joint_integration":"unification"}

static func model_id(display_id: String) -> String:
	return str(MODEL_IDS.get(display_id,display_id))

static func display_id(model_id: String) -> String:
	return str(DISPLAY_IDS.get(model_id,model_id))

static func duration(seconds: float) -> String:
	if not is_finite(seconds):return "耗时超出可计算范围"
	if seconds >= 9.0e18:return "%.2e 秒" % seconds
	if seconds < 1.0:return "不足 1 秒"
	if seconds < 60.0:return "%d 秒" % int(ceilf(seconds))
	if seconds < 3600.0:return "%d 分 %d 秒" % [int(seconds/60.0),int(ceilf(fmod(seconds,60.0)))]
	if seconds < 86400.0:return "%d 小时 %d 分" % [int(seconds/3600.0),int(fmod(seconds,3600.0)/60.0)]
	return "%d 天 %d 小时" % [int(seconds/86400.0),int(fmod(seconds,86400.0)/3600.0)]

static func requirement(game, id: String, level: int) -> String:
	var row: Dictionary = game.db.data.ai_tech_tree[id]
	var parts := PackedStringArray()
	if str(row.get("unlock","")) == "enhancement":parts.append("强化碎片已解锁")
	for predecessor in row.get("requirements",{}):
		var condition = row.requirements[predecessor]
		var target := 10*(level+1)+1 if condition is String else int(condition)
		parts.append("%s ≥ %d 级" % [game.db.data.ai_tech_tree[predecessor].name,target])
	return "无额外前置" if parts.is_empty() else "、".join(parts)

static func snapshot(game) -> Dictionary:
	var source: Dictionary = game.tech_tree_snapshot()
	var active_id := str(source.selected)
	var active: Dictionary = {}
	var technologies := []
	for node in source.nodes:
		var id := str(node.id)
		var can_start := bool(node.eligibility.ok)
		var is_active := id == active_id
		if is_active:active = node
		var effect := "%s 当前 ×%s；下一级 ×%s" % [node.description,N.text(node.current_multiplier),N.text(node.next_multiplier)]
		if id == "singularity":effect = "%s 当前 %d AI；下一级 %d AI" % [node.description,int(node.current_multiplier),int(node.next_multiplier)]
		var state_text := "研发中" if is_active else "可研发"
		if not can_start:state_text = "前置未满足"
		technologies.append({"id":display_id(id),"tier":"final" if node.tier=="ultimate" else node.tier,"name":node.name,"level":node.level,"effect_text":effect,"requirement_text":requirement(game,id,int(node.level)),"state_text":state_text,"can_research":can_start,"action_text":"暂停研发" if is_active else "开始研发"})
	var iron: Dictionary = source.inputs["1"]
	var uranium: Dictionary = source.inputs["2"]
	var shortage := bool(iron.shortage) or bool(uranium.shortage)
	var progress := float(active.progress_seconds)/float(active.required_seconds) if not active.is_empty() and is_finite(float(active.required_seconds)) else 0.0
	var status_text := "暂无研究，请选择科技" if active_id.is_empty() else "研发中"
	if not active_id.is_empty() and shortage:status_text = "研发中 · 资源加速暂停"
	return {"technologies":technologies,"active_id":display_id(active_id) if not active_id.is_empty() else "","researching":not active_id.is_empty(),"progress":clampf(progress,0.0,1.0),"remaining_text":duration(float(source.remaining_seconds)) if not active_id.is_empty() else "—","status_text":status_text,"ai_text":"AI 数：%d" % int(source.ai_count),"speed_text":"实际速度 ×%.3f" % float(source.speed),"iron_investment":str(iron.amount),"uranium_investment":str(uranium.amount),"iron_state":"余额不足，加速暂停" if iron.shortage else "实际 ×%.3f" % float(iron.factor),"uranium_state":"余额不足，加速暂停" if uranium.shortage else "实际 ×%.3f" % float(uranium.factor)}
