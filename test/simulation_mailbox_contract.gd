extends SceneTree
const Mailbox=preload("res://scripts/simulation_render_mailbox.gd")
var box=Mailbox.new()
var consumed=0
var previous=0
func _initialize()->void:call_deferred("run")
func run()->void:
	var payload={"position":Vector2(3,4),"parts":[{"id":7}],"values":PackedFloat64Array([1.0,2.0])}
	assert(box.append_event(payload))
	payload.parts[0].id=8;payload.values[0]=9.0
	var event=box.drain_events()[0]
	assert(not payload.has("sequence"))
	assert(event.payload.parts[0].id==7 and event.payload.values[0]==1.0)
	assert(event.is_read_only() and event.payload.is_read_only() and event.payload.parts.is_read_only())
	var foreign=RefCounted.new()
	assert(not box.append_event({"foreign":foreign}))
	assert(box.enqueue_input("bad",[foreign])==-1)
	var slot=box.begin_write();assert(not box.publish(slot,{"foreign":foreign}))
	box.event_limit=2
	assert(box.append_event({"id":1}) and box.append_event({"id":2}))
	assert(not box.append_event({"id":3}))
	var events=box.drain_events();assert(events[1].sequence==events[0].sequence+1)
	assert(box.append_event({"id":3}));assert(box.drain_events()[0].sequence==events[1].sequence+1)
	slot=box.begin_write();assert(box.publish(slot,{"tick":1}))
	var lease=box.acquire_latest();assert(lease.frame.tick==1)
	for tick in range(2,10):
		slot=box.begin_write();assert(slot!=lease.slot);assert(box.publish(slot,{"tick":tick}))
	assert(lease.frame.tick==1)
	var newest=box.acquire_latest();assert(newest.frame.tick==9)
	box.release(newest.slot);box.release(lease.slot)
	box.event_limit=17
	previous=int(box.metrics().events)
	var worker=Thread.new();assert(worker.start(produce)==OK)
	while worker.is_alive() or consumed<1000:
		for row in box.drain_events():
			assert(row.sequence==previous+1);previous=row.sequence;consumed+=1
		var latest=box.acquire_latest()
		if not latest.is_empty():box.release(latest.slot)
		await process_frame
	worker.wait_to_finish()
	assert(consumed==1000)
	box.stop();assert(box.begin_write()==-1 and not box.append_event({}) and box.enqueue_input("late",[])==-1)
	print("SIMULATION_MAILBOX_CONTRACT_PASS events=1000; leased_frames_preserved; objects_rejected; payloads_detached")
	quit()
func produce()->void:
	for index in 1000:
		while not box.append_event({"id":index}):OS.delay_usec(100)
		var slot=box.begin_write()
		if slot>=0:assert(box.publish(slot,{"tick":index,"position":Vector2(index,0)}))
