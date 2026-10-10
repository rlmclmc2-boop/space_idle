extends SceneTree
var checks=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:printerr(label);quit(1);assert(ok)
func _initialize():
 var db=ShipDatabase.new()
 var g=BattleGame.new(db,false)
 var Binder=preload("res://scripts/hyperspace_reward_binding.gd")
 var View=preload("res://scripts/hyperspace_encounter_database.gd")
 var Validator=preload("res://scripts/candidate_rewards.gd")
 var binder=Binder.new();check(binder.load_contract(),"Real frozen reward contract loads")
 check(g.load_hyperspace_routes(),"Load actual production route registry: "+g.manual_hyperspace.last_error)
 check(not g.manual_hyperspace.registry.is_empty(),"Real production registry exists")
 var native_refs=db.levels[13].rewardReferenceGroups.duplicate(true)
 var canonical=View.new();canonical.configure(db,14,[30146])
 check(canonical.levels[13].rewardReferenceGroups==native_refs,"No external registry: canonical reference retained")
 var ordinary={"groups":{"810000":db.groups["34146"].duplicate(true)},"enemies":db.enemies}
 var legacy=View.new();legacy.configure(db,14,[810000],ordinary)
 check(legacy.levels[13].rewardReferenceGroups.is_empty(),"Nonempty registry without reference field: no main references leak")
 check(legacy.levels[13].groups.size()==1 and not legacy.groups.has("34146"),"No implicit main wave or reference group copied into separate registry")
 check(Validator.binding_error("810000",legacy.groups,legacy.enemies,legacy.levels,14,legacy.ratio(14,0,"resRatio"),legacy.ratio(14,0,"jewelRatio")).is_empty(),"Legacy independent fleet needs no main budget")
 for selected in [12,14]:
  var bound=binder.bind(db,g.manual_hyperspace.registry,selected,14)
  check(not bound.is_empty(),"Production binder follows validated legacy14 budgets: "+binder.last_error)
  check(bound.has("rewardReferenceGroups"),"Production registry provides own references")
  var ids=g.manual_hyperspace.route_ids.values()[0]
  var view=View.new();view.configure(db,selected,ids,bound)
  check(view.levels[selected-1].rewardReferenceGroups==bound.rewardReferenceGroups,"Explicit registry references used exactly, without merging main references")
  check(view.levels[selected-1].groups.size()==ids.size(),"Reference budgets never become extra playable waves")
  check(view.ratio(selected,0,"resRatio")==float(db.levels[13].resRatio) and view.ratio(selected,0,"jewelRatio")==float(db.levels[13].jewelRatio),"Independent registry retains its resource reference level")
  for id in ids:
   check(Validator.binding_error(str(int(id)),view.groups,view.enemies,view.levels,selected,view.ratio(selected,0,"resRatio"),view.ratio(selected,0,"jewelRatio")).is_empty(),"Each actual route wave consumes one valid source budget")
  var missing=bound.duplicate();missing.erase("rewardReferenceGroups")
  var fail_closed=View.new();fail_closed.configure(db,selected,ids,missing)
  check(fail_closed.levels[selected-1].rewardReferenceGroups.is_empty(),"Missing registry field cannot fall back to canonical main references")
 check(db.levels[13].rewardReferenceGroups==native_refs,"Disposable binding leaves mainline references unchanged")
 print("WAVE_REWARD_ISOLATION ",checks," checks passed");quit()
