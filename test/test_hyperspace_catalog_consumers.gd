extends SceneTree
const C=preload("res://scripts/hyperspace_config.gd")
const Loader=preload("res://scripts/hyperspace_route_loader.gd")
const Binder=preload("res://scripts/hyperspace_reward_binding.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1:printerr("Pass reward fixture JSON path");quit(1);return
	var fixture=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var g:=BattleGame.new(ShipDatabase.new(),false)
	check(g.startup_error.is_empty(),"formal default pack boots before fixture edits")
	if not g.startup_error.is_empty():quit(1);return
	for edit in fixture.mainline_edits:g.db.enemies[str(int(edit.enemy_id))].drops[int(edit.drop_index)].amount=float(edit.amount)
	var loader:=Loader.new();var registry:=loader.load_files(g)
	check(not registry.is_empty(),"production loader uses separate registry")
	var binder:=Binder.new();check(binder.load_contract(),"production reward contract read")
	binder.catalog=fixture.catalog.references
	for probe in fixture.cases:
		var bound:=binder.bind(g.db,registry,7,int(probe.resource_level))
		check(not bound.is_empty(),str(probe.label)+" valid real binding "+binder.last_error)
		if bound.is_empty():continue
		var groups:Array=registry.groups.keys().filter(func(id):return registry.groups[id].rewardBinding.rewardReferenceDesignId==probe.reference_id)
		check(groups.size()==1,"one actual candidate group for reference")
		var group:Dictionary=bound.groups[groups[0]];var member:Dictionary=binder.recipes[groups[0]][0]
		var enemy:Dictionary=bound.enemies[str(int(member.enemy_id))]
		check(is_equal_approx(float(enemy.drops[0].amount),float(probe.first_amount)) and is_equal_approx(float(enemy.drops[0].chance),float(probe.first_chance)),str(probe.label)+" real drop receipt")
		check((int(group.rewardBinding.referenceGroupId)<900000000)==bool(probe.matched),str(probe.label)+" correct matched/fallback branch")
	print("HYPERSPACE_CATALOG_CONSUMERS ",checks," checks ",failures," failures")
	quit(1 if failures else 0)
