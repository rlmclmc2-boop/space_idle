"""Excel projection and validation shared by full and incremental imports."""
from ui_text import t as ui_text
import argparse
import ast
import copy
import json
import math
import os
import pathlib
import re
import sys
import openpyxl

ROOT = pathlib.Path(__file__).resolve().parents[1]
SECTIONS = {"level":"levels", "equipment":"equipment", "mon":"enemies", "monGroup":"groups", "res":"resources", "config":"config", "ship":"ship", "hightech":"hightech", "charge":"charge", "jewel":"jewel", "unlock":"unlock", "crew":"crew", "crew_level":"crew_level", "crew_assignment":"crew_assignment"}
DEFAULTS = {"autoCollectDelay":5.0,"loopDelay":6.0,"deathRetreatDistance":300.0,"deathRetreatDuration":1.2,"projectilePixelsPerUnit":28.0,"startingIron":0.0,"startingTitanium":0.0}
FALLBACKS = {"enemyWeaponMissingLevel":"Use player weapon row 1 when the enemy weapon row is missing.","enemyCannonMissingDamageAndCooldown":"Use player cannon row 1 for missing fields."}

def clean(value):
    return str(value).translate(str.maketrans({"｛":"{","｝":"}","，":",","；":";"})).strip("{} ")

def read_rows(sheet):
    values=sheet.iter_rows(values_only=True)
    header=next(values)
    next(values,None)
    next(values,None)
    return [{key:value for key,value in zip(header,row) if key is not None} for row in values if row[0] is not None]

def convert_sheet(name, rows):
    if name in ('crew', 'crew_assignment', 'crew_level'):
        result = {}
        for source in rows:
            row = {k: ('' if v is None else v) for k, v in source.items()}
            key = row.get('group') if name == 'crew_level' else row.get('id')
            if not isinstance(key, str) or not key.strip():
                raise ValueError(f'{name}: missing string ID/group')
            if name == 'crew_level':
                positive(row.get('level'), 'crew_level level')
                if row['level'] != int(row['level']):
                    raise ValueError('crew_level: level must be an integer')
                level = str(int(row['level']))
                if level in result.setdefault(key, {}):
                    raise ValueError(f'crew_level: duplicate {key}/{level}')
                result[key][level] = row
            else:
                if key in result:
                    raise ValueError(f'{name}: duplicate {key}')
                result[key] = row
        return result
    if name in ('mon', 'monGroup', 'res', 'level', 'jewel'):
        ids = [row.get('id') for row in rows]
        if any(type(i) not in (int, float) or not math.isfinite(i) or i < 1 or i != int(i) for i in ids) or len(set(ids)) != len(ids):
            raise ValueError(ui_text('debug.import_workbook.message_02', name=name))
    if name == 'jewel':
        for row in rows:
            positive(row.get('maxLevel'), 'jewel maxLevel')
            if row['maxLevel'] != int(row['maxLevel']):
                raise ValueError(ui_text('debug.import_workbook.message_07'))
            row["image"] = row.get("image") or f"res://assets/jewels/{int(row['id'])}.svg"
        return {str(int(row['id'])): row for row in rows}
    if name == 'config':
        keys = [row.get('name') for row in rows]
        if any(not isinstance(key, str) or not key.strip() for key in keys) or len(set(keys)) != len(keys):
            raise ValueError(ui_text('debug.import_workbook.message_03'))
    if name in ("hightech", "charge", "unlock"):
        result={}
        for row in rows:
            key=row.get("name")
            if not isinstance(key,str) or not key.strip() or key in result:
                raise ValueError(ui_text('debug.import_workbook.message_08', name=name))
            result[key]=row
        return result
    if name=="equipment":
        result={}
        for row in rows:
            if row.get('level') != 1:
                continue  # Legacy higher-level rows are no longer configuration.
            result.setdefault(row["name"],[]).append(row)
        for items in result.values():
            if any(type(r.get('level')) not in (int, float) or not math.isfinite(r['level']) or r['level'] < 1 or r['level'] != int(r['level']) for r in items):
                raise ValueError(ui_text('debug.import_workbook.message_09'))
            if len({r['level'] for r in items}) != len(items):
                raise ValueError(ui_text('debug.import_workbook.message_10'))
            items.sort(key=lambda r:r["level"])
        return result
    if name=="mon":
        result={}
        for row in rows:
            mounts = []
            for part in clean(row["equipment"]).split(","):
                fields = part.split("|")
                if len(fields) != 2 or not fields[0].strip() or not fields[1].strip().isdigit() or int(fields[1]) < 1:
                    raise ValueError(ui_text('debug.import_workbook.message_16', id=row["id"]))
                mounts.extend({"name": fields[0].strip()} for _ in range(int(fields[1])))
            row["equipment"] = mounts
            drop=clean(row["res"]).split(",")
            if len(drop)==4:
                drop=[drop[0],drop[1],drop[2]+"."+drop[3]]
            row["drops"]=[{"resourceId":int(drop[0]),"amount":float(drop[1]),"chance":float(drop[2])}]
            result[str(row["id"])]=row
        return result
    if name=="monGroup":
        return {str(r["id"]):{"description":r["des"],"slots":[None if v.strip()=="null" else int(v) for v in clean(r["mon"]).split(",")]} for r in rows}
    if name=="level":
        for row in rows:
            ratio = row.get("jewelRatio", 1)
            if type(ratio) not in (int, float) or not math.isfinite(ratio) or ratio < 0:
                raise ValueError(ui_text('debug.import_workbook.message_11'))
            row["jewelRatio"] = ratio
            row["groups"]=[{"id":int(p.split("|")[0]),"position":float(p.split("|")[1])} for p in clean(row["monGroup"]).split(",")]
        return rows
    if name=="res":
        return {str(r["id"]):r["name"] for r in rows}
    if name=="config":
        for row in rows:
            if row["name"] == "jewelCreat":
                positive(row["para_1"], "config jewelCreat")
                if row["para_1"] != int(row["para_1"]):
                    raise ValueError(ui_text('debug.import_workbook.message_17'))
        return {r["name"]:r["para_1"] for r in rows}
    if name=="ship":
        result={}
        for row in rows:
            key=row.get("name")
            if not isinstance(key,str) or not key.strip() or key in result:
                raise ValueError(ui_text('debug.import_workbook.message_12'))
            result[key]={"name":key,"des":row.get("des"),"weaponSlots":row.get("para_1"),"defenseSlots":row.get("para_2"),"movement":row.get("para_3"),"unlock":row.get("para_4"),"size":row.get("para_5"),"sameEquipmentLimit":row.get("para_6")}
        return result
    raise ValueError(ui_text('debug.import_workbook.message_01', name=name))

