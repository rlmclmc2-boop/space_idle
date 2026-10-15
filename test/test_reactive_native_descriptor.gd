extends SceneTree
# Stage 3-3's authored float JSON value is validated then copied as an INT for the kernel.
const Compiler=preload("res://scripts/native_execution_compiler.gd")
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	assert(ok,label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
	root.add_child(scene);scene.set_process(false)
	var g=scene.game;g.save_enabled=false;g.native_execution_auto=false
	g.profile.onboarding.completed=true;g.profile.cleared=[1,2];g.profile.unlocked=["armour","laser"]
	g.rebuild_unlocks();g.pending_unlocks.clear()
	g.profile.loadout={"weapons":[{"key":"laser","level":2},{"key":"missile","level":2},{"key":"cannon","level":1}],"defence":[{"key":"armour","level":2},{"key":"shield","level":1}]}
	g.invalidate_stat_cache();g.reset_player()
	var level:Dictionary=scene.db.levels[2];var point:=3
	var checkpoint={"distance":float(level.groups[point-1].position)*float(level.length),"groupIndex":point,"state":BattleGame.State.COMBAT,"guardArrived":false,"retreatBossPending":false}
	check(g.start(3,false,checkpoint),"authored 3-3 starts")
	check(g.native_execution==null and g.enemies.size()==2,"legacy state available before admission")
	var reactive:Dictionary=g.enemies[0]
	check(str(reactive.get("archetype_id",""))=="reactive" and typeof(reactive.reactiveReduction)==TYPE_FLOAT and reactive.reactiveReduction==1.0,"authored Godot parse is integral float")
	var original:Dictionary=reactive.duplicate(true)
	var compiled:Dictionary=Compiler.new().compile(g,"native_rich15_layer2")
	check(not compiled.has("error"),"valid descriptor compiles")
	check(typeof(compiled.enemies[0].reactiveReduction)==TYPE_INT and int(compiled.enemies[0].reactiveReduction)==1,"copied native field is strict integer")
	check(typeof(reactive.reactiveReduction)==TYPE_FLOAT and reactive==original,"source enemy remains unmodified")
	var kernel=ClassDB.instantiate("SpaceCombatKernel")
	check(kernel.configure(compiled),"strict native kernel accepts normalized authoring")
	var bad:Dictionary=compiled.duplicate(true);bad.enemies[0].reactiveReduction=1.0
	check(not ClassDB.instantiate("SpaceCombatKernel").configure(bad),"kernel still rejects unnormalized float")
	reactive.reactive_stacks=1.0;reactive.reactive_volley_at=0.5
	var resumed:Dictionary=Compiler.new().compile(g,"native_rich15_layer2")
	check(not resumed.has("error") and typeof(resumed.enemies[0].reactive_stacks)==TYPE_INT and int(resumed.enemies[0].reactive_stacks)==1,"valid resumed stack normalizes")
	check(ClassDB.instantiate("SpaceCombatKernel").configure(resumed),"valid resumed reactive state configures")
	reactive.clear();reactive.merge(original.duplicate(true),true)
	var rejected:Array=[]
	for pair in [["reactiveReduction","1"],["reactiveReduction",1.5],["reactiveReduction",-1],["reactiveReduction",2],["reactive_stacks","1"],["reactive_stacks",4],["reactive_volley_at","bad"]]:
		var key:String=pair[0];reactive[key]=pair[1]
		var result:Dictionary=Compiler.new().compile(g,"native_rich15_layer2")
		check(result.has("error"),"malformed "+key+" rejected")
		rejected.append({"key":key,"value":str(pair[1]),"error":result.get("error","")})
		reactive.clear();reactive.merge(original.duplicate(true),true)
		check(g.native_execution==null and g.projectiles.is_empty() and reactive==original,"rejection has no combat-state mutation")
	check(g.admit_native_compiled_execution("native_rich15_layer2"),"authored 3-3 admits native after valid normalization")
	var row={"checks":checks,"source_type":typeof(original.reactiveReduction),"descriptor_type":typeof(compiled.enemies[0].reactiveReduction),"rejections":rejected,"native_active":g.native_execution!=null,"save":g.save_enabled}
	print("REACTIVE_NATIVE_DESCRIPTOR ",JSON.stringify(row))
	quit()
