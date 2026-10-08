extends RefCounted
## Receipt-owned actor graph. Shared targets and equipment references survive JSON saves.
const MAX_NODES:=65536
const MAX_BYTES:=8388608
var nodes:Array=[]
var originals:Array=[]
var bindings:Array=[]
var error:=""

func encode(value:Variant)->Variant:
	if value is StringName:return {"name":str(value)}
	if value is int:return {"integer":str(value)}
	if value is Dictionary or value is Array:
		for i in originals.size():
			if is_same(value,originals[i]):return {"ref":i}
		if nodes.size()>=MAX_NODES:error="too_many_actors";return null
		var id:=nodes.size();originals.append(value);nodes.append({})
		var node:Dictionary={"type":"dict" if value is Dictionary else "array","items":[]}
		if value is Dictionary:
			for binding in bindings:
				if is_same(value,binding.entry):node.binding={"kind":binding.kind,"index":binding.index,"key":str(value.key)};break
			for key in value:node.items.append([encode(key),encode(value[key])])
		else:
			for item in value:node.items.append(encode(item))
		nodes[id]=node;return {"ref":id}
	if value is Vector2:return {"vec":[encode(float(value.x)),encode(float(value.y))]}
	if value is PackedVector2Array:
		var points:Array=[]
		for point in value:points.append([encode(float(point.x)),encode(float(point.y))])
		return {"points":points}
	if value is float:
		if is_nan(value):error="nan_actor_value";return null
		if not is_finite(value):return {"nonfinite":"inf" if value>0 else "negative_inf"}
		return {"float":Marshalls.raw_to_base64(var_to_bytes(value))}
	if value==null or value is String or value is bool or value is int or value is float:return value
	error="unsupported_actor_value";return null

static func capture(g)->String:
	var codec= new()
	for kind in ["weapons","defence"]:
		var entries:Array=g.combat_weapon_entries() if kind=="weapons" else g.defense_entries()
		for index in entries.size():codec.bindings.append({"kind":kind,"index":index,"entry":entries[index]})
	var root:Dictionary={"player":g.player,"enemies":g.enemies,"projectiles":g.projectiles,"jewel_repeats":g.jewel_repeats,"drone_delayed":g.drone_combat.delayed,"branch_weapons":g.enhancement_branches.weapons,"branch_defenses":g.enhancement_branches.defenses,"attack_contexts":g.enhancement_attack_contexts}
	for key in ["retreat_from","retreat_target","retreat_elapsed","guard_index","guard_elapsed","guard_engaged","first_clear","enemy_shield_time","enemy_shield_hit_time"]:root[key]=g.get(key)
	for key in ["pending_hits","missile_queue","motion_clock","release_context"]:
		if g.get(key)!=null:root[key]=g.get(key)
	var graph:Variant=codec.encode(root)
	if not codec.error.is_empty():return ""
	var result:=JSON.stringify({"root":graph,"nodes":codec.nodes},"",true,true)
	return result if result.length()<=MAX_BYTES else ""

static func encoded_valid(value:Variant,count:int)->bool:
	if value==null or value is String or value is bool:return true
	if value is int or value is float:return is_finite(float(value))
	if not value is Dictionary or value.size()!=1:return false
	if value.has("float"):
		if not value.float is String or value.float.length()>32:return false
		var decoded:Variant=bytes_to_var(Marshalls.base64_to_raw(value.float))
		return decoded is float and is_finite(decoded)
	if value.has("name"):return value.name is String
	if value.has("integer"):return value.integer is String and value.integer.is_valid_int() and str(value.integer.to_int())==value.integer
	if value.has("ref"):return preload("res://scripts/hyperspace_config.gd").integer(value.ref) and value.ref>=0 and value.ref<count
	if value.has("nonfinite"):return value.nonfinite in ["inf","negative_inf"]
	if value.has("vec"):return pair_valid(value.vec)
	if value.has("points"):return value.points is Array and value.points.all(func(pair):return pair_valid(pair))
	return false

static func pair_valid(value:Variant)->bool:
	return value is Array and value.size()==2 and value.all(func(n):return n is Dictionary and n.has("float") and encoded_valid(n,0))

