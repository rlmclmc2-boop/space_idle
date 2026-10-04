extends RefCounted
## Copies the existing monGroup workbook and replaces only its data rows.
const TEMPLATE := "res://config_excel/monGroup.xlsx"
const STYLES := "xl/styles.xml"
const SLOT_COUNTS := [10,15]
const MON_TABLE := "res://../space-battleship/config_excel/mon.xlsx"

static func read_mon_names() -> Dictionary:
	var table: Dictionary=read_mon_enemies()
	if table.has("error"):return table
	var names: Dictionary={}
	for id in table.enemies:names[id]=str(table.enemies[id].des)
	return {"names":names}

static func read_mon_enemies() -> Dictionary:
	var table: Dictionary=_read_mon_rows()
	if table.has("error"):return table
	var enemies: Dictionary={}
	for source in table.rows:
		var id: String=str(source.get("id","")).strip_edges()
		if not id.is_valid_int() or int(id)<1 or enemies.has(id):return {"error":"invalid_mon_table"}
		var description: String=str(source.get("des","")).strip_edges()
		var equipment_text: String=_clean_list(str(source.get("equipment","")))
		var resources: PackedStringArray=_clean_list(str(source.get("res",""))).split(",")
		if description.is_empty() or resources.size()!=3:return {"error":"invalid_mon_table"}
		var mounts: Array=[]
		for item in equipment_text.split(","):
			var pair: PackedStringArray=item.split("|")
			if pair.size()!=2 or pair[0].strip_edges().is_empty() or not pair[1].strip_edges().is_valid_int() or int(pair[1])<1:return {"error":"invalid_mon_table"}
			for _index in range(int(pair[1])):mounts.append({"name":pair[0].strip_edges()})
		if not resources[0].strip_edges().is_valid_int() or not resources[1].strip_edges().is_valid_float() or not resources[2].strip_edges().is_valid_float():return {"error":"invalid_mon_table"}
		var row: Dictionary=source.duplicate(true)
		row.id=int(id)
		for field in ["dmgMultiple","health","armourType","size"]:
			var number: String=str(source.get(field,"")).strip_edges()
			if not number.is_valid_float():return {"error":"invalid_mon_table"}
			row[field]=float(number)
		row.equipment=mounts
		row.drops=[{"resourceId":int(resources[0]),"amount":float(resources[1]),"chance":float(resources[2])}]
		enemies[id]=row
	return {"enemies":enemies}

static func _clean_list(value: String) -> String:
	return value.replace("｛","{").replace("｝","}").replace("，",",").replace("；",";").strip_edges().trim_prefix("{").trim_suffix("}").strip_edges()

static func _read_mon_rows() -> Dictionary:
	var path: String=ProjectSettings.globalize_path("res://config_excel/mon.xlsx")
	if FileAccess.file_exists("res://analyzer-package.json"):
		path=ProjectSettings.globalize_path(MON_TABLE)
		if not FileAccess.file_exists(path):
			var marker=JSON.parse_string(FileAccess.get_file_as_string("res://analyzer-package.json"))
			if marker is Dictionary:path=str(marker.get("source_mon",path))
	var archive:=ZIPReader.new()
	if archive.open(path)!=OK:return {"error":"missing_mon_table"}
	var sheet: String=""
	for member in archive.get_files():
		if member.begins_with("xl/worksheets/") and member.ends_with(".xml") and not member.contains("/_rels/"):
			sheet=member
			break
	if sheet.is_empty():
		archive.close()
		return {"error":"invalid_mon_table"}
	var shared:=_shared_strings(archive.read_file("xl/sharedStrings.xml"))
	var parser:=XMLParser.new()
	if parser.open_buffer(archive.read_file(sheet))!=OK:
		archive.close()
		return {"error":"invalid_mon_table"}
	var rows: Array=[]
	var headers: Dictionary={}
	var row:=0
	var cell: String=""
	var cell_type: String=""
	var value: String=""
	var in_value:=false
	var cells: Dictionary={}
	while parser.read()==OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				match parser.get_node_name():
					"row":
						row=int(parser.get_named_attribute_value_safe("r"))
						cells={}
					"c":
						cell=str(parser.get_named_attribute_value_safe("r")).trim_suffix(str(row))
						cell_type=parser.get_named_attribute_value_safe("t")
						value=""
					"v","t":in_value=true
			XMLParser.NODE_TEXT:
				if in_value:value+=parser.get_node_data()
			XMLParser.NODE_ELEMENT_END:
				match parser.get_node_name():
					"v","t":in_value=false
					"c":
						if cell_type=="s":
							var index:=int(value)
							value=str(shared[index]) if index>=0 and index<shared.size() else ""
						cells[cell]=value.strip_edges()
					"row":
						if row==1:headers=cells.duplicate()
						elif row>=4 and not str(cells.get("A","")).is_empty():
							var record: Dictionary={}
							for column in headers:record[str(headers[column])]=cells.get(column,"")
							rows.append(record)
	archive.close()
	return {"error":"invalid_mon_table"} if rows.is_empty() or headers.get("A")!="id" or headers.get("B")!="des" else {"rows":rows}

static func _shared_strings(bytes: PackedByteArray) -> Array:
	var strings: Array=[]
	var parser:=XMLParser.new()
	if parser.open_buffer(bytes)!=OK:return strings
	var in_text:=false
	var value: String=""
	while parser.read()==OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				if parser.get_node_name()=="si":value=""
				elif parser.get_node_name()=="t":in_text=true
			XMLParser.NODE_TEXT:
				if in_text:value+=parser.get_node_data()
			XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name()=="t":in_text=false
				elif parser.get_node_name()=="si":strings.append(value)
	return strings

