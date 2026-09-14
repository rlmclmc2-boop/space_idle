"""Excel projection and validation shared by full and incremental imports."""
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
SECTIONS = {"level":"levels", "equipment":"equipment", "mon":"enemies", "monGroup":"groups", "res":"resources", "config":"config", "hightech":"hightech", "charge":"charge"}
DEFAULTS = {"autoCollectDelay":5.0,"loopDelay":6.0,"deathRetreatDistance":300.0,"deathRetreatDuration":1.2,"projectilePixelsPerUnit":28.0,"startingIron":0.0,"startingTitanium":0.0}
FALLBACKS = {"enemyWeaponMissingLevel":"Use player weapon row 1 when the enemy weapon row is missing.","enemyCannonMissingDamageAndCooldown":"Use player cannon row 1 for missing fields."}

def clean(value):
    return str(value).translate(str.maketrans({"｛":"{","｝":"}","，":",","；":";"})).strip("{} ")

def read_rows(sheet):
    values=sheet.iter_rows(values_only=True)
    header=next(values)
    next(values,None)
    next(values,None)
    return [dict(zip(header,row)) for row in values if row[0] is not None]

def convert_sheet(name, rows):
    if name in ("hightech", "charge"):
        result={}
        for row in rows:
            key=row.get("name")
            if not isinstance(key,str) or not key.strip() or key in result:
                raise ValueError(f"{name}：名称必须非空且不能重复")
            result[key]=row
        return result
    if name=="equipment":
        result={}
        for row in rows:
            result.setdefault(row["name"],[]).append(row)
        for items in result.values():
            if any(not isinstance(r.get("level"),(int,float)) for r in items):
                raise ValueError("equipment：等级为空或不是数字，请在 Excel 中重新计算并保存")
            items.sort(key=lambda r:r["level"])
        return result
    if name=="mon":
        result={}
        for row in rows:
            mounts = []
            for part in clean(row["equipment"]).split(","):
                fields = part.split("|")
                if len(fields) != 2 or not fields[0].strip() or not fields[1].strip().isdigit() or int(fields[1]) < 1:
                    raise ValueError(f'mon {row["id"]}：武器格式应为 name|正整数数量')
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
            row["groups"]=[{"id":int(p.split("|")[0]),"position":float(p.split("|")[1])} for p in clean(row["monGroup"]).split(",")]
        return rows
    if name=="res":
        return {str(r["id"]):r["name"] for r in rows}
    if name=="config":
        return {r["name"]:r["para_1"] for r in rows}
    raise ValueError("未知配置表："+name)

def projection_base(previous, source):
    data=copy.deepcopy(previous or {})
    data["source"]=source
    data["defaults"]={**DEFAULTS,**data.get("defaults",{})}
    data.setdefault("fallbacks",dict(FALLBACKS))
    return data

def positive(value, label, allow_zero=False):
    if not isinstance(value, (int,float)) or not math.isfinite(value) or value < 0 or (value == 0 and not allow_zero):
        raise ValueError(f'{label}: expected {"nonnegative" if allow_zero else "positive"} number, got {value!r}')

