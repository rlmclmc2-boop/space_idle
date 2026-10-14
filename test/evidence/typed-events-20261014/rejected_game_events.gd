extends RefCounted
## Game owns this subscription table. Godot owns signal ordering/reentrant delivery.
## Empty kinds means all events; typed subscriptions never receive other kinds.
var listeners:Array=[]
var channels:Dictionary={}
func subscribe(callback:Callable,kinds:Array=[])->Error:
 if has_subscription(callback):return ERR_INVALID_PARAMETER
 listeners=listeners.filter(func(row):return row.callable.is_valid())
 var row={"callable":callback,"kinds":kinds.duplicate()}
 listeners.append(row)
 for kind in channels:
  if kinds.is_empty() or kinds.has(kind):channels[kind].connect(callback)
 return OK
func unsubscribe(callback:Callable)->void:
 for kind in channels:
  if channels[kind].is_connected(callback):channels[kind].disconnect(callback)
 listeners=listeners.filter(func(row):return row.callable!=callback and row.callable.is_valid())
func has_subscription(callback:Callable)->bool:
 for row in listeners:
  if row.callable==callback:return callback.is_valid()
 return false
func get_connections()->Array:
 var result=[]
 for row in listeners:
  if row.callable.is_valid():result.append({"callable":row.callable,"flags":0})
 return result
func emit(kind:String,payload:Dictionary)->void:
 if not channels.has(kind):
  var name=StringName("event_"+str(channels.size()))
  add_user_signal(name,[{"name":"kind","type":TYPE_STRING},{"name":"payload","type":TYPE_DICTIONARY}])
  var channel=Signal(self,name)
  for row in listeners:
   if row.callable.is_valid() and (row.kinds.is_empty() or row.kinds.has(kind)):channel.connect(row.callable)
  channels[kind]=channel
 channels[kind].emit(kind,payload)
