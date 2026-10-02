extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Legacy=preload("res://scripts/balance_autoplayer.gd")
const Sparse=preload("res://qa/sparse_policy.gd")
func fixture():
 var g=Game.new(ShipDatabase.new())
 g.profile.highestLevel=8;g.profile.cleared=range(1,8);g.rebuild_unlocks();g.profile.jewelFragments=1000000
 g.start(8,false);return g
func _initialize():
 var a=fixture();var b=fixture();var before:int=a.profile.enhancementLevel
 var legacy=Legacy.new();legacy.configure("BALANCED",20261002)
 var sparse=Sparse.new();sparse.configure("BALANCED",20261002);sparse.allow_reforge=false
 a.metrics=preload("res://scripts/balance_metrics.gd").new();a.metrics.initialize(a)
 b.metrics=preload("res://scripts/balance_metrics.gd").new();b.metrics.initialize(b)
 legacy.act(a,41284.466);sparse.act(b,41284.466)
 assert(a.profile.enhancementLevel==before);assert(b.profile.enhancementLevel>before)
 assert(b.enhancement_branch_choice("weapons","proficiency",1)=="A")
 assert(b.enhancement_branch_choice("defence","adaptation",1)=="A")
 print("SPARSE_PHASE_PASS legacy_missed=",a.profile.enhancementLevel," corrected_bought=",b.profile.enhancementLevel," version=",Sparse.VERSION," branchA_verified=true scope=eligible fragments at restored clock remainder4; actual visit action")
 quit()
