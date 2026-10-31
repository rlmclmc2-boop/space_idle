#!/usr/bin/env python3
"""Static design plates only. No game imports, runtime, state or rules execution."""
import base64
import hashlib
import html
import json
import re
from pathlib import Path
from PIL import Image, ImageFont

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[4]
ASSETS = PROJECT / 'assets'
CONTEXT = HERE.parent / 'upgrade-group-coherence/00-fresh-current.png'
INK = '#193847'
TEAL = '#326272'
MUTED = '#49636c'
WARN = '#903d23'
used = {}


def ref(path):
    path = Path(path)
    data = path.read_bytes()
    used[str(path.relative_to(PROJECT))] = hashlib.sha256(data).hexdigest()
    mime = 'image/svg+xml' if path.suffix == '.svg' else 'image/png'
    return 'data:' + mime + ';base64,' + base64.b64encode(data).decode()


def text(x, y, value, size=14, color=INK, weight=400, anchor='start'):
    identity = 'ink' + hashlib.sha256(f'{x}:{y}:{value}'.encode()).hexdigest()[:12]
    family = 'Noto Sans Symbols' if str(value)=='⌄' else 'Noto Sans SC'
    return f'<text font-family="{family}" id="{identity}" x="{x}" y="{y}" font-size="{size}" fill="{color}" font-weight="{weight}" text-anchor="{anchor}">{html.escape(str(value))}</text>'


def box(x, y, w, h, fill, stroke='none', r=5):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}"/>'


def image(path, x, y, w, h, bounds=None):
    path = Path(path)
    if bounds is None:
        if path.suffix == '.svg':
            bounds = (0, 0, 128, 128)
        else:
            with Image.open(path) as im:
                b = im.getbbox()
                bounds = (b[0], b[1], b[2]-b[0], b[3]-b[1])
    a, b, c, d = bounds
    clip = 'crop' + hashlib.sha256(f'{path}:{bounds}:{x}:{y}'.encode()).hexdigest()[:12]
    return f'<svg x="{x}" y="{y}" width="{w}" height="{h}" viewBox="{a} {b} {c} {d}" overflow="hidden" preserveAspectRatio="xMidYMid meet"><defs><clipPath id="{clip}"><rect x="{a}" y="{b}" width="{c}" height="{d}"/></clipPath></defs><g clip-path="url(#{clip})"><image href="{ref(path)}" width="{Image.open(path).width if path.suffix != ".svg" else 128}" height="{Image.open(path).height if path.suffix != ".svg" else 128}"/></g></svg>'


def resource_geometry(kind, size):
    cells = {'iron': ('resource-material-atlas.png', (62,129,602,475)),
             'matter': ('resource-material-supplement.png', (983,117,723,669))}
    filename, bounds = cells[kind]
    path = ASSETS/'ui/public_shell'/filename
    a,b,w,h = bounds
    with Image.open(path) as im:
        alpha = im.crop((a,b,a+w,b+h)).getbbox()
    scale = size/max(w,h)
    visible_height = (alpha[3]-alpha[1])*scale
    offset = (size-h*scale)/2+alpha[1]*scale
    return path,bounds,visible_height,offset


def resource(kind, x, center_y, size=20):
    path,bounds,visible_height,offset = resource_geometry(kind,size)
    return image(path,x,center_y-visible_height/2-offset,size,size,bounds)


CAPACITY_PROFILES = {
    'early': {'weapon:0':2,'defence:0':2},
    'middle': {'weapon:0':2,'weapon:1':1,'weapon:2':2,'defence:0':1,'defence:1':1},
    'late': {'weapon:0':2,'weapon:1':1,'weapon:2':1,'weapon:3':1,'weapon:4':1,
             'defence:0':1,'defence:1':1,'defence:2':1},
}


def row_height(fee_capacity, compact=False):
    if compact: return 94
    return 108 if fee_capacity==2 else 84


EQUIPMENT = {
    'laser': ('脉冲炮', ASSETS/'weapons/fleet_20261019/laser.png', '350', '420', '1.5秒'),
    'missile': ('导弹', ASSETS/'weapons/fleet_20261019/missile.png', '170', '200', '2.4秒'),
    'cannon': ('舰炮', ASSETS/'weapons/fleet_20261019/cannon.png', '1,200', '1,400', '3.5秒'),
    'longLaser': ('长激光', ASSETS/'weapons/fleet_20261019/longLaser.png', '35', '45', '0.25秒'),
    'armour': ('装甲', ASSETS/'ui/equipment/cartoon_armour.svg', '1,000', '1,200', ''),
    'shield': ('护盾', ASSETS/'ui/equipment/cartoon_shield.svg', '750', '900', ''),
}


ship_scene_records = {}
compact_view_records = {}

