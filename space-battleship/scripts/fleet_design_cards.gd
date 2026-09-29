extends VBoxContainer
## Display projection only. Reuse fixed card slots for paging/filtering.
signal detail_requested(row: Dictionary)
signal retest_requested(row: Dictionary)
const MonGroupXlsx := preload("res://scripts/mon_group_xlsx.gd")
const CATEGORIES := ["all","ordinary","insufficient","anomaly"]
var report := {}
var display_names := {}
var mon_names: Dictionary={}
var rows: Array=[]
var slots: Array=[]
var page := 0
var per_page := 12
var overview: Label
var category: OptionButton
var ordering: OptionButton
var page_label: Label
var previous: Button
var next: Button
var scroll: ScrollContainer
var grid: GridContainer

func _ready() -> void:
	add_theme_constant_override("separation",10)
	overview=label(self,"")
	var bar := HBoxContainer.new()
	add_child(bar)
	category=OptionButton.new()
	for key in CATEGORIES:category.add_item(UIText.t("design.category."+key))
	bar.add_child(category)
	category.item_selected.connect(func(_i):page=0;refresh())
	ordering=OptionButton.new()
	for key in ["recommended","win","difference","tests","time"]:ordering.add_item(UIText.t("design.order."+key))
	bar.add_child(ordering)
	ordering.item_selected.connect(func(_i):page=0;refresh())
	previous=Button.new()
	previous.text=UIText.t("design.previous")
	bar.add_child(previous)
	previous.pressed.connect(func():page-=1;refresh())
	page_label=label(bar,"")
	next=Button.new()
	next.text=UIText.t("design.next")
	bar.add_child(next)
	next.pressed.connect(func():page+=1;refresh())
	scroll=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(scroll)
	grid=GridContainer.new()
	grid.columns=2
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	per_page=int(JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_result_analysis.json")).design.cards_per_page)
	for i in range(per_page):
		var card := PanelContainer.new()
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var style := StyleBoxFlat.new()
		style.bg_color=Color("17212c")
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.content_margin_left=16
		style.content_margin_right=16
		style.content_margin_top=14
		style.content_margin_bottom=14
		card.add_theme_stylebox_override("panel",style)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation",9)
		card.add_child(body)
		var fields := {"card":card,"style":style,"row":{}}
		for key in ["title","composition","tags","performance","best","worst","conclusion","usage","confidence"]:
			fields[key]=label(body,"")
		fields.title.add_theme_font_size_override("font_size",22)
		var button := Button.new()
		button.text=UIText.t("design.details")
		body.add_child(button)
		fields.button=button
		button.pressed.connect(func():detail_requested.emit(fields.row))
		var retest := Button.new()
		retest.text=UIText.t("analysis.retest_card")
		body.add_child(retest)
		fields.retest=retest
		retest.pressed.connect(func():retest_requested.emit(fields.row))
		slots.append(fields)
	set_process(false)
	refresh()

func label(parent: Node,text: String) -> Label:
	var control := Label.new()
	control.text=text
	control.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(control)
	return control

func set_report(value: Dictionary) -> void:
	report=value
	var mon_table: Dictionary=MonGroupXlsx.read_mon_names()
	mon_names=mon_table.get("names",{})
	rows=report.get("level_candidates",[])
	page=0
	refresh()

func localized(section: String,key: String,field := "name") -> String:
	var saved: String=str(report.get("display_names",{}).get(section,{}).get(key,""))
	if not saved.is_empty():return saved
	var binding := UIText.data_key(section,key,field)
	if not binding.is_empty():return UIText.t(binding)
	var fallback: String=str(display_names.get(section,{}).get(key,""))
	if not fallback.is_empty():return fallback
	return UIText.t("design.unknown_name")

func tag_names(values: Array) -> String:
	var names := PackedStringArray()
	for tag in values:
		var key := "fleet.tag."+str(tag)
		var name := UIText.t(key) if UIText.entries.has(key) else UIText.t("design.unknown_tag")
		if not names.has(name):names.append(name)
	return " / ".join(names) if not names.is_empty() else UIText.t("design.no_tags")

func composition(row: Dictionary) -> String:
	var names := PackedStringArray()
	for id in row.composition:
		names.append(UIText.t("design.enemy_count",{"name":str(mon_names.get(str(id),id)),"count":int(row.composition[id])}))
	return "\n".join(names) if not names.is_empty() else UIText.t("design.no_composition")

func configurations(values: Array) -> String:
	var lines := PackedStringArray()
	for row in values:
		var names := PackedStringArray()
		for weapon in row.weapons:names.append(localized("equipment",str(weapon)))
		var weapons := " + ".join(names)
		if names.size()==1:weapons=UIText.t("design.single_weapon",{"weapon":weapons})
		lines.append(UIText.t("design.configuration",{"weapons":weapons,"number":int(row.player_index)+1,"rate":"%.0f%%" % (100*row.win_rate),"tests":row.tests}))
	return "\n".join(lines) if not lines.is_empty() else UIText.t("design.no_ranking")

func refresh() -> void:
	var counts := {}
	for key in CATEGORIES:counts[key]=0
	for row in rows:
		counts[row.design_category]+=1
	var values := {"total":report.get("attempts",0),"tests":report.get("tests",0),"enemies":rows.size(),"ordinary":counts.ordinary,"insufficient":counts.insufficient,"anomaly":counts.anomaly}
	write(overview,UIText.t("design.overview",values))
	var selected: Array=rows.filter(func(row):return category.selected==0 or row.design_category==CATEGORIES[category.selected])
	if ordering.selected>0:
		var key: String=["","win_rate","discrimination","tests","avg_battle_time"][ordering.selected]
		selected.sort_custom(func(a,b):
			if a[key]==b[key]:return a.enemy_index<b.enemy_index
			if a[key]==null:return false
			if b[key]==null:return true
			return a[key]<b[key] if ordering.selected in [1,4] else a[key]>b[key])
	var pages := maxi(1,ceili(float(selected.size())/per_page))
	page=clampi(page,0,pages-1)
	write(page_label,UIText.t("design.page",{"page":page+1,"pages":pages,"count":selected.size()}))
	previous.disabled=page==0
	next.disabled=page>=pages-1
	for i in range(slots.size()):
		var fields: Dictionary=slots[i]
		var index := page*per_page+i
		fields.card.visible=index<selected.size()
		if index>=selected.size():fields.row={};continue
		var row: Dictionary=selected[index]
		fields.row=row
		fields.retest.visible=row.design_category=="insufficient"
		fields.style.border_color=Color("d27b70") if row.design_category=="anomaly" else Color("b7a16a")
		write(fields.title,UIText.t("design.title",{"number":int(row.enemy_index)+1,"category":UIText.t("design.category."+row.design_category)}))
		write(fields.composition,UIText.t("design.composition",{"enemies":composition(row)}))
		write(fields.tags,UIText.t("design.tags",{"tags":tag_names(row.tags)}))
		var difficulty := "unknown"
		write(fields.performance,UIText.t("design.performance",{"rate":"—" if row.win_rate==null else "%.0f%%" % (100*row.win_rate),"time":"—" if row.avg_battle_time==null else "%.1f" % row.avg_battle_time,"difficulty":UIText.t("design.difficulty."+difficulty)}))
		write(fields.best,UIText.t("design.best",{"configurations":configurations(row.design_best)}))
		write(fields.worst,UIText.t("design.worst",{"configurations":configurations(row.design_worst)}))
		write(fields.conclusion,UIText.t("design.conclusion",{"conclusion":UIText.t("design.sentence."+row.design_conclusion)}))
		write(fields.usage,UIText.t("design.usage",{"usage":UIText.t("design.use."+row.design_use)}))
		write(fields.confidence,UIText.t("design.confidence",{"confidence":UIText.t("analysis.confidence."+row.design_confidence),"tests":row.tests}))
	scroll.scroll_vertical=0

func write(control: Label,value: String) -> void:
	if control.text!=value:control.text=value
