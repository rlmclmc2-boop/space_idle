extends RefCounted
## Synchronous install/completion boundary. Preparation remains in each use case.
const Result=preload("res://scripts/command_result.gd")
const N=preload("res://scripts/growth_number.gd")
var active := false
var _before: Array=[]
var _reactor_revision:=0

func begin(g) -> bool:
	if active:return false
	active=true
	_before=g.attributes.configuration_inputs(g)
	_reactor_revision=g.reactor.revision
	return true

func abort(reason: String, status := "blocked") -> Dictionary:
	active=false
	_before=[]
	return Result.make(status,reason)

func settle_progress(g, configuration: bool, defence: Dictionary) -> void:
	if not configuration:return
	# Capacity is authoritative before descriptors and refit health are finalized.
	g.reactor.reconcile_capacity(g.reactor_capacity())
	g.configuration_committed()
	if defence.keys().any(func(key):return N.compare(defence[key],g.stat(key))!=0):g.apply_refit_health()

func finish(g, domains: Array, resources: Array, slots: Array, facts: Dictionary, notices: Array) -> Dictionary:
	assert(active)
	if g.reactor.revision!=_reactor_revision:
		domains=domains.duplicate()
		if not domains.has("reactor"):domains.append("reactor")
		facts=facts.duplicate(true)
		facts.reactor_allocation_changed=true
	var result:=Result.make("committed","",domains,resources,slots,facts,{"before":_before,"after":g.attributes.configuration_inputs(g)})
	g.save_dirty=true
	# Business consumers see the complete commit before any UI observer runs.
	g.crew.on_committed(g,result)
	for notice in notices:
		var payload: Dictionary=notice.payload.duplicate(true)
		# Mixed migrated/unmigrated resource/reactor events retain a narrow bridge.
		payload._committed_fact=true
		Result.freeze(payload)
		g.event.emit(str(notice.kind),payload)
	active=false
	_before=[]
	return result
