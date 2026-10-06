extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Permission=preload("res://scripts/hyperspace_permissions.gd")
var checks:=0
var failures:=0
var receipts:Array=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(with_affix:bool=false):
	# Isolated transaction fixtures, never a campaign save or a pacing result.
	var g=BattleGame.new(ShipDatabase.new(),false);g.save_enabled=false
	g.profile.highestLevel=25;g.profile.cleared=range(1,25);g.rebuild_unlocks()
	var c:Dictionary=g.hyperspace.config
	g.profile.hyperspace.history={"alpha":{"20":1.0,"40":1.0},"beta":{"24":1.0}}
	g.profile.hyperspace.materials[c.routes.alpha.material]=1000
	g.profile.hyperspace.ultimate_cores=1
	var rng:=RandomNumberGenerator.new();rng.seed=12345
	var d:Dictionary=Rewards.create_drone(rng,c,"price-fixture","blue" if with_affix else "white",str(c.routes.alpha.weapon),5,Permission.planet_for_level(g.db.data,5))
	d.affixes=[]
	if with_affix:
		for key in c.affixes:
			var row:Dictionary=c.affixes[key]
			if (row.weapon.is_empty() or row.weapon==d.weapon) and row.ranges.has("5"):
				d.affixes.append({"key":key,"tier":5,"value":row.ranges["5"][0],"locked":false});break
		assert(d.affixes.size()==1)
	assert(Bag.insert(g.profile.hyperspace.inventory,d,c))
	return g
func request(g,op:String,args:Dictionary={})->Dictionary:
	return {"round_id":g.profile.hyperspace.round_id,"command_seq":g.profile.hyperspace.command_seq,"drone_id":"price-fixture","operation":op,"args":args,"expected_revision":g.profile.hyperspace.inventory.drones["price-fixture"].forge_revision}
func purchase(g,expected:int,label:String)->void:
	var h=g.hyperspace;var material:String=h.config.routes.alpha.material
	var command:Dictionary=request(g,"modernize")
	var before:Dictionary=g.profile.hyperspace.duplicate(true)
	var preview:Dictionary=h.preview_forge(g,command)
	check(preview.error.is_empty() and int(preview.cost.get(material,-1))==expected,label+" production quote")
	check(g.profile.hyperspace==before,label+" preview is nonmutating")
	var paid:Dictionary=h.forge(g,command)
	check(paid.error.is_empty() and paid.cost==preview.cost,label+" production command matches quote")
	check(int(before.materials[material])-int(g.profile.hyperspace.materials[material])==expected,label+" actual material debit")
	check(int(g.profile.hyperspace.inventory.drones["price-fixture"].level)==20,label+" highest cleared alpha record within round cap")
	var after:Dictionary=g.profile.hyperspace.duplicate(true)
	var replay:Dictionary=h.forge(g,command)
	check(replay.error.is_empty() and int(replay.cost.get(material,-1))==expected and g.profile.hyperspace==after,label+" replay does not charge twice")
	receipts.append({"case":label,"quote":preview,"result":paid,"material_before":before.materials[material],"material_after":after.materials[material]})
func _initialize()->void:
	# Authoritative Excel-derived configuration: base10, step3, start5, T5 weight0.5.
	var empty=fixture();purchase(empty,60,"zero affixes baseline1")
	var affixed=fixture(true);purchase(affixed,90,"one T5 affix baseline1 plus0.5")
	var rounded=fixture(true);rounded.profile.hyperspace.history.alpha={"21":1.0,"40":1.0}
	var rounded_quote:Dictionary=rounded.hyperspace.preview_forge(rounded,request(rounded,"modernize"))
	check(rounded_quote.error.is_empty() and int(rounded_quote.cost.get(rounded.hyperspace.config.routes.alpha.material,-1))==100,"raw95 retains nearest base10 rounding")
	var short=fixture();var material:String=short.hyperspace.config.routes.alpha.material
	short.profile.hyperspace.materials[material]=59;var baseline:Dictionary=short.profile.hyperspace.duplicate(true)
	check(short.hyperspace.forge(short,request(short,"modernize")).error=="insufficient_materials" and short.profile.hyperspace==baseline,"insufficient base fee rolls back level/materials/private RNG/command")
	check(short.hyperspace.preview_forge(short,request(short,"modernize",{"target_level":40})).error=="stale_modernization_target","record above round cap cannot be requested")
	check(short.hyperspace.preview_forge(short,request(short,"modernize",{"target_level":24})).error=="stale_modernization_target","beta record cannot substitute for alpha record")
	var capped=fixture();capped.profile.highestLevel=19
	check(capped.hyperspace.preview_forge(capped,request(capped,"modernize")).error=="no_new_record","no eligible recorded route level below cap remains rejected")
	var ultimate=fixture();var h=ultimate.hyperspace
	# Fund the existing restoration price; this test does not waive it.
	for key in h.config.forge_costs.restore_ultimate:
		if key=="ultimate_cores":ultimate.profile.hyperspace.ultimate_cores+=int(h.config.forge_costs.restore_ultimate[key])
		else:ultimate.profile.hyperspace.materials[key]+=int(h.config.forge_costs.restore_ultimate[key])
	check(h.forge(ultimate,request(ultimate,"ultimate")).error.is_empty(),"production ultimate conversion fixture")
	var ultimate_before:Dictionary=ultimate.profile.hyperspace.duplicate(true)
	check(h.preview_forge(ultimate,request(ultimate,"modernize")).error=="ultimate_modification_forbidden" and ultimate.profile.hyperspace==ultimate_before,"ultimate must be restored before modernization")
	check(h.forge(ultimate,request(ultimate,"restore_ultimate")).error.is_empty(),"production restore ultimate command")
	check(h.preview_forge(ultimate,request(ultimate,"modernize")).error.is_empty(),"modernization reenabled after real restoration")
	print("MODERNIZATION_RECEIPTS ",JSON.stringify(receipts))
	print("MODERNIZATION_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
