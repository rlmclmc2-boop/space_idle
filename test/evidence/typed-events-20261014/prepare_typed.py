from pathlib import Path
import re,shutil,sys
r=Path('D:/CodexBuild/space_idle/stable-integration');iso=r/'test/work/battle-fix-20261013/space-battleship';profile='--profile' in sys.argv
for p in (r/'space-battleship/scripts').rglob('*.gd'):shutil.copy2(p,iso/p.relative_to(r/'space-battleship'))
import os,subprocess
if os.environ.get("TYPED_EVENT_CASE")=="CPU":
 (iso/'scripts/balance_game.gd').write_bytes(subprocess.check_output(["git","show","85ada8bc:space-battleship/scripts/balance_game.gd"],cwd=r))
 (iso/'scripts/crew_system.gd').write_bytes(subprocess.check_output(["git","show","85ada8bc:space-battleship/scripts/crew_system.gd"],cwd=r))
 (iso/'scripts/game.gd').write_bytes(subprocess.check_output(["git","show","85ada8bc:space-battleship/scripts/game.gd"],cwd=r))
 (iso/'scripts/hightech_workshop.gd').write_bytes(subprocess.check_output(["git","show","85ada8bc:space-battleship/scripts/hightech_workshop.gd"],cwd=r))
 (iso/'scripts/hyperspace_panel.gd').write_bytes(subprocess.check_output(["git","show","85ada8bc:space-battleship/scripts/hyperspace_panel.gd"],cwd=r))
 (iso/'scripts/hyperspace_reforge_dialog.gd').write_bytes(subprocess.check_output(["git","show","85ada8bc:space-battleship/scripts/hyperspace_reforge_dialog.gd"],cwd=r))
 (iso/'scripts/main.gd').write_bytes(subprocess.check_output(["git","show","85ada8bc:space-battleship/scripts/main.gd"],cwd=r))
 (iso/'scripts/planet_panel.gd').write_bytes(subprocess.check_output(["git","show","85ada8bc:space-battleship/scripts/planet_panel.gd"],cwd=r))
 (iso/'scripts/reactor_panel.gd').write_bytes(subprocess.check_output(["git","show","85ada8bc:space-battleship/scripts/reactor_panel.gd"],cwd=r))
 (iso/'scripts/simulation_geometry_authority.gd').write_bytes(subprocess.check_output(["git","show","85ada8bc:space-battleship/scripts/simulation_geometry_authority.gd"],cwd=r))

gate='''extends RefCounted
static var mode:=0
static var sampled:=false
static var profiling:=false
static var steps:=0
static var limit:=180
static var counts:Dictionary={}
static var spans:Array=[]
static func mark(name:String)->void:
 if sampled:counts[name]=int(counts.get(name,0))+1
static func allow(name:String,threshold:int)->bool:
 if mode>=threshold:
  mark("blocked:"+name);return false
 mark("executed:"+name);return true
static func redraw(item:CanvasItem)->void:
 if mode>=2:mark("blocked:node.redraw");return
 item.queue_redraw()
static func begin()->int:
 return Time.get_ticks_usec() if profiling and sampled else 0
static func end(start:int,name:String)->void:
 if start>0:spans.append([start,Time.get_ticks_usec(),name])
'''
(iso/'strip_gate.gd').write_text(gate,encoding='utf-8');G='preload("res://strip_gate.gd")'
def read(n):return (iso/'scripts'/n).read_text(encoding='utf-8')
def write(n,s):(iso/'scripts'/n).write_text(re.sub(r'^[ \t]+',lambda m:m[0].replace(' ','\t'),s,flags=re.M),encoding='utf-8')
def insert(s,f,body):
 m=re.search(r'^func '+re.escape(f)+r'\([^\n]*\)[^\n]*:\s*\n',s,re.M);assert m,f
 return s[:m.end()]+body+s[m.end():]
