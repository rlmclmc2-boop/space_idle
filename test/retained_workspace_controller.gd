extends Node
# Opt-in diagnostic controller. No production integration or default enable.
# Original controls own input, state and drawing. Only quiet equipment raster is retained.
const CACHE_BIT = 1 << 19
var source: TabContainer
var host: Node2D
var view: Window
var cache: SubViewport
var output: Control
var caches = []
var outputs = []
var next_band = 0
var capture_rect = Rect2i()
var layers = []
var connections = []
var watched = {}
var scrollbars = []
var generation = 0
var last_dirty_frame = 0
var capturing = false
var retained = false
var capture_generation = -1
var capture_started = 0
var capture_times = []
var fallback_count = 0
var original_mask = 0
var signature = []
var active = false

func setup(scene: Node2D) -> bool:
 host = scene; source = scene.equipment_tabs; view = source.get_viewport()
 original_mask = view.canvas_cull_mask
 # Reserved bit must not already be used by this subtree.
 if not reserve(source): return false
 var parent = source.get_parent()
 while parent is CanvasItem:
  layers.append([weakref(parent),parent.visibility_layer])
  parent.visibility_layer |= CACHE_BIT
  parent = parent.get_parent()
 output = Control.new(); output.name = "WorkspaceRasterOutput"
 output.mouse_filter = Control.MOUSE_FILTER_IGNORE; output.visible = false
 scene.ui.add_child(output)
 var material = CanvasItemMaterial.new()
 material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
 material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
 for index in 4:
  var band = SubViewport.new(); band.name = "WorkspaceRasterBand" + str(index)
  band.disable_3d = true; band.transparent_bg = true
  band.world_2d = view.find_world_2d(); band.canvas_cull_mask = CACHE_BIT
  band.render_target_update_mode = SubViewport.UPDATE_DISABLED; add_child(band)
  caches.append(band)
  var quad = TextureRect.new(); quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
  quad.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
  quad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  quad.visibility_layer = original_mask & ~CACHE_BIT
  quad.texture = band.get_texture(); quad.material = material; output.add_child(quad)
  outputs.append(quad)
 cache = caches[0]
 watch(source)
 signature = layout_signature(); last_dirty_frame = Engine.get_process_frames()
 active = true
 RenderingServer.frame_pre_draw.connect(before_draw)
 RenderingServer.frame_post_draw.connect(after_draw)
 return true

func reserve(node: Node) -> bool:
 if node is Viewport: return true
 if node is CanvasItem and (node.visibility_layer & CACHE_BIT) != 0: return false
 for child in node.get_children(true):
  if not reserve(child): return false
 return true

func connect_dirty(node: Node, signal_name: StringName):
 var callback = Callable(self,"invalidate")
 node.connect(signal_name,callback)
 connections.append([weakref(node),signal_name,callback])

func watch(node: Node):
 if node is Viewport or watched.has(node.get_instance_id()): return
 watched[node.get_instance_id()] = true
 if node is CanvasItem:
  layers.append([weakref(node),node.visibility_layer]); node.visibility_layer = CACHE_BIT
  connect_dirty(node,&"draw"); connect_dirty(node,&"item_rect_changed")
  connect_dirty(node,&"visibility_changed")
 if node is ScrollBar:
  scrollbars.append(weakref(node));connect_dirty(node,&"value_changed")
 var callback = Callable(self,"child_added")
 node.child_entered_tree.connect(callback)
 connections.append([weakref(node),&"child_entered_tree",callback])
 var leaving = Callable(self,"child_removed")
 node.child_exiting_tree.connect(leaving)
 connections.append([weakref(node),&"child_exiting_tree",leaving])
 for child in node.get_children(true): watch(child)

func child_added(child: Node):
 watch(child); invalidate()

func child_removed(child: Node):
 unwatch(child);invalidate()

func unwatch(node: Node):
 if not watched.has(node.get_instance_id()): return
 for child in node.get_children(true): unwatch(child)
 watched.erase(node.get_instance_id())
 for index in range(connections.size()-1,-1,-1):
  var entry = connections[index]
  if entry[0].get_ref() == node:
   if node.is_connected(entry[1],entry[2]): node.disconnect(entry[1],entry[2])
   connections.remove_at(index)
 for index in range(layers.size()-1,-1,-1):
  if layers[index][0].get_ref() == node:
   node.visibility_layer = layers[index][1];layers.remove_at(index)

