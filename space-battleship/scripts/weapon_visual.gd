extends RefCounted

# Presentation component. Several logical slots may share one hardpoint.
var hardpoint: Dictionary
var profile: Dictionary
var slots: Array[int]
var owner_slot: int
var faction: String

func _init(point: Dictionary, weapon_profile: Dictionary, bound_slots: Array[int], selected_slot: int, skin: String) -> void:
	hardpoint = point
	profile = weapon_profile
	slots = bound_slots
	owner_slot = selected_slot
	faction = skin

func mode() -> String:
	if str(profile.get("visual_class",""))=="missile":return "bay"
	return str(hardpoint.get("mode","embedded"))

func skin() -> Dictionary:
	return profile.get("faction_skin",{}).get(faction,{})