def projection_base(previous, source):
    data=copy.deepcopy(previous or {})
    data["source"]=source
    data["defaults"]={**DEFAULTS,**data.get("defaults",{})}
    data.setdefault("fallbacks",dict(FALLBACKS))
    return data

def positive(value, label, allow_zero=False):
    if not isinstance(value, (int,float)) or not math.isfinite(value) or value < 0 or (value == 0 and not allow_zero):
        raise ValueError(ui_text('debug.import_workbook.message_101', label=label, positive="nonnegative" if allow_zero else "positive", value=repr(value)))

def validate_description(row, field='description', section='hightech'):
    description=row.get(field)
    label=f'{section} {row["name"]} {field}'
    if not isinstance(description,str) or not description.strip():
        raise ValueError(ui_text('debug.import_workbook.message_102', label=label))
    for token in re.findall(r'para\d+', description):
        positive(row.get(token if section=='hightech' else token.replace('para','para_')),f'{label} {token}',True)
    blocks=re.findall(r'\{([^{}]+)\}',description)
    if '{' in re.sub(r'\{[^{}]+\}','',description) or '}' in re.sub(r'\{[^{}]+\}','',description):
        raise ValueError(ui_text('debug.import_workbook.message_103', label=label))
    for block in blocks:
        parts=block.replace('，',',').split(',')
        if any(option.strip() not in ('向上取整','不含自身','百分比显示','保留两位小数','即100.3%展示为100%','百分比','四舍五入保留整数百分比部分') for option in parts[1:]):
            raise ValueError(ui_text('debug.import_workbook.message_106', label=label))
        formula=re.sub(r'para\d+','1.0',parts[0]).replace('过去一分钟的铁生成量','1.0').replace('过去一分钟的宝石碎片生成量','1.0').replace('等级','1.0').replace('lv','1.0').replace('（','(').replace('）',')').replace('^','**')
        if not re.fullmatch(r'[0-9. +*/()\-]+',formula):
            raise ValueError(ui_text('debug.import_workbook.message_107', label=label))
        try:
            tree=ast.parse(formula.strip(),mode='eval')
        except SyntaxError as error:
            raise ValueError(ui_text('debug.import_workbook.message_124', label=label)) from error
        for node in ast.walk(tree):
            if not isinstance(node,(ast.Expression,ast.BinOp,ast.UnaryOp,ast.Add,ast.Sub,ast.Mult,ast.Div,ast.Pow,ast.UAdd,ast.USub,ast.Constant)) or (isinstance(node,ast.Constant) and (type(node.value) not in (int,float) or not math.isfinite(node.value))):
                raise ValueError(ui_text('debug.import_workbook.message_125', label=label))