func supports_scroll() -> bool:
 # Godot shared-World capture has a one-pixel clipping difference for overflow
 # ScrollContainers at fractional stretch. Such regions must stay fully live.
 for reference in scrollbars:
  var bar = reference.get_ref()
  if bar != null and bar.is_visible_in_tree() and bar.max_value > bar.page: return false
 return true

func invalidate(_value = null):
 if not active: return
 next_band = 0
 generation += 1; last_dirty_frame = Engine.get_process_frames()
 if retained: fallback_count += 1
 retained = false; output.visible = false; view.canvas_cull_mask = original_mask

func layout_signature() -> Array:
 return [source.current_tab,source.is_visible_in_tree(),source.get_global_rect(),
  view.size,view.get_stretch_transform(),view.canvas_transform,
  host.ui.get_global_transform_with_canvas(),host.equipment_panel.detail.status.modulate,supports_scroll()]

func before_draw():
 if not active: return
 var current = layout_signature()
 if current != signature:
  signature = current; invalidate()
 if source.current_tab != 0 or not source.is_visible_in_tree() or not supports_scroll():
  if retained: invalidate()
  return
 if retained or capturing or Engine.get_process_frames() <= last_dirty_frame + 1: return
 var pixels = view.get_stretch_transform() * view.canvas_transform
 var bounds = source.get_global_rect(); var start = pixels * bounds.position; var end = pixels * bounds.end
 var rect = Rect2i(Vector2i(floor(start.x),floor(start.y)),Vector2i(ceil(end.x)-floor(start.x),ceil(end.y)-floor(start.y))).intersection(Rect2i(Vector2i.ZERO,view.size))
 if rect.size.x < 1 or rect.size.y < 1: return
 # Each native-pixel strip is prepared on a separate quiet frame. Originals stay live
 # until all strips share one unchanged generation, so no partial/stale UI is shown.
 if next_band == 0: capture_rect = rect
 elif rect != capture_rect: invalidate(); return
 var top = rect.position.y + rect.size.y * next_band / caches.size()
 var bottom = rect.position.y + rect.size.y * (next_band+1) / caches.size()
 var band_rect = Rect2i(rect.position.x,top,rect.size.x,bottom-top)
 var band = caches[next_band]; var quad = outputs[next_band]
 band.size = band_rect.size
 band.canvas_transform = Transform2D(0,Vector2(-band_rect.position)) * pixels
 var ui_pixels = pixels * host.ui.get_global_transform_with_canvas()
 quad.position = ui_pixels.affine_inverse() * Vector2(band_rect.position)
 quad.size = Vector2(band_rect.size) / Vector2(ui_pixels.x.length(),ui_pixels.y.length())
 capturing = true; capture_generation = generation; capture_started = Time.get_ticks_usec()
 band.render_target_update_mode = SubViewport.UPDATE_ONCE

func after_draw():
 if not active or not capturing: return
 capture_times.append(Time.get_ticks_usec()-capture_started)
 capturing = false
 for band in caches: band.render_target_update_mode = SubViewport.UPDATE_DISABLED
 if capture_generation != generation or layout_signature() != signature: return
 next_band += 1
 if next_band < caches.size(): return
 view.canvas_cull_mask = original_mask & ~CACHE_BIT
 output.visible = true; retained = true

func shutdown():
 if not active: return
 active = false
 RenderingServer.frame_pre_draw.disconnect(before_draw)
 RenderingServer.frame_post_draw.disconnect(after_draw)
 view.canvas_cull_mask = original_mask
 for entry in connections:
  var node = entry[0].get_ref()
  if node != null and node.is_connected(entry[1],entry[2]): node.disconnect(entry[1],entry[2])
 for entry in layers:
  var node = entry[0].get_ref()
  if node != null: node.visibility_layer = entry[1]
 output.queue_free()
 for band in caches: band.queue_free()

func _exit_tree():
 shutdown()