def mounted_weapon_scene(stage, hull_key, weapons, x, y, width, height, selected_slot):
    """Read existing art geometry only; static composition, no new physical rule or mount."""
    sources = {}
    for relative in ['assets/ui/ships/manifest.json','assets/weapons/fleet_20261019/manifest.json']:
        path = PROJECT/relative
        used[relative]=hashlib.sha256(path.read_bytes()).hexdigest()
        sources[relative]=used[relative]
    catalog=json.loads((ASSETS/'ui/ships/manifest.json').read_text())['hulls'][hull_key]
    weapon_meta=json.loads((ASSETS/'weapons/fleet_20261019/manifest.json').read_text())['weapons']
    hull_path=PROJECT/catalog['texture'].replace('res://','')
    with Image.open(hull_path) as im: bounds=im.getbbox()
    bx,by,bw,bh=bounds[0],bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]
    factor=min(width/bw,height/bh)
    origin=(x+(width-bw*factor)/2-bx*factor,y+(height-bh*factor)/2-by*factor)
    zoom=factor/(350.0/float(catalog['height']))
    markup=''
    rows=[]
    for i,key in enumerate(weapons):
        if not key:continue
        meta=weapon_meta[key]; path=PROJECT/meta['texture'].replace('res://','')
        mx,my=catalog['mounts'][i]
        mount=(origin[0]+mx*factor,origin[1]+my*factor)
        wf=(0.16 if key in ['longLaser','cannon'] else 0.13)*zoom
        left=mount[0]-meta['anchor'][0]*wf; top=mount[1]-meta['anchor'][1]*wf
        with Image.open(path) as im: tw,th=im.size; ab=im.getbbox()
        markup+=f'<image href="{ref(path)}" width="{tw}" height="{th}" transform="translate({left},{top}) scale({wf})"/>'
        visible=[left+ab[0]*wf,top+ab[1]*wf,(ab[2]-ab[0])*wf,(ab[3]-ab[1])*wf]
        selected=selected_slot==('weapon',i)
        rows.append({'slot':f'weapon:{i}','key':key,'authored_mount':catalog['mounts'][i],'display_mount':mount,'authored_anchor':meta['anchor'],'weapon_factor':wf,'visible_rect':visible,'selected':selected})
        if selected:
            a,b,w,h=visible; a-=4;b-=4;w+=8;h+=8
            for cx,cy,dx,dy in [(a,b,1,1),(a+w,b,-1,1),(a+w,b+h,-1,-1),(a,b+h,1,-1)]:
                d=f'M{cx} {cy+dy*8} V{cy} H{cx+dx*8}'
                markup+=f'<path d="{d}" fill="none" stroke="#153341" stroke-width="3.5"/><path d="{d}" fill="none" stroke="#91e2d4" stroke-width="1.5"/>'
    identity=f'{stage}:{selected_slot}'
    ship_scene_records[identity]={'sources':sources,'hull_key':hull_key,'hull_visible_source_bounds':[bx,by,bw,bh],'hull_display_allocation':[x,y,width,height],'hull_canvas_origin':origin,'hull_scale':factor,'preview_zoom_from_existing_calibration':zoom,'selected_slot':selected_slot,'weapons':rows,'defence_ship_targets':[],'geometry_scope':'Existing manifest mounts/weapon anchors and equipment_panel.gd995–1040 calibration consumed under current static hull transform. Not a new battle/shared geometry or accepted parking anchor.'}
    return markup


SHARED_PAINT_ACTIVE=False
CONTROL_STATE_OVERRIDE=None


def shared_surface(x,y,w,h,state='normal',role='secondary'):
    if CONTROL_STATE_OVERRIDE and (x,y,w,h)==CONTROL_STATE_OVERRIDE['rect'] and state!='disabled':state=CONTROL_STATE_OVERRIDE['state']
    face=(x+2,y+2,w-4,h-4);a,b,c,d=face;cut=min(5,min(c,d)*.25)
    pts=[(a+cut,b),(a+c-cut,b),(a+c,b+cut),(a+c,b+d-cut),(a+c-cut,b+d),(a+cut,b+d),(a,b+d-cut),(a,b+cut)]
    points=' '.join(f'{u},{v}' for u,v in pts)
    tone='#819995' if state in ['pressed','hover_pressed','selected'] else '#253d47' if state=='disabled' else '#3c5c65' if state=='hover' else '#52695f' if role=='commit' else '#304d57'
    edge='#e5c784' if state=='focus' else '#b6d3cb' if state in ['hover','hover_pressed'] else '#577b81' if state=='disabled' else '#baa779' if role=='commit' else '#89a8a7'
    cid='paint'+hashlib.sha256(f'{x}:{y}:{w}:{h}:{state}:{role}'.encode()).hexdigest()[:14]
    atlas=ASSETS/'ui/equipment/materials-20261029/control-materials.png'
    with Image.open(atlas) as im:iw,ih=im.size
    table=' '.join(str(round(min(.94,max(.71,.44+1.6*i/100)),4)) for i in range(101))
    rgb=[int(tone[i:i+2],16)/255 for i in [1,3,5]]
    s=f'<defs><clipPath id="{cid}"><polygon points="{points}"/></clipPath><filter id="{cid}tone" color-interpolation-filters="sRGB"><feColorMatrix values=".2126 .7152 .0722 0 0 .2126 .7152 .0722 0 0 .2126 .7152 .0722 0 0 0 0 0 1 0"/><feComponentTransfer><feFuncR type="table" tableValues="{table}"/><feFuncG type="table" tableValues="{table}"/><feFuncB type="table" tableValues="{table}"/></feComponentTransfer><feColorMatrix values="{rgb[0]} 0 0 0 0 0 {rgb[1]} 0 0 0 0 0 {rgb[2]} 0 0 0 0 0 1 0"/></filter></defs>'
    s+=f'<g clip-path="url(#{cid})"><svg x="{a}" y="{b}" width="{c}" height="{d}" viewBox="120 800 1200 130" preserveAspectRatio="none"><image href="{ref(atlas)}" width="{iw}" height="{ih}" filter="url(#{cid}tone)"/></svg></g>'
    opacity=.88 if state=='focus' else .65 if state in ['hover','hover_pressed'] else .36 if state=='disabled' else .69 if role=='commit' else .47
    s+=f'<polygon points="{points}" fill="none" stroke="{edge}" stroke-opacity="{opacity}" stroke-width="{1.5 if state=="focus" else 1}"/>'
    upper=[pts[7],pts[0],pts[1],pts[2]];lower=[pts[3],pts[4],pts[5],pts[6]]
    s+='<polyline points="'+' '.join(f'{u},{v}' for u,v in upper)+'" fill="none" stroke="#e6e8d7" stroke-opacity="'+('.37' if role=='commit' else '.23')+'"/>'
    s+='<polyline points="'+' '.join(f'{u},{v}' for u,v in lower)+'" fill="none" stroke="#091b28" stroke-opacity=".55"/>'
    return s,state