def validate_description(row, field='description', section='hightech'):
    description=row.get(field)
    label=f'{section} {row["name"]} {field}'
    if not isinstance(description,str) or not description.strip():
        raise ValueError(f'{label}: must not be empty')
    for token in re.findall(r'para\d+', description):
        positive(row.get(token if section=='hightech' else token.replace('para','para_')),f'{label} {token}',True)
    blocks=re.findall(r'\{([^{}]+)\}',description)
    if '{' in re.sub(r'\{[^{}]+\}','',description) or '}' in re.sub(r'\{[^{}]+\}','',description):
        raise ValueError(f'{label}: invalid braces')
    for block in blocks:
        parts=block.replace('，',',').split(',')
        if any(option.strip() not in ('向上取整','不含自身','百分比显示','保留两位小数','即100.3%展示为100%','百分比','四舍五入保留整数百分比部分') for option in parts[1:]):
            raise ValueError(f'{label}: unknown rounding instruction')
        formula=re.sub(r'para\d+','1.0',parts[0]).replace('过去一分钟的铁生成量','1.0').replace('等级','1.0').replace('lv','1.0').replace('（','(').replace('）',')').replace('^','**')
        if not re.fullmatch(r'[0-9. +*/()\-]+',formula):
            raise ValueError(f'{label}: only numeric arithmetic is supported')
        try:
            tree=ast.parse(formula.strip(),mode='eval')
        except SyntaxError as error:
            raise ValueError(f'{label}: invalid expression') from error
        for node in ast.walk(tree):
            if not isinstance(node,(ast.Expression,ast.BinOp,ast.UnaryOp,ast.Add,ast.Sub,ast.Mult,ast.Div,ast.Pow,ast.UAdd,ast.USub,ast.Constant)) or (isinstance(node,ast.Constant) and (type(node.value) not in (int,float) or not math.isfinite(node.value))):
                raise ValueError(f'{label}: only numeric arithmetic is supported')


