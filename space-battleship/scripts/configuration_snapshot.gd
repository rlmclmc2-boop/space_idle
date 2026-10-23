extends RefCounted
## Complete immutable input generation. Consumers parse captured bytes only.
## Not activated until every supported publisher/reader is wired to this owner.
static var current:RefCounted
var identity := ""
var error := ""
var _files:Dictionary = {}
const MANIFEST := "res://.configuration.json"

static func activate()->RefCounted:
 var snapshot=load("res://scripts/configuration_snapshot.gd").new()
 snapshot.capture()
 current=snapshot
 return snapshot

static func active()->RefCounted:
 if current==null:return activate()
 return current

static func text(path:String)->String:
 return active().read_bytes(path).get_string_from_utf8()

func read_bytes(path:String)->PackedByteArray:
 if not error.is_empty():return PackedByteArray()
 var name:=path.trim_prefix("res://")
 if not _files.has(name):
  push_error("Configuration snapshot member missing: "+name)
  return PackedByteArray()
 return _files[name].duplicate()

func json(path:String)->Variant:
 return JSON.parse_string(read_bytes(path).get_string_from_utf8())

func capture()->bool:
 _files={};identity="";error=""
 var lease:RefCounted
 # Exported player resources are a frozen package. Source/tools use the same
 # root lock as Python publishers; never lock by a UI-selected alias spelling.
 if OS.has_feature("editor"):
  lease=ClassDB.instantiate("SpaceSaveLock")
  if lease==null:error="configuration_lock_unavailable";return false
  var root:String=lease.canonical_path(ProjectSettings.globalize_path("res://"))
  if root.is_empty() or not lease.acquire(root.path_join(".configuration-lock")):
   error="configuration_busy";return false
  if FileAccess.file_exists("res://.configuration-transaction.json"):
   error="configuration_recovery_required";return false
 var manifest_bytes:=FileAccess.get_file_as_bytes(MANIFEST)
 var manifest=JSON.parse_string(manifest_bytes.get_string_from_utf8())
 if not manifest is Dictionary or manifest.get("version")!=1 or not manifest.get("files") is Dictionary or manifest.files.is_empty():
  error="configuration_manifest_required";return false
 var captured:Dictionary={}
 for name in manifest.files:
  if not name is String or name.contains("..") or name.contains("\\") or name.contains(":") or not (name.begins_with("data/") or name.begins_with("config_excel/")):
   error="invalid_configuration_member";return false
  var expected=manifest.files[name]
  if not expected is Dictionary or not expected.get("sha256") is String or not expected.has("size"):
   error="invalid_configuration_manifest";return false
  var bytes:=FileAccess.get_file_as_bytes("res://"+name)
  if not FileAccess.file_exists("res://"+name) or bytes.size()!=int(expected.size) or sha256(bytes)!=expected.sha256:
   error="configuration_generation_mismatch:"+name;return false
  captured[name]=bytes
 # Releasing the root lock is safe now: later source replacement cannot alter
 # these byte arrays or the generation identity used by consumer caches.
 _files=captured;identity=sha256(manifest_bytes)
 return true

static func sha256(bytes:PackedByteArray)->String:
 var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
 return hash.finish().hex_encode()

func workbook_path(path:String)->String:
 var bytes:=read_bytes(path)
 if bytes.is_empty():return ""
 var directory:="user://configuration-workbooks"
 if DirAccess.make_dir_recursive_absolute(directory)!=OK:return ""
 var target:=directory.path_join(sha256(bytes)+".xlsx")
 if FileAccess.file_exists(target):
  if FileAccess.get_file_as_bytes(target)!=bytes:return ""
 else:
  var file:=FileAccess.open(target,FileAccess.WRITE)
  if file==null:return ""
  file.store_buffer(bytes);file.flush()
  if file.get_error()!=OK:file.close();return ""
  file.close()
 return ProjectSettings.globalize_path(target)
