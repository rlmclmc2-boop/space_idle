extends RefCounted
## Draw-only opt-in sampler. Original textures remain geometry/profile authority.
var enabled := OS.get_environment("SPACE_IDLE_ENEMY_HULL_MIPMAPS") == "1"
var entries: Dictionary = {}

func texture_for(source: Texture2D) -> Texture2D:
	if not enabled or source == null:return source
	# Atlas/depth/normal/flat-compositor textures are outside this candidate.
	if not source is CompressedTexture2D and not source is ImageTexture:return source
	var id := source.get_instance_id()
	if entries.has(id):return entries[id].texture
	# Cache failures too; never retry image extraction on every draw.
	entries[id] = {"source":source,"texture":source}
	var changed := _invalidate.bind(id)
	if not source.changed.is_connected(changed):source.changed.connect(changed)
	var pixels := source.get_image()
	if pixels == null or pixels.is_empty():return source
	var diffuse: Texture2D = source
	if not pixels.has_mipmaps():
		if pixels.is_compressed() and pixels.decompress() != OK:return source
		# Adds smaller levels; leaves the full-resolution level intact. Runs once
		# per source, normally in prepare_enemy_hulls(), never per enemy/frame.
		if pixels.generate_mipmaps() != OK:return source
		diffuse = ImageTexture.create_from_image(pixels)
	var sampler := CanvasTexture.new()
	sampler.diffuse_texture = diffuse
	sampler.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	entries[id].texture = sampler
	return sampler

func _invalidate(id: int) -> void:
	entries.erase(id)