def shared_panel(x,y,w,h):
    source=HERE/'coherence-assets/public-panel-frame.svg'
    markup=''
    sx=[0,18,110];sy=[0,18,110];sw=[18,92,18];sh=[18,92,18]
    dx=[x,x+18,x+w-18];dy=[y,y+18,y+h-18];dw=[18,w-36,18];dh=[18,h-36,18]
    for row in range(3):
        for col in range(3):
            cid='panelpiece'+hashlib.sha256(f'{x}:{y}:{w}:{h}:{row}:{col}'.encode()).hexdigest()[:14]
            markup+=f'<svg x="{dx[col]}" y="{dy[row]}" width="{dw[col]}" height="{dh[row]}" viewBox="{sx[col]} {sy[row]} {sw[col]} {sh[row]}" preserveAspectRatio="none" overflow="hidden"><defs><clipPath id="{cid}"><rect x="{sx[col]}" y="{sy[row]}" width="{sw[col]}" height="{sh[row]}"/></clipPath></defs><g clip-path="url(#{cid})"><image href="{ref(source)}" width="128" height="128"/></g></svg>'
    return markup


def button(x, y, width, caption, disabled=False, height=36):
    if SHARED_PAINT_ACTIVE:
        surface,state=shared_surface(x,y,width,height,'disabled' if disabled else 'normal','commit' if caption.startswith('购买') else 'secondary')
        ink='#9cb4b4' if disabled else '#19363d' if state in ['pressed','hover_pressed'] else '#ffffff' if state=='hover' else '#f0f2e9'
        return surface+text(x+width/2,y+height/2+5,caption,14,ink,600,'middle')
    return box(x,y,width,height,'url(#disabled)' if disabled else 'url(#button)', '#92a4a4') + text(x+width/2,y+height/2+5,caption,14,'#eaf0e8' if not disabled else '#f0f0e8',600,'middle')


def compare_button(x, y, width, height=32):
    if SHARED_PAINT_ACTIVE:
        surface,state=shared_surface(x,y,width,26 if height==32 else height)
        surface+=text(x+width/2,y+(18.25 if height==32 else 34),'比较',14 if height==32 else 16,'#f0f2e9',600,'middle')
        if height>32:surface+=text(x+width/2,y+59,'仅查看',14,'#b8cfca',400,'middle')
        return surface
    # Main-row proposed hit area stays32px; visible face26px aligns the identity ink.
    s = box(x,y,width,26 if height==32 else height,'#eef0e4','#6d9291',4)
    s += text(x+width/2,y+(18.25 if height==32 else 34),'比较',14 if height==32 else 16,TEAL,600,'middle')
    if height>32: s += text(x+width/2,y+59,'仅查看',14,MUTED,400,'middle')
    return s


def compact_row(y,category,index,name,path,level,current,after,mode,purchase,costs,reason,disabled,focus,empty=False):
    # The full two-resource quote and its reason share one cost band, with no blank fee row.
    s=(box(350,y,432,94,'#cfe0d6',r=0).replace('fill="#cfe0d6"','fill="#cfe0d6" fill-opacity=".28"') if focus else '') if SHARED_PAINT_ACTIVE else box(350,y,440,94,'#e0ebe3' if focus else '#e8e8dc',r=0)
    s+=f'<path d="M358 {y+93} H782" stroke="#b0bcb5"/>'
    if focus:s+=box(350,y,4,93,'#397e82',r=0)
    s+=box(356,y+8,48,58,'#d6e0d8','#91aaa2',4)
    if not empty:s+=image(path,358,y+10,44,54)
    s+=box(410,y+5,216,27,'#dae3da','#91aaa2',4)
    s+=text(418,y+24,('武器' if category=='weapon' else '防御')+str(index+1)+' · '+name,16,INK,600)
    s+=text(614,y+21,'⌄',18,TEAL,500,'middle')+text(642,y+24,'Lv.'+level,14,MUTED,500)
    s+=compare_button(720,y+5,62)
    if SHARED_PAINT_ACTIVE:
        s+=text(410,y+46,'攻击力' if category=='weapon' else '容量',15,'#3e5d67',500)+text(459,y+46,current,18,'#173c4e',600)
        s+=text(433,y+66,'→',18,MUTED)+text(459,y+66,after,18,'#173c4e',600)
    else:
        s+=text(410,y+50,'攻击力' if category=='weapon' else '容量',15,'#3e5d67',500)
        s+=text(459,y+50,current,18,'#173c4e',600)+text(526,y+50,'→',18,MUTED)+text(550,y+50,after,18,'#173c4e',600)
    s+=button(632,y+34,52,mode)+button(690,y+34,92,purchase,disabled)
    s+=text(410,y+86,'费用' if SHARED_PAINT_ACTIVE else '升级费',15,'#284650',500)
    measure=ImageFont.truetype(str(ASSETS/'fonts/NotoSansSC.ttf'),15)
    if SHARED_PAINT_ACTIVE:measure.set_variation_by_axes([500])
    x=444 if SHARED_PAINT_ACTIVE else 464
    if costs:
        for kind,value in costs:
            s+=resource(kind,x,y+80.25,20)+text(x+23,y+86,value,15,'#1e3e4c',500)
            x+=23+measure.getlength(value)+(10 if SHARED_PAINT_ACTIVE else 12)
    else:
        s+=text(x,y+86,'—',15,MUTED);x+=28
    if reason:
        s+=text(x,y+86,reason,15,WARN,600)
        x+=measure.getlength(reason)
    assert x<=782, f'Fixture cost/reason band exceeds its declared width: {x}'
    return s


