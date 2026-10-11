extends SceneTree
const VIEW = preload("res://scripts/presented_ship_view.gd")
const HYPER = preload("res://scripts/hyperspace_drone_visual.gd")
const RIG = preload("res://scripts/logical_fleet_pose.gd")
const BATTLEFIELD = preload("res://scripts/battlefield.gd")
var checks := 0
var failures: Array = []

func _initialize() -> void: run.call_deferred()

func verify(actual, expected, label: String) -> void:
	checks += 1
	if actual != expected and failures.size()<20: failures.append({"label":label,"actual":str(actual),"expected":str(expected)})

func run() -> void:
	var view = VIEW.new();view.size=Vector2(572,960);root.add_child(view)
	var hyper = HYPER.new();view.world.add_child(hyper)
	var rig = RIG.new();rig.prepare(view)
	var entries: Array = []
	for index in 8:entries.append({"key":["laser","missile","cannon","longLaser"][index%4]})
	var bag := {"equipped":[],"drones":{},"generation":0}
	for index in 5:
		var id := "test:"+str(index);bag.equipped.append(id)
		bag.drones[id]={"weapon":["laser","missile","cannon","longLaser"][index%4],"quality":"white","level":1}
	hyper.sync(bag)
	for key in view.manifest.hulls:
		view.set_hull(key);view.set_loadout(entries,8)
		rig.configuration_dirty=true;rig.configure(key,entries,8,bag)
		for index in 24:
			var center := Vector2(286+index,730-index)
			var target := Vector2(100+index*8,100)
			var close_up := index>=16
			view.set_pose(center,180,0.0,target,float(index)/60.0,true,close_up,1.0/60.0,false)
			hyper.pose(view,[],2.8 if close_up else 1.0,false)
			rig.pose(center,180,0.0,target,float(index)/60.0,close_up,1.0/60.0)
			verify(rig.ship_transform,view.ship.transform,str(key)+" ship "+str(index))
			var angles: Array = []
			for slot in 8:angles.append(float(index+slot)*0.03)
			view.set_slot_angles(angles);rig.set_slot_angles(angles)
			for slot in 8:
				var module:Dictionary=view.modules[slot]
				verify(rig.screen_mount_for_slot(slot),view.camera.unproject_position(module.mount.global_position),str(key)+" aim mount "+str(index)+"/"+str(slot))
				for ordinal in 2:verify(rig.screen_muzzle_for_slot(slot,ordinal),view.screen_muzzle_for_slot(slot,ordinal),str(key)+" muzzle "+str(index)+"/"+str(slot)+"/"+str(ordinal))
			for id in bag.equipped:
				for ordinal in 2:verify(rig.screen_muzzle_for_drone(id,ordinal),hyper.screen_muzzle_for_drone(id,ordinal,view),"drone "+id+"/"+str(index)+"/"+str(ordinal))
	print(JSON.stringify({"checks":checks,"failures":failures}))
	view.free()
	quit(0 if failures.is_empty() else 1)
