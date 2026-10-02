extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Legacy=preload("res://scripts/balance_autoplayer.gd")
const Sparse=preload("res://qa/sparse_policy.gd")
func fixture():
 var g=Game.new(ShipDatabase.new())
 g.profile.highestLevel=8;g.profile.cleared=range(1,8);g.rebuild_unlocks();g.profile.jewelFragments=100000
 g.start(8,false);return g
func _initialize():
 var a=fixture();var b=fixture();var before:int=a.profile.enhancementLevel
 var legacy=Legacy.new();legacy.configure("BALANCED",20261002)
 var sparse=Sparse.new();sparse.configure("BALANCED",20261002);sparse.allow_reforge=false
 a.metrics=preload("res://scripts/balance_metrics.gd").new();a.metrics.initialize(a)
 b.metrics=preload("res://scripts/balance_metrics.gd").new();b.metrics.initialize(b)
 legacy.act(a,41284.466);sparse.act(b,41284.466)
 assert(a.profile.enhancementLevel==before);assert(b.profile.enhancementLevel>before)
 print("SPARSE_PHASE_PASS legacy_missed=",a.profile.enhancementLevel," corrected_bought=",b.profile.enhancementLevel," version=",Sparse.VERSION," scope=eligible fragments at restored clock remainder4; actual visit action")
 quit()
