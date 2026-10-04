extends RefCounted
## UI draft only. This codec never modifies inventory or runs an auto-destroy policy.
const MAX_LENGTH=4096
const WEAPONS=["laser","missile","cannon","longLaser"]
const QUALITIES=["white","blue","gold","legendary"]
static func parse(text: String,affix_keys: Array=[]) -> Dictionary:
 if text.length()>MAX_LENGTH:return {"ok":false,"reason":"length"}
 var raw=JSON.parse_string(text)
 if not raw is Dictionary or raw.size()!=3 or raw.get("version")!=1 or raw.get("mode") not in ["and","or"] or not raw.get("conditions") is Array:return {"ok":false,"reason":"schema"}
 if raw.conditions.size()>5:return {"ok":false,"reason":"conditions"}
 for condition in raw.conditions:
  if not condition is Dictionary or condition.size()!=2:return {"ok":false,"reason":"condition"}
  var kind=condition.get("kind");var value=condition.get("value")
  match kind:
   "weapon":
    if value not in WEAPONS:return {"ok":false,"reason":"weapon"}
   "quality":
    if value not in QUALITIES:return {"ok":false,"reason":"quality"}
   "min_level":
    if not value is float and not value is int:return {"ok":false,"reason":"level"}
    if not is_finite(float(value)) or float(value)!=floor(float(value)) or value<5 or value>1000000:return {"ok":false,"reason":"level"}
   "affix":
    if not value is Dictionary or value.size()!=2 or value.get("key") not in affix_keys:return {"ok":false,"reason":"affix"}
    var tier=value.get("max_tier")
    if (not tier is float and not tier is int) or float(tier)!=floor(float(tier)) or tier<1 or tier>5:return {"ok":false,"reason":"tier"}
   "legendary","ultimate":
    if not value is bool:return {"ok":false,"reason":"flag"}
   _ :return {"ok":false,"reason":"enum"}
 return {"ok":true,"rule":raw}