def validate_projection(data, *, check_level_ratios=True):
    validate_crew(data)
    validate_unlocks(data)
    equipment=data["equipment"]
    levels=data["levels"]
    groups=data["groups"]
    enemies=data["enemies"]
    config=data["config"]
    ships=data.get("ship",{})
    if ships:
        if len(ships) != 5:
            raise ValueError(ui_text('debug.import_workbook.message_04', ships=len(ships)))
        for key,row in ships.items():
            if not isinstance(row.get('des'),str) or not row['des'].strip():
                raise ValueError(ui_text('debug.import_workbook.message_126', key=key))
            for field in ('weaponSlots','defenseSlots','movement','size'):
                positive(row.get(field),f'ship {key} {field}', field == 'unlock')
            if row['weaponSlots'] != int(row['weaponSlots']) or row['weaponSlots'] < 1:
                raise ValueError(ui_text('debug.import_workbook.message_127', key=key))
            positive(row.get('sameEquipmentLimit'),f'ship {key} sameEquipmentLimit')
            if row['sameEquipmentLimit'] != int(row['sameEquipmentLimit']):
                raise ValueError(ui_text('debug.import_workbook.message_128', key=key))
            if row['defenseSlots'] != int(row['defenseSlots']) or row['defenseSlots'] < 1:
                raise ValueError(ui_text('debug.import_workbook.message_129', key=key))
    for key in ('armour','shield','laser','missile','cannon'):
        items=equipment.get(key,[])
        bases = [r for r in items if r.get('level') == 1]
        if len(bases) != 1:
            raise ValueError(ui_text('debug.import_workbook.message_108', key=key))
        for r in bases:
            positive(r['para1'] if key in ('armour','shield') else r['dmg'],f'{key} Lv.{r["level"]} value')
            if key not in ('armour','shield'):
                positive(r['cd'], f'{key} cooldown')
                positive(r['para2'] if key=='missile' else r['para1'],f'{key} projectile speed')
            growth = 'para2' if key == 'armour' else 'para4' if key == 'shield' else 'dmgMulti'
            positive(r.get(growth), f'{key} {growth}', True)
    for key, items in equipment.items():
        for r in (r for r in items if r.get('level') == 1):
            for field, value in r.items():
                if re.fullmatch(r'cost_\d+', str(field)) and value is not None:
                    positive(value, f'{key} {field}', True)
                    suffix = field.removeprefix('cost_')
                    positive(r.get('cost_multi_' + suffix, r.get('costMulti_' + suffix)), f'{key} cost multiplier {suffix}', True)
    if [r['id'] for r in levels] != list(range(1,len(levels)+1)) or not levels:
        raise ValueError(ui_text('debug.import_workbook.message_104'))
    for level in levels:
        for key in (('length','atkRatio','lifeRatio','resRatio') if check_level_ratios else ('length',)):
            positive(level[key],f'level {level["id"]} {key}')
        positions=[g['position'] for g in level['groups']]
        if not positions or positions!=sorted(set(positions)) or not all(0<=p<=1 for p in positions):
            raise ValueError(ui_text('debug.import_workbook.message_109', id=level["id"]))
        for g in level['groups']:
            if str(g['id']) not in groups: raise ValueError(ui_text('debug.import_workbook.message_131', id=g["id"]))
    for gid,g in groups.items():
        if len(g['slots'])!=10: raise ValueError(ui_text('debug.import_workbook.message_110', gid=gid))
        for enemy_id in g['slots']:
            if enemy_id is not None and str(enemy_id) not in enemies: raise ValueError(ui_text('debug.import_workbook.message_132', enemy_id=enemy_id))
    for enemy in enemies.values():
        eid = enemy['id']
        size = enemy['size']
        if type(size) not in (int, float) or not math.isfinite(size) or size != int(size) or size < 1:
            raise ValueError(ui_text('debug.import_workbook.message_05', eid=eid))
        if enemy['armourType'] not in (0, 1, 2): raise ValueError(ui_text('debug.import_workbook.message_06', eid=eid))
        for weapon in enemy['equipment']:
            key = weapon['name']
            base = key.replace('_mon', '').replace('-mon', '')
            candidates = equipment.get(key, []) + equipment.get(base, [])
            if base not in ('laser', 'cannon', 'missile') or not any(r['level'] == 1 for r in candidates):
                raise ValueError(ui_text('debug.import_workbook.message_13', eid=eid, key=key))
        positive(enemy['health'],f'enemy {enemy["id"]} health')
        positive(enemy['dmgMultiple'],f'enemy {enemy["id"]} damage multiplier',True)
        for drop in enemy['drops']:
            if str(drop['resourceId']) not in data['resources']: raise ValueError(ui_text('debug.import_workbook.message_14', eid=eid))
            positive(drop['amount'],'drop amount',True)
            if not 0<=drop['chance']<=1: raise ValueError(ui_text('debug.import_workbook.message_133'))
    for key in ('dmgReduce','autoCollectReduce'):
        if not isinstance(config[key],(int,float)) or not 0<=config[key]<1: raise ValueError(ui_text('debug.import_workbook.message_111', key=key))
    positive(config['movement'],'movement')
    positive(config['backRange'],'backRange',True)
    positive(config.get('offlineMax'),'offlineMax (hours)',True)
    auto_gen = config.get('autoGenRes')
    if auto_gen is not None:
        if not isinstance(auto_gen, str):
            raise ValueError(ui_text('debug.import_workbook.message_112'))
        parts = [part.strip() for part in auto_gen.replace('，', ',').split(',')]
        if len(parts) != 4 or not parts[0] or not parts[1] or not parts[2] or not parts[3]:
            raise ValueError(ui_text('debug.import_workbook.message_113'))
        if not re.fullmatch(r'\d+', parts[1]) or str(int(parts[1])) not in data['resources']:
            raise ValueError(ui_text('debug.import_workbook.message_114', parts=repr(parts[1])))
        try:
            interval, amount, speed = (float(parts[0]), float(parts[2]), float(parts[3]))
        except ValueError as error:
            raise ValueError(ui_text('debug.import_workbook.message_134')) from error
        positive(interval, 'autoGenRes interval')
        positive(amount, 'autoGenRes amount', True)
        positive(speed, 'autoGenRes speed')
    limit=config.get('hightechLimit')
    positive(limit,'hightechLimit')
    positive(config.get('techPointGet'),'techPointGet')
    parts=str(config.get('scientistCost','')).replace('，',',').split(',')
    if len(parts)<2: raise ValueError(ui_text('debug.import_workbook.message_105'))
    try:
        positive(float(parts[0]),'scientistCost multiplier')
        seen=set()
        for part in parts[1:]:
            rid,amount=part.split('|')
            if rid not in data['resources'] or rid in seen: raise ValueError(ui_text('debug.import_workbook.message_135'))
            seen.add(rid)
            positive(float(amount),'scientistCost amount',True)
    except (ValueError,TypeError) as error:
        raise ValueError(ui_text('debug.import_workbook.message_115')) from error
    for key,row in data['hightech'].items():
        validate_description(row)
        if not isinstance(row.get('des'),str) or not row['des'].strip():
            raise ValueError(ui_text('debug.import_workbook.message_116', key=key))
        positive(row.get('tpCostBase'),f'hightech {key} tpCostBase')
        if math.floor(row['tpCostBase']+0.5)<1:
            raise ValueError(ui_text('debug.import_workbook.message_117', key=key))
        positive(row.get('tpCostMutiple'),f'hightech {key} tpCostMutiple',True)
        positive(row.get('para1'),f'hightech {key} para1',True)
        if row.get('para2') is not None:
            positive(row['para2'],f'hightech {key} para2',True)
        if key in ('超时空炼铁炉', '宝石熔炼炉'):
            positive(row.get('para1'),f'hightech {key} interval')
            positive(row.get('para2'),f'hightech {key} para2',True)

    for key,row in data.get('charge',{}).items():
        if key not in ('攻击充能','防御充能','熔炼器充能'):
            raise ValueError(ui_text('debug.import_workbook.message_119', key=key))
        if not isinstance(row.get('func'),str) or not row['func'].strip():
            raise ValueError(ui_text('debug.import_workbook.message_120', key=key))
        validate_description(row,'des','charge')
        for field in ('para_1','para_2','para_4','para_5','para_6'):
            positive(row.get(field),f'charge {key} {field}')
        positive(row.get('para_3'),f'charge {key} para_3',True)
        positive(row.get('para_7',0),f'charge {key} para_7',True)
        if row['para_1'] != int(row['para_1']) or str(int(row['para_1'])) not in data['resources']:
            raise ValueError(ui_text('debug.import_workbook.message_121', key=key))
        if math.floor(row['para_5'] + 0.5) < 1 or row['para_6'] < 1:
            raise ValueError(ui_text('debug.import_workbook.message_122', key=key))

    data["defaults"].pop("maxEquipmentLevel", None)

