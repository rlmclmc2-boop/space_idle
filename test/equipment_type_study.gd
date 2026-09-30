extends SceneTree
# Review-only typography specimen. Does not modify production controls or saves.
class PreviewHost extends "res://scripts/main.gd":
	func create_battle_game(_persist: bool) -> BattleGame:
		return BattleGame.new(db,false)
const Card = preload("res://scripts/equipment_card.gd")
var host
var panel
var board: Control
var font_base: FontFile
var fonts: Dictionary = {}
var results: Array = []
var scenario: Label
var checks: Array = []
var samples: Array = []
var current_samples: Array = []
const INK = Color("203c4d")
const MUTED = Color("546c74")
func _initialize() -> void:call_deferred("run")
func face(weight: int) -> FontVariation:
	if fonts.has(weight):return fonts[weight]
	var f=FontVariation.new()
	f.base_font=font_base
	f.variation_opentype={2003265652:float(weight)}
	f.opentype_features={TextServerManager.get_primary_interface().name_to_tag("tnum"):1}
	fonts[weight]=f
	return f
func label(parent: Control, text: String, rect: Rect2, size: int, weight: int, color: Color) -> Label:
	var l=Label.new()
	l.text=text
	l.position=rect.position
	l.size=rect.size
	l.add_theme_font_override("font",face(weight))
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
func create_card(item: Dictionary, position: Vector2, compact: bool, proposal: bool) -> Control:
	var c=Card.new()
	board.add_child(c)
	c.setup(host,panel)
	c.compact=compact
	c.custom_minimum_size=Vector2(319,176) if compact else Vector2(652,156)
	c.size=c.custom_minimum_size
	c.position=position
	# Reproduce production initialization's minimum button font, then its card overrides.
	for key in c.fields:c.fields[key].add_theme_font_size_override("font_size",21)
	c.upgrade_button.add_theme_font_size_override("font_size",21)
	c.refresh(item,false)
	if proposal:
		for key in c.fields:c.fields[key].hide()
		c.upgrade_button.text=""
		var left=60.0 if compact else 106.0
		var title=label(c,item.name,Rect2(left,8,245 if compact else 242,34),23 if compact else 26,650,INK)
		var level=label(c,"Lv."+item.levelText,Rect2(left,43 if compact else 47,245 if compact else 230,29),20,500,MUTED)
		var caption=label(c,item.mainStatLabel,Rect2(16 if compact else 546,80 if compact else 8,60,29),18,500,MUTED)
		if not compact:caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		var num=label(c,"",Rect2(82 if compact else 356,74 if compact else 33,195 if compact else 250,44 if compact else 46),30 if compact else 36,650,INK)
		num.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		var unit=label(c,"",Rect2(283 if compact else 612,79 if compact else 47,22,30),20,500,MUTED)
		var b=c.upgrade_button
		var action=label(b,"升级",Rect2(16,0,52,56),20,500,INK)
		action.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		var cost=label(b,"",Rect2(75,0,b.size.x-115,56),24,650,INK)
		cost.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		cost.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		var res=label(b,"铁",Rect2(b.size.x-32,0,22,56),18,500,MUTED)
		res.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		samples.append({"card":c,"title":title,"level":level,"caption":caption,"num":num,"unit":unit,"cost":cost,"resource":res,"action":action,"compact":compact})
	else:current_samples.append(c)
	return c
func assign_value(sample: Dictionary, value: String, level: String, cost: String) -> void:
	var suffix=""
	var digits=value
	if value.right(1) in ["K","M","B","T"]:
		suffix=value.right(1)
		digits=value.left(-1)
	sample.num.text=digits
	sample.unit.text=suffix
	sample.level.text="Lv."+level
	sample.cost.text=cost
func font_info(font: Font, glyph: String) -> Dictionary:
	var line=TextLine.new()
	line.add_string(glyph,font,24)
	var ts=TextServerManager.get_primary_interface()
	var data=[]
	for g in ts.shaped_text_get_glyphs(line.get_rid()):
		var rid: RID=g.font_rid
		data.append({"family":ts.font_get_name(rid),"style":ts.font_get_style_name(rid),"weight":ts.font_get_weight(rid),"variation":ts.font_get_variation_coordinates(rid)})
	return {"glyph":glyph,"fonts":data}
func verify(ok: bool, message: String) -> void:
	checks.append({"pass":ok,"message":message})
