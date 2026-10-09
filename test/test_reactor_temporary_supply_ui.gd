extends SceneTree
const Preview=preload("res://scripts/reactor_upgrade_preview.gd")
const Growth=preload("res://scripts/reactor_allocation_growth.gd")
class ActiveFixture extends BattleGame:
 var limited:=false
 var edit_key:=""
 var edit_value:=0.0
 func reactor_capacity(_totals:Dictionary={}) -> int:return 75 if limited else 100
 func reactor_energy(level:=-1,_totals:Dictionary={}) -> float:return float(reactor_capacity())*pow(1.2,0 if level<0 else level-1)
 func reactor_capacity_at(level:int,_totals:Dictionary={}):return preload("res://scripts/reactor_growth.gd").capacity(reactor_energy(level))
 func reactor_active_allocation(_totals:Dictionary={}) -> Dictionary:return {"weapons":38,"defence":22,"smelting":15,"condensation":0} if limited else profile.reactorAllocation.duplicate()
 func reactor_allocated() -> int:
  var total:=0
  for value in reactor_active_allocation().values():total+=int(value)
  return total
 func reactor_effective_ratio(key:String) -> float:return float(reactor_active_allocation().get(key,0))/reactor_capacity()+charge_free_ratio() if reactor_module_unlocked(key) else 0.0
 func reactor_multiplier(key:String,_totals:Dictionary={}) -> float:
  var energy:=float(reactor_active_allocation().get(key,0))+reactor_capacity()*charge_free_ratio()
  return 1.0+pow(energy,float(db.config.reactorBoostExponent))/float(db.config.reactorPercentScale) if energy>0 and reactor_module_unlocked(key) else 1.0
 func set_reactor_allocation(key:String,value:float) -> bool:edit_key=key;edit_value=value;return true
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false)
 var old_game=scene.game
 var g=ActiveFixture.new(scene.db,false);g.save_enabled=false;g.paused=true;g.profile.cleared=range(1,20);g.profile.highestLevel=20;g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 g.profile.reactorAllocation={"weapons":50,"defence":30,"smelting":20,"condensation":0};g.profile.resources["2"]=1000000
 scene.game=g
 var p=scene.reactor_panel;p.host=scene;scene.refresh_tab_visibility();scene.select_system(2);await process_frame;p.refresh()
 check(p.module_controls.weapons.energy.text==UIText.t("reactor.flow.manual",{"amount":"50","capacity":"100"}),"Normal capacity retains the existing manual-energy display")
 var before:=JSON.stringify(g.profile);var rng_before:int=g.rng.state
 g.limited=true;p.on_game_event("hyperspace_rebuild",{});check(p.dirty,"Actual disable event invalidates the panel without adding a new polling loop")
 p.refresh_pending(0)
 var weapon=p.module_controls.weapons
 check(weapon.slider.value==38 and weapon.track.ratio==38.0/75.0 and p.remaining_label.text==UIText.t("reactor.remaining",{"energy":"0"}),"Slider, track and remaining use actual allocation without a negative pool")
 check(weapon.energy.text==UIText.t("reactor.flow.preset_active",{"preset":"50","active":"38"}),"Module readout distinguishes preserved preset from effective integers")
 check(p.allocation_hint.text==UIText.t("reactor.temporary_supply") and p.allocation_hint.tooltip_text.contains(UIText.t("reactor.temporary_rearrange")) and p.allocation_hint.mouse_filter==Control.MOUSE_FILTER_PASS,"Short temporary hint has a usable explicit-operation tooltip")
 check(weapon.row.tooltip_text.contains(UIText.t("reactor.temporary_rearrange")) and p.upgrade_buttons.x1.tooltip_text.contains(UIText.t("reactor.temporary_rearrange")),"Module and purchase previews explain when the saved preset is replaced")
 var quote:Dictionary=Preview.quote(g,1);var expected:Dictionary=Growth.expand(Array(g.reactor_modules()),g.reactor_active_allocation(),75,90)
 check(quote.capacity==75 and quote.next_capacity==90 and quote.allocation==expected and int(quote.allocation.weapons)==46,"Upgrade grows the effective38/22/15 baseline to46/26/18 rather than the overallocated preset")
 check(is_equal_approx(quote.effects.weapons.current,g.reactor_multiplier("weapons")) and is_equal_approx(quote.effects.weapons.next,1+pow(46.0+90*g.charge_free_ratio(),float(g.db.config.reactorBoostExponent))/float(g.db.config.reactorPercentScale)),"Current and next multipliers correspond to effective supply")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before and g.edit_key.is_empty(),"Refresh and quotation never normalize or write the saved preset")
 p.step_allocation("weapons",-1)
 check(g.edit_key=="weapons" and g.edit_value==maxi(0,38-int(scene.db.config.reactorAllocationStep)),"Explicit step starts at the visible effective38 instead of saved50")
 g.limited=false;p.on_game_event("hyperspace_drone_restored",{});check(p.dirty,"Actual restoration event invalidates the panel")
 p.refresh_pending(0)
 check(weapon.slider.value==50 and weapon.energy.text==UIText.t("reactor.flow.manual",{"amount":"50","capacity":"100"}) and p.allocation_hint.text!=UIText.t("reactor.temporary_supply"),"Restoration displays the original preset and clears the temporary explanation")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"Restoration readout leaves the original plan and RNG intact")
 scene.game=old_game;scene.queue_free();await process_frame
 print("REACTOR TEMPORARY SUPPLY UI: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
