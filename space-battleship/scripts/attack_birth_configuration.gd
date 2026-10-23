extends RefCounted
## Immutable rule inputs prepared once at attack birth (or native configuration).
## No RNG, counters, runtime ownership or per-instance chain state is consumed here.
static func prepare(g,entry:Dictionary,totals:Dictionary)->Dictionary:
 var effects:Array=g.jewel_effects(entry)
 if float(totals.repeat_chance)>0 and not effects.any(func(e):return e.kind=="repeat"):
  effects.append({"kind":"repeat","p4":0.0,"level":0})
 for effect in effects:
  if g.enhancement_branch_active(entry,"proficiency",3,"B"):
   effect.enemy_resistance=g.enhancement_parameter("proficiency_b3_resistance")
  if effect.kind=="repeat" and g.enhancement_branch_active(entry,"repeat",1,"B"):
   effect.chain=true;effect.chain_targets=int(g.enhancement_parameter("repeat_b1_targets"))
 var extra_chain:=int(totals.chain_count)
 if extra_chain>0:
  var existing:Array=effects.filter(func(e):return e.get("chain",false))
  if existing.is_empty():effects.append({"kind":"hyperspace_chain","chain":true,"chain_targets":extra_chain})
  else:existing[0].chain_targets=int(existing[0].get("chain_targets",0))+extra_chain
 var chain:=0;var repeat_factor:=1.0
 for effect in effects:
  if effect.get("chain",false):chain=int(effect.chain_targets)
  if effect.kind=="repeat":repeat_factor=g.enhancement_branches.repeat_multiplier(effect)
 var secondary:bool=g.enhancement_branch_active(entry,"repeat",3,"B")
 return {"effects":effects,"chain_count":chain,"repeat_multiplier":repeat_factor,
  "repeat_probability":g.enhancement_branches.repeat_probability(g,entry),
  "secondary_enabled":secondary,"secondary_probability":g.enhancement_parameter("repeat_b3_probability") if secondary else 0.0}
