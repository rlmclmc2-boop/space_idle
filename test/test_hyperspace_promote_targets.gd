extends SceneTree
const F=preload("res://scripts/drone_forge.gd")
const C=preload("res://scripts/hyperspace_config.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:
 var c=C.load_config()
 var d={"id":"promotion-target","weapon":"laser","ultimate":false,"legendary":false,"omen":false,"forge_revision":0,"forge_rng_state":"12345","affixes":[{"key":"global_damage","tier":1,"value":0.1,"locked":false},{"key":"global_damage","tier":2,"value":0.1,"locked":false}]}
 var req={"drone_id":d.id,"operation":"promote_affix","expected_revision":0,"args":{}}
 var base={"inventory":{"drones":{d.id:d},"sealed":{},"generation":0},"materials":{"antiproton":1000000},"ultimate_cores":0}
 var valid:=true
 for seed in range(1,33):
  var s=base.duplicate(true);var rng=RandomNumberGenerator.new();rng.seed=seed;s.inventory.drones[d.id].forge_rng_state=str(rng.state)
  var r=F.plan(s,c,req,null)
  valid=valid and r.error.is_empty() and int(r.get("index",-1))==1 and s.inventory.drones[d.id].affixes[0]==d.affixes[0]
 check(valid,"T1 must never block another eligible unlocked affix across32 seeds")
 for locked in [false,true]:
  var s=base.duplicate(true)
  s.inventory.drones[d.id].affixes[1].tier=1
  s.inventory.drones[d.id].affixes[1].locked=locked
  var before=JSON.stringify(s);var r=F.plan(s,c,req,null)
  check(r.error=="already_highest_tier" and JSON.stringify(s)==before,"No eligible grade returns clear error without charging or consuming RNG")
 var s=base.duplicate(true)
 for a in s.inventory.drones[d.id].affixes:a.locked=true
 var before=JSON.stringify(s);var r=F.plan(s,c,req,null)
 check(r.error=="no_unlocked_affix" and JSON.stringify(s)==before,"Locked-only drone preserves existing rejection")
 for attempts in [10,100]:
  var equivalent:=true
  for seed in range(1,13):
   var bulk=base.duplicate(true);var rng=RandomNumberGenerator.new();rng.seed=seed;bulk.inventory.drones[d.id].forge_rng_state=str(rng.state)
   var single=bulk.duplicate(true);var batch_req=req.duplicate(true);batch_req.args={"attempts":attempts}
   var batch=F.plan(bulk,c,batch_req,null);var spent:=0;var count:=0
   for attempt in attempts:
    if single.inventory.drones[d.id].affixes.all(func(a):return a.locked or int(a.tier)<=1):break
    var next=req.duplicate(true);next.expected_revision=single.inventory.drones[d.id].forge_revision
    var one=F.plan(single,c,next,null)
    if not one.error.is_empty():equivalent=false;break
    count+=1;spent+=int(one.cost.antiproton)
   equivalent=equivalent and batch.error.is_empty() and batch.draws==count and int(batch.cost.antiproton)==spent and bulk.inventory.drones[d.id]==single.inventory.drones[d.id] and bulk.materials==single.materials
  check(equivalent,"Batch matches repeated single attempts including RNG, costs and early stop: "+str(attempts))
 for invalid in [0,-1,2,10.5,"100"]:
  var state=base.duplicate(true);var original=JSON.stringify(state);var bad=req.duplicate(true);bad.args={"attempts":invalid}
  check(F.plan(state,c,bad,null).error=="invalid_arguments" and JSON.stringify(state)==original,"Reject invalid batch without mutations")
 var sure=c.duplicate(true);sure.tier_weights={"1":1.0}
 var state=base.duplicate(true);var many=req.duplicate(true);many.args={"attempts":100}
 var early=F.plan(state,sure,many,null)
 check(early.error.is_empty() and early.draws==1 and int(early.cost.antiproton)==int(c.forge_costs.promote_affix.antiproton)*int(c.material_unit_scale),"Stop after final T1 and charge only actual attempts")
 print("PROMOTION_TARGETS %d checks %d failures"%[checks,failures]);quit(1 if failures else 0)