def validate_unlocks(data):
    rows = data.get('unlock')
    if not isinstance(rows, dict) or not rows:
        raise ValueError('Missing unlock table; import unlock.xlsx first')
    targets = set()
    allowed = {kind: set(data.get(kind, {})) for kind in ('equipment', 'ship', 'charge', 'hightech')}
    allowed['equipment'] = {key for key in allowed['equipment'] if not key.endswith(('_mon', '-mon'))}
    allowed['feature'] = {'jewels'}
    allowed['crew'] = set(data.get('crew', {}))
    for name, row in rows.items():
        kind, target = row.get('type'), row.get('target')
        identity = (kind, target)
        if row.get('name') != name or kind not in allowed or target not in allowed[kind] or identity in targets:
            raise ValueError(f'Invalid or duplicate unlock target: {name}')
        targets.add(identity)
        gate = row.get('level')
        if type(gate) not in (int, float) or not math.isfinite(gate) or gate != int(gate) or not 0 <= gate <= len(data['levels']):
            raise ValueError(f'Invalid unlock level: {name}')
        if row.get('mode') not in ('cleared', 'reached'):
            raise ValueError(f'Invalid unlock mode: {name}')
        if any(not isinstance(row.get(field), str) or not row[field].strip() for field in ('title', 'desc')):
            raise ValueError(f'Missing unlock title/desc: {name}')
    # Crew may explicitly be initially available (empty unlockId).
    missing = {(kind, key) for kind, keys in allowed.items() if kind != 'crew' for key in keys} - targets
    if missing:
        raise ValueError(f'Missing unlock targets: {sorted(missing)}')
    # Legacy columns may arrive from an old master. Never restore a second gate source.
    for kind in ('ship', 'charge', 'hightech'):
        for row in data.get(kind, {}).values(): row.pop('unlock', None)
    for items in data.get('equipment', {}).values():
        for row in items: row.pop('unlock', None)
    data['config'].pop('jewelDropLevel', None)


