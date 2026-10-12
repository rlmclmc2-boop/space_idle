extends RefCounted
## Three immutable frame slots plus independent lossless ordered event/input FIFOs.
## Slot replacement never discards events. Producer and consumer exchange ownership.
const FREE=0
const WRITING=1
const PUBLISHED=2
const READING=3
var mutex=Mutex.new()
var wake=Semaphore.new()
var acknowledgements:Dictionary={}
var owner_status:Dictionary={}
var frames:Array=[null,null,null]
var states:PackedInt32Array=PackedInt32Array([FREE,FREE,FREE])
var sequences:PackedInt64Array=PackedInt64Array([0,0,0])
var event_watermarks:PackedInt64Array=PackedInt64Array([0,0,0])
var events:Array=[]
var inputs:Array=[]
var event_limit:int=4096
var input_limit:int=256
var published_sequence:int=0
var event_sequence:int=0
var input_sequence:int=0
var dropped_snapshots:int=0
var event_backpressure:int=0
var publication_backpressure:int=0
var stopped:bool=false

func begin_write()->int:
	mutex.lock()
	if stopped:mutex.unlock();return -1
	var slot=-1
	for i in states.size():
		if states[i]==FREE:slot=i;break
	if slot<0:
		for i in states.size():
			if states[i]==PUBLISHED and (slot<0 or sequences[i]<sequences[slot]):slot=i
		if slot>=0:dropped_snapshots+=1
	if slot>=0:states[slot]=WRITING;frames[slot]=null
	else:publication_backpressure+=1
	mutex.unlock()
	return slot
func publish(slot:int,record)->bool:
	if not _is_value_packet(record):
		cancel_write(slot);return false
	var transferred=_freeze_value(record)
	mutex.lock()
	assert(states[slot]==WRITING)
	published_sequence+=1;sequences[slot]=published_sequence;event_watermarks[slot]=event_sequence
	frames[slot]=transferred;states[slot]=PUBLISHED
	mutex.unlock();return true
func acquire_latest()->Dictionary:
	mutex.lock();var result=_take_latest_locked();mutex.unlock();return result
func consume_bundle()->Dictionary:
	# One lock chooses both the event prefix and frame lease. The frame's event
	# watermark separates events before it from newer in-progress-step events.
	mutex.lock();var ordered=events;events=[]
	var lease=_take_latest_locked();mutex.unlock()
	if not ordered.is_empty() or not lease.is_empty():wake.post()
	return {"events":ordered,"snapshot":lease}
func _take_latest_locked()->Dictionary:
	var slot=-1
	for i in states.size():
		if states[i]==PUBLISHED and (slot<0 or sequences[i]>sequences[slot]):slot=i
	var result={}
	if slot>=0:
		states[slot]=READING
		result={"slot":slot,"sequence":sequences[slot],"frame":frames[slot],"event_watermark":event_watermarks[slot]}
		for i in states.size():
			if states[i]==PUBLISHED:states[i]=FREE;frames[i]=null;dropped_snapshots+=1
	return result
func release(slot:int)->void:
	mutex.lock();assert(states[slot]==READING)
	states[slot]=FREE;frames[slot]=null
	mutex.unlock();wake.post()
func append_event(record:Dictionary)->bool:
	if not _is_value_packet(record):return false
	var transferred:Dictionary=_freeze_value(record)
	mutex.lock()
	if stopped or events.size()>=event_limit:
		event_backpressure+=1;mutex.unlock();return false
	event_sequence+=1
	# Sequence belongs to the envelope; caller payload stays immutable.
	var envelope={"sequence":event_sequence,"payload":transferred}
	envelope.make_read_only();events.append(envelope)
	mutex.unlock();return true
func drain_events()->Array:
	mutex.lock();var result=events;events=[];mutex.unlock();return result
func enqueue_input(name:String,arguments:Array)->int:
	if not _is_value_packet(arguments):return -1
	var transferred:Array=_freeze_value(arguments)
	mutex.lock()
	if stopped or inputs.size()>=input_limit:mutex.unlock();return -1
	input_sequence+=1
	var envelope={"sequence":input_sequence,"name":name,"arguments":transferred,"queued_us":Time.get_ticks_usec()}
	envelope.make_read_only();inputs.append(envelope)
	var result=input_sequence;mutex.unlock();return result
func drain_inputs()->Array:
	mutex.lock();var result=inputs;inputs=[];mutex.unlock();return result
func stop()->void:
	mutex.lock();stopped=true;mutex.unlock()
func should_stop()->bool:
	mutex.lock();var value=stopped;mutex.unlock();return value
func metrics()->Dictionary:
	mutex.lock()
	var result={"published":published_sequence,"events":event_sequence,"inputs":input_sequence,"dropped_snapshots":dropped_snapshots,"event_backpressure":event_backpressure,"publication_backpressure":publication_backpressure}
	mutex.unlock();return result

