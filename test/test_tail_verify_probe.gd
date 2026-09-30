extends SceneTree
# CPU/readback attribution only, run through verify_tail_candidate.py in isolation.
func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
func _initialize() -> void:
	var data := ("{\"value\":\""+"a".repeat(31000)+"\"}").to_utf8_buffer()
	var path := ProjectSettings.globalize_path("res://.runtime/verify-probe.json")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(data)
	file.close()
	var rows := {}
	print("USER_DIR ",OS.get_user_data_dir())
	print("WRITE_PATH ",path)
	print("GLOBALIZED_USER_PATH ",ProjectSettings.globalize_path("user://progress.json"))
	var read := FileAccess.get_file_as_bytes(path)
	var read_variant: Variant=read
	for method in ["read", "packed_equal", "variant_equal", "inline_read_equal", "typed_read_equal", "inline_read_unequal", "hex_equal", "sha_equal"]:
		var start := Time.get_ticks_usec()
		var passed := true
		for i in 100:
			match method:
				"read":read=FileAccess.get_file_as_bytes(path)
				"packed_equal":passed=passed and read==data
				"variant_equal":passed=passed and read_variant==data
				"inline_read_equal":passed=passed and FileAccess.get_file_as_bytes(path)==data
				"typed_read_equal":
					var verified: PackedByteArray=FileAccess.get_file_as_bytes(path)
					passed=passed and verified==data
				"inline_read_unequal":passed=passed and not FileAccess.get_file_as_bytes(path)!=data
				"hex_equal":passed=passed and read.hex_encode()==data.hex_encode()
				"sha_equal":passed=passed and digest(read)==digest(data)
		rows[method]={"avg_ms":float(Time.get_ticks_usec()-start)/100000.0,"passed":passed}
	FileAccess.open("res://.runtime/verify-probe-results.json",FileAccess.WRITE).store_string(JSON.stringify(rows))
	var user_path := ProjectSettings.globalize_path("user://tail-verify-probe.json.tmp")
	var user_file := FileAccess.open(user_path,FileAccess.WRITE)
	user_file.store_buffer(data)
	user_file.close()
	var user_started := Time.get_ticks_usec()
	for i in 100:
		var actual := FileAccess.get_file_as_bytes(user_path)
		assert(actual==data)
	rows.user_read={"avg_ms":float(Time.get_ticks_usec()-user_started)/100000.0}
	var thread := Thread.new()
	thread.start(worker_probe.bind(user_path,data))
	rows.worker_read=thread.wait_to_finish()
	for method in ["roundtrip_after_close", "roundtrip_same_handle"]:
		var started := Time.get_ticks_usec()
		for i in 100:
			var stream := FileAccess.open(user_path,FileAccess.WRITE if method=="roundtrip_after_close" else FileAccess.WRITE_READ)
			stream.store_buffer(data)
			stream.flush()
			if method=="roundtrip_after_close":
				stream.close()
				assert(FileAccess.get_file_as_bytes(user_path)==data)
			else:
				stream.seek(0)
				assert(stream.get_buffer(data.size())==data)
				stream.close()
		rows[method]={"avg_ms":float(Time.get_ticks_usec()-started)/100000.0}
	FileAccess.open("res://.runtime/verify-probe-results.json",FileAccess.WRITE).store_string(JSON.stringify(rows))
	print(JSON.stringify(rows))
	quit()
func worker_probe(path: String, data: PackedByteArray) -> Dictionary:
	var start := Time.get_ticks_usec()
	for i in 100:
		var actual := FileAccess.get_file_as_bytes(path)
		assert(actual==data)
	return {"avg_ms":float(Time.get_ticks_usec()-start)/100000.0}
