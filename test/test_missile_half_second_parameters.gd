extends SceneTree
const Display=preload("res://scripts/equipment_display.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:
 var db=ShipDatabase.new();var g=BattleGame.new(db,false);var row=db.equip("missile",1)
 check(row.cd==2.5 and row.dmg==208.5 and row.para1==4 and row.para2==30,"Authoritative missile changes only base cycle and proportional damage")
 check(is_equal_approx(float(row.dmg)/row.cd/(200.0/2.4),1.0008),"Half-unit authored base preserves nominal DPS within +0.08 percent")
 var projection=Display.snapshot(g,{"key":"missile","level":1,"gems":[]})
 check(projection.rate.interval==2.5 and is_equal_approx(float(projection.rate.single),208.5) and is_equal_approx(float(projection.rate.start),333.6),"Actual projected four-missile DPS uses the new real interval and damage")
 var minimum=INF;var maximum=-INF;var min_level=0;var max_level=0
 for level in range(1,1001):
  var old_damage=200.0 if level==1 else db.equipment_combat_growth(200.0,0.2,level)
  var new_damage=db.equip("missile",level).dmg
  var relative=float(new_damage)/2.5/(float(old_damage)/2.4)-1.0
  if relative<minimum:minimum=relative;min_level=level
  if relative>maximum:maximum=relative;max_level=level
 check(minimum>=-0.04000001 and maximum<=0.05600001,"Real existing damage rounding drift remains within evaluated -4 to +5.6 percent for levels1..1000")
 print("Missile actual rounded DPS drift levels1..1000: ",minimum*100,"% at ",min_level,"; ",maximum*100,"% at ",max_level)
 check(db.equip("cannon",1).cd==3.5 and db.equip("longLaser",1).cd==0.5 and db.equip("longLaser",1).dmg==62.5,"Other player weapon bases remain unchanged")
 check(db.enemy_weapon("missile-mon").cd==1 and db.enemy_weapon("missile-mon").dmg==5 and db.enemy_weapon("missile-mon").para1==3,"Enemy-specific missile mechanics are unchanged")
 print("Missile half-second parameters: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
