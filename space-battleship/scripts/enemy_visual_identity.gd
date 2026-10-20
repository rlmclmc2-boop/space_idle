extends RefCounted
## Pure identity lookup. Asset availability is captured on the main thread.
const ARCHETYPES := {
	"scout":["enemy_opening_scout",2],
	"sentry":["enemy_opening_sentry",2],
	"interceptor":["enemy_opening_interceptor",1],
	"swarm":["enemy_opening_swarm",1],
	"anchor":["enemy_opening_anchor",1],
	"reactive":["enemy_opening_reactive",1],
	"shielded":["enemy_opening_shielded",1],
	"command":["enemy_opening_command",1]
}
const RANKED_ARCHETYPES:=["anchor","reactive","shielded","command"]
var diagnostics:Dictionary={}

static func visual_rank(enemy:Dictionary)->String:
	# Use published encounter metadata, never numeric size or final-wave index.
	var tier:=str(enemy.get("combat_tier","normal"))
	if tier in ["boss","ultimate"] and bool(enemy.get("encounter_leader",false)):return "boss"
	return "elite" if tier=="elite" else ""


func resolve(enemy:Dictionary,config:Dictionary)->String:
	var fallback="enemy_"+str(clampi(int(enemy.get("size",1)),1,6))
	var archetype=str(enemy.get("archetype_id",""))
	if archetype.is_empty():return fallback
	var binding:Array=ARCHETYPES.get(archetype,[])
	var reason="unknown_archetype"
	if not binding.is_empty():
		if int(enemy.get("armourType",0))!=int(binding[1]):reason="armour_type_mismatch"
		else:
			var row:Dictionary=config.get("ships",{}).get(binding[0],{})
			if bool(row.get("asset_ready",false)):
				var rank:=visual_rank(enemy)
				if archetype in RANKED_ARCHETYPES and not rank.is_empty():
					var variant:=str(binding[0])+"_"+rank
					if bool(config.get("ships",{}).get(variant,{}).get("asset_ready",false)):return variant
				return str(binding[0])
			reason="asset_unavailable"
	var diagnostic=archetype+":"+reason
	if not diagnostics.has(diagnostic):
		diagnostics[diagnostic]=fallback
		push_warning("Enemy visual fallback: "+diagnostic+" -> "+fallback)
	return fallback
