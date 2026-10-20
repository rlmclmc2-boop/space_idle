"""Approved runtime art and unchanged active weapon contracts. No report files emitted."""
from pathlib import Path
import hashlib,json,subprocess
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT/'space-battleship'
HASHES={'assets/ships/enemy/elite_boss_20261020/anchor-boss.png': 'fbed2eba5d173f97b5fe83927fbb51e5ec0527dad5417f8e28759ef2c3010c50', 'assets/ships/enemy/elite_boss_20261020/anchor-elite.png': '1b6bb40679af09700c83e629b61cdfea8ec10e0b83efa7cbb5fa6fb7283afa18', 'assets/ships/enemy/elite_boss_20261020/command-boss.png': '6a16b97e155d9ebe45beffbc620c44c6ca390ba098ddbc70316384a6cb65c149', 'assets/ships/enemy/elite_boss_20261020/command-elite.png': 'c9f3d6f099691983377ee69f4dc9c81f16993a8299bfe9cded08bc50576cabd1', 'assets/ships/enemy/elite_boss_20261020/reactive-boss.png': 'e5efc27836e633097f6208a7841d437daed41dd1464ed4510489392eb44580c9', 'assets/ships/enemy/elite_boss_20261020/reactive-elite.png': 'b9f067e577d494b9d0687253ab5d60c7e8a6dd0212baf9744fcf7ae1ae4180ad', 'assets/ships/enemy/elite_boss_20261020/shielded-boss.png': '3e87b7f9991a0aa91e5abf8ab645c203a59ed14ed1cab31a285c812972944d5d', 'assets/ships/enemy/elite_boss_20261020/shielded-elite.png': '2d457858bb5ba222089caf798da869ff4be192291670889881aa78fa7831040d', 'assets/weapons/integrated_ranked_20261020/cannon-rotating.png': 'f5252b35125f2667a4451d3648ad51803bc63a5dc3252dafe7dd1496307fb772'}
APPROVED_MOUNTS={'enemy_opening_anchor_elite': [{'centre_px': [234.4079335460182, 803.3556246421394], 'housing_width_uv': 0.12820945945945947}, {'centre_px': [653.985727300334, 806.2877590694916], 'housing_width_uv': 0.13208754837137024}], 'enemy_opening_reactive_elite': [{'centre_px': [253.42461832061068, 959.6203253424658], 'housing_width_uv': 0.1491260531683262}, {'centre_px': [634.7030288106378, 960.1742532037118], 'housing_width_uv': 0.1491260531683262}], 'enemy_opening_shielded_elite': [{'centre_px': [206.45582524271848, 815.2671907234135], 'housing_width_uv': 0.14266065388951524}, {'centre_px': [674.8897637795277, 815.5689432325491], 'housing_width_uv': 0.14266065388951524}], 'enemy_opening_command_elite': [{'centre_px': [218.70319424838328, 814.0353391281001], 'housing_width_uv': 0.15548845110573864}, {'centre_px': [665.6820035477203, 814.009312054572], 'housing_width_uv': 0.159690841676164}], 'enemy_opening_anchor_boss': [{'centre_px': [241.90162122328667, 732.0526039403157], 'housing_width_uv': 0.1377536334003235}, {'centre_px': [644.112684894666, 731.2340646753019], 'housing_width_uv': 0.13411107298661828}, {'centre_px': [233.0419899300168, 976.129456365436], 'housing_width_uv': 0.13075829616195284}, {'centre_px': [650.6460939231769, 975.9528825144266], 'housing_width_uv': 0.13411107298661828}], 'enemy_opening_reactive_boss': [{'centre_px': [254.74403076758722, 717.0608283698933], 'housing_width_uv': 0.12177442787573078}, {'centre_px': [628.6173390697297, 716.7085183277323], 'housing_width_uv': 0.12193852497123397}, {'centre_px': [248.31841182522527, 1000.4544797000209], 'housing_width_uv': 0.15899766385011446}, {'centre_px': [636.472991988054, 1002.001897144196], 'housing_width_uv': 0.15502272225386163}], 'enemy_opening_shielded_boss': [{'centre_px': [223.4957436624213, 738.7054908996864], 'housing_width_uv': 0.13859174247580255}, {'centre_px': [661.2963635061246, 737.2729104983963], 'housing_width_uv': 0.142145376898259}, {'centre_px': [233.86923263493713, 981.3134551121393], 'housing_width_uv': 0.13503810805334607}, {'centre_px': [651.0576036866357, 983.8015930451129], 'housing_width_uv': 0.142145376898259}], 'enemy_opening_command_boss': [{'centre_px': [233.2706962527224, 761.9225928039143], 'housing_width_uv': 0.15083396961820147}, {'centre_px': [650.4134913507738, 761.290483719438], 'housing_width_uv': 0.14706312037774646}, {'centre_px': [232.51152265515265, 998.8034188034188], 'housing_width_uv': 0.14706312037774646}, {'centre_px': [650.9677292465273, 997.8497613847771], 'housing_width_uv': 0.14706312037774646}]}
config=json.loads((PROJECT/'data/ship_weapon_visuals.json').read_text())
base=json.loads(subprocess.check_output(['git','show','108080a7:space-battleship/data/ship_weapon_visuals.json'],cwd=ROOT))
assert config['weapons']==base['weapons']
assert set(config['ships'])==set(base['ships'])|set(APPROVED_MOUNTS)
for key,value in base['ships'].items():assert config['ships'][key]==value,key
for relative,expected in HASHES.items():
 path=PROJECT/relative
 assert hashlib.sha256(path.read_bytes()).hexdigest()==expected,relative
 image=Image.open(path)
 assert image.mode=='RGBA' and image.size==((320,640) if 'weapons/' in relative else (887,1774))
 assert image.getextrema()[-1][0]==0,'transparent background required'
for key,mounts in APPROVED_MOUNTS.items():
 row=config['ships'][key];ordinary=base['ships'][key.rsplit('_',1)[0]]
 assert row['rotating_mounts']==mounts,key
 assert len(mounts)==(2 if key.endswith('_elite') else 4)
 for field in ['hardpoints','slot_map','geometry_texture']:assert row[field]==ordinary[field],(key,field)
 assert row['texture'].removeprefix('res://') in HASHES
 geometry=PROJECT/row['geometry_texture'].removeprefix('res://')
 assert geometry.read_bytes()==subprocess.check_output(['git','show','108080a7:space-battleship/'+row['geometry_texture'].removeprefix('res://')],cwd=ROOT)
meta=config['enemy_rotating_art']
assert meta['pivot_px']==[159.0,299.5115606936416] and meta['muzzle_px']==[159.0,445.4797687861272]
assert meta['housing_width_px']==253.36625514403292
assert meta['texture'].removeprefix('res://') in HASHES
print('ENEMY_RUNTIME_ART PASS 9 approved PNGs, 24 approved mounts, 8 ranked rows; ordinary/active weapon contracts and centre geometry unchanged')
