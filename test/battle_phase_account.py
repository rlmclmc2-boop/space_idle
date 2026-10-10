"""Mutate only runner's private copy: disjoint whole-frame phase accounting."""
import re
import shutil

SCOPES = {
 'game': {'tick':'simulation','tick_projectiles':'simulation', **{name:'numeric_queries' for name in ['stat','jewel_equipment_stat','player_weapon_row','equipment_damage','module_damage','enhancement_effects','combat_weapon_entries','hyperspace_totals']}},
 'presented_battle_game': {'tick':'simulation','tick_projectiles':'simulation'},
 'main': {'_process':'process_other','advance_game_time':'simulation_boundary',
          **{name:'event_presentation' for name in ['on_event','weapon_launch']},
          **{name:'damage_layout' for name in ['queue_damage_number','flush_damage_numbers','damage_text_position']},
          **{name:'ui_refresh' for name in ['refresh_visible_cards','refresh_navigation','equipment_display_snapshot']},
          **{name:'presentation_update' for name in ['advance_turrets','advance_projectile_visuals','sync_beam_visuals','refresh_draw_layers']},
          **{name:'draw_materialization' for name in ['draw_background','draw_stars','draw_chrome','draw_battle_resources','draw_battle','draw_vertical_battle_hud','draw_resources','draw_overlay','draw_battle_foreground']},
          **{name:'geometry_queries' for name in ['enemy_render_width_at_y','enemy_frontline_y_limit','enemy_render_position','enemy_component_pose','enemy_recognition_geometry','enemy_weapon_components','enemy_weapon_angle','damage_text_enemy_bounds','damage_text_enemy_bottom']},
          'visual_muzzle':'geometry_authority'},
 'battlefield': {'_process':'presentation_update','before_logical_game_tick':'step_pose_update','weapon_launch':'event_presentation','on_event':'event_presentation','enemy_target_point':'geometry_authority','enemy_render_position':'geometry_queries','draw_battle':'draw_materialization','draw_projectile_fx':'draw_materialization','draw_projectile_body_override':'draw_materialization'},
 'retained_enemy_contacts': {'sync':'draw_materialization','paint':'draw_materialization'},
 'presented_ship_view': {name:'ship_native_update' for name in ['set_pose','set_loadout','apply_parameters','aim_at','set_hull']},
}

def arguments(value):
    parts=[];start=0;level=0;quote='';escape=False
    for i,char in enumerate(value):
        if quote:
            if escape:escape=False
            elif char=='\\':escape=True
            elif char==quote:quote=''
        elif char in '\"\'':quote=char
        elif char in '([{':level+=1
        elif char in ')]}':level-=1
        elif char==',' and not level:parts.append(value[start:i]);start=i+1
    parts.append(value[start:])
    return [p.strip().split(':')[0].split('=')[0].strip() for p in parts if p.strip()]

def prepare(project,root):
    shutil.copy2(root/'test/exclusive_phase_ledger.gd',project/'exclusive_phase_ledger.gd')
    wrapped=[]
    for module,methods in SCOPES.items():
        path=project/'scripts'/(module+'.gd');source=path.read_text(encoding='utf-8')
        for name,category in methods.items():
            match=re.search(rf'^func {name}\((.*)\)([^\n]*):$',source,re.M)
            if not match:continue
            original=f'_phase_{module}_{name}'
            call=original+'('+', '.join(arguments(match[1]))+')'
            is_void=bool(re.search(r'->\s*void',match[2]))
            indent=re.match(r'\n([ \t]+)',source[match.end():])[1]
            wrapper=match[0]+'\n'+indent+'var ledger=Engine.get_meta("phase_ledger")\n'
            wrapper+=f'{indent}ledger.enter("{category}","{module}.{name}")\n'
            wrapper+=indent+(call if is_void else 'var result='+call)+'\n'+indent+'ledger.leave()\n'
            if not is_void:wrapper+=indent+'return result\n'
            wrapper+='\n'+match[0].replace('func '+name+'(','func '+original+'(')
            source=source[:match.start()]+wrapper+source[match.end():];wrapped.append(module+'.'+name)
        path.write_text(source,encoding='utf-8')
    path=project/'probe.gd';source=path.read_text(encoding='utf-8')
    source=source.replace(' Engine.set_meta("saved_perf",meter)',' Engine.set_meta("saved_perf",meter)\n Engine.set_meta("phase_ledger",preload("res://exclusive_phase_ledger.gd").new())')
    source=source.replace('   var start=Time.get_ticks_usec()','   Engine.get_meta("phase_ledger").start_frame(i>=warmup)\n   var start=Time.get_ticks_usec()')
    source=source.replace('   await RenderingServer.frame_post_draw\n   if i>=warmup:', '   await RenderingServer.frame_post_draw\n   Engine.get_meta("phase_ledger").end_frame(i)\n   if i>=warmup:')
    source=source.replace('  row.battle_scope=scope','  row.battle_scope=scope') # scope assignment is on a shared line.
    source=source.replace('  row.retention_counts=', '  row.exclusive_phases=Engine.get_meta("phase_ledger").report()\n  row.retention_counts=')
    source=source.replace(' Engine.remove_meta("saved_perf")',' Engine.remove_meta("saved_perf")\n Engine.remove_meta("phase_ledger")')
    path.write_text(source,encoding='utf-8')
    return wrapped
