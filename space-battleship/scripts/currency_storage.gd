extends RefCounted
## Exact tokens are restored only at resource/material/equipment-level boundaries.
const Ledger = preload("res://scripts/currency_ledger.gd")
const I = preload("res://scripts/currency_integer.gd")

class Outcome extends RefCounted:
	var status: String
	var data: Dictionary
	func _init(state: String, candidate: Dictionary = {}) -> void:
		status = state
		data = candidate

class TokenReader extends RefCounted:
	var tokens:Array=[]
	var at:=0
	var error:=""
	func _init(source:String)->void:
		# JSON syntax and ordinary values come from the engine parser. Tokenize
		# in native code; only exact boundary fields are restored below.
		var regex:=RegEx.new()
		regex.compile(r'"(?:\\.|[^"\\])*"|[{}\[\]:,]|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|true|false|null')
		tokens=regex.search_all(source)
		var nesting:=0
		for token in tokens:
			var text:String=token.get_string()
			if text in ["{","["]:
				nesting+=1
				if nesting>49:error="depth"
			elif text in ["}","]"]:nesting-=1
			elif text not in [":",","] and nesting>48:error="depth"
	func _text()->String:
		return tokens[at].get_string() if at<tokens.size() else ""
	func _skip()->void:
		var token:String=_text()
		at+=1
		if token not in ["{","["]:return
		var depth:=1
		while at<tokens.size() and depth>0:
			token=_text();at+=1
			if token in ["{","["]:depth+=1
			elif token in ["}","]"]:depth-=1
	func _descend(path:Array,key:String)->bool:
		if path.is_empty():return key in ["resources","hyperspace","loadout","levels"]
		if path==["hyperspace"]:return key=="materials"
		if path==["loadout"]:return key in ["weapons","defence"]
		if path in [["resources"],["levels"],["hyperspace","materials"]]:return true
		return path.size()==3 and path[0]=="loadout" and path[1] in ["weapons","defence"] and key=="level"
	func _integer_kind(path: Array) -> String:
		if path.size() == 2 and path[0] == "resources":
			return "resource"
		if path.size() == 3 and path[0] == "hyperspace" and path[1] == "materials":
			return "material"
		if path.size() == 4 and path[0] == "loadout" and path[1] in ["weapons","defence"] and path[3] == "level":
			return "level"
		if path.size() == 2 and path[0] == "levels":
			return "level"
		return ""
	func _guard_duplicate(path: Array, key: String) -> bool:
		return (path.is_empty() and key in ["resources","hyperspace","loadout","levels"]) or path in [["resources"],["levels"]] or path == ["hyperspace","materials"] or (path == ["hyperspace"] and key == "materials") or (path.size() == 3 and path[0] == "loadout" and key == "level")
	func read(path:Array,depth:int,candidate:Variant)->Variant:
		if not error.is_empty():return null
		var kind:String=_integer_kind(path)
		if not kind.is_empty():
			var token:String=_text()
			_skip()
			if not I._canonical(token):return candidate
			var integer:Variant=I.make(token)
			if kind=="resource":return I.encode(integer)
			if I.compare(integer,I.make(I.MAX_INT))>0:
				error="integer_transport";return null
			return int(token)
		if _text()=="{" and candidate is Dictionary:
			at+=1
			var seen:Dictionary={}
			while _text()!="}" and at<tokens.size():
				var key:String=JSON.parse_string(_text())
				if seen.has(key) and _guard_duplicate(path,key):
					error="duplicate_boundary";return null
				seen[key]=true
				at+=2 # key and colon; full JSON syntax is already valid.
				if _descend(path,key):
					var child:Array=path.duplicate();child.append(key)
					candidate[key]=read(child,depth+1,candidate[key])
				else:_skip()
				if not error.is_empty():return null
				if _text()==",":at+=1
			at+=1
			return candidate
		if _text()=="[" and candidate is Array:
			at+=1
			for index in candidate.size():
				var child:Array=path.duplicate();child.append(index)
				candidate[index]=read(child,depth+1,candidate[index])
				if not error.is_empty():return null
				if _text()==",":at+=1
			at+=1
			return candidate
		_skip()
		return candidate

static func parse_source(source: String) -> Outcome:
	var parser := JSON.new()
	if parser.parse(source) != OK or not parser.data is Dictionary:
		return Outcome.new("format")
	var reader := TokenReader.new(source)
	var candidate: Variant = reader.read([], 0, parser.data)
	if not reader.error.is_empty() or not candidate is Dictionary:
		return Outcome.new(reader.error if not reader.error.is_empty() else "format")
	return Outcome.new("ok", candidate)

static func valid_resource(raw: Variant) -> bool:
	return Ledger.decode(raw).status == "ok"

static func valid_int64(raw: Variant, minimum: int = 0) -> bool:
	if not (raw is int or raw is float) or not is_finite(float(raw)) or raw < minimum or float(raw) != floorf(float(raw)):
		return false
	var exact: Variant = I.command_floor(raw)
	return exact != null and I.compare(exact,I.make(I.MAX_INT))<=0

