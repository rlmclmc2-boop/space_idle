extends RefCounted
## Copies the existing level workbook, changing only monGroup cells in the output.

const TEMPLATE := "res://config_excel/level.xlsx"
const SHEET := "xl/worksheets/sheet1.xml"

static func export_levels(levels: Array,output_path: String,groups: Dictionary) -> String:
	if levels.is_empty():return "没有可导出的关卡。"
	var template_path: String=ProjectSettings.globalize_path(TEMPLATE)
	if output_path.get_file().to_lower()=="level.xlsx" or output_path.replace("\\","/")==template_path.replace("\\","/"):return "不能覆盖现有 level.xlsx。"
	var archive:=ZIPReader.new()
	if archive.open(template_path)!=OK:return "找不到现有 level.xlsx。"
	var xml: String=archive.read_file(SHEET).get_string_from_utf8()
	var start: int=xml.find("<sheetData>")
	var end: int=xml.find("</sheetData>",start)
	var first: int=xml.find('<row r="4"',start)
	if start<0 or end<0 or first<0 or first>=end:
		archive.close()
		return "现有 level.xlsx 的表结构无效。"
	var old_data: String=xml.substr(first,end-first)
	var row_pattern:=RegEx.new()
	row_pattern.compile('<row r="([0-9]+)"[^>]*>.*?</row>')
	var existing: Dictionary={}
	for found in row_pattern.search_all(old_data):existing[int(found.get_string(1))]=found.get_string()
	var generated:=PackedStringArray()
	for stage in levels:
		var level_id: int=int(stage.level_id)
		var row_number: int=level_id+3
		var points: Array=stage.battle_points
		var entries:=PackedStringArray()
		for index in range(points.size()):
			var group_id: int=int(points[index].mon_group_id)
			if not groups.has(str(group_id)):
				archive.close()
				return "monGroup ID %d 不在现有配置中。" % group_id
			var position: float=float(index+1)/float(points.size()+1)
			entries.append("%d|%s" % [group_id,str(snappedf(position,0.001))])
		var cell: String='<c r="C%d" t="inlineStr"><is><t>%s</t></is></c>' % [row_number,("{"+",".join(entries)+"}").xml_escape()]
		var source: String=str(existing.get(row_number,""))
		if source.is_empty():
			generated.append('<row r="%d" spans="1:8"><c r="A%d"><v>%d</v></c>%s</row>' % [row_number,row_number,level_id,cell])
			continue
		var cell_start: int=source.find('<c r="C%d"' % row_number)
		var cell_end: int=source.find("</c>",cell_start)
		if cell_start>=0 and cell_end>=0:
			cell_end+="</c>".length()
			source=source.substr(0,cell_start)+cell+source.substr(cell_end)
		else:
			var close: int=source.find("</row>")
			source=source.substr(0,close)+cell+source.substr(close)
		generated.append(source)
	xml=xml.substr(0,first)+"".join(generated)+xml.substr(end)
	var dimension:=RegEx.new()
	dimension.compile('<dimension ref="[^"]+"')
	xml=dimension.sub(xml,'<dimension ref="A1:H%d"' % (levels.size()+3),true)
	if DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())!=OK:
		archive.close()
		return "无法创建导出目录。"
	var writer:=ZIPPacker.new()
	if writer.open(output_path)!=OK:
		archive.close()
		return "无法写入 Excel 文件。"
	for name in archive.get_files():
		if name.ends_with("/"):continue
		if writer.start_file(name)!=OK:
			writer.close();archive.close()
			return "Excel 写入失败。"
		var bytes: PackedByteArray=xml.to_utf8_buffer() if name==SHEET else archive.read_file(name)
		if writer.write_file(bytes)!=OK or writer.close_file()!=OK:
			writer.close();archive.close()
			return "Excel 写入失败。"
	writer.close()
	archive.close()
	return ""
