extends RefCounted
## Single-thread display contract: simulation_geometry_authority writes geometry.
## Main enemy position/width/angle, weapon sockets, recognition drawing and labels
## consume these values. Fleet Nodes receive transforms, never run the aim/orbit
## solver. Mutable pose caches below contain display-only shield/rail animation.
## Birth descriptors are compiled once; events update only referenced entities.
const Component=preload("res://scripts/weapon_visual.gd")
var rows:Dictionary={}
var appearances:Dictionary={}
var spatials:Dictionary={}
var poses:Dictionary={}
var fleet:Dictionary={}
var fleet_configuration_version:int=0
var shapes:Dictionary={}
var shape_members:Dictionary={}
var player_position:=Vector2.ZERO
var grid_plan:Dictionary={}
var ready:=false
var applied_rows:=0
func descriptor(uid:int,value:Dictionary)->void:
	var components:Array=[]
	for item in value.components:
		var slots:Array[int]=[];slots.assign(item.slots)
		var component=Component.new(item.hardpoint,item.profile,slots,int(item.owner_slot),"enemy")
		component.damage_type=int(item.damage_type);components.append(component)
	appearances[uid]={"ship_key":str(value.ship_key),"components":components,"mounts":value.mounts,"types":value.types}
	spatials[uid]={"shape_revision":1,"appearance":appearances[uid],"components":components}
var source_rows:Dictionary={}

func apply(value:Dictionary)->void:
	grid_plan=value.get("grid_plan",{})
	for shape in value.get("shapes",[]):
		shapes[str(shape.id)]=shape.value
		if not shape_members.has(int(shape.uid)):shape_members[int(shape.uid)]={}
		shape_members[int(shape.uid)][str(shape.id)]=true
	if value.has("player_position"):player_position=value.player_position
	if value.has("fleet"):
		fleet=value.fleet;fleet_configuration_version=int(value.get("configuration_version",0))
	for uid in value.get("enemies",{}):
		if source_rows.has(uid) and is_same(source_rows[uid],value.enemies[uid]):continue
		source_rows[uid]=value.enemies[uid]
		var row:Dictionary=value.enemies[uid].duplicate()
		assert(shapes.has(str(row.recognition_id)),"Display missing immutable shape publication")
		row.recognition=shapes[str(row.recognition_id)];rows[int(uid)]=row;applied_rows+=1
		spatials[int(uid)].position=row.position;spatials[int(uid)].frontline=row.frontline
		if not poses.has(int(uid)):poses[int(uid)]={}
		# Preserve display animation history while replacing source-owned pose values.
		poses[int(uid)].merge(row.pose,true)
	ready=true
func row(enemy:Dictionary)->Dictionary:
	var value:Dictionary=rows.get(int(enemy.uid),{})
	assert(not value.is_empty(),"Display geometry missing entity "+str(enemy.uid))
	return value
func pose(enemy:Dictionary)->Dictionary:
	row(enemy)
	return poses[int(enemy.uid)]
func appearance(enemy:Dictionary)->Dictionary:
	var value:Dictionary=appearances.get(int(enemy.uid),{})
	assert(not value.is_empty(),"Display geometry missing birth descriptor")
	return value
func retire(uid:int)->void:
	rows.erase(uid);poses.erase(uid);appearances.erase(uid);spatials.erase(uid);source_rows.erase(uid)
	for identity in shape_members.get(uid,{}):shapes.erase(identity)
	shape_members.erase(uid)

func width_at(enemy:Dictionary,y:float)->float:
	var value:Dictionary=row(enemy)
	if is_equal_approx(y,float(value.position.y)):return value.width
	if is_equal_approx(y,90.0):return value.width_low
	if is_equal_approx(y,floorf(float(value.frontline))):return value.width_high
	assert(false,"Display attempted an unpublished geometry width solve")
	return value.width
func spatial(enemy:Dictionary)->Dictionary:
	row(enemy)
	return spatials[int(enemy.uid)]
