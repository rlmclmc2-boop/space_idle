from pathlib import Path
import re,json
r=Path('D:/CodexBuild/space_idle/stable-integration');a=r/'test/work/battle-fix-20261013';iso=a/'space-battleship'
selected={
'battle_slice_runtime.gd':['advance','snapshot'],
'simulation_geometry_authority.gd':['before_tick','after_tick','advance_turrets','enemy_pose','_source_enemy_appearance','enemy_steady_position_key','_source_enemy_render_position','_source_enemy_render_width_at_y','_source_enemy_frontline_y_limit','enemy_display_top_clearance','_source_enemy_component_pose','battle_logical_point','display_enemy','display_frame','display_shape','finish_display_boundary','sync_fleet_angles','launch_pose','drone_launch_pose'],
'battle_read_model.gd':['begin','position','width_at','ballistic_shape','compile_shape'],
'simulation_geometry_view.gd':['apply'],
'native_execution_session.gd':['prepare_geometry','advance','consume_feedback'],
'game.gd':['tick','advance_shared_clock_and_economy'],
'enemy_recognition_visual.gd':['geometry_from_profile']}
for file,names in selected.items():
 s=(r/'space-battleship/scripts'/file).read_text(encoding='utf-8');wrappers=[]
 for name in names:
  m=re.search(r'^func '+name+r'\((.*?)\)([^\n]*?):',s,re.M);assert m,(file,name)
  params,ret=m.group(1,2);args=','.join(re.split(r'[:=]',x.strip())[0].strip() for x in params.split(',') if x.strip());original='_probe_'+file[:-3]+'_'+name
  header=m.group(0);s=s[:m.start()]+header.replace('func '+name+'(','func '+original+'(')+s[m.end():]
  returned='void' not in ret # untyped funcs may return; preserve result even when null
  label=file[:-3]+'.'+name
  wrappers.append(header+'\n\tvar stamp=preload("res://.runtime/frame_ledger.gd").begin()\n\t'+('var result=' if returned else '')+original+'('+args+')\n\tpreload("res://.runtime/frame_ledger.gd").finish(stamp,"'+label+'")\n'+('\treturn result\n' if returned else ''))
 s+='\n'+'\n'.join(wrappers)
 if file=='simulation_geometry_authority.gd':
  old='if game.combat_presentation!=null:top=game.combat_presentation.rotated_outlines_min_y(outlines,angle)'
  new='if game.combat_presentation!=null:\n\t\tvar native_stamp=preload("res://.runtime/frame_ledger.gd").begin()\n\t\ttop=game.combat_presentation.rotated_outlines_min_y(outlines,angle)\n\t\tpreload("res://.runtime/frame_ledger.gd").finish(native_stamp,"native.rotated_outlines")'
  assert old in s;s=s.replace(old,new)
  old='if game.combat_presentation!=null:return game.combat_presentation.battle_logical_point(point)'
  new='if game.combat_presentation!=null:\n\t\tvar native_stamp=preload("res://.runtime/frame_ledger.gd").begin()\n\t\tvar native_result=game.combat_presentation.battle_logical_point(point)\n\t\tpreload("res://.runtime/frame_ledger.gd").finish(native_stamp,"native.inverse")\n\t\treturn native_result'
  assert old in s;s=s.replace(old,new)
 if file=='native_execution_session.gd':
  old='if not kernel.advance(dt):';new='var native_stamp=preload("res://.runtime/frame_ledger.gd").begin()\n\tvar native_ok=kernel.advance(dt)\n\tpreload("res://.runtime/frame_ledger.gd").finish(native_stamp,"native.kernel_advance")\n\tif not native_ok:';assert old in s;s=s.replace(old,new)
  old='kernel.input_ballistic_geometry(hulls,screen_points,screen_muzzles)';s=s.replace(old,'var input_stamp=preload("res://.runtime/frame_ledger.gd").begin()\n\t'+old)
  old='kernel.input_player_point(aim)';s=s.replace(old,old+'\n\tpreload("res://.runtime/frame_ledger.gd").finish(input_stamp,"native.geometry_input")')
 if file=='enemy_recognition_visual.gd':
  old='var min_width := 15.0/scale_safe';s=s.replace(old,'var build_stamp=preload("res://.runtime/frame_ledger.gd").begin()\n\t'+old,1)
  old='envelope_builds+=1';assert old in s;s=s.replace(old,old+'\n\tpreload("res://.runtime/frame_ledger.gd").finish(build_stamp,"recognition.envelope_build")',1)
 (iso/'scripts'/file).write_text(s,encoding='utf-8')
(a/'geometry-probe-functions.json').write_text(json.dumps(selected,indent=2),encoding='utf-8')
(iso/'qa_astra_geometry_boundary.gd').write_bytes((iso/'qa_astra_frame_ledger.gd').read_bytes())
