extends RefCounted
## One capture per batch. Retain loaded scripts so later dynamic loads use the
## same implementations; never reread source files when producing the result.
var retained_scripts: Array[Script] = []
var value: Dictionary = {}

static func digest(data: Variant) -> String:
	return JSON.stringify(canonical(data),"",true,true).sha256_text()

# JSON loads integers as floats. Canonicalize only exactly represented integral
# metadata; never round a fractional quantity or introduce accounting precision.
static func canonical(data: Variant) -> Variant:
	if data is float:
		if is_finite(data) and absf(data)<=9007199254740991.0 and data==floorf(data):return int(data)
		return {"float64":var_to_bytes(data).hex_encode()}
	if data is Dictionary:
		var result:Dictionary={}
		for key in data:result[key]=canonical(data[key])
		return result
	if data is Array:
		var result:Array=[]
		for item in data:result.append(canonical(item))
		return result
	return data

func capture(database, roots: Array, model: String, parameters: Dictionary, policy: Dictionary={}) -> Dictionary:
	retained_scripts.clear()
	var pending: Array=roots.duplicate()
	var sources: Dictionary={}
	var text_by_path: Dictionary={}
	var missing: Array=[]
	var paths := RegEx.new()
	paths.compile("res://scripts/[A-Za-z0-9_]+\\.gd")
	var globals: Array=ProjectSettings.get_global_class_list()
	while not pending.is_empty():
		var path: String=str(pending.pop_back())
		if sources.has(path):continue
		var script=load(path)
		if not script is GDScript or not script.has_source_code():
			sources[path]="unknown";missing.append(path);continue
		retained_scripts.append(script)
		var source: String=script.source_code
		sources[path]=source.sha256_text();text_by_path[path]=source
		var base:Script=script.get_base_script()
		if base!=null and not base.resource_path.is_empty():pending.append(base.resource_path)
		for matched in paths.search_all(source):pending.append(matched.get_string())
		for entry in globals:
			if str(entry.path).begins_with("res://scripts/") and source.contains(str(entry["class"])):pending.append(entry.path)
	var snapshot=preload("res://scripts/configuration_snapshot.gd").active()
	var auxiliary:Dictionary={}
	for name in snapshot.members():
		if not str(name).ends_with(".json"):continue
		for source in text_by_path.values():
			if str(source).contains(str(name).get_file()):
				auxiliary[name]=snapshot.sha256(snapshot.read_bytes("res://"+str(name)))
				break
	value={"version":1,"status":"known" if missing.is_empty() else "unknown","missing_sources":missing,
		"model":model,"capability_version":preload("res://scripts/execution_contract.gd").VERSION,
		"numeric_version":preload("res://scripts/execution_contract.gd").NUMERIC_VERSION,
		"rules_sha256":digest(sources),"rules":sources,"data_sha256":digest(database.data),
		"auxiliary_sha256":digest(auxiliary),"auxiliary":auxiliary,"input_origin":database.input_origin.duplicate(true),
		"engine":Engine.get_version_info().string,"native":"not_used",
		"parameters":canonical(parameters),"policy_sha256":digest(policy)}
	value.batch_sha256=digest(value)
	return value.duplicate(true)

static func compare(before: Dictionary, after: Dictionary, operation: String) -> Dictionary:
	var reasons: Array=[]
	var differences: Array=[]
	if operation not in ["comparison","retest","merge"]:return {"compatible":false,"reasons":["unknown_identity_operation"],"differences":[]}
	if before.get("status")!="known" or after.get("status")!="known" or before.get("version")!=1 or after.get("version")!=1:
		return {"compatible":false,"reasons":["unknown_execution_identity"],"differences":[]}
	for key in ["model","capability_version","numeric_version","rules_sha256","engine","native","auxiliary_sha256","data_sha256","input_origin","policy_sha256"]:
		if not before.has(key) or not after.has(key):reasons.append("missing_identity:"+key);continue
		if digest(before[key])==digest(after[key]):continue
		differences.append(key)
		# Balance comparison intentionally varies data, with the difference exposed.
		if operation!="comparison" or key not in ["data_sha256","input_origin","auxiliary_sha256"]:reasons.append("different_identity:"+key)
	if not before.get("parameters") is Dictionary or not after.get("parameters") is Dictionary:
		reasons.append("missing_identity:parameters")
	else:
		# Follow-up sampling may vary seed/count/budget; physical experiment settings may not.
		for key in ["step_seconds","max_seconds","power_multiplier","module_delta","selected_inputs_sha256"]:
			if digest(before.parameters.get(key))!=digest(after.parameters.get(key)):
				differences.append("parameters/"+key);reasons.append("different_identity:parameters/"+key)
	return {"compatible":reasons.is_empty(),"reasons":reasons,"differences":differences}
