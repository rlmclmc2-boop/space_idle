extends Control
## Production factory page. The game owns research, costs, AI, unlocks and saves.
## One visible machine, static room, 5 Hz changed-value readouts. No extra viewport.
const INK:=Color("e2e9e8")
const MUTED:=Color("90a7b2")
const CYAN:=Color("8ad5d0")
const AMBER:=Color("efb976")
const LINE:=Color("34505e")
const SHELL=preload("res://scripts/shell_presentation.gd")
const PRESENTATION=preload("res://scripts/hightech_presentation.gd")
const NUMBER=preload("res://scripts/number_format.gd")
const ROOM=preload("res://scripts/hightech_workshop_room.gd")
const CONSTRUCTION=preload("res://scripts/hightech_workshop_construction.gd")
class PurchaseButton extends Button:
	var quote_text: Callable
	func _make_custom_tooltip(_for_text: String) -> Object:
		return EnhancementTooltip.content(quote_text.call())
var game: BattleGame
var selected: String=""
var rows: Dictionary={}
var machines: Dictionary={}
var stage: Control
var room: Control
var stage_title: Label
var stage_state: Label
var stage_count: Label
var stage_points: Label
var stage_percent: Label
var stage_eta: Label
var stage_bar: Control
var stage_steps: Array[ColorRect]=[]
var total: Label
var idle: Label
var cost: RichTextLabel
var console: Panel
var console_title: Label
var effect: RichTextLabel
var allocation: Label
var dedicated: Label
var rate: Label
var actions: Dictionary={}
var generate_actions: Dictionary={}
var distribute: Button
var worklist: VBoxContainer
var refresh_elapsed:=0.0
var writes:=0
var factory_events:=0
var refresh_count:=0
var refresh_usec:=0
var quote_evaluations:=0
var quote_snapshot: Array=[]
var effect_snapshot: Array=[]
var dirty:=true
var projects_dirty:=false
var shown_paused:=false
var completion_key: String=""
var completion_level:=0

func t(key: String, values: Dictionary={}) -> String:
	return UIText.t("research.workshop."+key,values)
func skin(fill: Color, edge:=LINE, radius:=10) -> StyleBoxFlat:
	var result:=StyleBoxFlat.new()
	result.bg_color=fill
	result.border_color=edge
	result.set_border_width_all(1)
	result.set_corner_radius_all(radius)
	return result
func panel(parent: Node, rect: Rect2, fill: Color) -> Panel:
	var p:=Panel.new()
	p.position=rect.position
	p.size=rect.size
	p.add_theme_stylebox_override("panel",skin(fill))
	p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p
func label(parent: Node, text: String, rect: Rect2, font_size:=22, color:=INK) -> Label:
	var l:=Label.new()
	l.text=text
	l.position=rect.position
	l.size=rect.size
	l.add_theme_font_override("font",SHELL.face(500))
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
func button(parent: Node, text: String, rect: Rect2, callback: Callable, primary:=false, quote_text: Callable=Callable()) -> Button:
	var b: Button=PurchaseButton.new() if quote_text.is_valid() else Button.new()
	if b is PurchaseButton:
		b.quote_text=quote_text
		b.tooltip_text=UIText.t("research.ai_purchase_hover")
	b.text=text
	b.position=rect.position
	b.size=rect.size
	b.add_theme_font_override("font",SHELL.face(600))
	b.add_theme_font_size_override("font_size",21)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var fill:=Color("244951") if primary else Color("203441")
		if state=="hover":fill=Color("345663")
		if state=="pressed":fill=Color("386875")
		if state=="disabled":fill=Color("172a36")
		b.add_theme_stylebox_override(state,skin(Color.TRANSPARENT if state=="focus" else fill,CYAN if state=="focus" else LINE,7))
	for prop in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(prop,INK)
	b.add_theme_color_override("font_disabled_color",Color("637b89"))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b
