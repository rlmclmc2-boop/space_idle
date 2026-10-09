extends SceneTree
const I=preload("res://scripts/reactor_integer.gd")
const T=preload("res://scripts/save_transfer.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 check(I.valid("100000000000000000000") and not I.valid("01") and not I.valid("1e20") and not I.valid("-1"),"Canonical bounded unsigned storage rejects alternate notation")
 check(I.add("99999999999999999999",1)=="100000000000000000000","Carry across native integer range")
 check(I.subtract("100000000000000000000",1)=="99999999999999999999","Exact single-unit subtraction beyond floating precision")
 check(I.multiply("12345678901234567890",12345)=="152407406035740740602050","Multi-limb multiplication")
 var q:Array=I.divmod("152407406035740740602051",12345)
 check(q==["12345678901234567890",1],"Division and remainder preserve the last unit")
 q=I.divmod("100000000000000000000000000000000000000", "333333333333333333333")
 check(I.add(I.multiply(q[0],"333333333333333333333"),q[1])=="100000000000000000000000000000000000000" and I.compare(q[1],"333333333333333333333")<0,"Large divisor Euclidean identity")
 check(I.encode(9007199254740993)=="9007199254740993" and I.normalize(JSON.parse_string(JSON.stringify(I.encode(9007199254740993))))==9007199254740993,"JSON preserves native integers beyond double precision")
 check(T.shape({"reactorIntegerVersion":1,"reactorAllocation":{"weapons":"100000000000000000000"}},T.schema()),"Portable schema transports reactor integer strings")
 check(not T.shape({"reactorAllocation":{"weapons":"9".repeat(I.MAX_DIGITS+1)}},T.schema()),"Excessive persisted digits rejected before arithmetic")
 check(I.compare(I.from_growth(GrowthNumber.power(1.2,215)),0)>0 and I.from_growth({"m":1.2,"e":I.MAX_DIGITS})==null,"Growth conversion is bounded without overflowing a native integer")
 var huge:String="1"+"0".repeat(999);var begin:int=Time.get_ticks_usec()
 q=I.divmod(I.multiply(huge,3),7)
 check(I.add(I.multiply(q[0],7),q[1])==I.multiply(huge,3),"1000-digit exact arithmetic identity")
 print("1000-digit arithmetic usec: ",Time.get_ticks_usec()-begin)
 check(I.as_growth(huge).e==999 and I.ratio(huge,I.multiply(huge,2))==0.5,"Compact conversion and ratios do not expand UI text")
 var arithmetic_rng:=RandomNumberGenerator.new();arithmetic_rng.seed=5215
 var identities:=true
 for index in 80:
  var divisor:=str(arithmetic_rng.randi_range(1,9999))+"0123456789".repeat(arithmetic_rng.randi_range(2,25))
  var quotient=I.normalize(str(arithmetic_rng.randi_range(1,9999))+"8765432109".repeat(arithmetic_rng.randi_range(0,20)))
  var remainder:int=arithmetic_rng.randi_range(0,9999)
  var numerator=I.add(I.multiply(divisor,quotient),remainder)
  var actual:=I.divmod(numerator,divisor)
  identities=identities and actual[0]==quotient and actual[1]==remainder
 check(identities,"Seeded multi-limb quotient estimates preserve known quotient and remainder")
 var db=ShipDatabase.new();var game=BattleGame.new(db,false)
 game.profile.highestLevel=20;game.profile.cleared=range(1,20);game.rebuild_unlocks();game.profile.reactorLevel=215;game.profile.reactorAllocation.weapons=9007199254740993
 var exported:Dictionary=game.portable_save_data();var parsed:Dictionary=JSON.parse_string(JSON.stringify(exported))
 check(parsed.reactorAllocation.weapons=="9007199254740993" and parsed.reactorIntegerVersion==1,"Real portable snapshot encodes exact reactor units without mutating live integers")
 var restored=BattleGame.new(db,false);restored.load_progress_data(parsed)
 check(restored.profile.reactorAllocation.weapons==9007199254740993 and game.profile.reactorAllocation.weapons==9007199254740993,"Real loader round-trips the final unit above double precision")
 check(T.new().prepare_data(parsed,db).error.is_empty(),"Portable import validation accepts the encoded checkpoint")
 print("REACTOR INTEGER: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
