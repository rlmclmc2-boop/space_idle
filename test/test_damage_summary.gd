extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func hit(ui,amount,critical=false,type=1)->void:
 ui.queue_damage_number({"player":false,"uid":101,"amount":amount,"absorbed":2,"critical":critical,"type":type})
func run()->void:
 var ui=preload("res://scripts/main.gd").new()
 var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 ui.game=g;g.enemies.assign([{"uid":101,"hp":1}]);ui.fx_time=1.0
 hit(ui,10);hit(ui,20,true,2)
 check(ui.damage_pending.size()==1,"simple mode one card across types and critical hits")
 var card=ui.damage_pending[0]
 check(GrowthNumber.compare(card.amount,30)==0 and GrowthNumber.compare(card.absorbed,4)==0,"window totals exact")
 check(card.critical and ui.damage_tag_text(card).ends_with("★"),"critical marker means contains critical")
 check(ui.damage_history_records.size()==2 and ui.damage_history_records[0][4]==10 and ui.damage_history_records[1][4]==20,"raw individual hits retained")
 ui.damage_pending.clear();ui.floats.append(card);ui.fx_time=1.21;hit(ui,7)
 check(ui.floats.size()==1 and ui.damage_pending.is_empty() and is_same(ui.floats[0],card),"reuse visible card")
 check(GrowthNumber.compare(card.amount,7)==0 and not card.critical and not ui.damage_tag_text(card).ends_with("★"),"new window resets total and critical marker")
 check(card.life>0,"new actual hit refreshes visible lifetime")
 var actor=g.enemies[0]
 g.enemies.clear();hit(ui,3)
 check(is_same(card.target_entity,actor) and card.target_entity.uid==101,"retains killed target owner")
 ui.floats.clear();ui.damage_pending.clear();ui.damage_mode=1
 hit(ui,10);hit(ui,20,true);hit(ui,30,false,2)
 check(ui.damage_pending.size()==3,"full mode retains separate critical and type groups")
 check(not ui.damage_pending[1].summary and not ui.damage_tag_text(ui.damage_pending[1]).ends_with("★"),"full mode unchanged tag formatting")
 ui.show_damage_numbers=false;var pending=ui.damage_pending.size()
 for i in 45:hit(ui,i)
 check(ui.damage_pending.size()==pending,"off mode creates no tags")
 check(ui.damage_history_records.size()==40,"history remains bounded 40 independent records")
 check(ui.read_damage_history().size()==40,"raw history readable")
 ui.free()
 print("DAMAGE_SUMMARY checks=",checks," failures=",failures)
 quit(failures)