class ResearchTrack extends Control:
	var value:=0.0:
		set(next):
			if is_equal_approx(value,next):return
			value=next
			queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("0e202a"))
		draw_rect(Rect2(Vector2.ZERO,Vector2(size.x*clampf(value/100,0,1),size.y)),Color("8ad5d0"))

func bar(parent: Node, rect: Rect2) -> Control:
	var b:=ResearchTrack.new()
	b.position=rect.position
	b.size=rect.size
	b.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	return b
func put(object: Object, property: String, value: Variant) -> void:
	if object.get(property)==value:return
	object.set(property,value)
	writes+=1

func setup(source: BattleGame) -> void:
	game=source
	size=Vector2(1344,1160)
	clip_contents=true
	panel(self,Rect2(0,0,1344,1160),Color("0c1924"))
	label(self,t("title"),Rect2(28,20,300,46),34)
	label(self,t("subtitle"),Rect2(205,31,510,30),21,MUTED)
	total=label(self,"",Rect2(882,30,192,30),22)
	idle=label(self,"",Rect2(1090,30,230,30),22,CYAN)
	panel(self,Rect2(24,85,1296,83),Color("182c39"))
	cost=PRESENTATION.PARAMETERS.create_label(self,Rect2(44,108,600,38),21,SHELL.face(500),MUTED)
	for i in 3:
		var amount: int=[1,10,-1][i]
		generate_actions[amount]=button(self,UIText.t(["research.dock_ai_one","research.dock_ai_ten","research.dock_ai_max"][i]),Rect2(670+i*117,101,108,50),func():game.generate_scientist(amount);dirty=true,false,generation_quote_text.bind(amount))
	distribute=button(self,UIText.t("research.dock_distribute"),Rect2(1035,101,263,50),func():game.distribute_scientists();dirty=true,true)
	distribute.tooltip_text=UIText.t("upgrade.build_hightech_tab.text_03")
	stage=Control.new()
	stage.position=Vector2(24,192)
	stage.size=Vector2(854,730)
	add_child(stage)
	room=ROOM.new()
	room.size=stage.size
	room.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(room)
	label(stage,t("active"),Rect2(30,20,200,25),18,AMBER)
	stage_title=label(stage,t("empty"),Rect2(30,50,610,43),30)
	stage_state=label(stage,"",Rect2(665,22,158,29),20,CYAN)
	stage_count=label(stage,"",Rect2(598,61,225,27),19,MUTED)
	stage_count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	label(stage,t("dock"),Rect2(22,702,175,24),16,MUTED)
	stage_eta=label(stage,"",Rect2(605,702,225,26),18,MUTED)
	stage_eta.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	# One narrow process readout tied to real research, separated from the art.
	stage_points=label(stage,"",Rect2(205,644,450,29),20,MUTED)
	stage_percent=label(stage,"",Rect2(676,641,128,34),26,CYAN)
	stage_percent.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	stage_bar=bar(stage,Rect2(205,686,600,5))
	for i in 23:
		var tick:=ColorRect.new()
		tick.position=Vector2(205+i*26,679)
		tick.size=Vector2(21,2)
		tick.color=LINE
		stage.add_child(tick)
		stage_steps.append(tick)
	panel(self,Rect2(902,192,418,730),Color("142632"))
	label(self,t("overview"),Rect2(924,209,230,38),25)
	label(self,t("independent"),Rect2(924,248,355,29),18,MUTED)
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(916,292)
	scroll.size=Vector2(390,610)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	worklist=VBoxContainer.new()
	worklist.add_theme_constant_override("separation",8)
	worklist.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(worklist)
	console=panel(self,Rect2(24,946,1296,190),Color("1a303e"))
	label(console,t("console"),Rect2(24,15,200,26),18,MUTED)
	console_title=label(console,"",Rect2(24,48,594,34),27)
	effect=RichTextLabel.new()
	effect.position=Vector2(24,95)
	effect.size=Vector2(595,65)
	effect.bbcode_enabled=true
	effect.scroll_active=true
	effect.add_theme_font_override("normal_font",SHELL.face(500))
	effect.add_theme_font_size_override("normal_font_size",22)
	effect.add_theme_color_override("default_color",INK)
	console.add_child(effect)
	allocation=label(console,"",Rect2(662,20,350,33),25,CYAN)
	dedicated=label(console,"",Rect2(1024,24,246,29),18,MUTED)
	rate=label(console,"",Rect2(662,135,560,32),21,MUTED)
	for i in 4:
		var delta: int=[-1,1,10,-1][i]
		var captions: Array=[t("crew",{"count":"−1"}),t("crew",{"count":"+1"}),t("crew",{"count":"+10"}),UIText.t("weapon.build_equipment_card.text_19")]
		actions[i]=button(console,str(captions[i]),Rect2(662+i*150,72,137,48),func():
			if not selected.is_empty():game.assign_scientist(selected,game.idle_scientists() if i==3 else delta)
			dirty=true,i>0)
	button(console,t("details"),Rect2(520,13,91,32),func():
		var help_dialog:=AcceptDialog.new()
		help_dialog.dialog_text=t("help")
		help_dialog.title=t("title")
		add_child(help_dialog)
		preload("res://scripts/dialog_presentation.gd").dialog(help_dialog)
		help_dialog.confirmed.connect(help_dialog.queue_free)
		help_dialog.canceled.connect(help_dialog.queue_free)
		help_dialog.popup_centered(Vector2i(620,250)))
	# Rules live in the control heading's tooltip, not across the work cell.
	console_title.mouse_filter=Control.MOUSE_FILTER_PASS
	console_title.tooltip_text=t("help")
	game.event.connect(on_game_event)
	projects_dirty=true
	set_process(is_visible_in_tree())
	if is_visible_in_tree():
		projects_dirty=false
		sync_projects()
		refresh()

