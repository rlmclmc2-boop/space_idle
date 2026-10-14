extends SceneTree
const Bus=preload("res://scripts/game_events.gd")
class Harness extends RefCounted:
 signal plain(kind,payload)
 var bus=Bus.new()
 var typed=false
 var trace=[]
 var irrelevant=0
 var changed=false
 func add(cb,kinds=[]):
  if typed:bus.subscribe(cb,kinds)
  else:plain.connect(cb)
 func remove(cb):
  if typed:bus.unsubscribe(cb)
  else:plain.disconnect(cb)
 func publish(kind,payload={}):
  if typed:bus.emit(kind,payload)
  else:plain.emit(kind,payload)
 func first(kind,payload):
  if kind!="alpha":irrelevant+=1;return
  trace.append("first:"+kind)
  payload.changed=true
  if not changed:
   changed=true;remove(last);add(added,["alpha"])
   publish("beta",{})
 func middle(kind,payload):trace.append("middle:"+kind+":"+str(payload.get("changed",false)))
 func last(kind,_payload):
  if kind!="alpha":irrelevant+=1;return
  trace.append("last:"+kind)
 func added(kind,_payload):
  if kind!="alpha":irrelevant+=1;return
  trace.append("added:"+kind)
 func beta(kind,_payload):
  if kind!="beta":irrelevant+=1;return
  trace.append("beta:"+kind)
 func run():
  add(first,["alpha"]);add(middle);add(last,["alpha"]);add(beta,["beta"])
  publish("alpha",{});publish("alpha",{});publish("beta",{});publish("new_kind",{})
  remove(middle);add(middle);publish("alpha",{})
  return trace
class Receiver extends Node:
 var calls=0
 func receive(_kind,_payload):calls+=1
func _initialize():call_deferred("run")
func run():
 var original=Harness.new();var candidate=Harness.new();candidate.typed=true
 assert(original.run()==candidate.run(),"registration order, nested emit and connection changes differ")
 assert(candidate.irrelevant==0 and original.irrelevant>0,"typed publication must avoid irrelevant callbacks")
 var bus=Bus.new();var node=Receiver.new();var cb=node.receive
 bus.subscribe(cb,["alpha"]);bus.emit("beta",{});assert(node.calls==0)
 bus.emit("alpha",{});assert(node.calls==1);node.free()
 bus.emit("alpha",{});bus.emit("new",{});assert(bus.get_connections().is_empty())
 var replacement=Receiver.new();bus.subscribe(replacement.receive,["alpha"])
 bus.emit("alpha",{});assert(replacement.calls==1)
 bus.unsubscribe(replacement.receive);bus.emit("alpha",{});assert(replacement.calls==1)
 replacement.free()
 print("GAME_EVENTS_OK order/reentry/mutation/connect/disconnect/freed/reconnect; irrelevant=",candidate.irrelevant," original=",original.irrelevant)
 quit()
