extends RefCounted
## Runtime provenance travels with damage. Trigger permission has one authority.
const MAX_TRIGGER_DEPTH:=1
static func root(id: int,source_id: String,weapon: String) -> Dictionary:
	return {"root_id":id,"batch_id":id,"source_id":source_id,"weapon":weapon,"trigger_depth":0,"trigger":"","guidance_factors":{}}
static func can_trigger(context: Dictionary) -> bool:
	return int(context.get("trigger_depth",0))==0
static func derive(context: Dictionary,trigger: String) -> Dictionary:
	if not can_trigger(context):return {}
	return {"root_id":int(context.get("root_id",0)),"batch_id":int(context.get("batch_id",0)),"source_id":str(context.get("source_id","direct")),"weapon":str(context.get("weapon","")),"trigger_depth":MAX_TRIGGER_DEPTH,"trigger":trigger,"guidance_factors":{}}