def validate_projection(data):
    equipment=data["equipment"]
    levels=data["levels"]
    groups=data["groups"]
    enemies=data["enemies"]
    config=data["config"]
    for key in ('armour','shield','laser','missile','cannon'):
        items=equipment.get(key,[])
        if not items or [r['level'] for r in items] != list(range(1,len(items)+1)):
            raise ValueError(f'equipment 表 {key}：等级必须从 1 连续递增，不能重复或缺级；当前共 {len(items)} 行')
        for r in items:
            positive(r['para1'] if key in ('armour','shield') else r['dmg'],f'{key} Lv.{r["level"]} value')
            if key not in ('armour','shield'):
                positive(r['cd'], f'{key} cooldown')
                positive(r['para2'] if key=='missile' else r['para1'],f'{key} projectile speed')
            for field in ('cost_1','cost_2'):
                if r[field] is not None: positive(r[field],f'{key} {field}',True)
    if [r['id'] for r in levels] != list(range(1,len(levels)+1)) or not levels:
        raise ValueError('Level IDs must be consecutive from 1')
    for level in levels:
        for key in ('length','atkRatio','lifeRatio','resRatio'): positive(level[key],f'level {level["id"]} {key}')
        positions=[g['position'] for g in level['groups']]
        if not positions or positions!=sorted(set(positions)) or not all(0<=p<=1 for p in positions):
            raise ValueError(f'level {level["id"]}: invalid encounter positions')
        for g in level['groups']:
            if str(g['id']) not in groups: raise ValueError(f'Unknown group {g["id"]}')
    for gid,g in groups.items():
        if len(g['slots'])!=10: raise ValueError(f'group {gid}: expected 10 slots')
        for enemy_id in g['slots']:
            if enemy_id is not None and str(enemy_id) not in enemies: raise ValueError(f'Unknown enemy {enemy_id}')
    for enemy in enemies.values():
        positive(enemy['health'],f'enemy {enemy["id"]} health')
        positive(enemy['dmgMultiple'],f'enemy {enemy["id"]} damage multiplier',True)
        for drop in enemy['drops']:
            positive(drop['amount'],'drop amount',True)
            if not 0<=drop['chance']<=1: raise ValueError('Drop chance must be between 0 and 1')
    for key in ('dmgReduce','autoCollectReduce'):
        if not isinstance(config[key],(int,float)) or not 0<=config[key]<1: raise ValueError(f'{key} must be between 0 (inclusive) and 1 (exclusive)')
    positive(config['movement'],'movement')
    positive(config['backRange'],'backRange',True)
    positive(config.get('offlineMax'),'offlineMax (hours)',True)
    auto_gen = config.get('autoGenRes')
    if auto_gen is not None:
        if not isinstance(auto_gen, str):
            raise ValueError('autoGenRes: expected interval, resource ID, amount, speed')
        parts = [part.strip() for part in auto_gen.replace('，', ',').split(',')]
        if len(parts) != 4 or not parts[0] or not parts[1] or not parts[2] or not parts[3]:
            raise ValueError('autoGenRes: expected interval, resource ID, amount, speed')
        if not re.fullmatch(r'\d+', parts[1]) or str(int(parts[1])) not in data['resources']:
            raise ValueError(f'autoGenRes: unknown resource ID {parts[1]!r}')
        try:
            interval, amount, speed = (float(parts[0]), float(parts[2]), float(parts[3]))
        except ValueError as error:
            raise ValueError('autoGenRes: interval, amount and speed must be numbers') from error
        positive(interval, 'autoGenRes interval')
        positive(amount, 'autoGenRes amount', True)
        positive(speed, 'autoGenRes speed')
    limit=config.get('hightechLimit')
    positive(limit,'hightechLimit')
    if isinstance(limit,bool) or limit != int(limit):
        raise ValueError('hightechLimit: expected positive integer')
    for key,row in data['hightech'].items():
        validate_description(row)
        if not isinstance(row.get('des'),str) or not row['des'].strip():
            raise ValueError(f'hightech {key}: des must not be empty')
        positive(row.get('timeCostBase'),f'hightech {key} timeCostBase')
        if math.floor(row['timeCostBase']+0.5)<1:
            raise ValueError(f'hightech {key}: rounded research duration must be positive')
        positive(row.get('timeCostMutiple'),f'hightech {key} timeCostMutiple',True)
        unlock=row.get('unlock')
        positive(unlock,f'hightech {key} unlock',True)
        if unlock != int(unlock) or unlock > len(levels):
            raise ValueError(f'hightech {key}: unlock must reference a level or be zero')
        positive(row.get('para1'),f'hightech {key} para1',True)
        if row.get('para2') is not None:
            positive(row['para2'],f'hightech {key} para2',True)
        if key == '超时空炼铁炉':
            positive(row.get('para1'),f'hightech {key} interval')
            positive(row.get('para2'),f'hightech {key} para2',True)

    for key,row in data.get('charge',{}).items():
        if key not in ('攻击充能','防御充能','熔炼器充能'):
            raise ValueError(f'charge {key}: unsupported effect')
        if not isinstance(row.get('func'),str) or not row['func'].strip():
            raise ValueError(f'charge {key}: func must not be empty')
        validate_description(row,'des','charge')
        for field in ('para_1','para_2','para_4','para_5','para_6'):
            positive(row.get(field),f'charge {key} {field}')
        positive(row.get('para_3'),f'charge {key} para_3',True)
        positive(row.get('para_7',0),f'charge {key} para_7',True)
        if row['para_1'] != int(row['para_1']) or str(int(row['para_1'])) not in data['resources']:
            raise ValueError(f'charge {key}: unknown resource')
        if math.floor(row['para_5'] + 0.5) < 1 or row['para_6'] < 1:
            raise ValueError(f'charge {key}: rounded charge count must stay positive; growth multiplier must be at least 1')
        positive(row.get('unlock'),f'charge {key} unlock',True)
        if row['unlock'] != int(row['unlock']) or row['unlock'] > len(levels):
            raise ValueError(f'charge {key}: invalid unlock level')

    data["defaults"]["maxEquipmentLevel"]=max(len(equipment[key]) for key in ("armour","shield","laser","missile","cannon"))

def encode(data):
    return json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False).encode("utf-8")

def full_import(source, target):
    previous=json.loads(target.read_text(encoding="utf-8")) if target.exists() else {}
    data=projection_base(previous,source.name)

    book=openpyxl.load_workbook(source,data_only=True,read_only=True)
    try:
        for name,section in SECTIONS.items():
            if name not in book.sheetnames:
                if name == 'charge':
                    continue  # Older master workbooks predate the optional charge sheet.
                raise ValueError("缺少配置表："+name)
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