def passive_row_fragment(y,height,viewport_top,viewport_bottom,category,index,key,state):
    # Never paint clipped purchase controls or a quote without its full object identity.
    top=max(y,viewport_top);bottom=min(y+height,viewport_bottom)
    if bottom<=top:return ''
    name='空槽' if state=='empty' else EQUIPMENT[key][0]
    level='19' if state.startswith(('evolution','legacy-long')) else '29' if state=='ten' else '33' if state=='maxzero' else '1'
    label=('武器' if category=='weapon' else '防御')+str(index+1)+' · '+name+' · Lv.'+level
    s='' if SHARED_PAINT_ACTIVE else box(350,top,440,bottom-top,'#dce4dc',r=0)
    if bottom-top>=16:s+=text(360,top+min(23,bottom-top-2),label,14,MUTED,500)
    return s


def row(y, category, index, key, fee_capacity, state='normal', focus=False, compact=False):
    name, path, current, after, interval = EQUIPMENT[key]
    level, mode, purchase, costs, reason = '1', '×1', '购买1级', [('iron','铁65')], ''
    disabled = False
    if state == 'poor': disabled, reason = True, '铁不足'
    if state in ['evolution','evolution-poor']:
        level,current,after,costs = '19','9,300','1.76万',[('iron','铁1,600'),('matter','简并物质10')]
        if state=='evolution-poor': disabled,reason=True,'资源不足'
    if state in ['evolution-ten','evolution-max','evolution-locked']:
        level,current = '19','9,300'
        if state=='evolution-ten':
            after,mode,purchase,costs = '9.28万','×10','购买10级',[('iron','铁4.15万'),('matter','简并物质10')]
        elif state=='evolution-max':
            after,mode,purchase,costs = '19.2万','MAX','购买14级',[('iron','铁9.44万'),('matter','简并物质10')]
        else:
            after,costs,disabled,reason = '—',[],True,'进化材料尚未开放'
    if state in ['legacy-long-max','legacy-long-max-poor']:
        level,current,after,mode,purchase,costs='19','9,300','1.556×10^43','MAX','购买444级',[('iron','铁1.145×10^39'),('matter','简并物质2,760')]
        if state=='legacy-long-max-poor':disabled,reason=True,'资源不足'
    if state == 'ten':
        level,current,after,mode,purchase,costs = '29','9.28万','57.6万','×10','购买10级',[('iron','铁25.79万')]
        disabled,reason = True,'铁不足'
    if state == 'maxzero':
        level,current,after,mode,purchase,costs = '33','19.2万','—','MAX','可购0级',[]
        disabled,reason = True,'当前预算不可购'
    if state=='empty': name,current,after='空槽','—','—'
    if compact:return compact_row(y,category,index,name,path,level,current,after,mode,purchase,costs,reason,disabled,focus,state=='empty')
    # Geometry follows the fixed presentation budget, never affordability/reason text.
    dense = fee_capacity==2
    height = row_height(fee_capacity)
    assert len(costs)<=fee_capacity, 'This static budget does not cover this quote.'
    # A single workbench surface with quiet separators; each row retains its own targets.
    s = box(350,y,440,height,'#e0ebe3' if focus else '#e8e8dc',r=0)
    s += f'<path d="M358 {y+height-1} H782" stroke="#b0bcb5"/>'
    if focus: s += box(350,y,4,height-1,'#397e82',r=0)
    s += box(356,y+8,48,58,'#d6e0d8','#91aaa2',4)
    if state!='empty': s += image(path,358,y+10,44,54)
    # Identity is one clear name target; Lv remains a distinct adjacent reading.
    s += box(410,y+5,216,27,'#dae3da','#91aaa2',4)
    s += text(418,y+24,('武器' if category=='weapon' else '防御')+str(index+1)+' · '+name,16,INK,600)
    s += text(614,y+21,'⌄',18,TEAL,500,'middle')
    s += text(642,y+24,'Lv.'+level,14,MUTED,500)
    s += compare_button(720,y+5,62)
    # Shared three baselines: identity24 / benefit47 / cost73. Fee rows never touch benefit ink.
    s += text(410,y+47,'攻击力' if category=='weapon' else '容量',15,'#3e5d67',500)
    s += text(459,y+47,current,18,'#173c4e',600)+text(526,y+47,'→',18,MUTED)+text(550,y+47,after,18,'#173c4e',600)
    s += text(410,y+73,'升级费',15,'#284650',500)
    for i,(kind,value) in enumerate(costs):
        s += resource(kind,464,y+67.25+i*22,20)+text(487,y+73+i*22,value,15,'#1e3e4c',500)
    if not costs: s += text(470,y+73,'—',15,MUTED)
    action_y = 48 if dense else 42
    s += button(632,y+action_y,52,mode)+button(690,y+action_y,92,purchase,disabled)
    if reason:
        if dense:
            s += text(632,y+100,reason,15,WARN,600)
        else:
            assert len(reason)<=5, 'Longer reason needs another static budget design.'
            # Single-fee reason stays beside its resource, leaving identity and control bands clear.
            s += text(550,y+73,reason,15,WARN,600)
    return s


