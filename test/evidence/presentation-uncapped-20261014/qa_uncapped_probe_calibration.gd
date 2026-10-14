extends SceneTree
const Gate=preload("res://strip_gate.gd")
func _initialize()->void:
 Gate.sampled=true;Gate.profiling=true
 var start:=Time.get_ticks_usec()
 for i in 20000:
  var stamp=Gate.begin();Gate.end(stamp,"noop")
 var elapsed:=Time.get_ticks_usec()-start
 var row={"calls":20000,"elapsed_us":elapsed,"us_per_pair":float(elapsed)/20000.0,"note":"Empty begin/end record calibration only; does not include all function wrapper, frame sampling, render-query or serialization overhead. Never subtract as claimed savings."}
 FileAccess.open("res://.runtime/uncapped-probe-calibration.json",FileAccess.WRITE).store_string(JSON.stringify(row))
 print("STRIP_PROBE ",row.us_per_pair);quit()
