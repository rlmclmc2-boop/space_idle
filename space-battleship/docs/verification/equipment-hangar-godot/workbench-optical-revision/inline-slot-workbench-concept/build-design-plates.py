#!/usr/bin/env python3
"""Static design plates only. No game imports, runtime, state or rules execution."""
import base64
import hashlib
import html
import json
import re
from pathlib import Path
from PIL import Image

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


def row_height(fee_capacity):
    return 108 if fee_capacity==2 else 84


EQUIPMENT = {
    'laser': ('脉冲炮', ASSETS/'weapons/fleet_20261019/laser.png', '350', '420', '1.5秒'),
    'missile': ('导弹', ASSETS/'weapons/fleet_20261019/missile.png', '170', '200', '2.4秒'),
    'cannon': ('舰炮', ASSETS/'weapons/fleet_20261019/cannon.png', '1,200', '1,400', '3.5秒'),
    'longLaser': ('长激光', ASSETS/'weapons/fleet_20261019/longLaser.png', '35', '45', '0.25秒'),
    'armour': ('装甲', ASSETS/'ui/equipment/cartoon_armour.svg', '1,000', '1,200', ''),
    'shield': ('护盾', ASSETS/'ui/equipment/cartoon_shield.svg', '750', '900', ''),
}


def button(x, y, width, caption, disabled=False, height=36):
    return box(x,y,width,height,'url(#disabled)' if disabled else 'url(#button)', '#92a4a4') + text(x+width/2,y+height/2+5,caption,14,'#eaf0e8' if not disabled else '#f0f0e8',600,'middle')


def compare_button(x, y, width, height=32):
    # Main-row proposed hit area stays32px; visible face26px aligns the identity ink.
    s = box(x,y,width,26 if height==32 else height,'#eef0e4','#6d9291',4)
    s += text(x+width/2,y+(18.25 if height==32 else 34),'比较',14 if height==32 else 16,TEAL,600,'middle')
    if height>32: s += text(x+width/2,y+59,'仅查看',14,MUTED,400,'middle')
    return s


def row(y, category, index, key, fee_capacity, state='normal', focus=False):
    name, path, current, after, interval = EQUIPMENT[key]
    level, mode, purchase, costs, reason = '1', '×1', '购买1级', [('iron','铁65')], ''
    disabled = False
    if state == 'poor': disabled, reason = True, '铁不足'
    if state in ['evolution','evolution-poor']:
        level,current,after,costs = '19','9,300','1.76万',[('iron','铁1,600'),('matter','简并物质10')]
        if state=='evolution-poor': disabled,reason=True,'资源不足'
    if state == 'ten':
        level,current,after,mode,purchase,costs = '29','9.28万','57.6万','×10','购买10级',[('iron','铁25.79万')]
        disabled,reason = True,'铁不足'
    if state == 'maxzero':
        level,current,after,mode,purchase,costs = '33','19.2万','—','MAX','可购0级',[]
        disabled,reason = True,'当前预算不可购'
    # Geometry follows the fixed presentation budget, never affordability/reason text.
    dense = fee_capacity==2
    height = row_height(fee_capacity)
    assert len(costs)<=fee_capacity, 'This static budget does not cover this quote.'
    # A single workbench surface with quiet separators; each row retains its own targets.
    s = box(350,y,440,height,'#e0ebe3' if focus else '#e8e8dc',r=0)
    s += f'<path d="M358 {y+height-1} H782" stroke="#b0bcb5"/>'
    if focus: s += box(350,y,4,height-1,'#397e82',r=0)
    s += box(356,y+8,48,58,'#d6e0d8','#91aaa2',4)
    s += image(path,358,y+10,44,54)
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


