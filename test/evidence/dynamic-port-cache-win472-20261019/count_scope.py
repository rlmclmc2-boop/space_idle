"""QA-only query/build/allocation counters; no time measurement or work removal."""
def once(text,old,new):
    if text.count(old)!=1:raise RuntimeError('Unexpected source anchor: '+old)
    return text.replace(old,new,1)
def pose(text):
    text=once(text,'extends RefCounted\n','extends RefCounted\nvar qa_port_queries:=0\nvar qa_port_builds:=0\n')
    text=once(text,'func screen_presentation_muzzles_for_slot(slot:int)->PackedVector2Array:\n',
        'func screen_presentation_muzzles_for_slot(slot:int)->PackedVector2Array:\n\tif preload("res://probe.gd").active:qa_port_queries+=1\n')
    text=once(text,'func _project_presentation_muzzles(module:Dictionary,art:Dictionary,root:Transform3D)->PackedVector2Array:\n',
        'func _project_presentation_muzzles(module:Dictionary,art:Dictionary,root:Transform3D)->PackedVector2Array:\n\tif preload("res://probe.gd").active:qa_port_builds+=1\n')
    return text
def session(text):
    text=once(text,'extends RefCounted\n','extends RefCounted\nvar qa_port_rows_rebuilt:=0\n')
    return once(text,'\t\tif ports_changed:\n\t\t\tpresentation_muzzles.resize(weapons.size())',
        '\t\tif ports_changed:\n\t\t\tif preload("res://probe.gd").active:qa_port_rows_rebuilt+=1\n\t\t\tpresentation_muzzles.resize(weapons.size())')
def driver(text):
    return once(text,'row.runtime_config_end=config(scene)',
        'row.qa_cache_counts={"queries":scene.battle_slice_runtime.geometry.fleet_pose.qa_port_queries,"builds":scene.battle_slice_runtime.geometry.fleet_pose.qa_port_builds,"row_rebuilds":g.native_execution.qa_port_rows_rebuilt}\n row.runtime_config_end=config(scene)')
