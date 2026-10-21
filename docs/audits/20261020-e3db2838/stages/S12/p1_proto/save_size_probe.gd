extends SceneTree

# Audit-only construction of a retained, schema-shaped resourceSamples field.
# This does not invoke a live game or claim full portable-save acceptance.
func _initialize() -> void:
	var now := Time.get_unix_time_from_system()
	var production_now := 1000.0
	var source: Array = []
	var sample := {"time":now - 1.0,"production_time":999.0,"id":"1","amount":1,"production_base":1,"origin":"drop"}
	for i in 200000:
		source.append(sample.duplicate(true))
	# Same portable_save_data filter: either wall-time or production-time window.
	var retained := source.filter(func(item):return float(item.time)>now-60.0 or (item.has("production_time") and float(item.production_time)>production_now-60.0)).duplicate(true)
	var encoded := JSON.stringify({"resourceSamples":retained}, "\t")
	var bytes := encoded.to_utf8_buffer()
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(bytes)
	print(JSON.stringify({"kind":"exploratory_retained_save_field","now_bits":bits(now),"production_now":production_now,"input_samples":source.size(),"retained_samples":retained.size(),"first_sample":sample,"field_only_bytes":bytes.size(),"portable_limit_bytes":16*1024*1024,"field_sha256":hasher.finish().hex_encode()}))
	quit(0 if retained.size()==200000 and bytes.size()>16*1024*1024 else 1)

func bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0,value)
	return "%016x" % bytes.decode_u64(0)