func invalidate(structure:=false) -> void:
	dirty=true
	projects_dirty=projects_dirty or structure

func _exit_tree() -> void:
	if game!=null and game.event.is_connected(on_game_event):game.event.disconnect(on_game_event)

func sync_projects() -> void:
	var ordered: Array=[]
	for key in game.hightech_slots():
		if not str(key).is_empty() and not ordered.has(key):ordered.append(key)
	for key in rows.keys():
		if ordered.has(key):continue
		rows[key].button.hide()
		machines[key].hide()
		rows[key].button.queue_free()
		machines[key].queue_free()
		rows.erase(key)
		machines.erase(key)
	for key in ordered:
		if rows.has(key):continue
		var b:=button(worklist,"",Rect2(0,0,386,139),func():select_project(key))
		b.custom_minimum_size=Vector2(374,139)
		var name_label:=label(b,"",Rect2(18,14,347,32),23)
		var level_label:=label(b,"",Rect2(18,48,178,26),19,MUTED)
		var workers_label:=label(b,"",Rect2(208,48,151,26),19,CYAN)
		workers_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		var progress_bar:=bar(b,Rect2(18,91,256,5))
		var percent_label:=label(b,"",Rect2(286,79,73,27),19)
		percent_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		var status_label:=label(b,"",Rect2(18,105,341,25),18,MUTED)
		rows[key]={"button":b,"name":name_label,"level":level_label,"workers":workers_label,"bar":progress_bar,"percent":percent_label,"status":status_label}
		var c:=CONSTRUCTION.new()
		c.size=Vector2(296,304)
		stage.add_child(c)
		c.setup(key)
		rows[key].grounding=ROOM.add_grounding(c,c.shape)
		var placement: Dictionary=ROOM.layout(c.shape,not game.hightech_unlocked(key))
		c.position=placement.position
		c.scale=placement.scale
		c.hide()
		machines[key]=c
	for index in ordered.size():worklist.move_child(rows[ordered[index]].button,index)
	if not rows.has(selected):select_project(str(ordered[0]) if not ordered.is_empty() else "")