def block(s,start,end,threshold,label):
 a=s.index(start);b=s.index(end,a);chunk=s[a:b]
 return s[:a]+re.match(r'\s*',start).group(0)+'if '+G+'.allow("'+label+'",'+str(threshold)+'):\n'+''.join('\t'+l if l.strip() else l for l in chunk.splitlines(True))+s[b:]
# Draw callback gates remove command construction/submission, not the public visibility state.
for n,fs in {'main.gd':['draw_stars','draw_vertical_battle_hud','draw_battle_resources','draw_battle','draw_battle_foreground'],'battlefield.gd':['draw_stars','draw_battle','_draw_muzzle_cues'],'retained_enemy_contacts.gd':['paint']}.items():
 s=read(n)
 for f in fs:s=insert(s,f,'\tif not '+G+'.allow("draw.'+n+'.'+f+'",1):return\n')
 write(n,s)
# B retains numeric node work, but viewport/texture submission cannot be restored.
s=read('presented_ship_view.gd');s=insert(s,'set_rendering','\tif '+G+'.mode>=1:\n\t\tviewport.render_target_update_mode=SubViewport.UPDATE_DISABLED\n\t\t'+G+'.mark("blocked:ship_submission");return\n')
s=s.replace('if viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS:viewport.render_target_update_mode=SubViewport.UPDATE_ONCE','if '+G+'.mode==0 and viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS:viewport.render_target_update_mode=SubViewport.UPDATE_ONCE')
write('presented_ship_view.gd',s)
# C only freezes battlefield node mutation regions. UI and Main logic keep running.
s=read('battlefield.gd');s=block(s,'\tif is_instance_valid(ship_view):\n\t\tif hyperspace_visual.sync','\tsuper._process(delta)',2,'node.fleet_setup')
s=block(s,'\tdestruction_events = destruction_events.filter','\tprototype_frames += 1',3,'producer.contact_cleanup')
s=block(s,'\tprototype_frames += 1','\n\n\nfunc ',2,'node.fleet_pose')
# A shader/time pure process is still allowed, but no hidden late node writes.

for target in ['battle_layer','battle_hud_layer','pulse_layer','stars_layer']:s=s.replace(target+'.queue_redraw()',G+'.redraw('+target+')')
write('battlefield.gd',s)
s=read('battle_slice_runtime.gd');s=insert(s,'apply_nodes','\tif not '+G+'.allow("node.apply_nodes",2):return\n')
# Preserve all retained/dead lifecycle and authoritative finish before omitting publication.
s=s.replace('\tvar values:Dictionary=geometry.display_frame(retained.values())','\tif not '+G+'.allow("producer.display_frame",3):return\n\tvar values:Dictionary=geometry.display_frame(retained.values())')
s=s.replace('\tgeometry.on_simulation_event(kind,info)','\tgeometry.on_simulation_event(kind,info)\n\tif '+G+'.mode>=3 and kind in HOT:\n\t\t'+G+'.mark("blocked:producer.effect");return true')
write('battle_slice_runtime.gd',s)
s=read('main.gd');s=block(s,'\t\tif not accelerated_visual_mode:\n\t\t\tsync_beam_visuals()','\tflush_damage_numbers(',3,'producer.visual_advance')
# Keep damage history records while omitting display queues.
s=s.replace('\tif not show_damage_numbers:return','\tif not '+G+'.allow("producer.damage_display",3):return\n\tif not show_damage_numbers:return',1)
for f in ['flush_damage_numbers','weapon_smoke','weapon_flash','weapon_sparks','resource_pickup_feedback']:
 s=insert(s,f,'\tif not '+G+'.allow("producer.'+f+'",3):return\n')
# D retains refresh_draw_layers global resource/overlay work, skips battle display queries.
s=block(s,'\tfor slot in enemy_poses.keys():','\tif ui_state_changed(resource_layer,',3,'producer.battle_refresh')
# C avoids battle Canvas update requests, while allowing resource/overlay/global UI.
for target in ['battle_layer','battle_hud_layer','drop_layer','stars_layer']:
 s=s.replace(target+'.queue_redraw()',G+'.redraw('+target+')')