def validate_crew(data):
    """Shared full/incremental checks; no crew values are defaulted by code."""
    def integer(value, label, zero=False):
        positive(value, label, zero)
        if isinstance(value, bool) or value != int(value):
            raise ValueError(f'{label}: expected integer')
    groups = data.get('crew_level', {})
    jobs = data.get('crew_assignment', {})
    contracts = json.loads((ROOT/'data/ui_text_contract.json').read_text(encoding='utf-8'))['entries'] if jobs else {}
    for group, levels in groups.items():
        for level, row in levels.items():
            integer(row.get('level'), f'{group} level')
            positive(row.get('needExp'), f'{group}/{level} needExp', int(level) == 1)
            positive(row.get('powerMultiplier'), f'{group}/{level} powerMultiplier')
    for id, row in jobs.items():
        for field in ('targetType', 'effectType', 'description'):
            if not isinstance(row.get(field), str) or not row[field].strip():
                raise ValueError(f'crew_assignment {id}: missing {field}')
        for field in ('baseValue', 'powerScale', 'levelScale', 'interval'):
            positive(row.get(field), f'crew_assignment {id} {field}', True)
        integer(row.get('maxCrew'), f'crew_assignment {id} maxCrew')
        if row['effectType'] == 'AUTO_UPGRADE':
            positive(row['baseValue'], f'{id} baseValue')
            positive(row['interval'], f'{id} interval')
            modes = [mode.strip() for mode in str(row.get('upgradeModes','')).split(',')]
            if not modes or len(set(modes))!=len(modes) or any(mode!='max' and (not mode.isdigit() or not 0<int(mode)<=2147483647) for mode in modes):
                raise ValueError(f'{id}: upgradeModes requires positive integers or max')
        for field in ('titleTextId','descTextId'):
            if not isinstance(row.get(field,''),str):
                raise ValueError(f'{id}: {field} must be text')
            key = row.get(field, '')
            if key and (key not in contracts or not set(contracts[key]['params']).issubset(set() if field=='titleTextId' else {'value','interval','description','mode'})):
                raise ValueError(f'{id}: unknown or incompatible {field}: {key}')
    for id, row in data.get('crew', {}).items():
        for field in ('name', 'description', 'icon', 'expGroup'):
            if not isinstance(row.get(field), str) or not row[field].strip():
                raise ValueError(f'crew {id}: missing {field}')
        for field in ('baseLevel', 'maxLevel', 'equipmentSlotCount'):
            integer(row.get(field), f'crew {id} {field}', field == 'equipmentSlotCount')
        positive(row.get('basePower'), f'crew {id} basePower')
        if row['baseLevel'] > row['maxLevel']:
            raise ValueError(f'crew {id}: baseLevel exceeds maxLevel')
        levels = groups.get(row['expGroup'], {})
        if row['maxLevel']-row['baseLevel']+1 > len(levels) or any(str(n) not in levels for n in range(int(row['baseLevel']),int(row['maxLevel'])+1)):
            raise ValueError(f'crew {id}: missing growth levels')
        for job in jobs.values():
            try:
                values = [float(job['baseValue'])*float(row['basePower'])**float(job['powerScale'])*float(levels[str(level)]['powerMultiplier'])**float(job['levelScale']) for level in range(int(row['baseLevel']),int(row['maxLevel'])+1)]
                if any(not math.isfinite(value) or (job['effectType']=='AUTO_UPGRADE' and (value<=0 or not math.isfinite(float(job['interval'])/value))) for value in values):
                    raise ValueError(f'crew {id}: nonfinite effective power or interval')
            except OverflowError as error:
                raise ValueError(f'crew {id}: effect power overflow') from error
        if row.get('defaultAssignment') and row['defaultAssignment'] not in jobs:
            raise ValueError(f'crew {id}: unknown defaultAssignment')
        if bool(row.get('defaultAssignment')) != bool(row.get('defaultTargetId')):
            raise ValueError(f'crew {id}: defaultAssignment requires defaultTargetId')
        if row.get('unlockId') and row['unlockId'] not in data.get('unlock', {}):
            raise ValueError(f'crew {id}: unknown unlockId')


