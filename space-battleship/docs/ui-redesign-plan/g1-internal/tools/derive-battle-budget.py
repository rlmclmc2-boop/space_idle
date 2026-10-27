import json,math,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[4];d=root/'docs/ui-redesign-plan/g1-internal';base=json.loads((d/'art/battle/geometry.json').read_text());groups=json.loads(Path('/tmp/battle-group-demands.json').read_text())['records'];models=list(base['enemies'])
profiles={'art':{'title':'P1 · 若按模型display_span占位','condition':'Authored display_span condition only; not approved actor role classification','columns':7,'rows':3,'cell':[80,96],'player_origin':[286,520],'player_scale':.8,'pickup_point':[250,316],'visual_bounds':[-32,-48,604,960],'shield_margin':6,'effect_margin':4,'label_height_px':18,'label_width_px':[42,60,84],'label_gap':6,'drone_centres':[[105,768],[195,850],[286,768],[377,850],[467,768]],'drone_radius':48},'tier':{'title':'P2 · 若按encounter rank占位','condition':'Encounter rank condition only; not approved actor role classification','columns':10,'rows':6,'cell':[56,80],'player_origin':[286,710],'player_scale':.8,'pickup_point':[250,505],'visual_bounds':[-32,-48,604,1008],'shield_margin':4,'effect_margin':2,'label_height_px':18,'label_width_px':[34,60,84],'label_gap':6,'drone_centres':[[78,930],[182,930],[286,930],[390,930],[494,930]],'drone_radius':48}}
# Full authored alpha geometry and all mount/weapon combinations. q=1 raw source pixel scale.
def half_bounds(a):
 w,h=a['size'];b=a['alpha_bounds'];x=max(abs(b[0]-w/2),abs(b[2]-w/2));y=max(abs(b[1]-h/2),abs(b[3]-h/2));s=math.sin(math.radians(4));return x+y*s,y+x*s

def envelope(a):
 hx,hy=half_bounds(a);x,y=hx,hy;sn=math.sin(math.radians(4));W,H=a['size']
 for hp in a['hardpoints']:
  px,py=[abs(hp['pos'][j]*[W,H][j]) for j in range(2)];px,py=px+py*sn,py+px*sn;cls={'small':.7,'medium':.9,'large':1.1}.get(hp.get('visual_size_class','small'),.7);mw=2*hx*.42*cls
  for w in base['weapons'].values():
   sc=[mw/w['size'][0],mw*w['pixels_per_model'][0]/w['size'][0]/w['pixels_per_model'][1]];r=max(math.hypot(*[(p[j]-w['anchor'][j])*sc[j] for j in range(2)]) for p in w['alpha_hull']);x=max(x,px+r);y=max(y,py+r)
 r=base['ranked']
 for m in a.get('rotating_mounts',[]):
  px,py=abs(m['centre_px'][0]-W/2),abs(m['centre_px'][1]-H/2);px,py=px+py*sn,py+px*sn;sc=m['housing_width_uv']*W/r['housing_width_px'];radius=max(math.hypot(*[(p[j]-r['pivot_px'][j])*sc for j in range(2)]) for p in r['alpha_hull']);x=max(x,px+radius);y=max(y,py+radius)
 return [x,y]
raw={k:envelope(v) for k,v in base['enemies'].items()}
for name,p in profiles.items():
 # Fixed main-size host height662; exact CSS rectangle measured at render is used for labels.
 s=662/(p['visual_bounds'][3]-p['visual_bounds'][1]);p['main_scale']=s;p['models']={}
 for key,a in base['enemies'].items():
  p['models'][key]={}
  for rank,span in enumerate([[1,1],[2,2],[3,2]]):
   bw=span[0]*p['cell'][0]-2*(p['shield_margin']+p['effect_margin']);bh=span[1]*p['cell'][1]-2*(p['shield_margin']+p['effect_margin'])-p['label_height_px']/s-p['label_gap'];q=min(bw/(2*raw[key][0]),bh/(2*raw[key][1]));b=a['alpha_bounds'];p['models'][key][str(rank)]={'span':span,'q_upper':q,'display_size':[(b[2]-b[0])*q,(b[3]-b[1])*q],'raw_half_upper':raw[key],'assembly_half_upper':[v*q for v in raw[key]],'content_budget':[bw,bh]}
# Actual source member ordering preserved; no gameplay identities added.
record={str(g['group']):{'source':g['source'],'tier':g['tier'],'current_positions':g['current_positions'],'members':[[models.index(e['visual_key']),e['conditional_tier_span'][0],e['id'],e['size'],e['weapons'],e['has_shield']] for e in g['entities']],'art_cells':g['art_cells'],'tier_cells':g['tier_cells']} for g in groups}
result={'kind':'Unapproved conditional joint-space design proposals. No runtime/config changes. Classification undecided.','source_baseline':'d829dd30e1d87b2b329af9082b33b157df23df55','source_files':{p:hashlib.sha256((root/p).read_bytes()).hexdigest() for p in ['config_excel/level.xlsx','config_excel/monGroup.xlsx','config_excel/mon.xlsx','config_excel/hyperspace_enemies.xlsx','src/combat_setup.gd','scripts/enemy_visual_identity.gd','data/ship_weapon_visuals.json']},'models':models,'profiles':profiles,'groups':record,'maxima':{'main_referenced_groups':1970,'hyperspace_groups':40,'art_cells':21,'tier_cells':60},'main_samples':['30081','30086','33011','7018','7036','7037']}
(d/'battle-budget-models.js').write_text('/* Read-only source facts + explicitly conditional, unapproved geometry proposals. */\nwindow.BattleBudgets='+json.dumps(result,ensure_ascii=False,separators=(',',':'))+';\n')
# Supporting data excludes repeated complete group tables but retains exact selected witnesses.
summary={k:v for k,v in result.items() if k!='groups'};summary['witnesses']={k:record[k] for k in result['main_samples']};(d/'art/battle/joint-budget.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n');print('profiles',[(k,p['main_scale']) for k,p in profiles.items()],'groups',len(record))