def plate(stage, popup=False, affordability_override=False, switched=False, comparison=False, scroll_bottom=False, capacity_example=None, weapon_popup=False, weapon_comparison=False, empty_slot=False, dormant_details=False, weapon_scene=False, selected_slot=None, compact_workbench=False, first_slot_state=None, shared_finish=False, control_state=None):
    global SHARED_PAINT_ACTIVE, CONTROL_STATE_OVERRIDE
    SHARED_PAINT_ACTIVE=shared_finish
    CONTROL_STATE_OVERRIDE=control_state
    hull, title, height = {'early':('01-frigate','游隼侦察艇',165),
                           'middle':('03-cruiser','云鳐巡洋舰',286),
                           'late':('05-heavy-battleship','白鲸无畏舰',336)}[stage]
    weapons = {'early':['laser'],'middle':['laser','missile','laser'],
               'late':['laser','missile','cannon','longLaser','laser']}[stage]
    defence = ['armour'] if stage == 'early' else ['armour','shield'] if stage == 'middle' else ['armour','shield','shield']
    if switched: defence[1]='armour'
    console_top = ({'early':398,'middle':260,'late':260} if shared_finish else {'early':320,'middle':280,'late':280})[stage]
    states = {}
    for cat,keys in [('weapon',weapons),('defence',defence)]:
        for i,_ in enumerate(keys):
            state='poor' if stage=='early' else 'normal'
            if stage=='middle' and cat=='weapon' and i==0: state='ten'
            if stage=='middle' and cat=='weapon' and i==2: state='maxzero'
            if stage=='late' and cat=='weapon' and i==0: state='evolution-poor'
            if affordability_override and stage=='late' and cat=='weapon' and i==1: state='poor'
            states[(cat,i)]=state
    capacities = CAPACITY_PROFILES[stage].copy()
    if capacity_example is not None and capacity_example.startswith('reserved-'):
        # Lifecycle-safe capacity proposal: reserve current config's2fees up front for every slot.
        capacities={slot_id:2 for slot_id in capacities}
        states[('weapon',0)]={'reserved-base':'normal','reserved-evolution':'evolution','reserved-locked':'evolution-locked'}[capacity_example]
    elif capacity_example is not None:
        # Separate preset design fixture, never automatic promotion from quote/reason.
        capacities['weapon:4']=2
        states[('weapon',4)]='evolution-locked' if capacity_example=='locked' else 'evolution'
        states[('weapon',0)]={'single':'evolution','ten':'evolution-ten','max':'evolution-max','locked':'evolution-locked'}[capacity_example]
    if compact_workbench: capacities={slot_id:2 for slot_id in capacities}
    if first_slot_state is not None: states[('weapon',0)]=first_slot_state
    if empty_slot: states[('weapon',0)]='empty'
    content_height = 2*(18+1) + sum(row_height(v,compact_workbench) for v in capacities.values())
    viewport_height = min(content_height,510 if shared_finish else 523)
    console_bottom = console_top + 34 + viewport_height + 7
    scroll_offset = content_height-viewport_height if scroll_bottom or popup or switched or comparison else 0
    s = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1440" height="900" viewBox="0 0 1440 900"><defs>'
    s += '<linearGradient id="face" x2="0" y2="1"><stop stop-color="#f1efdf"/><stop offset="1" stop-color="#d4d9d1"/></linearGradient><linearGradient id="button" x2="0" y2="1"><stop stop-color="#507786"/><stop offset="1" stop-color="#294957"/></linearGradient><linearGradient id="disabled" x2="0" y2="1"><stop stop-color="#9eaba9"/><stop offset="1" stop-color="#83928f"/></linearGradient>'
    s += '<clipPath id="header"><rect width="808" height="85"/></clipPath><clipPath id="battle"><rect x="808" width="632" height="900"/></clipPath><clipPath id="module"><rect y="85" width="808" height="815"/></clipPath><clipPath id="stage"><rect y="85" width="302" height="815"/></clipPath></defs><g font-family="Noto Sans SC, sans-serif">'
    # Unchanged screenshot regions are context, not a new battle/nav proposal.
    for clip in ['header','battle']:
        context=HERE/'coherence-assets/public-rail-b17.png' if shared_finish and clip=='header' else CONTEXT
        s += f'<image href="{ref(context)}" width="1440" height="900" clip-path="url(#{clip})"/>'
    s += '<g clip-path="url(#module)">'+box(0,85,808,815,'#324a57',r=0)
    if shared_finish:
        background=HERE/('coherence-assets/hangar-short-carrier.png' if stage=='early' else 'coherence-assets/hangar-tall-carrier.png')
        s+=f'<image href="{ref(background)}" x="-27" y="85" width="843.2" height="815" preserveAspectRatio="none"/>'
        identity_top=(640 if stage=='early' else 680)-height-83
        s+=shared_surface(16,identity_top,309,72)[0]+text(30,identity_top+28,title,21,'#f2eedb',600)+text(30,identity_top+53,f'武器 {len(weapons)}  ·  防御 {len(defence)}',14,'#c9ded9')
    else:
        s += f'<svg x="0" y="85" width="808" height="815" viewBox="0 0 1188 845" preserveAspectRatio="xMidYMid slice"><image href="{ref(ASSETS / "ui/equipment/hangar/hangar-console.png")}" width="1188" height="1324"/></svg>'
        s += box(16,104,309,72,'#274957', '#587882')+text(30,132,title,21,'#f2eedb',600)+text(30,157,f'武器 {len(weapons)}  ·  防御 {len(defence)}',14,'#c9ded9')
    ship_y=(640 if stage=='early' else 680)-height
    s += image(ASSETS/f'ui/ships/fleet_20261019/{hull}.png',16,ship_y,314,height)
    if weapon_scene:
        hull_key={'early':'Frigate','middle':'Cruiser','late':'Heavy_Battleship'}[stage]
        scene_weapons=weapons.copy()
        if empty_slot:scene_weapons[0]=''
        s += mounted_weapon_scene(stage,hull_key,scene_weapons,16,ship_y,314,height,selected_slot)
    s += text(20,853,'表现候选 · 静态设计稿',13,'#f0e9d3',500)
    s += '<g transform="translate(-10,0)">'
    if not shared_finish:s += box(342,console_top,456,console_bottom-console_top,'#34525e','#8faaa9',9)+box(348,console_top+6,444,console_bottom-console_top-12,'url(#face)','#a3b3ab',7)
    s += text(376 if shared_finish else 356,console_top+25,'逐槽工作台',20,INK,600)
    s += button(686,console_top+2,96,'全部升级',height=30)
    if shared_finish and stage=='late':s+=text(548,console_top+25,'↑ 返回武器' if scroll_offset else '↓ 防御还有3槽',14,'#315768',500)
    body_top=console_top+34
    s += f'<defs><clipPath id="row-viewport"><rect x="350" y="{body_top}" width="440" height="{viewport_height}"/></clipPath></defs><g clip-path="url(#row-viewport)">'
    y=body_top-scroll_offset
    compact_rows=[]
    for cat, keys in [('weapon',weapons),('defence',defence)]:
        s += box(350,y,432 if shared_finish else 440,16,'#304d57' if shared_finish else '#355c68',r=3)+text(360,y+13,('武器' if cat=='weapon' else '防御')+' · '+str(len(keys)),14,'#eef0df',500)
        y += 18
        for i,key in enumerate(keys):
            state=states[(cat,i)]
            capacity=capacities[f'{cat}:{i}']
            full_row=(y>=body_top and y+row_height(capacity,compact_workbench)<=body_top+viewport_height)
            if compact_workbench:compact_rows.append({'slot':f'{cat}:{i}','row_y':y,'height':94,'fully_visible':full_row,'operable_targets_drawn':full_row,'partial_identity_only':not full_row and y<body_top+viewport_height and y+94>body_top})
            if compact_workbench and not full_row:
                s += passive_row_fragment(y,row_height(capacity,True),body_top,body_top+viewport_height,cat,i,key,state)
            else:
                s += row(y,cat,i,key,capacity,state,focus=((cat=='defence' and i==1 and popup) or selected_slot==(cat,i)),compact=compact_workbench)
            y += row_height(capacity,compact_workbench)
        y += 1
    s += '</g>'
    if compact_workbench:
        identity=str((stage,scroll_bottom,selected_slot,first_slot_state,popup,comparison,weapon_popup,weapon_comparison,shared_finish))
        compact_view_records[identity]={'stage':stage,'body_top':body_top,'viewport_height':viewport_height,'content_height':content_height,'scroll_offset':scroll_offset,'rows':compact_rows,'no_partial_purchase_controls':True}
    if content_height>viewport_height:
        track=viewport_height
        thumb=track*viewport_height/content_height
        thumb_y=body_top+scroll_offset/(content_height-viewport_height)*(track-thumb)
        s += box(790,body_top,6,track,'#31505b' if shared_finish else '#b0c1b8',r=3)+box(789 if shared_finish else 790,thumb_y,8 if shared_finish else 6,thumb,'#cbb47f' if shared_finish else '#345d68',r=3)
    if popup:
        # Anchored upward because defence2 is near the lower edge. Underlying rows do not move.
        py=(372 if shared_finish else 405) if compact_workbench else 425
        s += shared_panel(402,py,386,238) if shared_finish else box(402,py,386,238,'#244450','#10303f',7)
        s += '<path d="M600 610 L614 620 L626 610Z" fill="#244450"/>' if shared_finish else '<path d="M600 643 L614 653 L626 643Z" fill="#244450"/>' if compact_workbench else '<path d="M600 663 L614 673 L626 663Z" fill="#244450"/>'
        s += text(416,py+27,'防御2 · 同槽Lv.1',16,'#f4f0df',500)
        s += button(746,py+7,32,'×',height=30)
        for k,yy,current in [('shield',py+42,True),('armour',py+136,False)]:
            name,path,value,_,_=EQUIPMENT[k]
            # Two separate target boxes, no whole-row click handler spanning the compare target.
            s += box(410,yy,268,84,'#e0e8de' if current else '#f1efdf','#aac1b8')
            s += image(path,420,yy+14,42,50)+text(474,yy+25,name,18,INK,500)
            # Center the capacity ink between the title and status ink in these examples.
            s += text(474,yy+48+(0.995 if current else 0.127),'容量 '+value,16,MUTED)
            s += text(474,yy+71,'✓ 现装' if current else '点选即切换',14,TEAL,500)
            s += compare_button(688,yy,90,height=84)
    if comparison:
        # Optional reading target, separate from direct candidate selection. No confirmation action.
        py=(372 if shared_finish else 405) if compact_workbench else 425
        s += shared_panel(402,py,386,238) if shared_finish else box(402,py,386,238,'#244450','#10303f',7)
        s += text(416,py+27,'防御2 · 容量比较',16,'#f4f0df',600)
        s += button(746,py+7,32,'×',height=30)
        for key,yy,status in [('shield',py+46,'当前'),('armour',py+138,'候选')]:
            name,path,value,_,_=EQUIPMENT[key]
            s += box(412,yy,366,82,'#e8e8dc','#91aaa2',4)
            s += image(path,424,yy+13,44,54)
            s += text(484,yy+24,status+' · '+name,16,INK,600)
            s += text(484,yy+57,'容量',15,'#3e5d67',500)
            s += text(542,yy+57,value,18,'#173c4e',600)
            s += text(724,yy+24,'Lv.1',14,MUTED,500)
    if weapon_popup:
        py=356 if shared_finish else 376
        s += shared_panel(402,py,386,418) if shared_finish else box(402,py,386,418,'#244450','#10303f',7)
        s += '<path d="M600 356 L614 346 L626 356Z" fill="#244450"/>' if shared_finish else '<path d="M600 376 L614 366 L626 376Z" fill="#244450"/>'
        s += text(416,py+27,'武器1 · 同槽Lv.1',16,'#f4f0df',600)
        s += button(746,py+7,32,'×',height=30)
        for i,key in enumerate(['laser','missile','cannon','longLaser']):
            name,path,value,_,period=EQUIPMENT[key]
            yy=py+42+i*94
            s += box(410,yy,268,84,'#e0e8de' if key=='laser' else '#f1efdf','#aac1b8')
            s += image(path,420,yy+15,42,54)
            s += text(474,yy+23,name,18,INK,600)
            if key=='laser': s += text(606,yy+23,'现装',14,TEAL,500)
            s += text(474,yy+46,'攻击力 '+value,15,'#3e5d67',500)
            s += text(474,yy+69,'周期 '+period,15,'#3e5d67',500)
            s += compare_button(688,yy,90,height=84)
    if weapon_comparison:
        py=356 if shared_finish else 376
        s += shared_panel(402,py,386,238) if shared_finish else box(402,py,386,238,'#244450','#10303f',7)
        s += text(416,py+27,'武器1 · 同槽比较',16,'#f4f0df',600)
        s += button(746,py+7,32,'×',height=30)
        for key,yy,status in [('laser',py+46,'当前'),('missile',py+138,'候选')]:
            name,path,value,_,period=EQUIPMENT[key]
            s += box(412,yy,366,82,'#e8e8dc','#91aaa2',4)
            s += image(path,424,yy+14,44,54)
            s += text(484,yy+23,status+' · '+name,16,INK,600)
            s += text(484,yy+48,'攻击力 '+value,16,'#173c4e',600)
            s += text(630,yy+48,'周期 '+period,15,'#3e5d67',500)
            s += text(724,yy+23,'Lv.1',14,MUTED,500)
    if dormant_details:
        # Optional tooltip on existing hull identity, no extra permanent pane or action.
        details_top=((640 if stage=='early' else 680)-height-244) if shared_finish else 184
        s += shared_panel(26,details_top,309,152) if shared_finish else box(26,details_top,309,152,'#244450','#10303f',6)
        s += text(40,details_top+28,'未启用槽',16,'#f4f0df',600)
        for offset,label in [(58,'武器4 · 长激光 · Lv.1'),(90,'武器5 · 脉冲炮 · Lv.19'),(122,'防御3 · 护盾 · Lv.1')]:
            s += text(40,details_top+offset,label,15,'#dce7df',500)
    s += '</g></g></g></svg>'
    # Preserve embedded originals once per SVG, rather than repeating atlas bytes per row.
    embedded = {}
    definitions = []
    def deduplicate(match):
        url, w, h, extra = match.groups()
        key = (url, w, h)
        if key not in embedded:
            identity = 'asset' + str(len(embedded))
            embedded[key] = identity
            definitions.append(f'<image id="{identity}" href="{url}" width="{w}" height="{h}"/>')
        return f'<use href="#{embedded[key]}"{extra}/>'
    s = re.sub(r'<image href="(data:[^"]+)" width="(\d+)" height="(\d+)"([^>]*)/>',deduplicate,s)
    return s.replace('</defs>', ''.join(definitions)+'</defs>',1)