func run() -> void:
	host=PreviewHost.new()
	host.automation_args=["--capture"]
	root.add_child(host)
	host.automation_args=[]
	host.set_process(false)
	host.game.pending_unlocks.clear()
	host.game.profile.cleared=range(1,60)
	host.game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	host.game.switch_ship("Heavy_Battleship")
	for i in 8:host.game.equip_slot("weapons",i,BattleGame.WEAPON_KEYS[i%4])
	for i in 4:host.game.equip_slot("defence",i,BattleGame.DEFENSE_KEYS[i%2])
	host.build_ui()
	panel=host.equipment_panel
	host.hide()
	root.size=Vector2i(1480,710)
	root.content_scale_size=Vector2i(1480,710)
	font_base=load("res://assets/fonts/NotoSansSC.ttf")
	board=Control.new()
	root.add_child(board)
	var bg=ColorRect.new()
	bg.size=Vector2(1480,710)
	bg.color=Color("142934")
	board.add_child(bg)
	label(board,"装备 · 文字层级样稿",Rect2(40,24,1000,55),34,650,Color("eff0de"))
	scenario=label(board,"",Rect2(40,81,1392,40),22,500,Color("b9cbd0"))
	label(board,"当前排版",Rect2(40,134,652,42),24,600,Color("b9cbd0"))
	label(board,"样稿  /  名称成组 · 数值突出",Rect2(780,134,652,42),24,600,Color("9ad9cf"))
	var entries=[panel.items.weapons_0.duplicate(true),panel.items.defence_0.duplicate(true)]
	for i in 2:
		entries[i].direct_upgradeable=true
		create_card(entries[i],Vector2(40,190 if i==0 else 390),i==1,false)
		create_card(entries[i],Vector2(780,190 if i==0 else 390),i==1,true)
	label(board,"卡片尺寸保持不变：武器 652×156，防御 319×176。此图按逻辑尺寸 1:1 渲染。",Rect2(40,610,1392,36),20,400,Color("b9cbd0"))
	label(board,"复用内置 Noto Sans SC；仅测试文字与排版。底板、图标、费用格式及12槽容量不变。",Rect2(40,648,1392,36),20,400,Color("b9cbd0"))
	for extreme in [false,true]:
		scenario.text="极端数据  ·  Lv.10000000  /  长 T 金额" if extreme else "正常数据  ·  Lv.1  /  初始属性与升级费用"
		for i in 2:
			var item=entries[i].duplicate(true)
			if extreme:
				item.level=10000000
				item.levelText="10000000"
				item.mainStatValue=host.number(9.99999e19)
				item.cost=host.cost_text({"1":9.99999e19})
			current_samples[i].refresh(item,false)
			assign_value(samples[i],item.mainStatValue,item.levelText,host.number(9.99999e19) if extreme else host.number(host.game.slot_upgrade_cost(item.category,item.index).get("1",0)))
		for i in 5:await process_frame
		await RenderingServer.frame_post_draw
		var tag="type-extreme" if extreme else "type-normal"
		root.get_texture().get_image().save_png("res://../"+tag+".png")
		for s in samples:
			for k in ["title","level","num","unit","cost"]:
				var l: Label=s[k]
				var width=l.get_theme_font("font").get_string_size(l.text,HORIZONTAL_ALIGNMENT_LEFT,-1,l.get_theme_font_size("font_size")).x
				verify(width<=l.size.x,tag+" "+str(s.compact)+" "+k+" fits")
			verify(not s.level.get_rect().intersects(s.num.get_rect()),tag+" level/number do not overlap")
			verify(not s.title.get_rect().intersects(s.level.get_rect()),tag+" title/level do not overlap")
			verify(s.num.get_rect().end.y<=s.card.upgrade_button.position.y,tag+" number clears button")
			verify(s.card.size==(Vector2(319,176) if s.compact else Vector2(652,156)),tag+" dimensions retained")
			results.append({"scenario":tag,"compact":s.compact,"level":s.level.text,"number":s.num.text,"unit":s.unit.text,"cost":s.cost.text})
	var font_report={"developer_chinese":font_info(host.font,"装甲"),"developer_digits":font_info(host.font,"0123456789"),"release_chinese":font_info(load("res://assets/fonts/NotoSansSC-Regular.tres"),"装甲"),"proposal_chinese":font_info(face(650),"装甲"),"proposal_digits":font_info(face(650),"0123456789")}
	var widths=[]
	for d in "0123456789":widths.append(face(650).get_string_size(d,HORIZONTAL_ALIGNMENT_LEFT,-1,32).x)
	font_report.digit_widths_32=widths
	var f=FileAccess.open("res://../type-study-results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"fonts":font_report,"checks":checks,"samples":results},"\t"))
	print("TYPE_STUDY_CHECKS ",checks.size()," failures ",checks.filter(func(c):return not c["pass"]).size())
	quit(1 if checks.any(func(c):return not c["pass"]) else 0)