func select_project(key: String) -> void:
	if key==selected:return
	if machines.has(selected):machines[selected].hide()
	selected=key
	completion_key=""
	if selected.is_empty():
		put(stage_title,"text",t("empty"))
		for readout in [stage_state,stage_count,stage_points,stage_percent,stage_eta]:put(readout,"text","")
		put(stage_bar,"value",0.0)
		for tick in stage_steps:put(tick,"color",LINE)
	if machines.has(selected):machines[selected].show()
	for item in rows:
		var b: Button=rows[item].button
		b.add_theme_stylebox_override("normal",skin(Color("213e4a") if item==key else Color("172d3b"),CYAN if item==key else Color("2b4352"),8))
	dirty=true
	refresh()

func on_game_event(kind: String, payload: Dictionary) -> void:
	if kind=="unlock":invalidate(true)
	if kind=="hightech_complete":
		factory_events+=1
		var key:=str(payload.key)
		if machines.has(key):machines[key].celebrate()
		if key==selected:
			completion_key=key
			completion_level=game.hightech_level(key)
	if kind in ["scientists_changed","hightech_complete","crew_changed"]:dirty=true

func generation_quote(amount: int) -> Dictionary:
	# MAX asks the complete purchase authority only when its tooltip is opened;
	# ordinary factory/resource refreshes retain the bounded availability check.
	if amount<0:return game.scientist_purchase(amount)
	var costs := {}
	for offset in amount:
		var unit_cost := game.scientist_cost(offset)
		for id in unit_cost:
			var value := float(unit_cost[id])
			if not is_finite(value):return {"count":0,"costs":{}}
			costs[id]=float(costs.get(id,0))+value
	return {"count":amount,"costs":costs}

func generation_quote_text(amount: int) -> String:
	var quote := generation_quote(amount)
	var costs := PackedStringArray()
	for id in quote.costs:costs.append(NUMBER.precise(quote.costs[id])+" "+UIText.data_text("resources",str(id)))
	var text := UIText.t("research.ai_purchase_quote",{"count":str(quote.count),"cost":" / ".join(costs) if not costs.is_empty() else "0"})
	if amount>=0 and not game.can_generate_scientist(amount):text+="\n"+UIText.t("research.ai_purchase_insufficient")
	return text

