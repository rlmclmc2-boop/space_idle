extends "res://qa/wave_matrix.gd"
func run() -> void:
	var db=Database.new()
	var f=FileAccess.open("res://.runtime/pair-threshold.jsonl",FileAccess.WRITE)
	var count:=0
	for key in db.data.battle_design:
		var record:Dictionary=db.data.battle_design[key]
		if record.attack_variant!="physical_attack" or record.tier=="normal":continue
		var chosen:String={"physical":"cannon","energy":"longLaser"}.get(record.counter,record.counter)
		var weapons:Array=["laser","missile","cannon","longLaser"] if record.counter=="neutral" else [chosen]
		for weapon in weapons:
			for factor in [1.1,1.2,1.3,1.4,1.5,1.6]:
				for delta in [int(record.min_upgrade)-1,int(record.min_upgrade)]:
					var row:Dictionary=run_wave(record,weapon,delta,factor)
					row.merge({"key":key,"weapon":weapon,"delta":delta,"factor":factor,"seed":1701,"target":record.min_upgrade,"scope":"Private damage-factor diagnostic; not source change or progression"})
					f.store_line(JSON.stringify(row));f.flush();count+=1
		print("PAIR_GROUP ",key," rows=",count)
	f.close();print("PAIR_THRESHOLD_COMPLETE rows=",count);quit()
