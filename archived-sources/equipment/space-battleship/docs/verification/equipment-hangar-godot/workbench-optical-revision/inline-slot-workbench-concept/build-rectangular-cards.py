#!/usr/bin/env python3
"""Current static card source; no game execution or domain price calculation."""
import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
from PIL import Image, ImageFont, ImageChops

HERE = Path(__file__).resolve().parent
base = (HERE/'build-design-plates.py').read_text().split('\nfor name,stage,popup in')[0]
n = {'__file__':str(HERE/'build-design-plates.py')}
exec(compile(base,'preserved-design-helpers','exec'),n)
original_ref = n['ref']
def current_ref(path):
    path = Path(path)
    if path == n['CONTEXT'] or path.name == 'public-rail-b17.png':
        path = HERE/'coherence-assets/host-75d55275.png'
    if path.name == 'hangar-short-carrier.png':path=HERE/'coherence-assets/hangar-short-subordinate.png'
    if path.name == 'hangar-tall-carrier.png':path=HERE/'coherence-assets/hangar-tall-wallfixed.png'
    return original_ref(path)
n['ref']=current_ref
fonts={}
for size,weight in [(15,500),(18,600)]:
    f=ImageFont.truetype(str(n['ASSETS']/'fonts/NotoSansSC.ttf'),size);f.set_variation_by_axes([weight]);fonts[(size,weight)]=f
STATE='normal'
PLATE=''
row_records=[]
def card(y,category,index,name,path,level,current,after,mode,purchase,costs,reason,disabled,focus,empty=False):
    text,box,image,resource,button,compare=(n[k] for k in ['text','box','image','resource','button','compare_button'])
    insufficient=set()
    if STATE in ['poor','ten']:insufficient={'iron'}
    elif STATE=='evolution-poor':insufficient={'iron','matter'}
    elif STATE=='legacy-long-max-poor':insufficient={'matter'}
    denied=reason=='进化材料尚未开放'
    # One whole rectangular carrier replaces the former row tint/divider/left bar.
    s=box(350,y+2,432,90,'#d2ddd3' if focus else '#dce2d7','#397c85' if focus else '#65858a',0)
    s+=box(353,y+5,426,84,'none','#a8bbb2',0)
    s+=box(356,y+8,48,54,'#d6e0d8','#91aaa2',4)
    if not empty:s+=image(path,358,y+10,44,50)
    s+=box(410,y+6,216,26,'#dae3da','#91aaa2',4)
    s+=text(418,y+24,('武器' if category=='weapon' else '防御')+str(index+1)+' · '+name,16,n['INK'],600)
    s+=text(614,y+22,'⌄',18,n['TEAL'],500,'middle')
    if empty:
        row_records.append({'plate':PLATE,'slot':category+':'+str(index),'card_rect':[340,y+2,432,90],'empty':True,'visible_controls':['equipment_choice'],'fee_cells':[],'purchase_enabled':False,'admission_reason':'No installed object; Owner slot-level rule unchanged'})
        return s
    s+=text(642,y+24,'Lv.'+level,14,n['MUTED'],500)
    s+=compare(714,y+6,64)
    s+=text(410,y+50,'攻击力' if category=='weapon' else '容量',15,'#3e5d67',500)
    x=459
    s+=text(x,y+50,current,18,'#173c4e',600);x+=fonts[(18,600)].getlength(current)+9
    s+=text(x,y+50,'→',18,n['MUTED']);x+=27
    s+=text(x,y+50,after,18,'#173c4e',600)
    end=x+fonts[(18,600)].getlength(after)
    assert end<=778,(PLATE,current,after,end)
    # No permanent affordability reason; all resource cells share this bottom band.
    s+=text(356,y+82,'费用',15,'#284650',500)
    names={'iron':'铁','matter':'简并物质'}
    def cell_width(value):return 23+fonts[(15,500)].getlength(value)
    full_width=sum(cell_width(v) for _,v in costs)+12*max(0,len(costs)-1)
    compact=full_width>218
    x=392;cells=[]
    for kind,value in costs:
        label=value.removeprefix(names[kind]) if compact else value
        color='#a33725' if kind in insufficient else '#1e3e4c'
        width=cell_width(label)
        s+=resource(kind,x,y+76.25,20)+text(x+23,y+82,label,15,color,500)
        cells.append({'resource':kind,'display':label,'full_display':value,'name_omitted':compact,'insufficient':kind in insufficient,'rect':[x-10,y+64,width,24],'tooltip_delay_seconds':.5})
        x+=width+12
    if not costs:s+=text(x,y+82,'—',15,n['MUTED'])
    assert not costs or x-12<=610,(PLATE,costs,x)
    if denied:s+=text(420,y+82,reason,15,n['WARN'],500)
    s+=button(622,y+55,52,mode,height=33)+button(680,y+55,98,purchase,denied,height=33)
    row_records.append({'plate':PLATE,'slot':category+':'+str(index),'card_rect':[340,y+2,432,90],'attribute_baseline':y+50,'attribute_end_x':end-10,'fee_cells':cells,'purchase_rect':[670,y+55,98,33],'purchase_enabled':not denied,'admission_reason':reason if denied else '', 'shortage_click_feedback':'资源不足' if insufficient or STATE=='maxzero' else ''})
    return s