func _freeze_value(value:Variant,depth:int=0)->Variant:
	# Only boundary packets are copied. BattleGame/Profile are never transferable.
	# The depth limit rejects cycles instead of traversing a mutable object graph.
	assert(depth<32,"Cyclic or excessively nested cross-thread packet")
	match typeof(value):
		TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID:
			assert(false,"Cross-thread packets must contain values and stable IDs only")
			return null
		TYPE_DICTIONARY:
			var result={}
			for key in value:
				assert(typeof(key) in [TYPE_STRING,TYPE_STRING_NAME,TYPE_INT],"Packet keys must be stable scalar IDs")
				result[key]=_freeze_value(value[key],depth+1)
			result.make_read_only()
			return result
		TYPE_ARRAY:
			var result=[]
			for element in value:result.append(_freeze_value(element,depth+1))
			result.make_read_only()
			return result
		TYPE_PACKED_BYTE_ARRAY,TYPE_PACKED_INT32_ARRAY,TYPE_PACKED_INT64_ARRAY,TYPE_PACKED_FLOAT32_ARRAY,TYPE_PACKED_FLOAT64_ARRAY,TYPE_PACKED_STRING_ARRAY,TYPE_PACKED_VECTOR2_ARRAY,TYPE_PACKED_VECTOR3_ARRAY,TYPE_PACKED_COLOR_ARRAY,TYPE_PACKED_VECTOR4_ARRAY:
			# Packed arrays use copy-on-write; detached ownership prevents producer writes.
			return value.duplicate()
		_:return value

func cancel_write(slot:int)->void:
	mutex.lock();assert(states[slot]==WRITING)
	states[slot]=FREE;frames[slot]=null;mutex.unlock()

func _is_value_packet(value:Variant,depth:int=0)->bool:
	if depth>=32:return false
	match typeof(value):
		TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID:return false
		TYPE_DICTIONARY:
			for key in value:
				if not typeof(key) in [TYPE_STRING,TYPE_STRING_NAME,TYPE_INT]:return false
				if not _is_value_packet(value[key],depth+1):return false
		TYPE_ARRAY:
			for element in value:
				if not _is_value_packet(element,depth+1):return false
	return true

func append_owned_event(record:Dictionary)->bool:
	# Simulation publisher-only ownership transfer: every nested value was newly
	# constructed from IDs/scalars. Generic/foreign callers use append_event.
	# Seal rather than recursively copy a second time; producer relinquishes writes.
	mutex.lock()
	if stopped or events.size()>=event_limit:event_backpressure+=1;mutex.unlock();return false
	mutex.unlock()
	if not _seal_owned(record):
		push_error("Owned event contains an uncompiled mutable object");return false
	mutex.lock()
	# Recheck after sealing: a foreign producer may enqueue through append_event.
	# On rejection the owner retains the sealed packet and retries without loss.
	if stopped or events.size()>=event_limit:event_backpressure+=1;mutex.unlock();return false
	event_sequence+=1;var envelope={"sequence":event_sequence,"payload":record}
	envelope.make_read_only();events.append(envelope);mutex.unlock();return true

func publish_owned(slot:int,record:Dictionary)->bool:
	if not _seal_owned(record):
		push_error("Owned frame contains an uncompiled mutable object");cancel_write(slot);return false
	mutex.lock();assert(states[slot]==WRITING)
	published_sequence+=1;sequences[slot]=published_sequence;event_watermarks[slot]=event_sequence
	frames[slot]=record;states[slot]=PUBLISHED;mutex.unlock();return true

func _seal_owned(value:Variant,depth:int=0)->bool:
	if depth>=32:return false
	match typeof(value):
		TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID:return false
		TYPE_DICTIONARY:
			for key in value:
				if not typeof(key) in [TYPE_STRING,TYPE_STRING_NAME,TYPE_INT] or not _seal_owned(value[key],depth+1):return false
			if not value.is_read_only():value.make_read_only()
		TYPE_ARRAY:
			for member in value:
				if not _seal_owned(member,depth+1):return false
			if not value.is_read_only():value.make_read_only()
	return true

func publish_ack(record:Dictionary)->void:
	var value=_freeze_value(record)
	mutex.lock();acknowledgements[int(record.sequence)]=value;mutex.unlock()
func take_ack(sequence:int)->Dictionary:
	mutex.lock();var value:Dictionary=acknowledgements.get(sequence,{})
	acknowledgements.erase(sequence);mutex.unlock();return value
func publish_owner_status(record:Dictionary)->void:
	var value=_freeze_value(record)
	mutex.lock();owner_status=value;mutex.unlock()
func read_owner_status()->Dictionary:
	mutex.lock();var value=owner_status.duplicate(true);mutex.unlock();return value
