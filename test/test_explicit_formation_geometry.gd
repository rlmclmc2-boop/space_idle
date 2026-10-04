extends SceneTree
const Geometry=preload("res://scripts/explicit_formation_geometry.gd")
const Formation=preload("res://scripts/enemy_formation.gd")
const Recognition=preload("res://scripts/enemy_recognition_visual.gd")
func _initialize():
	var a:=PackedVector2Array([Vector2(0,0),Vector2(10,0),Vector2(0,10)])
	var b:=PackedVector2Array([Vector2(10,10),Vector2(10,6),Vector2(6,10)])
	assert(not Geometry.overlap(a,b),"Overlapping AABBs with separated triangles are a false positive")
	assert(Geometry.overlap(a,PackedVector2Array([Vector2(2,2),Vector2(6,2),Vector2(2,6)])),"Real contained collision must reject")
	assert(Geometry.overlap(a,Geometry.rectangle(Rect2(2,2,5,2))),"An actual meter/body crossing must reject")
	var enemies:Dictionary={"1":{"size":4},"2":{"size":1}}
	var slots:Array=[1,2,null]
	assert(Formation.positions(slots,enemies)==Formation.positions(slots,enemies,null),"Absent coordinates preserve default placement")
	assert(Formation.positions(slots,enemies,[[286,140],[166,260],null])[0]==Vector2(286,140),"Explicit slot identity survives")
	assert(not Formation.explicit_error(slots,enemies,[[286,260],[166,140],null]).is_empty(),"Large front hull must reject")
	assert(not Formation.explicit_error(slots,enemies,[[286,140],[166,260],[100,200]]).is_empty(),"Empty-slot coordinates must reject")
	assert(Recognition.shield_color(0)==Recognition.NEUTRAL and Recognition.shield_color(0)!=Recognition.ENERGY and Recognition.shield_color(0)!=Recognition.PHYSICAL,"Neutral shield must not imply either resistance")
	assert(Recognition.shield_color(1)==Recognition.ENERGY and Recognition.shield_color(2)==Recognition.PHYSICAL,"Existing resistance colours stay unchanged")
	print("EXPLICIT GEOMETRY: 9 checks passed; no battle ticks")
	quit()