for name,stage,popup in [('01-early-two','early',False),('02-middle-five','middle',False),('03-late-eight','late',False),('04-local-dropdown','late',True)]:
    (HERE/(name+'.svg')).write_text(plate(stage,popup),encoding='utf-8')
(HERE/'05-late-affordability-only.svg').write_text(plate('late',affordability_override=True),encoding='utf-8')
(HERE/'06-local-switch-accepted.svg').write_text(plate('late',switched=True),encoding='utf-8')
(HERE/'07-optional-comparison.svg').write_text(plate('late',comparison=True),encoding='utf-8')
(HERE/'08-late-scroll-bottom.svg').write_text(plate('late',scroll_bottom=True),encoding='utf-8')
for suffix,example,bottom in [('09-two-dense-single','single',False),('10-two-dense-ten','ten',False),('11-two-dense-max','max',False),('12-evolution-material-locked','locked',False),('13-two-dense-bottom','single',True)]:
    (HERE/(suffix+'.svg')).write_text(plate('late',scroll_bottom=bottom,capacity_example=example),encoding='utf-8')
for suffix,example,bottom in [('14-reserved-two-fee-base','reserved-base',False),('15-reserved-two-fee-evolution','reserved-evolution',False),('16-reserved-two-fee-locked','reserved-locked',False),('17-reserved-two-fee-bottom','reserved-base',True)]:
    (HERE/(suffix+'.svg')).write_text(plate('late',scroll_bottom=bottom,capacity_example=example),encoding='utf-8')