static func graph_valid(graph:Variant)->bool:
	if not graph is Dictionary or graph.size()!=2 or not graph.get("nodes") is Array or graph.nodes.is_empty() or graph.nodes.size()>MAX_NODES or not encoded_valid(graph.get("root"),graph.nodes.size()):return false
	for node in graph.nodes:
		if not node is Dictionary or node.get("type") not in ["dict","array"] or not node.get("items") is Array or node.size() not in [2,3]:return false
		if node.has("binding"):
			var binding:Variant=node.binding
			if node.type!="dict" or not binding is Dictionary or binding.size()!=3 or binding.get("kind") not in ["weapons","defence"] or not preload("res://scripts/hyperspace_config.gd").integer(binding.get("index")) or binding.index<0 or not binding.get("key") is String:return false
		for item in node.items:
			if node.type=="dict":
				if not item is Array or item.size()!=2 or not key_valid(item[0]) or not encoded_valid(item[1],graph.nodes.size()):return false
			elif not encoded_valid(item,graph.nodes.size()):return false
	return true

static func key_valid(value:Variant)->bool:
	return value is String or value is int or value is float or (value is Dictionary and value.size()==1 and (value.has("integer") or value.has("name") or value.has("float")) and encoded_valid(value,0))

static func decode_value(value:Variant,objects:Array)->Variant:
	if not value is Dictionary:return value
	if value.has("float"):return bytes_to_var(Marshalls.base64_to_raw(value.float))
	if value.has("name"):return StringName(value.name)
	if value.has("integer"):return value.integer.to_int()
	if value.has("ref"):return objects[int(value.ref)]
	if value.has("vec"):return Vector2(decode_value(value.vec[0],objects),decode_value(value.vec[1],objects))
	if value.has("points"):
		var points:=PackedVector2Array()
		for pair in value.points:points.append(Vector2(decode_value(pair[0],objects),decode_value(pair[1],objects)))
		return points
	return INF if value.nonfinite=="inf" else -INF

static func decode(graph:Dictionary,g=null)->Dictionary:
	var objects:Array=[];var external:Dictionary={}
	for i in graph.nodes.size():
		var node:Dictionary=graph.nodes[i];var object:Variant={} if node.type=="dict" else []
		if g!=null and node.has("binding"):
			var binding:Dictionary=node.binding
			var entry:Dictionary=g.combat_entry(int(binding.index)) if binding.kind=="weapons" else g.slot_entry("defence",int(binding.index))
			if not entry.is_empty() and entry.key==binding.key:object=entry;external[i]=true
		objects.append(object)
	for i in graph.nodes.size():
		if external.has(i):continue
		var node:Dictionary=graph.nodes[i]
		for item in node.items:
			if node.type=="dict":objects[i][decode_value(item[0],objects)]=decode_value(item[1],objects)
			else:objects[i].append(decode_value(item,objects))
	var root:Variant=decode_value(graph.root,objects)
	return root if root is Dictionary else {}

static func valid(text:String)->bool:
	if text.is_empty() or text.length()>MAX_BYTES:return false
	var graph:Variant=JSON.parse_string(text)
	if not graph_valid(graph):return false
	var root:=decode(graph)
	for key in ["player","branch_weapons","branch_defenses","attack_contexts"]:
		if not root.get(key) is Dictionary:return false
	for key in ["enemies","projectiles","jewel_repeats","drone_delayed"]:
		if not root.get(key) is Array or not root[key].all(func(item):return item is Dictionary):return false
	for key in ["pending_hits","missile_queue"]:
		if root.has(key) and (not root[key] is Array or not root[key].all(func(item):return item is Dictionary)):return false
	for key in ["retreat_from","retreat_target","retreat_elapsed","guard_elapsed","enemy_shield_time","enemy_shield_hit_time"]:
		if not preload("res://scripts/hyperspace_config.gd").number(root.get(key)):return false
	for key in ["guard_index"]:
		if not preload("res://scripts/hyperspace_config.gd").integer(root.get(key)):return false
	for key in ["guard_engaged","first_clear"]:
		if not root.get(key) is bool:return false
	return true

static func restore(g,text:String)->void:
	var root:=decode(JSON.parse_string(text),g)
	var armour:Variant=g.player.armour;var shield:Variant=g.player.shield
	g.player=root.player;g.player.armour=armour;g.player.shield=shield
	g.enemies.assign(root.enemies);g.projectiles.assign(root.projectiles);g.jewel_repeats.assign(root.jewel_repeats)
	g.drone_combat.delayed=root.drone_delayed
	g.enhancement_branches.weapons=root.branch_weapons;g.enhancement_branches.defenses=root.branch_defenses;g.enhancement_attack_contexts=root.attack_contexts
	for key in ["retreat_from","retreat_target","retreat_elapsed","guard_index","guard_elapsed","guard_engaged","first_clear","enemy_shield_time","enemy_shield_hit_time","motion_clock","release_context"]:
		if root.has(key):g.set(key,root[key])
	for key in ["pending_hits","missile_queue"]:
		if root.has(key):g.get(key).assign(root[key])
	if g.has_method("refresh_missile_target_registry"):g.refresh_missile_target_registry()
