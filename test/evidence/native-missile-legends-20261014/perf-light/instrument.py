from pathlib import Path
import re,json

def instrument(project,evidence):
 selected={
 'main.gd':{'draw_background','draw_stars','draw_chrome','draw_battle_resources','draw_battle','draw_vertical_battle_hud','draw_resources','draw_overlay','draw_battle_foreground'},
 'battlefield.gd':{'draw_battle','_draw_muzzle_cues'},
 'retained_enemy_contacts.gd':{'_draw'},
 'chrono_panel.gd':{'_draw'},
 'ship_body_baker.gd':{'_sync_shadow_policy','_finish'},
 'presented_ship_view.gd':{'_commit_fleet_redraw','_sync_render_scale'},
 'reactor_visual.gd':{'_draw'},
 }
 manifest=[]
 for path in sorted((project/'scripts').glob('*.gd')):
  if path.name=='restart_host.gd':continue
  source=path.read_text(encoding='utf8');lines=source.splitlines(True);out=[]
  for i,line in enumerate(lines):
   m=re.match(r'^(\s*)func (\w+)\((.*?)\)(.*):\s*$',line.rstrip('\n\r'))
   if not m or not (m[2]=='_process' or m[2] in selected.get(path.name,set())):
    out.append(line);continue
   indent,name,args,suffix=m.groups()
   assert 'void' in suffix,(path,name,suffix)
   names=[a.split(':')[0].split('=')[0].strip() for a in args.split(',') if a.strip()]
   assert all(re.match(r'^\w+$',n) for n in names)
   original='qa_original_'+path.stem+'_'+name+'_'+str(i+1)
   pad=indent+('\t' if '\t' in indent or (i+1<len(lines) and lines[i+1].startswith(indent+'\t')) else ' ')
   label=path.stem+'.'+name
   out.append(line)
   out.append(pad+'if not preload("res://probe.gd").active:\n')
   out.append(pad+('\t' if '\t' in pad else ' ')+original+'('+','.join(names)+')\n')
   out.append(pad+('\t' if '\t' in pad else ' ')+'return\n')
   out.append(pad+'var qa_span=preload("res://probe.gd").begin("'+label+'")\n')
   out.append(pad+original+'('+','.join(names)+')\n')
   out.append(pad+'preload("res://probe.gd").finish(qa_span)\n')
   out.append(indent+'func '+original+'('+args+')'+suffix+':\n')
   manifest.append({'file':path.name,'function':name,'source_line':i+1})
  altered=''.join(out)
  if path.name=='ship_body_baker.gd':
   altered=altered.replace('\tfor id in body_roots:\n','\tfor id in body_roots:\n\t\tif preload("res://probe.gd").active:preload("res://probe.gd").roots_visited+=1\n')
   altered=altered.replace('\tif light.shadow_enabled != needs_shadows:\n','\tif light.shadow_enabled != needs_shadows:\n\t\tif preload("res://probe.gd").active:preload("res://probe.gd").policy_changes+=1\n')

  if altered!=source:path.write_text(altered,encoding='utf8')
 (evidence/'instrumented-functions.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