(HERE/'18-local-weapon-dropdown.svg').write_text(plate('late',capacity_example='reserved-base',weapon_popup=True),encoding='utf-8')
(HERE/'19-optional-weapon-comparison.svg').write_text(plate('late',capacity_example='reserved-base',weapon_comparison=True),encoding='utf-8')
(HERE/'20-middle-reserved-two-fee.svg').write_text(plate('middle',capacity_example='reserved-base'),encoding='utf-8')
(HERE/'21-middle-reserved-two-fee-bottom.svg').write_text(plate('middle',scroll_bottom=True,capacity_example='reserved-base'),encoding='utf-8')
(HERE/'22-active-empty-slot.svg').write_text(plate('late',capacity_example='reserved-base',empty_slot=True),encoding='utf-8')
(HERE/'23-dormant-slot-details.svg').write_text(plate('middle',capacity_example='reserved-base',dormant_details=True),encoding='utf-8')
for suffix,stage,bottom,selection in [('29-compact-scene-early','early',False,('weapon',0)),('30-compact-scene-middle','middle',False,('weapon',1)),('31-compact-scene-late','late',False,('weapon',0)),('32-compact-scene-bottom','late',True,('weapon',4)),('33-compact-defence-row-only','late',True,('defence',1))]:
    (HERE/(suffix+'.svg')).write_text(plate(stage,scroll_bottom=bottom,weapon_scene=True,selected_slot=selection,compact_workbench=True),encoding='utf-8')
