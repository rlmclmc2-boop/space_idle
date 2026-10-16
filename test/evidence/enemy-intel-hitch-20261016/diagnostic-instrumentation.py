from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[3]
project = root / 'test/work/enemy-intel-perf-20261016/candidate/space-battleship'
page = project / 'scripts/enemy_intel_page.gd'
source = subprocess.check_output(['git','show','3aa52c25:space-battleship/scripts/enemy_intel_page.gd'],cwd=root).decode('utf-8')
source = source.replace('var heading: Label\n', 'var heading: Label\nvar timing: Dictionary = {}\n')
source = source.replace('route_builds += 1\n', 'var t0 := Time.get_ticks_usec()\n\troute_builds += 1\n')
source = source.replace('for child in list.get_children():child.queue_free()\n', '# DIAG\n\ttiming.route_projection_us = Time.get_ticks_usec()-t0\n\tvar t_buttons := Time.get_ticks_usec()\n\tfor child in list.get_children():child.queue_free()\n')
source = source.replace('show_entry(0 if not entries.is_empty() else -1)\n', 'timing.buttons_us = Time.get_ticks_usec()-t_buttons\n\tshow_entry(0 if not entries.is_empty() else -1)\n\ttiming.route_total_us = Time.get_ticks_usec()-t0\n')
source = source.replace('for index in entries.size():\n', 'timing.old_buttons_us = Time.get_ticks_usec()-t_buttons\n\tvar t_add := Time.get_ticks_usec()\n\tfor index in entries.size():\n')
source = source.replace('timing.buttons_us = Time.get_ticks_usec()-t_buttons\n\tshow_entry', 'timing.new_buttons_us = Time.get_ticks_usec()-t_add\n\ttiming.button_count = entries.size()\n\ttiming.buttons_us = Time.get_ticks_usec()-t_buttons\n\tshow_entry')
source = source.replace('detail_builds += 1\n', 'var t0 := Time.get_ticks_usec()\n\tdetail_builds += 1\n')
source = source.replace('var image := TextureRect.new()\n', 'timing.detail_clear_us = Time.get_ticks_usec()-t0\n\tvar t_image := Time.get_ticks_usec()\n\tvar image := TextureRect.new()\n')
source = source.replace('detail.add_child(image)\n', 'detail.add_child(image)\n\ttiming.texture_us = Time.get_ticks_usec()-t_image\n\tvar t_labels := Time.get_ticks_usec()\n')
source = source.replace('var health = host.db.enemy_encounter_capacity(row,stage,point,"health")', 'var t_capacity := Time.get_ticks_usec()\n\tvar health = host.db.enemy_encounter_capacity(row,stage,point,"health")')
source = source.replace('var attacks: Dictionary = {}', 'timing.capacity_us = Time.get_ticks_usec()-t_capacity\n\tvar attacks: Dictionary = {}')
source = source.replace('\nfunc resistance_text(value: int)', '\n\ttiming.labels_us = Time.get_ticks_usec()-t_labels\n\ttiming.detail_total_us = Time.get_ticks_usec()-t0\n\nfunc resistance_text(value: int)')
page.write_text(source,encoding='utf-8')
driver = project / 'port_perf.gd'
source = driver.read_text(encoding='utf-8')
source = source.replace('intel_probe.first_build_sync_us=Time.get_ticks_usec()-opening_us', 'intel_probe.first_build_sync_us=Time.get_ticks_usec()-opening_us\n  intel_probe.first_page_timing=scene.enemy_intel_page.timing.duplicate(true)')
source = source.replace('scene.select_system(0)\n  scene.select_system(11)', 'scene.select_system(0)\n  intel_probe.switch_to_equipment_us=Time.get_ticks_usec()-reopen_us\n  var t_back:int=Time.get_ticks_usec()\n  scene.select_system(11)\n  intel_probe.switch_back_to_intel_us=Time.get_ticks_usec()-t_back')
source = source.replace('intel_probe.reopen_sync_us=Time.get_ticks_usec()-reopen_us', 'intel_probe.reopen_sync_us=Time.get_ticks_usec()-reopen_us\n  intel_probe.reopen_page_timing=scene.enemy_intel_page.timing.duplicate(true)')
source = source.replace('intel_probe.stage_switch_sync_us=Time.get_ticks_usec()-switch_us', 'intel_probe.stage_switch_sync_us=Time.get_ticks_usec()-switch_us\n  intel_probe.stage_page_timing=scene.enemy_intel_page.timing.duplicate(true)')
source = source.replace('intel_probe.final_compile_delta=g.compiled_combat_rules.builds-compiled_before', 'intel_probe.final_compile_delta=g.compiled_combat_rules.builds-compiled_before\n  intel_probe.final_refresh_delta=scene.equipment_panel.refresh_passes-refresh_before')
source = source.replace('intel_probe.final_projection_delta=scene.equipment_panel.projection_builds-projection_before', 'intel_probe.final_projection_delta=scene.equipment_panel.projection_builds-projection_before\n  intel_probe.stage=g.stage')
source = source.replace('row.enemy_intel_probe=intel_probe', 'if not intel_probe.enabled:\n  intel_probe.final_compile_delta=g.compiled_combat_rules.builds-compiled_before\n  intel_probe.final_projection_delta=scene.equipment_panel.projection_builds-projection_before\n  intel_probe.final_refresh_delta=scene.equipment_panel.refresh_passes-refresh_before\n row.enemy_intel_probe=intel_probe')
driver.write_text(source,encoding='utf-8')
print('diagnostic only in ignored project copy')
