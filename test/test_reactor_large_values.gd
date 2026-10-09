extends SceneTree
const I=preload("res://scripts/reactor_integer.gd")
const N=preload("res://scripts/growth_number.gd")
const P=preload("res://scripts/reactor_upgrade_preview.gd")
const G=preload("res://scripts/reactor_allocation_growth.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func fixture(db)->BattleGame:
 var g=BattleGame.new(db,false);g.save_enabled=false;g.profile.highestLevel=63;g.profile.cleared=range(1,63);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true;g.profile.reactorLevel=215;g.profile.resources["2"]=6.99e30
 return g
func run()->void:
 var db=ShipDatabase.new();var g=fixture(db)
 check(g.reactor_capacity() is int and g.reactor_can_grow(1) and g.reactor_capacity_at(216) is String,"215→216 crosses legacy int64 without blocking")
 check(g.reactor_max_upgrades()==13,"6.99No affords13 levels at unchanged1.35 prices")
 g.equalize_reactor_allocation();var before:=JSON.stringify(g.profile);var rng_before:int=g.rng.state
 var quote:=P.quote(g,13)
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"Read-only MAX quote leaves profile and RNG unchanged")
 check(g.upgrade_reactor(13) and g.reactor_capacity()==quote.next_capacity and g.profile.reactorAllocation==quote.allocation,"Actual MAX capacity and integer allocation match preview")
 check(N.compare(g.profile.resources["2"],N.subtract(6.99e30,quote.cost))==0 and N.compare(g.reactor_multiplier("weapons"),quote.effects.weapons.next)==0,"Exact same price sum and effect used for payment and preview")
 check(I.compare(g.reactor_allocated(),g.reactor_capacity())==0,"Equalized full plan preserves exact total through MAX growth")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(g.portable_save_data()));var restored=BattleGame.new(db,false);restored.load_progress_data(saved)
 check(restored.reactor_capacity()==g.reactor_capacity() and restored.profile.reactorAllocation==g.profile.reactorAllocation,"Big integer units survive actual portable JSON reload")
 var old=g.profile.reactorAllocation.weapons
 check(g.set_reactor_allocation("weapons",I.subtract(old,50)) and I.subtract(old,g.profile.reactorAllocation.weapons)==50,"Step editing changes exactly50 beyond native integers")
 check(g.equalize_reactor_allocation() and g.reactor_allocated()==g.reactor_capacity(),"Integer equalization includes all remainder units")
 var limited=G.available(Array(g.reactor_modules()),g.profile.reactorAllocation,I.divmod(g.reactor_capacity(),2)[0]);var sum=0
 for v in limited.values():sum=I.add(sum,v)
 check(sum==I.divmod(g.reactor_capacity(),2)[0] and g.reactor_allocated()==g.reactor_capacity(),"Temporary large supply projects exact total without changing preset")
 g.reactor_multiplier("weapons");g.reactor_allocated();var operations:int=I.long_operations
 for i in 50:
  g.invalidate_stat_cache();g.reactor_capacity();g.reactor_allocated();g.reactor_multiplier("weapons");g.reactor_effective_ratio("weapons")
 check(I.long_operations==operations,"Hot reactor reads across battle-stat invalidation perform no large arithmetic")
 P.quote(g,1);P.quote(g,10);operations=I.long_operations
 for i in 20:
  g.profile.resources["2"]=N.add(g.profile.resources["2"],1)
  P.quote(g,1);P.quote(g,10)
 check(I.long_operations==operations,"Income-only refresh reuses cached integer upgrade previews")
 var preview_totals:Dictionary={"hangings":{"extra_storage":0.1}}
 g.reactor_active_allocation(preview_totals);g.reactor_allocated();operations=I.long_operations
 for i in 20:g.reactor_active_allocation(preview_totals);g.reactor_allocated()
 check(I.long_operations==operations,"Alternating live and presentation capacities reuse bounded exact allocation caches")
 g.profile.reactorLevel=5000;g.profile.reactorAllocation={"weapons":0,"defence":0,"smelting":0,"condensation":0};g.profile.resources["2"]={"m":1.0,"e":660}
 check(g.reactor_capacity() is String and N.valid(g.reactor_upgrade_cost()) and g.reactor_upgrade_cost() is Dictionary,"5000-level capacity and prices remain GrowthNumber-consistent")
 g.equalize_reactor_allocation();quote=P.quote(g,1)
 check(N.valid(g.reactor_multiplier("weapons")) and g.upgrade_reactor(1) and g.profile.reactorAllocation==quote.allocation,"5000-level effect and purchase still match preview")
 check(N.valid(g.equipment_stat("laser",1)) and N.valid(g.settle_jewel_fragments(1,"drop")),"Large effects flow into existing equipment and condensation number representation")
 var extreme_saved:Dictionary=JSON.parse_string(JSON.stringify(g.portable_save_data()))
 var extreme_restored=BattleGame.new(db,false);extreme_restored.load_progress_data(extreme_saved)
 check(preload("res://scripts/save_transfer.gd").new().prepare_data(extreme_saved,db).error.is_empty() and is_equal_approx(N.ratio(extreme_restored.profile.jewelFurnaceIncomePeak,g.profile.jewelFurnaceIncomePeak),1),"Large reactor-derived production peak survives portable validation and reload")
 var saved_level:int=int(g.profile.reactorLevel)
 g.profile.reactorLevel=floori((I.MAX_DIGITS-3)/log(1.2)*log(10.0))+1
 while g.reactor_can_grow(1):g.profile.reactorLevel+=1
 var guarded:Dictionary=g.portable_save_data();var guard_before:=JSON.stringify(g.profile);var guarded_quote:=P.quote(g,1)
 check(g.reactor_capacity()!=null and not g.upgrade_reactor(1) and g.profile.reactorLevel==guarded.reactorLevel and JSON.stringify(g.profile)==guard_before,"Digit boundary refuses purchase without spending or corrupting current capacity")
 guarded.reactorLevel+=1
 check(not preload("res://scripts/save_transfer.gd").new().prepare_data(guarded,db).error.is_empty(),"Unsupported capacity save is rejected before installation")
 g.profile.reactorLevel=saved_level
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var original=scene.game;scene.game=g;g.paused=true;scene.reactor_panel.host=scene;scene.refresh_tab_visibility();scene.select_system(2);await process_frame
 var panel=scene.reactor_panel;panel.refresh();var controls=panel.module_controls.weapons
 check(not panel.upgrade_buttons.x1.disabled and controls.slider.max_value==1 and controls.slider.get_meta("reactor_normalized",false),"Large energy UI uses normalized slider and live upgrade availability")
 check(panel.energy_label.text.length()<80 and not panel.energy_label.text.contains("inf") and panel.upgrade_buttons.x1.tooltip_text.length()<3000,"Large energy and purchase UI remain bounded and finite")
 old=g.profile.reactorAllocation.weapons;panel.step_allocation("weapons",-1)
 check(I.subtract(old,g.profile.reactorAllocation.weapons)==int(db.config.reactorAllocationStep),"Actual UI minus button preserves configured integer step")
 controls.input.apply_pointer(controls.input.size.x*0.25)
 check(I.compare(g.reactor_allocated(),g.reactor_capacity())<=0 and I.valid(g.profile.reactorAllocation.weapons),"Actual normalized pointer commits a valid integer allocation")
 scene.game=original;scene.queue_free();await process_frame
 # Cold extreme benchmark, not a frame loop or playtest.
 var extreme="7".repeat(I.MAX_DIGITS);var divisor="3".repeat(I.MAX_DIGITS);var begin:int=Time.get_ticks_usec()
 var division:=I.share(extreme,I.divmod(divisor,2)[0],divisor)
 print("MAX-digit cold share usec: ",Time.get_ticks_usec()-begin)
 check(I.compare(division[1],divisor)<0,"Configured extreme share keeps a legal remainder")
 print("REACTOR LARGE VALUES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