def plate(stage, popup=False, affordability_override=False, switched=False, comparison=False):
    hull, title, height = {'early':('01-frigate','游隼侦察艇',165),
                           'middle':('03-cruiser','云鳐巡洋舰',286),
                           'late':('05-heavy-battleship','白鲸无畏舰',336)}[stage]
    weapons = {'early':['laser'],'middle':['laser','missile','laser'],
               'late':['laser','missile','cannon','longLaser','laser']}[stage]
    defence = ['armour'] if stage == 'early' else ['armour','shield'] if stage == 'middle' else ['armour','shield','shield']
    if switched: defence[1]='armour'
    console_top = {'early':320,'middle':200,'late':105}[stage]
    states = {}
    for cat,keys in [('weapon',weapons),('defence',defence)]:
        for i,_ in enumerate(keys):
            state='poor' if stage=='early' else 'normal'
            if stage=='middle' and cat=='weapon' and i==0: state='ten'
            if stage=='middle' and cat=='weapon' and i==2: state='maxzero'
            if stage=='late' and cat=='weapon' and i==0: state='evolution-poor'
            if affordability_override and stage=='late' and cat=='weapon' and i==1: state='poor'
            states[(cat,i)]=state
    capacities = CAPACITY_PROFILES[stage]
    console_bottom = console_top + 34 + 2*(18+1) + sum(row_height(v) for v in capacities.values()) + 7
    s = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1440" height="900" viewBox="0 0 1440 900"><defs>'
    s += '<linearGradient id="face" x2="0" y2="1"><stop stop-color="#f1efdf"/><stop offset="1" stop-color="#d4d9d1"/></linearGradient><linearGradient id="button" x2="0" y2="1"><stop stop-color="#507786"/><stop offset="1" stop-color="#294957"/></linearGradient><linearGradient id="disabled" x2="0" y2="1"><stop stop-color="#9eaba9"/><stop offset="1" stop-color="#83928f"/></linearGradient>'
    s += '<clipPath id="header"><rect width="808" height="85"/></clipPath><clipPath id="battle"><rect x="808" width="632" height="900"/></clipPath><clipPath id="module"><rect y="85" width="808" height="815"/></clipPath><clipPath id="stage"><rect y="85" width="302" height="815"/></clipPath></defs><g font-family="Noto Sans SC, sans-serif">'
    # Unchanged screenshot regions are context, not a new battle/nav proposal.
    for clip in ['header','battle']:
        s += f'<image href="{ref(CONTEXT)}" width="1440" height="900" clip-path="url(#{clip})"/>'
    s += '<g clip-path="url(#module)">'+box(0,85,808,815,'#324a57',r=0)
    s += f'<svg x="0" y="85" width="808" height="815" viewBox="0 0 1188 845" preserveAspectRatio="xMidYMid slice"><image href="{ref(ASSETS / "ui/equipment/hangar/hangar-console.png")}" width="1188" height="1324"/></svg>'
    s += box(16,104,309,72,'#274957', '#587882')+text(30,132,title,21,'#f2eedb',600)+text(30,157,f'武器 {len(weapons)}  ·  防御 {len(defence)}',14,'#c9ded9')
    s += image(ASSETS/f'ui/ships/fleet_20261019/{hull}.png',16,640-height,314,height)
    s += text(20,853,'表现候选 · 静态设计稿',13,'#f0e9d3',500)
    s += '<g transform="translate(-10,0)">'
    s += box(342,console_top,456,console_bottom-console_top,'#34525e','#8faaa9',9)+box(348,console_top+6,444,console_bottom-console_top-12,'url(#face)','#a3b3ab',7)
    s += text(356,console_top+25,'逐槽工作台',20,INK,600)
    s += button(686,console_top+2,96,'全部升级',height=30)
    y=console_top+34
    for cat, keys in [('weapon',weapons),('defence',defence)]:
        s += box(350,y,440,16,'#355c68',r=3)+text(360,y+13,('武器' if cat=='weapon' else '防御')+' · '+str(len(keys)),14,'#eef0df',500)
        y += 18
        for i,key in enumerate(keys):
            state=states[(cat,i)]
            capacity=capacities[f'{cat}:{i}']
            s += row(y,cat,i,key,capacity,state,focus=(cat=='defence' and i==1 and popup))
            y += row_height(capacity)
        y += 1
    if popup:
        # Anchored upward because defence2 is near the lower edge. Underlying rows do not move.
        py=460
        s += box(402,py,386,238,'#244450','#10303f',7)
        s += '<path d="M600 698 L614 708 L626 698Z" fill="#244450"/>'
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
        py=460
        s += box(402,py,386,238,'#244450','#10303f',7)
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
used['assets/fonts/NotoSansSC.ttf'] = hashlib.sha256((ASSETS/'fonts/NotoSansSC.ttf').read_bytes()).hexdigest()
(HERE/'reference-hashes.json').write_text(json.dumps(used,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
# Existing repository family, private render configuration only; no system install.
fontconfig = Path('/tmp/space-idle-workbench-rebuild/fontconfig-local.xml')
fontconfig.parent.mkdir(parents=True,exist_ok=True)
fontconfig.write_text('<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig><include ignore_missing="yes">/etc/fonts/fonts.conf</include><dir>'+str(ASSETS/'fonts')+'</dir><cachedir>/tmp/space-idle-workbench-rebuild/font-cache</cachedir></fontconfig>')