func refresh() -> void:
	if not is_visible_in_tree():return
	var started:=Time.get_ticks_usec()
	refresh_count+=1
	put(total,"text",t("total",{"count":NUMBER.compact(game.profile.scientists)}))
	put(idle,"text",t("idle",{"count":NUMBER.compact(game.idle_scientists())}))
	# Quotes depend on the ordinary AI pool/resources/config, never research points.
	# MAX availability asks the existing bounded predicate, not a MAX purchase quote.
	var next_quote: Array=[game.profile.scientists,game.profile.resources,game.db.config.scientistCost,rows.keys()]
	if next_quote!=quote_snapshot:
		quote_snapshot=next_quote.duplicate(true)
		quote_evaluations+=1
		var costs: Array[String]=[]
		var current_cost:=game.scientist_cost()
		for id in current_cost:costs.append("[color=#efb976]"+NUMBER.compact(current_cost[id])+" "+PRESENTATION.PARAMETERS.escape(UIText.data_text("resources",str(id)))+"[/color]")
		put(cost,"text",t("cost",{"cost":" / ".join(costs)}))
		for amount in generate_actions:put(generate_actions[amount],"disabled",not game.can_generate_scientist(amount))
	put(distribute,"disabled",rows.is_empty() or int(game.profile.scientists)<=0)
	for key in rows:
		var row: Dictionary=rows[key]
		var workers:=game.assigned_scientists(key)
		var dedicated_ai:=game.dedicated_scientists(key)
		var required:=game.hightech_required(key)
		var points:=float(game.profile.techPoints.get(key,0))
		var fraction:=clampf(points/required,0,1)
		var c=machines[key]
		var pending:=not game.hightech_unlocked(key)
		c.research_pending=pending
		put(row.grounding,"visible",not pending)
		var placement: Dictionary=ROOM.layout(c.shape,pending)
		put(c,"position",placement.position)
		put(c,"scale",placement.scale)
		if key==selected:
			c.set_workers(0 if pending else workers+dedicated_ai)
			c.set_fraction(0 if pending else fraction)
		put(row.name,"text",UIText.t("research.unrevealed") if pending else UIText.data_text("hightech",key))
		put(row.level,"text","" if pending else "Lv."+game.permanent_level_text(game.hightech_level(key),"hightech"))
		put(row.workers,"text","" if pending else t("crew",{"count":NUMBER.compact(workers+dedicated_ai)}))
		put(row.percent,"text","" if pending else t("percent",{"value":"%.0f" % (fraction*100)}))
		put(row.bar,"value",0 if pending else fraction*100)
		put(row.status,"text",UIText.t("research.pending") if pending else t("paused") if game.paused else t("working") if workers+dedicated_ai>0 else t("waiting"))
		if key!=selected:continue
		put(stage_title,"text",row.name.text)
		put(stage_state,"text",t("complete",{"level":completion_level}) if completion_key==key and c.completed>0 else row.status.text)
		put(stage_count,"text",t("built",{"count":c.built,"total":c.parts.size()}))
		put(stage_percent,"text",row.percent.text)
		put(stage_points,"text",t("next_points" if completion_key==key and c.completed>0 else "points",{"points":NUMBER.compact(points),"required":NUMBER.compact(required)}))
		put(stage_bar,"value",fraction*100)
		var research_rate:=game.research_rate(key)
		var seconds:=ceili(maxf(0,required-points)/research_rate) if research_rate>0 else 0
		put(stage_eta,"text",t("remaining",{"time":"%02d:%02d" % [seconds/60,seconds%60]}) if research_rate>0 else t("waiting"))
		for i in stage_steps.size():put(stage_steps[i],"color",CYAN if i<c.built else LINE)
		put(console_title,"text",row.name.text)
		var income: float=game.furnace_income_peak(-1,key==BattleGame.JEWEL_FURNACE) if key in [BattleGame.FURNACE,BattleGame.JEWEL_FURNACE] else 0.0
		var next_effect: Array=[key,game.effective_hightech_level(key),income,game.db.data.hightech[key],pending]
		if next_effect!=effect_snapshot:
			effect_snapshot=next_effect.duplicate(true)
			put(effect,"text",PRESENTATION.effect_markup(game,key).replace("#005449","#8ad5d0").replace("#214663","#efb976").replace("#243b50","#d9e9e5"))
		put(allocation,"text",t("allocation")+"  "+t("crew",{"count":NUMBER.compact(workers)}))
		put(dedicated,"text",t("dedicated",{"count":dedicated_ai}) if dedicated_ai>0 else "")
		put(rate,"text",t("rate",{"rate":NUMBER.compact(research_rate)}))
		for i in actions:put(actions[i],"disabled",pending or (workers<=0 if i==0 else game.idle_scientists()<=0))
	put(console,"visible",not selected.is_empty())
	dirty=false
	refresh_usec+=Time.get_ticks_usec()-started

func _notification(what: int) -> void:
	if what==NOTIFICATION_VISIBILITY_CHANGED and game!=null:
		set_process(is_visible_in_tree())
		if is_visible_in_tree():dirty=true

func _process(delta: float) -> void:
	if not is_visible_in_tree() or game==null:return
	if shown_paused!=game.paused:
		shown_paused=game.paused
		dirty=true
	if projects_dirty:
		projects_dirty=false
		sync_projects()
		dirty=true
	refresh_elapsed+=delta if not game.paused else 0.0
	if dirty or refresh_elapsed>=0.2:
		refresh_elapsed=0
		refresh()
	if not game.paused and machines.has(selected):machines[selected].advance(delta,false)
