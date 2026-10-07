extends SceneTree
const F=preload("res://scripts/drone_forge.gd")
const C=preload("res://scripts/hyperspace_config.gd")
var failures=0
func check(ok,label):
 print("CHECK ",ok," ",label)
 if not ok:failures+=1
func _initialize():
 var c=C.load_config()
 var d={"id":"fixture","weapon":"laser","ultimate":false,"legendary":false,"omen":true,"forge_revision":0,"forge_rng_state":"12345","affixes":[{"key":"global_damage","tier":2,"value":0.1,"locked":false},{"key":"global_damage","tier":4,"value":0.1,"locked":false},{"key":"global_damage","tier":5,"value":0.1,"locked":false}]}
 check(F.eligible_indices(d,c)==[0,1,2],"lock and promotion candidate set ignores omen")
 check(F.eligible_indices(d,c,true)==[2],"replacement targets worst available tier")
 d.affixes[2].locked=true
 check(F.eligible_indices(d,c)==[0,1],"locked affixes excluded from uniform candidate set")
 check(F.eligible_indices(d,c,true)==[1],"replacement respects lock then worst tier")
 d.affixes[2].locked=false
 var all_match=true;var hits={}
 for op in ["lock_affix","promote_affix"]:
  for seed in range(1,49):
   var drone=d.duplicate(true);var rng=RandomNumberGenerator.new();rng.seed=seed;drone.forge_rng_state=str(rng.state)
   var s={"inventory":{"drones":{"fixture":drone},"sealed":{},"generation":0},"materials":{"glueball":1000000,"antiproton":1000000},"ultimate_cores":10}
   var other=s.duplicate(true);other.inventory.drones.fixture.omen=false
   var request={"drone_id":"fixture","operation":op,"expected_revision":0,"args":{}}
   var a=F.plan(s,c,request,null);var b=F.plan(other,c,request,null)
   all_match=all_match and a.error.is_empty() and a==b and s.inventory.drones.fixture.affixes==other.inventory.drones.fixture.affixes
   if op=="lock_affix":hits[a.index]=true
 check(all_match,"96 actual paired plans have identical outcomes/costs/RNG with omen on and off")
 check(hits.size()==3,"actual lock draws reach every unlocked tier")
 print("OMEN_SCOPE failures=",failures);quit(failures)
