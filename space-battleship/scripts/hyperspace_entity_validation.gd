extends RefCounted
## Fixed schema/order and typed mappings shared with the authoritative importer.
static var schema:Dictionary={}
static func definition()->Dictionary:
	if schema.is_empty():
		var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://data/hyperspace_entity_schema.json"))
		if parsed is Dictionary:schema=parsed
	return schema
static func template_matches(template:Variant,value:Variant,filename:String,path:String="")->bool:
	if template==null:return value!=null if definition().editable_paths[filename].has(path) else value==null
	if template is Dictionary:
		if not value is Dictionary or template.keys()!=value.keys():return false
		for key in template:
			if not template_matches(template[key],value[key],filename,path+"/"+str(key)):return false
		return true
	if template is Array:
		if not value is Array or template.size()!=value.size():return false
		for i in template.size():
			if not template_matches(template[i],value[i],filename,path+"/"+str(i)):return false
		return true
	return template==value
static func at(value:Variant,path:String)->Variant:
	for key in path.trim_prefix("/").split("/"):
		if value is Dictionary:value=value.get(key)
		elif value is Array and key.is_valid_int() and int(key)>=0 and int(key)<value.size():value=value[int(key)]
		else:return null
	return value
static func typed(value:Variant,kind:String)->bool:
	if kind.ends_with("_or_blank") and value==null:return true
	kind=kind.trim_suffix("_or_blank")
	if kind in ["int","float","number"]:
		return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and absf(float(value))<9e15 and (kind!="int" or float(value)==floorf(float(value)))
	if kind in ["string","enum"]:return value is String
	if kind=="bool":return value is bool
	return kind=="null" and value==null
static func output_valid(filename:String,value:Dictionary)->bool:
	var spec:=definition()
	if spec.is_empty() or not spec.get("templates",{}).has(filename) or not template_matches(spec.templates[filename],value,filename):return false
	for table in spec.tables:
		for row in table.rows:
			for field in row.mappings:
				var kind:String=""
				for col in table.columns:
					if col.key==field:kind=str(col.type)
				if kind=="typed_literal":kind=str(row.locked.get("data_type",""))
				for target in row.mappings[field]:
					if target[0]==filename and not typed(at(value,str(target[1])),kind):return false
	return true
static func frozen_valid()->bool:
	var spec:=definition()
	if spec.is_empty():return false
	for name in spec.frozen_inputs:
		if FileAccess.get_sha256("res://data/"+str(name))!=str(spec.frozen_inputs[name]):return false
	return true
