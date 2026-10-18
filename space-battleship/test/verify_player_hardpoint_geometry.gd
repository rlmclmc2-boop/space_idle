extends SceneTree

const VIEW := preload("res://scripts/presented_ship_view.gd")
const LOGICAL := preload("res://scripts/logical_fleet_pose.gd")
const KEYS := ["Frigate", "Destroyer", "Cruiser", "Battleship", "Heavy_Battleship"]
const WEAPONS := ["cannon", "laser", "missile", "longLaser", "cannon"]

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var view := VIEW.new()
	view.size=Vector2(800,800)
	root.add_child(view)
	var logical := LOGICAL.new()
	logical.prepare(view)
	var maximum := 0.0
	for index in KEYS.size():
		var key: String=KEYS[index]
		assert(view.set_hull(key),key)
		var entries := []
		var angles := []
		for slot in index+1:
			entries.append({"key":WEAPONS[slot]})
			angles.append(0.12*float(slot+1))
		assert(view.set_loadout(entries,index+1),key)
		logical.configure(key,entries,index+1,{})
		for center in [Vector2(400,400),Vector2(400,755)]:
			view.set_pose(center,550.0,0.0,Vector2(400,-100),0.0,false,false)
			logical.pose_base(center,550.0,0.0,0.0,false,0.0)
			view.set_slot_angles(angles)
			logical.set_slot_angles(angles)
			for slot in index+1:
				var base:Vector2=view.camera.unproject_position(view.modules[slot].node.global_position)
				var base_error:float=base.distance_to(logical.screen_mount_for_slot(slot))
				for ordinal in 2:
					var muzzle_error:float=view.screen_muzzle_for_slot(slot,ordinal).distance_to(logical.screen_muzzle_for_slot(slot,ordinal))
					maximum=maxf(maximum,maxf(base_error,muzzle_error))
					assert(base_error<0.5 and muzzle_error<0.5,key+" slot="+str(slot)+" muzzle="+str(ordinal)+" drift="+str(base_error)+"/"+str(muzzle_error))
		print("GEOMETRY ",key," slots=",index+1," poses=2")
	print("GEOMETRY_DONE max_pixel_drift=",maximum)
	quit()