static func group_name_from_slots(slots: Array,mon_names: Dictionary) -> String:
	var composition: Dictionary={}
	for value in slots:
		if value==null:continue
		var id:=str(int(value))
		composition[id]=int(composition.get(id,0))+1
	return group_name(composition,mon_names)

static func group_name(composition: Dictionary,mon_names: Dictionary) -> String:
	var ids: Array=composition.keys()
	ids.sort_custom(func(a,b):return int(a)<int(b))
	var counts: Dictionary={}
	var order: Array=[]
	for id in ids:
		var name: String=str(mon_names.get(str(id),str(id))).strip_edges()
		if not counts.has(name):order.append(name)
		counts[name]=int(counts.get(name,0))+int(composition[id])
	var parts:=PackedStringArray()
	for name in order:parts.append("%s×%d" % [name,int(counts[name])])
	return "、".join(parts)

static func export_groups(levels: Array,output_path: String,known_enemies: Dictionary,mon_names: Dictionary) -> String:
	var rows := PackedStringArray()
	var ids := {}
	for index in range(levels.size()):
		var stage=levels[index]
		if not stage is Dictionary or not stage.get("group_data") is Dictionary:return "invalid_group"
		var group: Dictionary=stage.group_data
		# The legacy generated workbook has no coordinate column. Refuse to lose
		# an authored explicit layout; use the coordinate-aware source importer.
		if group.has("formation_positions"):return "explicit_layout_export_not_supported"
		if not group.get("slots") is Array or not group.slots.size() in SLOT_COUNTS:return "invalid_group"
		var id: int=int(stage.get("enemy_group",0))
		if id<1 or ids.has(id):return "invalid_group"
		ids[id]=true
		var members := PackedStringArray()
		for value in group.slots:
			if value==null:members.append("null");continue
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)):return "invalid_group"
			var enemy_id := str(int(value))
			if not known_enemies.has(enemy_id):return "invalid_group"
			members.append(enemy_id)
		var number := index+4
		var title: String=str(stage.get("name","")).strip_edges()
		if title.is_empty():title=group_name_from_slots(group.slots,mon_names)
		if title.is_empty():return "invalid_group"
		var lineup := "{%s}" % ",".join(members)
		rows.append('<row r="%d" spans="1:3"><c r="A%d"><v>%d</v></c><c r="B%d" t="inlineStr"><is><t xml:space="preserve">%s</t></is></c><c r="C%d" t="inlineStr"><is><t xml:space="preserve">%s</t></is></c></row>' % [number,number,id,number,title.xml_escape(),number,lineup.xml_escape()])
	var reader := ZIPReader.new()
	if reader.open(TEMPLATE)!=OK:return "missing_template"
	var sheet_path: String=""
	for member in reader.get_files():
		if member.begins_with("xl/worksheets/") and member.ends_with(".xml") and not member.contains("/_rels/"):
			sheet_path=member
			break
	if sheet_path.is_empty():
		reader.close()
		return "invalid_template"
	var sheet: String=reader.read_file(sheet_path).get_string_from_utf8()
	var styles: String=reader.read_file(STYLES).get_string_from_utf8()
	var fonts_start := styles.find("<fonts")
	var font_start := styles.find("<font>",fonts_start)
	var font_end := styles.find("</font>",font_start)
	if fonts_start<0 or font_start<0 or font_end<0:
		reader.close()
		return "invalid_template"
	font_end+="</font>".length()
	styles=styles.substr(0,font_start)+'<font><sz val="13"/><color rgb="FF1F2937"/><name val="Microsoft YaHei"/><family val="2"/></font>'+styles.substr(font_end)
	sheet=sheet.replace('defaultRowHeight="14.4"','defaultRowHeight="23"')
	sheet=sheet.replace('width="15.2222222222222"','width="22"')
	var marker := sheet.find('<sheetData>')
	var data_start := marker+'<sheetData>'.length()
	var first_data := sheet.find('<row r="4"',data_start)
	var data_end := sheet.find('</sheetData>',data_start)
	var dimension_start := sheet.find('<dimension ref="')
	if marker<0 or first_data<0 or data_end<0 or dimension_start<0 or first_data>data_end:
		reader.close()
		return "invalid_template"
	var dimension_end := sheet.find('"',dimension_start+'<dimension ref="'.length())
	if dimension_end<0:
		reader.close()
		return "invalid_template"
	var old_dimension := sheet.substr(dimension_start,dimension_end-dimension_start+1)
	var last_row := maxi(3,levels.size()+3)
	sheet=sheet.replace(old_dimension,'<dimension ref="A1:C%d"' % last_row)
	# This template keeps row 1-3 as the importer contract and starts data at row 4.
	marker=sheet.find('<sheetData>')
	data_start=marker+'<sheetData>'.length()
	first_data=sheet.find('<row r="4"',data_start)
	data_end=sheet.find('</sheetData>',data_start)
	sheet=sheet.substr(0,first_data)+"".join(rows)+sheet.substr(data_end)
	sheet=sheet.replace('activeCell="C16" sqref="C16"','activeCell="A1" sqref="A1"')
	var writer := ZIPPacker.new()
	if writer.open(output_path)!=OK:
		reader.close()
		return "output_error"
	for name in reader.get_files():
		if name.ends_with("/"):continue
		if writer.start_file(name)!=OK:
			writer.close();reader.close()
			return "output_error"
		var content: PackedByteArray=sheet.to_utf8_buffer() if name==sheet_path else styles.to_utf8_buffer() if name==STYLES else reader.read_file(name)
		if writer.write_file(content)!=OK or writer.close_file()!=OK:
			writer.close();reader.close()
			return "output_error"
	writer.close()
	reader.close()
	return ""
