extends SceneTree
const VIEW:=preload("res://scripts/presented_ship_view.gd")
const KEYS:=["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]
const WEAPONS:=["cannon","missile","laser","longLaser"]
func _initialize()->void:call_deferred("run")
func run()->void:
	var view:=VIEW.new();view.size=Vector2(800,800);root.add_child(view)
	var pairs:=0;var max_anchor_error:=0.0
	for index in KEYS.size():
		assert(view.set_hull(KEYS[index]))
		for weapon in WEAPONS:
			var entries:Array=[]
			for slot in index+1:entries.append({"key":weapon})
			assert(view.set_loadout(entries,index+1))
			view.set_pose(Vector2(400,400),550.0,0.0,Vector2(400,-100),0.0,false,false)
			for degrees in [-60,0,60]:
				var angles:Array=[]
				for slot in index+1:angles.append(deg_to_rad(degrees))
				view.set_slot_angles(angles)
				for module in view.modules:
					var plane:MeshInstance3D=module.node.find_child("StaticWeaponArt",true,false)
					var texture:Texture2D=(plane.material_override as StandardMaterial3D).albedo_texture
					var image:=texture.get_image();var span:Vector2=(plane.mesh as PlaneMesh).size
					var row:Dictionary=view.static_weapon_art[weapon]
					var local_anchor:=Vector3((float(row.anchor[0])/image.get_width()-.5)*span.x,0,(float(row.anchor[1])/image.get_height()-.5)*span.y)
					var error:float=view.camera.unproject_position(plane.to_global(local_anchor)).distance_to(view.camera.unproject_position(module.pivot.global_position))
					max_anchor_error=maxf(max_anchor_error,error);assert(error<0.01,"Enlarged art base left the fixed axis")
					for other in view.modules:
						if other==module:continue
						pairs+=1
						var point:Vector3=plane.to_local(other.pivot.global_position)
						var uv:=Vector2(point.x/span.x+.5,point.z/span.y+.5)
						if uv.x<0 or uv.x>=1 or uv.y<0 or uv.y>=1:continue
						var pixel:=Vector2i(uv*Vector2(image.get_size()))
						assert(image.get_pixelv(pixel).a<0.5,KEYS[index]+" "+weapon+" turn="+str(degrees)+" art covers neighbouring bearing "+str(other.slot))
	print("TURRET_CLEARANCE hulls=5 weapons=4 angles=3 pairs=",pairs," max_base_error=",max_anchor_error," covered_neighbour_bearings=0")
	quit()
