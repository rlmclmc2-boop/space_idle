extends RefCounted
## Resource reward values shared by live kills and native configuration.
## Draw order, drop identity and collection remain at the settlement boundary.
const N=preload("res://scripts/growth_number.gd")
static func resource_drop(g,enemy:Dictionary,drop:Dictionary,galaxy_charge:float=-1.0)->Dictionary:
 var resource:=int(drop.resourceId)
 var smelting=g.reactor_multiplier("smelting",galaxy_charge) if resource==1 else 1.0
 var factor=N.multiply(float(enemy.res_ratio),smelting)
 var base=N.ceiling(N.multiply(N.multiply(drop.amount,factor),1.0+float(enemy.get("jewelIron",0)) if resource==1 else 1.0))
 var amount=N.ceiling(N.multiply(base,g.planet_resource_multiplier())) if resource in [1,2] else base
 return {"resource":resource,"chance":float(drop.chance),"base":base,"amount":amount}
