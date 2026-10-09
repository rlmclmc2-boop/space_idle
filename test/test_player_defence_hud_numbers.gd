extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true
 var before=JSON.stringify(g.profile);var player_before=JSON.stringify(g.player);var rng=g.rng.state
 check(scene.player_defence_hud_text("shield",20.8,1370)=="护盾 21 / 1.37K","Observed fractional HUD shield uses half units while retaining large capacity abbreviation")
 check(scene.player_defence_hud_text("armour",20.8,1370)=="生命 21 / 1.37K","Companion armour HUD shares the same display policy")
 check(scene.player_defence_hud_text("shield",20.24,20.25)=="护盾 20 / 20.5","Nearest half-unit boundary applies consistently to current and capacity")
 check(scene.player_defence_hud_text("shield",0,0.5)=="护盾 0 / 0.5","Empty and exact half-unit layers remain explicit")
 check(scene.player_defence_hud_text("armour",999.8,39100)=="生命 1000 / 39.1K","Half-unit rounding near suffix boundary preserves the normal large-number ladder")
 var current={"m":2.08,"e":1};var capacity={"m":1.37,"e":3};var inputs=JSON.stringify([current,capacity])
 check(scene.player_defence_hud_text("shield",current,capacity)=="护盾 21 / 1.37K" and JSON.stringify([current,capacity])==inputs,"Dictionary-based small shield follows half units without rewriting quantities")
 var huge={"m":3.91,"e":400}
 check(scene.player_defence_hud_text("shield",huge,huge)=="护盾 3.91e+400 / 3.91e+400","Beyond-float shield keeps existing scientific ladder")
 check(JSON.stringify(g.profile)==before and JSON.stringify(g.player)==player_before and g.rng.state==rng,"HUD formatting changes neither actual defense, profile nor RNG")
 scene.queue_free();await process_frame
 print("Player defence HUD numbers: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