n['compact_row']=card
base_row=n['row']
def row(*args,**kwargs):
    global STATE
    STATE=kwargs.get('state',args[5] if len(args)>5 else 'normal')
    return base_row(*args,**kwargs)
n['row']=row

cases=[]
for num,stage,bottom,selected in [(63,'early',False,('weapon',0)),(64,'middle',False,('weapon',1)),(65,'late',False,('weapon',0)),(66,'late',True,('weapon',4)),(67,'late',True,('defence',1))]:
    cases.append((num,dict(stage=stage,scroll_bottom=bottom,selected_slot=selected)))
for num,state in [(68,'evolution-max'),(69,'evolution-locked'),(70,'evolution'),(71,'normal')]:cases.append((num,dict(stage='late',first_slot_state=state,selected_slot=('weapon',0))))
for num,flag,selected in [(72,'popup',('defence',1)),(73,'comparison',('defence',1)),(74,'weapon_popup',('weapon',0)),(75,'weapon_comparison',('weapon',0))]:
    cases.append((num,dict(stage='late',selected_slot=selected,**{flag:True},**({'first_slot_state':'normal'} if num in [74,75] else {}))))
for num,state in [(76,'hover'),(77,'pressed'),(78,'focus'),(79,'hover_pressed')]:
    cases.append((num,dict(stage='late',first_slot_state='evolution',selected_slot=('weapon',0),control_state={'rect':(680,367,98,33),'state':state})))
cases += [(80,dict(stage='late',empty_slot=True)),(81,dict(stage='middle',dormant_details=True)),(82,dict(stage='late',first_slot_state='legacy-long-max',selected_slot=('weapon',0))),(83,dict(stage='late',first_slot_state='legacy-long-max-poor',selected_slot=('weapon',0)))]
manifest=[]
env=dict(os.environ,FONTCONFIG_FILE='/tmp/space-idle-workbench-rebuild/fontconfig-local.xml')
for number,kwargs in cases+[(84,dict(stage='late',first_slot_state='legacy-long-max-poor',selected_slot=('weapon',0))),(85,dict(stage='late',first_slot_state='legacy-long-max-poor',selected_slot=('weapon',0)))]:
    PLATE=str(number)
    svg=n['plate'](weapon_scene=True,compact_workbench=True,shared_finish=True,**kwargs)
    if number==63:
        a=svg.index('<svg x="16" y="475" width="314" height="165"');b=svg.index('<text ',a)
        c=svg.index('<defs><clipPath id="paint',svg.index('x="-27" y="85"'))
        svg=svg[:c]+'<g transform="translate(0,-95)">'+svg[c:a]+'</g><g transform="translate(173,640) scale(1.5757575757575757) translate(-173,-640)">'+svg[a:b]+'</g>'+svg[b:]
    if number in [84,85]:
        if number==84:
            overlay=n['shared_panel'](430,207,348,44)+n['text'](604,235,'资源不足',18,'#f2e5c8',600,'middle')
        else:
            cell=next(r for r in row_records if r['plate']=='85' and r['slot']=='weapon:0')['fee_cells'][1]
            overlay=n['shared_panel'](502,405,276,42)+n['text'](516,432,'简并物质 · 需要 2,760',15,'#f0f2e9',500)
        svg=svg.rsplit('</svg>',1)[0]+overlay+'</svg>'
    file=next(HERE.glob(str(number)+'-host-return-*.svg')) if number<=83 else HERE/('84-insufficient-click-feedback.svg' if number==84 else '85-resource-hover-half-second.svg')
    file.write_text(svg)
    subprocess.run(['inkscape',str(file),'--export-type=png','--export-filename='+str(file.with_suffix('.png'))],env=env,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    im=Image.open(file.with_suffix('.png')).convert('RGB');host=Image.open(HERE/'coherence-assets/host-75d55275.png').convert('RGB')
    for rect in [(0,0,808,85),(808,0,1440,900)]:assert ImageChops.difference(im.crop(rect),host.crop(rect)).getbbox() is None
    manifest.append({'file':file.with_suffix('.png').name,'svg_sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'sha256':hashlib.sha256(file.with_suffix('.png').read_bytes()).hexdigest(),'actually_viewed':False})
(HERE/'rectangular-card-manifest.json').write_text(json.dumps({'scope':'static current21 +click feedback84 and delayed hover85, not runtime proof','original_design':'3946a1b8','rows':row_records,'plates':manifest,'shortage_fixture_note':'83/84/85 flip only matter insufficiency on the historical true quote, not new Owner sampling;65 uses both insufficient,63/64 iron insufficient.','feedback_semantics':'Insufficient funds remain clickable; Owner rejection later triggers transient toast, no history panel. Other admission denial stays disabled.'},ensure_ascii=False,indent=2)+'\n')
