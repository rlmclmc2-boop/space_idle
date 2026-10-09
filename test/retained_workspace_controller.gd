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
var pending_bands = [0,1,2,3]
var active_band = -1
var band_rects = []
var valid_bands = {}
var capture_enabled = true
const MIN_QUIET_US = 1000000
var quiet_us = MIN_QUIET_US
var last_dirty_us = 0
var retained_since_us = 0
var preparation_us = 0
var backoffs = 0
var allocations = {}
var allocation_capture = false
var attempts_since_retained = 0
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
 signature = layout_signature(); last_dirty_frame = Engine.get_process_frames();last_dirty_us = Time.get_ticks_usec()
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
  var redraw = Callable(self,"invalidate_draw").bind(weakref(node))
  node.draw.connect(redraw);connections.append([weakref(node),&"draw",redraw])
  connect_dirty(node,&"item_rect_changed")
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

func invalidate_draw(reference):
 var node = reference.get_ref()
 if node == null or not node is Control or band_rects.size() != caches.size():
  invalidate();return
 # Layout changes use full invalidation. Only a redraw at unchanged geometry can
 # reuse other native strips. Conservative padding includes theme borders/shadows.
 var pixels = view.get_stretch_transform() * view.canvas_transform
 var bounds = node.get_global_rect()
 var affected = Rect2(pixels*bounds.position,(pixels*bounds.end)-(pixels*bounds.position)).grow(32)
 var bands = []
 for index in band_rects.size():
  if affected.intersects(Rect2(band_rects[index])):bands.append(index)
 invalidate_bands(bands)

func invalidate(_value = null):
 invalidate_bands([0,1,2,3])

func invalidate_bands(bands):
 if not active: return
 var now = Time.get_ticks_usec()
 # If the retained interval cannot repay even a conservative preparation bound,
 # wait for a longer quiet interval instead of repeatedly spending on snapshots.
 if retained:
  fallback_count += 1
  if now-retained_since_us < max(500000,preparation_us*4):
   quiet_us = max(1000000,preparation_us*4);backoffs += 1
  else:quiet_us = MIN_QUIET_US
 elif attempts_since_retained > 0:
  # A source update interrupted preparation. Stop speculative recapture while
  # changes continue, including before the first complete snapshot.
  quiet_us = max(1000000,preparation_us*4);backoffs += 1
  attempts_since_retained = 0
 for index in bands:valid_bands.erase(index)
 pending_bands.clear()
 for index in caches.size():
  if not valid_bands.has(index):pending_bands.append(index)
 generation += 1;last_dirty_frame = Engine.get_process_frames();last_dirty_us = now
 retained = false;output.visible = false;view.canvas_cull_mask = original_mask

func set_capture_enabled(enabled: bool):
 capture_enabled = enabled
 invalidate()

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
 if not capture_enabled or retained or capturing or Engine.get_process_frames() <= last_dirty_frame + 1: return
 if Time.get_ticks_usec()-last_dirty_us < quiet_us: return
 var pixels = view.get_stretch_transform() * view.canvas_transform
 var bounds = source.get_global_rect(); var start = pixels * bounds.position; var end = pixels * bounds.end
 var rect = Rect2i(Vector2i(floor(start.x),floor(start.y)),Vector2i(ceil(end.x)-floor(start.x),ceil(end.y)-floor(start.y))).intersection(Rect2i(Vector2i.ZERO,view.size))
 if rect.size.x < 1 or rect.size.y < 1: return
 if rect != capture_rect or band_rects.is_empty():
  capture_rect = rect;valid_bands.clear();pending_bands = [0,1,2,3];band_rects.clear()
  for index in caches.size():
   var top = rect.position.y + rect.size.y*index/caches.size()
   var bottom = rect.position.y + rect.size.y*(index+1)/caches.size()
   band_rects.append(Rect2i(rect.position.x,top,rect.size.x,bottom-top))
  allocations.clear()
 if pending_bands.is_empty():
  view.canvas_cull_mask = original_mask & ~CACHE_BIT
  output.visible = true;retained = true;retained_since_us = Time.get_ticks_usec();attempts_since_retained = 0
  return
 active_band = pending_bands[0]
 var band_rect = band_rects[active_band]
 var band = caches[active_band];var quad = outputs[active_band]
 band.size = band_rect.size
 band.canvas_transform = Transform2D(0,Vector2(-band_rect.position)) * pixels
 var ui_pixels = pixels * host.ui.get_global_transform_with_canvas()
 quad.position = ui_pixels.affine_inverse()*Vector2(band_rect.position)
 quad.size = Vector2(band_rect.size)/Vector2(ui_pixels.x.length(),ui_pixels.y.length())
 # Allocate/clear each framebuffer separately, with source Canvas culled. Account
 # for these frames too; they are preparation, not hidden benchmark warmup.
 allocation_capture = not allocations.has(active_band)
 band.canvas_cull_mask = 0 if allocation_capture else CACHE_BIT
 if pending_bands.size() == caches.size() and not allocation_capture:preparation_us = 0
 capturing = true;capture_generation = generation;capture_started = Time.get_ticks_usec()
 band.render_target_update_mode = SubViewport.UPDATE_ONCE

func after_draw():
 if not active or not capturing: return
 var elapsed = Time.get_ticks_usec()-capture_started
 capture_times.append({"us":elapsed,"allocation":allocation_capture,"band":active_band})
 preparation_us += elapsed;attempts_since_retained += 1
 capturing = false
 for band in caches:band.render_target_update_mode = SubViewport.UPDATE_DISABLED
 if allocation_capture:
  allocations[active_band] = true
  return
 if capture_generation != generation or layout_signature() != signature:return
 valid_bands[active_band] = true
 pending_bands.erase(active_band)
 if not pending_bands.is_empty():return
 view.canvas_cull_mask = original_mask & ~CACHE_BIT
 output.visible = true;retained = true;retained_since_us = Time.get_ticks_usec();attempts_since_retained = 0

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
