extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var view=preload("res://scripts/enemy_defence_inspector.gd").new()
 for pair in [[-0.2,"0"],[0,"0"],[0.2,"1"],[9.1,"10"],[999,"999"],[39100,"39.1K"],[12000,"12K"]]:
  check(view.remaining_text(pair[0])==pair[1],"Whole surviving small layers and shared quantity suffixes")
 var giant=15041509101792030.0
 check(view.remaining_text(giant)==NumberFormat.compact(giant) and view.remaining_text(giant).length()<12,"Reported giant armour uses the shared compact ladder")
 check(view.remaining_text({"m":3.91,"e":400})==NumberFormat.compact({"m":3.91,"e":400}),"Beyond-native layers keep compact scientific representation")
 var enemy={"hp":giant,"armourType":2,"shield":39100,"max_shield":39100,"shieldType":1}
 var before=JSON.stringify(enemy)
 var text=view.defence_text(enemy)
 check(text.contains("装甲："+NumberFormat.compact(giant)+" · 抵抗物理伤害") and text.contains("护盾：39.1K · 抵抗能量伤害"),"Both resistance types remain attached to their compact layers")
 check(JSON.stringify(enemy)==before,"Inspection never mutates the actual remaining layers")
 enemy.shield=0;text=view.defence_text(enemy)
 check(text.contains("护盾：0（已破）"),"Broken shield retains its explicit zero")
 enemy.max_shield=0;enemy.armourType=0;text=view.defence_text(enemy)
 check(text.contains("无护盾") and text.contains("无类型抗性"),"Unshielded and neutral meanings remain unchanged")
 print("Enemy defence numbers: ",checks," checks, ",failures," failures")
 view.free();quit(1 if failures else 0)
