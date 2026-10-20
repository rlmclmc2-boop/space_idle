"""Native-size design coverage only. All art files are existing06/hull images."""
from pathlib import Path
import json,re
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
meta=json.loads((HERE/'design-meta.json').read_text());measured=json.loads((HERE.parent/'cannon-coverage-review-07/coverage-measurements.json').read_text())['cases'];manifest=json.loads((ROOT/'assets/ships/enemy/elite_boss_20261020/manifest.json').read_text())
snaps={s['case']:s for s in json.loads((ROOT/'evidence/cannon-redesign-20261020/revision2/ranked.json').read_text())['snapshots']}
old_meta=json.loads((HERE.parent/'cannon-coverage-review-07/design-meta.json').read_text());old_meta['source_texture']='../cannon-design-review-06/cannon-design.png'
W,H=Image.open(HERE/meta['source_texture']).size;names={'anchor':'锚定','reactive':'反应','shielded':'护盾','command':'指挥'}
def assembly(case,mode='proposed',yaw=0):
 item=manifest['sprites'][case];im=Image.open(ROOT/item['texture'].removeprefix('res://'));box=im.getbbox();cx=(box[0]+box[2])/2;cy=(box[1]+box[3])/2
 body=[float(v) for v in re.findall(r'[-\d.]+',snaps[case]['body'])][-2:];hs=body[0]*meta['screen_scale']/(box[2]-box[0]);record=measured[case]
 widths=record['levels'][1]['width_screen']
 artwork=meta if mode!='old' else old_meta
 aw,ah=Image.open(HERE/artwork['source_texture']).size
 parts=[f'<div class="ship"><img class="hull" src="../../../{item["texture"].removeprefix("res://")}" style="width:{im.width*hs}px;height:{im.height*hs}px;left:{-cx*hs}px;top:{-cy*hs}px">']
 for socket,width in zip(item['sockets'],widths):
  gs=width/artwork['housing_width_source_px'];x,y=socket['socket_centre_px'];px,py=artwork['pivot_source_px']
  parts.append(f'<div class="mount" style="left:{(x-cx)*hs}px;top:{(y-cy)*hs}px;transform:rotate({yaw}deg)"><img class="gun" src="{artwork["source_texture"]}" style="width:{aw*gs}px;height:{ah*gs}px;left:{-px*gs}px;top:{-py*gs}px"></div>')
 parts.append('</div>');return ''.join(parts),widths
style='''<style>*{box-sizing:border-box}body{margin:0;background:#0c1823;color:#e3ebf1;font:14px "Noto Sans CJK SC",sans-serif}.board{width:1240px;padding:30px}.compare-board{width:1000px;padding:28px}.direction-board{width:1000px;padding:28px}h1{font-size:26px;letter-spacing:1px;margin:0 0 10px}h2{font-size:16px;font-weight:500;margin:20px 0 12px}h3{font-size:13px;font-weight:500;margin:0}p{color:#a7bbc9;line-height:1.7;margin:5px 0}.header{border-bottom:1px solid #34424e;margin-bottom:20px;padding-bottom:14px}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}.three{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}.card{border:1px solid #34424e;background:#132331;text-align:center;height:218px}.card p{font-size:11px}.native{height:170px;position:relative;width:100%}.ship{position:absolute;left:50%;top:50%;width:0;height:0;transform:rotate(180deg)}.hull,.gun{position:absolute;max-width:none}.mount{position:absolute;width:0;height:0;transform-origin:0 0}.foot{border-top:1px solid #34424e;margin-top:22px;padding-top:12px;font-size:12px}</style>'''
def head(title,cls):return '<!doctype html><meta charset="utf-8">'+style+f'<div class="{cls}"><div class="header"><h1>{title}</h1><p>同一06炮身素材，整件等比；舰体、固定底座及轴心不变。正常窗口比例，未接入游戏。</p></div>'
def card(case,mode,label,yaw=0):
 body,w=assembly(case,mode,yaw);size=f'{min(w):.1f}' if max(w)-min(w)<.05 else f'{min(w):.1f}–{max(w):.1f}'
 return f'<div class="card"><div class="native">{body}</div><h3>{label}</h3><p>炮身宽 {size}px</p></div>'
compare=head('同一07覆盖尺寸 · 内部明暗简化前后','compare-board').replace('同一06炮身素材，整件等比','保留06轮廓和短炮管比例，固定07逐底座覆盖尺寸')
compare=compare.replace('.compare-board{width:1000px', '.compare-board{width:760px')+'<style>.two{display:grid;grid-template-columns:1fr 1fr;gap:12px}</style>'
for case,label in [('command_boss','指挥 BOSS'),('reactive_elite','反应精英'),('anchor_elite','锚定精英')]:
 compare+=f'<h2>{label}</h2><div class="two">'+card(case,'old','原06内部 · 07覆盖')+card(case,'proposed','简化内部 · 相同07覆盖')+'</div>'
compare+='<p class="foot">仅简化炮机内部框线和亮边；中央凸起炮机、两侧白甲和短炮管保持。覆盖尺寸、舰体、底座坐标均相同。<br>正常比例静态设计示意，未接入游戏；请以100%查看。</p></div>';(HERE/'normal-comparison.html').write_text(compare)
direction=head('简化内部 · 同尺寸正向与转向','direction-board').replace('同一06炮身素材，整件等比','沿用07逐底座覆盖尺寸，仅简化06内部表达')
for case,label in [('command_boss','指挥 BOSS'),('reactive_elite','反应精英'),('anchor_elite','锚定精英')]:
 direction+=f'<h2>{label}</h2><div class="three">'+''.join(card(case,'proposed',f'{yaw:+}°',yaw) for yaw in [-35,0,35])+'</div>'
direction+='<p class="foot">连续暗面表现炮机，少量侧面亮部表现高度；固定底座和舰体不动。静态设计示意，未接入。</p></div>';(HERE/'direction-check.html').write_text(direction)
page=head('炮机内部简化 · 八版正常窗口比例','board').replace('同一06炮身素材，整件等比','06轮廓与短炮管比例，07覆盖基准不变，只简化内部明暗')+'<h2>01 / 正常窗口八舰 · 原覆盖尺寸不变</h2><div class="grid">'
for rank in ['elite','boss']:
 for key,label in names.items():page+=card(key+'_'+rank,'proposed',label+(' · 精英' if rank=='elite' else ' · BOSS'))
page+='</div><h2>02 / 指挥BOSS · 同尺寸转向</h2><div class="three">'+''.join(card('command_boss','proposed',f'{yaw:+}°',yaw) for yaw in [-35,0,35])+'</div><h2>03 / 内部表达细节 · 放大仅供结构审阅</h2><style>.details{display:flex;gap:20px;align-items:center;justify-content:center}.details img{width:220px;height:240px;object-fit:contain}.details div{text-align:center;color:#a7bbc9}</style><div class="details"><div>原06内部<img src="../cannon-design-review-06/cannon-design.png"></div><div>本轮简化<img src="cannon-design.png"></div><p>中央连续大暗面<br>侧甲大面与少量侧亮<br>保留凸起炮机、承载侧甲与连接层次</p></div><p class="foot">沿用07外承载面95%目标及逐底座边界钳制。舰体与坐标不动；未改生产配置、未接入、未合main。<br>先以100%查看上方正常窗口与转向，再看细节。</p></div>'; (HERE/'review.html').write_text(page)
print('Internal-simplification boards ready;07 widths reused exactly')
