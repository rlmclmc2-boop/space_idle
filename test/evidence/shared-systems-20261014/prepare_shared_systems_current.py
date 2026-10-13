from pathlib import Path
import re,subprocess,shutil,json,hashlib
r=Path('D:/CodexBuild/space_idle/stable-integration');iso=r/'test/work/battle-fix-20261013/space-battleship'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip().startswith('346c67f8')
for p in (r/'space-battleship/scripts').rglob('*.gd'):
 q=iso/p.relative_to(r/'space-battleship');q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
probe='''extends RefCounted
static var enabled:=false
static var stack:Array=[]
static var rows:Dictionary={}
static var overhead_us:=0
static func begin(name:String)->void:
 if not enabled:return
 var t:=Time.get_ticks_usec()
 var path:=name if stack.is_empty() else str(stack[-1].path)+">"+name
 stack.append({"path":path,"start":0,"child":0})
 var now:=Time.get_ticks_usec()
 overhead_us+=now-t
 stack[-1].start=now
static func end()->void:
 if not enabled:return
 var t:=Time.get_ticks_usec()
 var node:Dictionary=stack.pop_back()
 var elapsed:int=t-int(node.start)
 if not rows.has(node.path):rows[node.path]={"calls":0,"inclusive_us":0,"exclusive_us":0,"max_us":0}
 var row:Dictionary=rows[node.path]
 row.calls+=1;row.inclusive_us+=elapsed;row.exclusive_us+=elapsed-int(node.child);row.max_us=maxi(row.max_us,elapsed)
 if not stack.is_empty():stack[-1].child+=elapsed
 overhead_us+=Time.get_ticks_usec()-t
static func reset()->void:
 assert(stack.is_empty());rows.clear();overhead_us=0
'''
(iso/'system_probe.gd').write_text(probe,encoding='utf-8')
targets={
'game.gd':['advance_shared_clock_and_economy','advance_planets','advance_auto_gen','advance_hightech','active_research','advance_furnace','invalidate_stat_cache'],
'crew_system.gd':['advance','invalidate_resources'],
'hyperspace_system.gd':['advance'],
'native_execution_session.gd':['prepare_numeric_batch'],
'native_execution_compiler.gd':['compile'],
'hightech_workshop.gd':['refresh','_process'],
'reactor_panel.gd':['refresh_pending']}
# Instrument complete callable bodies via wrappers, including early return paths.
for name,funcs in targets.items():
 p=iso/'scripts'/name
 if not p.exists():raise RuntimeError(name)
 s=p.read_text(encoding='utf-8')
 for f in funcs:
  pat=r'^func '+re.escape(f)+r'\((.*)\)(\s*->\s*[^:]+)?:\s*$'
  m=re.search(pat,s,re.M);assert m,(name,f)
  args=m[1];ret=m[2] or '';names=[re.split(r'[:=]',x.strip())[0].strip() for x in args.split(',') if x.strip()]
  call='_cost_original_'+f+'('+','.join(names)+')'
  body='\t'+call+'\n' if ret.strip()=='->void' or ret.replace(' ','')=='->void' else '\tvar result='+call+'\n'
  tail='' if 'var result=' not in body else '\treturn result\n'
  wrapper='func '+f+'('+args+')'+ret+':\n\tpreload("res://system_probe.gd").begin("'+name[:-3]+'.'+f+'")\n'+body+'\tpreload("res://system_probe.gd").end()\n'+tail+'\nfunc _cost_original_'+f+'('+args+')'+ret+':'
  s=s[:m.start()]+wrapper+s[m.end():]
 p.write_text(s,encoding='utf-8')
