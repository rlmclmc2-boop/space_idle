"""Native-size design coverage only. All art files are existing06/hull images."""
from pathlib import Path
import json,re
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
meta=json.loads((HERE/'design-meta.json').read_text());measured=json.loads((HERE/'coverage-measurements.json').read_text())['cases'];manifest=json.loads((ROOT/'assets/ships/enemy/elite_boss_20261020/manifest.json').read_text())
snaps={s['case']:s for s in json.loads((ROOT/'evidence/cannon-redesign-20261020/revision2/ranked.json').read_text())['snapshots']}
W,H=Image.open(HERE/meta['source_texture']).size;names={'anchor':'锚定','reactive':'反应','shielded':'护盾','command':'指挥'}
def assembly(case,mode='proposed',yaw=0):
 item=manifest['sprites'][case];im=Image.open(ROOT/item['texture'].removeprefix('res://'));box=im.getbbox();cx=(box[0]+box[2])/2;cy=(box[1]+box[3])/2
 body=[float(v) for v in re.findall(r'[-\d.]+',snaps[case]['body'])][-2:];hs=body[0]*meta['screen_scale']/(box[2]-box[0]);record=measured[case]
 if mode=='old':widths=[min(s['socket_well_width_uv'] for s in item['sockets'])*im.width*hs*1.2]*len(item['sockets'])
 else:widths=record['levels'][0 if mode=='medium' else 1]['width_screen']
 parts=[f'<div class="ship"><img class="hull" src="../../../{item["texture"].removeprefix("res://")}" style="width:{im.width*hs}px;height:{im.height*hs}px;left:{-cx*hs}px;top:{-cy*hs}px">']
 for socket,width in zip(item['sockets'],widths):
  gs=width/meta['housing_width_source_px'];x,y=socket['socket_centre_px'];px,py=meta['pivot_source_px']
  parts.append(f'<div class="mount" style="left:{(x-cx)*hs}px;top:{(y-cy)*hs}px;transform:rotate({yaw}deg)"><img class="gun" src="{meta["source_texture"]}" style="width:{W*gs}px;height:{H*gs}px;left:{-px*gs}px;top:{-py*gs}px"></div>')
 parts.append('</div>');return ''.join(parts),widths
style='''<style>*{box-sizing:border-box}body{margin:0;background:#0c1823;color:#e3ebf1;font:14px "Noto Sans CJK SC",sans-serif}.board{width:1240px;padding:30px}.compare-board{width:1000px;padding:28px}.direction-board{width:1000px;padding:28px}h1{font-size:26px;letter-spacing:1px;margin:0 0 10px}h2{font-size:16px;font-weight:500;margin:20px 0 12px}h3{font-size:13px;font-weight:500;margin:0}p{color:#a7bbc9;line-height:1.7;margin:5px 0}.header{border-bottom:1px solid #34424e;margin-bottom:20px;padding-bottom:14px}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}.three{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}.card{border:1px solid #34424e;background:#132331;text-align:center;height:218px}.card p{font-size:11px}.native{height:170px;position:relative;width:100%}.ship{position:absolute;left:50%;top:50%;width:0;height:0;transform:rotate(180deg)}.hull,.gun{position:absolute;max-width:none}.mount{position:absolute;width:0;height:0;transform-origin:0 0}.foot{border-top:1px solid #34424e;margin-top:22px;padding-top:12px;font-size:12px}</style>'''
def head(title,cls):return '<!doctype html><meta charset="utf-8">'+style+f'<div class="{cls}"><div class="header"><h1>{title}</h1><p>同一06炮身素材，整件等比；舰体、固定底座及轴心不变。正常窗口比例，未接入游戏。</p></div>'
def card(case,mode,label,yaw=0):
 body,w=assembly(case,mode,yaw);size=f'{min(w):.1f}' if max(w)-min(w)<.05 else f'{min(w):.1f}–{max(w):.1f}'
 return f'<div class="card"><div class="native">{body}</div><h3>{label}</h3><p>炮身宽 {size}px</p></div>'
compare=head('06现稿 · 底座承载面覆盖对照','compare-board')
for case,label in [('command_boss','指挥 BOSS'),('reactive_elite','反应精英'),('anchor_elite','锚定精英 · 舰体边界限制案例')]:
 compare+=f'<h2>{label}</h2><div class="three">'+card(case,'old','原方案：内部凹槽 ×1.2')+card(case,'medium','外侧承载面 85% · 边界钳制')+card(case,'proposed','外侧承载面 95% · 边界钳制')+'</div>'
compare+='<p class="foot">只增大整个06旋转炮身的覆盖比例，不单独改炮管。提案按原底座外侧红色承载缘测量，再受原舰体alpha边界约束。<br>静态设计示意，非实机截图；请以100%查看。</p></div>'; (HERE/'normal-comparison.html').write_text(compare)
direction=head('06现稿 · 覆盖修正后的同尺寸转向','direction-board')
for case,label in [('command_boss','指挥 BOSS'),('reactive_elite','反应精英'),('anchor_elite','锚定精英')]:
 direction+=f'<h2>{label}</h2><div class="three">'+''.join(card(case,'proposed',f'{yaw:+}°',yaw) for yaw in [-35,0,35])+'</div>'
direction+='<p class="foot">炮身按外承载面覆盖、逐底座边界钳制。正向与转向等尺寸；舰体与固定底座不动。静态设计示意，未接入。</p></div>'; (HERE/'direction-check.html').write_text(direction)
page=head('06现稿覆盖修正 · 八版正常窗口比例','board')+'<h2>外侧承载面95%目标覆盖，受舰体边界限制</h2><div class="grid">'
for rank in ['elite','boss']:
 for key,label in names.items():page+=card(key+'_'+rank,'proposed',label+(' · 精英' if rank=='elite' else ' · BOSS'))
page+='</div><h2>指挥BOSS · 同尺寸转向</h2><div class="three">'+''.join(card('command_boss','proposed',f'{yaw:+}°',yaw) for yaw in [-35,0,35])+'</div><p class="foot">不生成新炮图。原06炮身与8舰体PNG均未修改，炮管随整件等比，24底座坐标不动；未改游戏配置、未接入、未合main。<br>设计板请以100%查看；几何检查见coverage-measurements.json。</p></div>'; (HERE/'review.html').write_text(page)
print('Existing-art native coverage boards ready')
