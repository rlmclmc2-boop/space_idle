extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;var view=scene.enemy_defence_inspector
 var before=JSON.stringify(g.profile);var rng=g.rng.state
 var physical=scene.db.enemies["46125"].duplicate(true);physical.hp=10;physical.shield=10;physical.max_shield=10
 var energy=scene.db.enemies["46145"].duplicate(true);energy.hp=10;energy.shield=10;energy.max_shield=10
 var records=JSON.stringify([physical,energy]);var physical_text=view.defence_text(physical);var energy_text=view.defence_text(energy)
 check(physical_text.contains("攻击：物理伤害") and physical_text.count("抵抗物理伤害")==2,"Real wave6 physical attack is identified separately from both physical-resisting defenses")
 check(energy_text.contains("攻击：能量伤害") and energy_text.count("抵抗物理伤害")==2,"Real wave7 energy attack is retained despite both layers resisting physical damage")
 var mixed=energy.duplicate(true);mixed.equipment=[{"name":"laser_mon"},{"name":"cannon-mon"},{"name":"laser_mon"}]
 check(view.attack_text(mixed)=="攻击：能量、物理伤害","Multiple real resolved weapon types appear once each without inferring from hull or tier")
 check(view.attack_text({"armourType":2,"shieldType":2})=="攻击类型未知","Missing weapons never borrow defense type as attack type")
 check(view.attack_text({"equipment":[{"name":"unknown-fact-fixture"}]})=="攻击类型未知","Unresolved weapon never invents attack information")
 check(energy_text.split("\n").size()==4 and view.description.size.y==148 and view.panel.size.y==172,"Only one short hover line is added with space for all four facts")
 check(view.hint.text=="指向敌舰看攻击与防御" and not view.panel.visible,"Existing hover invitation reflects facts while detail panel stays initially folded")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng and JSON.stringify([physical,energy])==records,"Fact inspection changes no combat record, profile or RNG")
 scene.queue_free();await process_frame
 print("Enemy attack/defence facts: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