def encode(data):
    return json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False).encode("utf-8")

def full_import(source, target):
    previous=json.loads(target.read_text(encoding="utf-8")) if target.exists() else {}
    data=projection_base(previous,source.name)

    book=openpyxl.load_workbook(source,data_only=True,read_only=True)
    try:
        for name,section in SECTIONS.items():
            if name not in book.sheetnames:
                if name in ('charge','ship','jewel','unlock','crew','crew_level','crew_assignment'):
                    continue  # Older master workbooks predate optional projections.
                raise ValueError(ui_text('debug.import_workbook.message_15', name=name))
            data[section]=convert_sheet(name,read_rows(book[name]))
    finally:
        book.close()
    validate_projection(data)
    target.parent.mkdir(parents=True,exist_ok=True)
    temporary=target.with_suffix(".json.tmp")
    try:
        temporary.write_bytes(encode(data))
        os.replace(temporary,target)
    finally:
        if temporary.exists(): temporary.unlink()
    return data

def main():
    if hasattr(sys.stdout,"reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    parser=argparse.ArgumentParser()
    parser.add_argument("source",nargs="?",type=pathlib.Path,default=ROOT.parent/"太空战舰.xlsx")
    parser.add_argument("target",nargs="?",type=pathlib.Path,default=ROOT/"data"/"game_data.json")
    args=parser.parse_args()
    data=full_import(args.source,args.target)
    print(f'Imported {len(data["levels"])} levels, {len(data["enemies"])} enemies, {len(data["groups"])} groups, {sum(map(len,data["equipment"].values()))} equipment rows.')

if __name__=="__main__":
    main()
