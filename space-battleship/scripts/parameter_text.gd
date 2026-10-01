extends RefCounted
## Selective, escaped parameter emphasis. Text and gameplay remain catalog-owned.
const COLORS := {"effect":"005449","cost":"743214","time":"214663","level":"243b50"}

static func escape(value: String) -> String:
	var result := ""
	for character in value:
		result += "[lb]" if character=="[" else "[rb]" if character=="]" else character
	return result

static func render(key: String, values: Dictionary = {}, spans: Dictionary = {}) -> String:
	var validated := UIText.t(key,values)
	if validated.is_empty() or not UIText.entries.has(key):return escape(validated)
	for parameter in UIText.contracts[key].params:
		if not values.has(parameter):return escape(validated)
	for parameter in values:
		if not UIText.contracts[key].params.has(parameter):return escape(validated)
	var template: String = UIText.entries[key]
	var result := ""
	var cursor := 0
	for found in UIText.pattern().search_all(template):
		result += escape(template.substr(cursor,found.get_start()-cursor))
		var parameter := found.get_string(1)
		var value := escape(str(values[parameter]))
		cursor = found.get_end()
		var span: Dictionary = spans.get(parameter,{})
		var role := str(span.get("role",""))
		var unit := str(span.get("unit",""))
		if COLORS.has(role) and template.substr(cursor,unit.length())==unit:
			result += "[color=#%s]%s%s[/color]" % [COLORS[role],value,escape(unit)]
			cursor += unit.length()
		else:result += value
	result += escape(template.substr(cursor))
	return result

static func create_label(parent: Node, rect: Rect2, font_size: int, font: Font, color: Color) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.position = rect.position
	label.size = rect.size
	label.bbcode_enabled = true
	label.scroll_active = false
	label.add_theme_font_override("normal_font",font)
	label.add_theme_font_size_override("normal_font_size",font_size)
	label.add_theme_color_override("default_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