base=(r/'test/qa_galaxy_refit_real.gd').read_text(encoding='utf-8').split(' scene.refresh_structure();')[0]
base=base.replace('func run()->void:', 'const Probe=preload("res://system_probe.gd")\nvar system_events:Dictionary={}\nfunc record_event(kind:String,_info:Dictionary)->void:\n system_events[kind]=int(system_events.get(kind,0))+1\nfunc run()->void:')
body='''
 # Finite normal research: twelve purchased AI, six on each level-one furnace.
 for key in [BattleGame.FURNACE,BattleGame.JEWEL_FURNACE]:
  assert(g.hightech_unlocked(key));g.profile.hightechLevels[key]=1
 assert(g.generate_scientist(12))
 assert(g.assign_scientist(BattleGame.FURNACE,6));assert(g.assign_scientist(BattleGame.JEWEL_FURNACE,6))
 assert(g.assign_crew("navigator","equipment_upgrade","equipment"))
 var exploration:Dictionary={}
 for id in g.profile.planets:
  for member in g.profile.crew:
   if g.start_planet_exploration(str(id),str(member.crewId)):
    exploration={"id":id,"crew":member.crewId,"duration":g.planet_duration(str(id))};break
  if not exploration.is_empty():break
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(1)
 scene.hightech_page.select_project(BattleGame.FURNACE)
 assert(scene.hightech_page.is_visible_in_tree())
 g.native_execution_auto=true
 assert(g.admit_native_compiled_execution("native_rich15_layer2") and scene.attach_native_display())
 scene.retained_contacts_enabled=true;g.event.connect(scene.watch)
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 RenderingServer.viewport_set_measure_render_time(scene.ship_view.viewport.get_viewport_rid(),true)
 scene.set_process(true)
 var warm:float=g.production_time()
 while g.production_time()-warm<3.0:await RenderingServer.frame_post_draw
 scene.set_process(false)
 var page=scene.hightech_page
 var setup={"scientists":g.profile.scientists,"assignments":g.profile.scientistAssignments.duplicate(true),"levels":g.profile.hightechLevels.duplicate(true),"points":g.profile.techPoints.duplicate(true),"auto_gen":g.auto_gen_settings(),"furnace_row":g.db.data.hightech[BattleGame.FURNACE],"jewel_furnace_row":g.db.data.hightech[BattleGame.JEWEL_FURNACE],"exploration":exploration,"visible_rows":page.rows.size(),"selected":page.selected}
 var before=snapshot(scene);var session=g.native_execution;var initial_ticks:int=session.ticks
 var refresh_before:int=page.refresh_count;var refresh_us_before:int=page.refresh_usec;var quote_before:int=page.quote_evaluations
 var samples:Array=[];var frames:Array=[];var start:=Time.get_ticks_usec();var previous:=start;var start_game:float=g.production_time()
 g.event.connect(record_event);Probe.reset();Probe.enabled=true;scene.set_process(true)
 while g.production_time()-start_game<30.0:
  await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();frames.append(now-previous);previous=now
  samples.append({"game":g.production_time()-start_game,"native":g.native_execution==session,"steps":session.ticks-initial_ticks,"drops":g.drops.size(),"projectiles":g.projectiles.size(),"floats":scene.floats.size(),"refresh_count":page.refresh_count-refresh_before,"render":render_times(scene)})
 Probe.enabled=false;scene.set_process(false)
 var row={"source":"346c67f8856dac075cc604e21c41fe96220f78df","config":config(scene),"accessibility":ProjectSettings.get_setting("accessibility/general/accessibility_support"),"setup":setup,"before":before,"after":snapshot(scene),"steps":session.ticks-initial_ticks,"game_seconds":g.production_time()-start_game,"wall_seconds":(previous-start)/1000000.0,"frames_us":frames,"samples":samples,"cost_paths":Probe.rows,"probe_bookkeeping_us":Probe.overhead_us,"events":system_events,"ui_refresh_count":page.refresh_count-refresh_before,"ui_refresh_us":page.refresh_usec-refresh_us_before,"ui_quote_evaluations":page.quote_evaluations-quote_before,"points_end":g.profile.techPoints,"levels_end":g.profile.hightechLevels,"native_same_session":g.native_execution==session,"notes":"One diagnostic run, visible AI workshop throughout; no A/B and no benefit claim. Path exclusive times subtract measured child spans; probe bookkeeping can remain in ancestor exclusive cost. Existing battle fixture and 12 finite purchased AI; no database/config changes."}
 FileAccess.open("res://.runtime/shared-systems-current.json",FileAccess.WRITE).store_string(JSON.stringify(row))
 root.get_texture().get_image().save_png("res://.runtime/shared-systems-current.png")
 print("SHARED_SYSTEMS_RESULT frames=",frames.size()," wall=",row.wall_seconds," game=",row.game_seconds," native=",row.native_same_session," refresh=",row.ui_refresh_count)
 stress.finish(g);g.begin_retreat();scene.queue_free();await process_frame;await process_frame;quit()
'''
(iso/'qa_shared_systems_current.gd').write_text(base+body,encoding='utf-8')
print('Prepared isolated probes',len(targets),'files; DLL',hashlib.sha256((iso/'bin/space_native.dll').read_bytes()).hexdigest())