write('main.gd',s)
s=read('flat_ship_compositor.gd');s=insert(s,'_process','\tif not '+G+'.allow("node.flat_compositor",2):return\n');write('flat_ship_compositor.gd',s)
# Strict fixed-step observation endpoints only. Gates activated after unmodified warm-up.
s=read('game.gd');s=insert(s,'prepare_logical_step','\tif '+G+'.steps>='+G+'.limit:return false\n')
s=s.replace('func tick(dt: float) -> void:', 'func tick(dt: float) -> void:\n\t_strip_tick(dt)\n\t'+G+'.steps+=1\n\t'+G+'.mark("logic.tick")\n\nfunc _strip_tick(dt: float) -> void:',1);write('game.gd',s)
for n,fs in {'simulation_geometry_authority.gd':['before_tick','after_tick','on_simulation_event','finish_display_boundary'],'native_execution_session.gd':['prepare_geometry','consume_feedback']}.items():
 s=read(n)
 for f in fs:s=insert(s,f,'\t'+G+'.mark("kept.'+n+'.'+f+'")\n')
 write(n,s)
# Complete mutually-exclusive selected script spans; other callback/gap time remains explicit.
def splitargs(t):
 a=[];level=0;start=0
 for i,c in enumerate(t):
  if c in '([{':level+=1
  elif c in ')]}':level-=1
  elif c==',' and level==0:a.append(t[start:i]);start=i+1
 a.append(t[start:]);return [re.split(r'[:=]',x.strip())[0].strip() for x in a if x.strip()]
targets={'main.gd':['_process','advance_game_time','advance_projectile_visuals','sync_beam_visuals','flush_damage_numbers','refresh_visible_cards','refresh_navigation','refresh_draw_layers','draw_battle','draw_battle_foreground','draw_stars','draw_overlay','draw_resources','draw_vertical_battle_hud'],'battlefield.gd':['_process','_process_battlefield','_draw_muzzle_cues','on_event'],'battle_slice_runtime.gd':['advance','snapshot','apply_nodes','on_event','spawn_visual','consume'],'simulation_geometry_authority.gd':['before_tick','after_tick','display_frame','finish_display_boundary'],'native_execution_session.gd':['advance','prepare_geometry','consume_feedback'],'game.gd':['tick','advance_shared_clock_and_economy'],'equipment_tab.gd':['refresh_stats','refresh_slots','refresh_pending'],'hightech_workshop.gd':['_process','refresh'],'retained_enemy_contacts.gd':['paint','sync'],'flat_ship_compositor.gd':['_process','sync']}
if profile:
 s=read('native_execution_session.gd');s=s.replace('\tif not kernel.advance(dt):','\tvar kernel_stamp='+G+'.begin()\n\tvar advanced=kernel.advance(dt)\n\t'+G+'.end(kernel_stamp,"native.kernel_advance")\n\tif not advanced:');write('native_execution_session.gd',s)
 for n,fs in targets.items():
  s=read(n)
  for f in fs:
   m=re.search(r'^func '+re.escape(f)+r'\(([^\n]*)\)(\s*->\s*[^:]+)?:\s*$',s,re.M)
   if not m:raise RuntimeError((n,f))
   args=m[1];ret=m[2] or '';void=ret.replace(' ','')=='->void';call='_diag_'+n[:-3]+'_'+f+'('+','.join(splitargs(args))+')'
   wrapper='func '+f+'('+args+')'+ret+':\n\tvar stamp='+G+'.begin()\n\t'+(call if void else 'var answer='+call)+'\n\t'+G+'.end(stamp,"'+n[:-3]+'.'+f+'")\n'+('' if void else '\treturn answer\n')+'\nfunc _diag_'+n[:-3]+'_'+f+'('+args+')'+ret+':'
   s=s[:m.start()]+wrapper+s[m.end():]
  write(n,s)
print('Prepared strip isolated copy profile=',profile)