for suffix,state in [('34-compact-max','evolution-max'),('35-compact-material-locked','evolution-locked'),('36-compact-affordable','evolution'),('37-compact-single-fee','normal')]:
    (HERE/(suffix+'.svg')).write_text(plate('late',weapon_scene=True,selected_slot=('weapon',0),compact_workbench=True,first_slot_state=state),encoding='utf-8')
(HERE/'38-compact-defence-dropdown.svg').write_text(plate('late',popup=True,weapon_scene=True,compact_workbench=True,selected_slot=('defence',1)),encoding='utf-8')
(HERE/'39-compact-defence-comparison.svg').write_text(plate('late',comparison=True,weapon_scene=True,compact_workbench=True,selected_slot=('defence',1)),encoding='utf-8')
(HERE/'40-compact-weapon-dropdown.svg').write_text(plate('late',weapon_popup=True,weapon_scene=True,compact_workbench=True,first_slot_state='normal',selected_slot=('weapon',0)),encoding='utf-8')
(HERE/'41-compact-weapon-comparison.svg').write_text(plate('late',weapon_comparison=True,weapon_scene=True,compact_workbench=True,first_slot_state='normal',selected_slot=('weapon',0)),encoding='utf-8')
for suffix,stage,bottom,selection in [('42-coherent-early','early',False,('weapon',0)),('43-coherent-middle','middle',False,('weapon',1)),('44-coherent-late','late',False,('weapon',0)),('45-coherent-bottom','late',True,('weapon',4)),('46-coherent-defence','late',True,('defence',1))]:
    (HERE/(suffix+'.svg')).write_text(plate(stage,scroll_bottom=bottom,weapon_scene=True,selected_slot=selection,compact_workbench=True,shared_finish=True),encoding='utf-8')
for suffix,state in [('47-coherent-max','evolution-max'),('48-coherent-material-locked','evolution-locked'),('49-coherent-affordable','evolution'),('50-coherent-single-fee','normal')]:
    (HERE/(suffix+'.svg')).write_text(plate('late',weapon_scene=True,selected_slot=('weapon',0),compact_workbench=True,first_slot_state=state,shared_finish=True),encoding='utf-8')
(HERE/'51-coherent-defence-dropdown.svg').write_text(plate('late',popup=True,weapon_scene=True,compact_workbench=True,selected_slot=('defence',1),shared_finish=True),encoding='utf-8')
(HERE/'52-coherent-defence-comparison.svg').write_text(plate('late',comparison=True,weapon_scene=True,compact_workbench=True,selected_slot=('defence',1),shared_finish=True),encoding='utf-8')
(HERE/'53-coherent-weapon-dropdown.svg').write_text(plate('late',weapon_popup=True,weapon_scene=True,compact_workbench=True,first_slot_state='normal',selected_slot=('weapon',0),shared_finish=True),encoding='utf-8')
(HERE/'54-coherent-weapon-comparison.svg').write_text(plate('late',weapon_comparison=True,weapon_scene=True,compact_workbench=True,first_slot_state='normal',selected_slot=('weapon',0),shared_finish=True),encoding='utf-8')
for num,state in [('55','hover'),('56','pressed'),('57','focus'),('58','hover_pressed')]:
    (HERE/(num+'-coherent-purchase-'+state+'.svg')).write_text(plate('late',weapon_scene=True,compact_workbench=True,first_slot_state='evolution',selected_slot=('weapon',0),shared_finish=True,control_state={'rect':(690,346,92,36),'state':state}),encoding='utf-8')
(HERE/'59-coherent-active-empty.svg').write_text(plate('late',weapon_scene=True,compact_workbench=True,empty_slot=True,shared_finish=True),encoding='utf-8')
(HERE/'60-coherent-dormant-details.svg').write_text(plate('middle',weapon_scene=True,compact_workbench=True,dormant_details=True,shared_finish=True),encoding='utf-8')
(HERE/'ship-weapon-layout.json').write_text(json.dumps(ship_scene_records,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(HERE/'compact-row-boundaries.json').write_text(json.dumps(compact_view_records,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for num,state in [('61','legacy-long-max'),('62','legacy-long-max-poor')]:
    (HERE/(num+'-coherent-long-max'+('-poor' if num=='62' else '')+'.svg')).write_text(plate('late',weapon_scene=True,compact_workbench=True,first_slot_state=state,selected_slot=('weapon',0),shared_finish=True),encoding='utf-8')
used['assets/fonts/NotoSansSC.ttf'] = hashlib.sha256((ASSETS/'fonts/NotoSansSC.ttf').read_bytes()).hexdigest()
(HERE/'reference-hashes.json').write_text(json.dumps(used,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
# Existing repository family, private render configuration only; no system install.
fontconfig = Path('/tmp/space-idle-workbench-rebuild/fontconfig-local.xml')
fontconfig.parent.mkdir(parents=True,exist_ok=True)
fontconfig.write_text('<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig><include ignore_missing="yes">/etc/fonts/fonts.conf</include><dir>'+str(ASSETS/'fonts')+'</dir><cachedir>/tmp/space-idle-workbench-rebuild/font-cache</cachedir></fontconfig>')
