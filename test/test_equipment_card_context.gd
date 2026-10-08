extends SceneTree
## Synthetic UI fixture; no player saves or progression run.
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI)
 root.add_child(scene);scene.set_process(false);scene.beginner_guide.set_process(false)
 var g:BattleGame=scene.game
 g.save_enabled=false;g.paused=true;g.pending_unlocks.clear()
 g.profile.cleared=range(1,20);g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.profile.onboarding.completed=true;scene.beginner_guide.refresh()
 var panel=scene.equipment_panel
 for i in 3:
  var entry=g.module_entry("weapons",i);entry.key=["cannon","longLaser","laser"][i];entry.level=107
 g.invalidate_stat_cache();panel.refresh()
 await process_frame;await process_frame
 for i in 3:
  var entry=g.module_entry("weapons",i);var row=g.player_weapon_row(entry)
  var card=panel.cards["weapons_%d"%i];var label=card.fields.level
  check(label.text.contains(UIText.t("equipment.energy" if int(row.dmgtype)==1 else "equipment.physical")),"Card exposes authoritative damage type")
  check(label.text.contains("秒升满") if entry.key=="longLaser" else not label.text.contains("秒"),"Card keeps type and beam stage; ordinary intervals move to detail")
  check(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x,"Context fits existing level line")
  check(card.custom_minimum_size==Vector2(310,176),"Card height is unchanged")
 check(panel.cards.weapons_1.fields.caption.text==UIText.t("weapon.rate") and panel.cards.weapons_1.fields.stat.text.contains("→"),"Beam shows its determinate rate range")
 panel.select_item("weapons_1");panel.show_inspector()
 check(panel.detail.basics.text.contains(UIText.t("equipment.attack_interval",{"seconds":scene.number(float(g.player_weapon_row(g.module_entry("weapons",1)).cd))})),"Inspector shares combat interval")
 var card=panel.cards.weapons_1;var damage=panel.items.weapons_1.projection.expected
 var old_rate=panel.items.weapons_1.mainStatNumber
 g.db.equipment.longLaser[0].cd=float(g.db.equipment.longLaser[0].cd)*0.8
 panel.invalidate_stats({"slot":"weapons_1","detail":true});panel.refresh_pending()
 check(panel.cards.weapons_1==card and GrowthNumber.compare(old_rate,panel.items.weapons_1.mainStatNumber)!=0,"Interval-only update reuses card and refreshes context")
 check(GrowthNumber.compare(damage,panel.items.weapons_1.projection.expected)==0,"Interval context does not change damage")
 check(not panel.cards.defence_0.name_button.visible and panel.cards.defence_0.fields.title.visible and panel.cards.defence_0.fields.title.text.contains("固定"),"Fixed armour has no swap arrow and explains fixed identity")
 var defence=g.module_entry("defence",0)
 for key in ["armour","shield"]:
  defence.key=key;defence.level=107;g.invalidate_stat_cache();panel.refresh()
  var row=g.db.equip(key,107)
  check(panel.cards.defence_0.fields.level.text.contains("抗"+UIText.t("equipment.energy" if int(row.dmgtype)==1 else "equipment.physical")),"Defence shows its configured matching resistance")
 var reduction=g.db.config.dmgReduce;g.db.config.dmgReduce=0;panel.refresh()
 check(not panel.cards.defence_0.fields.level.text.contains("抗"),"Zero resistance is not labelled as protection against a type")
 g.db.config.dmgReduce=reduction;defence.key="";panel.refresh()
 check(not panel.cards.defence_0.fields.level.text.contains("抗"),"Empty defence has no resistance claim")
 g.module_entry("weapons",2).key="";panel.refresh()
 check(not panel.cards.weapons_2.fields.level.text.contains("秒") and not panel.cards.weapons_2.fields.stat.visible,"Empty slot has no attack context or damage")
 g.profile.loadout.weapons.append({"key":"cannon","level":107})
 check(not str(panel.equipment_item("weapons",3).cardLevelText).contains("秒"),"Inactive slot has no attack context")
 print("Equipment card context: %d checks, %d failures"%[checks,failures])
 scene.queue_free();await process_frame;quit(1 if failures else 0)
