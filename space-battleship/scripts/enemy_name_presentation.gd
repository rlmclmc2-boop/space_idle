extends RefCounted
## Player names only. Authoring descriptions and enemy definitions stay intact.
const DESIGN_PREFIXES=["编排草案-","物理甲BOSS：","能量盾BOSS：","物理甲终极：","能量盾终极："]
const WEAPONS={"laser":"laser","missile":"missile","cannon":"cannon","longLaser":"beam"}
static func name_for(row:Dictionary,id:String="",mainline:=true) -> String:
 var original:=str(row.get("des","")).strip_edges()
 # Manual hyperspace owns another registry; its IDs must not use mainline bindings.
 if not mainline:return original
 var authored:=false
 for prefix in DESIGN_PREFIXES:
  if original.begins_with(prefix):authored=true;break
 if not authored:return UIText.data_text("enemies",id,"des",original) if not id.is_empty() else original
 var size:=int(row.get("size",1))
 var shielded:=float(row.get("max_shield",row.get("shield",0)))>0
 if size>=5:
  return UIText.t("battle.enemy_name."+("shield_" if shielded else "armour_")+("dreadnought" if size>=6 else "flagship"))
 var weapons:Array[String]=[]
 for entry in row.get("equipment",[]):
  var weapon:=str(entry.get("name","")).trim_suffix("_mon").trim_suffix("-mon")
  if WEAPONS.has(weapon) and not weapons.has(weapon):weapons.append(weapon)
 var weapon_name:=UIText.t("battle.enemy_identity.weapon."+(str(WEAPONS[weapons[0]]) if weapons.size()==1 else "mixed" if weapons.size()>1 else "unknown"))
 var protection:=UIText.t("battle.enemy_identity.shield" if shielded else "battle.enemy_identity.armour") if shielded or int(row.get("armourType",0))!=0 else ""
 return UIText.t("battle.enemy_identity.name",{"protection":protection,"weapon":weapon_name,"hull":UIText.t("battle.enemy_identity.hull."+str(clampi(size,1,4)))})
