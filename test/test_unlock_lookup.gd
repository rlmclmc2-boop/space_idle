extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func scan(db,kind:String,key:String)->String:
 for id in db.data.get("unlock",{}):
  var row=db.data.unlock[id]
  if row.type==kind and row.target==key:return str(id)
 return ""
func _initialize()->void:
 var db=ShipDatabase.new()
 for row in db.data.unlock.values():
  for repeat in 2:check(db.unlock_id(row.type,row.target)==scan(db,row.type,row.target),"lookup agrees with authored first match")
 var g=BattleGame.new(db,false)
 var id=db.unlock_id("feature","jewels")
 g.profile.cleared=[];g.profile.grantedUnlocks=[]
 var row=db.data.unlock[id];var original_level=row.level
 row.level=999999
 check(not g.jewels_unlocked(),"cached identity does not cache availability")
 row.level=0
 check(g.jewels_unlocked(),"edited gate takes effect immediately")
 row.level=original_level
 var original=db.data.unlock.duplicate(true)
 db.data.unlock.erase(id)
 check(db.unlock_id("feature","jewels").is_empty(),"removed ID cannot remain cached")
 db.data.unlock["replacement"]=row
 check(db.unlock_id("feature","jewels")=="replacement","new source row is discovered after missing query")
 row.target="temporary"
 check(db.unlock_id("feature","jewels").is_empty() and db.unlock_id("feature","temporary")=="replacement","renamed source target invalidates old lookup")
 db.data.unlock=original
 check(db.unlock_id("feature","jewels")==id and db.unlock_id("feature","temporary").is_empty(),"table replacement resolves live identities")
 var before=db.unlock_lookup.duplicate(true)
 for i in 1000:db.unlock_id("unknown",str(i))
 check(db.unlock_lookup==before,"unknown queries retain no cache entries")
 db.data.unlock={}
 for i in 160:db.data.unlock[str(i)]={"type":"feature","target":str(i),"level":0}
 for i in 160:check(db.unlock_id("feature",str(i))==str(i),"large alternate source remains correct")
 check(db.unlock_lookup.feature.size()<=128,"one source-kind lookup remains bounded")
 print("UNLOCK LOOKUP: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
