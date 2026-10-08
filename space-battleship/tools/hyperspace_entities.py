"""Read the two authoritative entity workbooks without editing either workbook.

Immutable shape/order comes from a pinned schema, not a second editable balance
source. The catalog is rebuilt from current mainline drops and95 literal early fallback
rows. Only the1960 source mapping remains pinned and is structurally verified.
"""
import copy
import hashlib
import io
import json
import math
import re
from pathlib import Path
import openpyxl
from explicit_formation import validate as validate_formation

SCHEMA_PATH = Path(__file__).resolve().parents[1] / 'data/hyperspace_entity_schema.json'


def load_schema():
    return json.loads(SCHEMA_PATH.read_text(encoding='utf-8'))


def finite(v):
    return not isinstance(v, bool) and isinstance(v, (int, float)) and math.isfinite(v) and abs(v) < 9e15


def literal(v, kind, context):
    if kind.endswith('_or_blank') and v is None:
        return None
    kind = kind.removesuffix('_or_blank')
    if kind in ('int', 'float', 'number'):
        if not finite(v) or (kind == 'int' and int(v) != v):
            raise ValueError(f'{context}: expected finite {kind}')
        return int(v) if kind == 'int' else float(v) if kind == 'float' else v
    if kind == 'bool' and isinstance(v, bool):
        return v
    if kind in ('string', 'enum') and (v is None or isinstance(v, str)):
        return '' if v is None else v
    if kind == 'null' and v is None:
        return None
    raise ValueError(f'{context}: invalid literal type {kind}')


def parse_tables(raw_by_filename, schema=None):
    schema = schema or load_schema()
    result = {}
    expected_names = {t['workbook'] for t in schema['tables']}
    if set(raw_by_filename) != expected_names:
        raise ValueError('Exactly both hyperspace entity workbooks are required')
    for filename, raw in raw_by_filename.items():
        book = openpyxl.load_workbook(io.BytesIO(raw), read_only=True, data_only=False)
        try:
            definitions = [t for t in schema['tables'] if t['workbook'] == filename]
            if set(book.sheetnames) != {t['sheet'] for t in definitions}:
                raise ValueError(f'{filename}: authoritative sheet set mismatch')
            for t in definitions:
                rows = list(book[t['sheet']].iter_rows())
                names = [c['key'] for c in t['columns']]
                if len(rows) < 3 or [c.value for c in rows[0]] != names:
                    raise ValueError(f"{filename}/{t['sheet']}: exact header required")
                if [c.value for c in rows[2]] != [c['type'] for c in t['columns']]:
                    raise ValueError(f"{t['sheet']}: row3 type contract mismatch")
                if any(c.data_type == 'f' for row in rows for c in row):
                    raise ValueError(f"{t['sheet']}: formulas are not supported")
                if any(not isinstance(c.value, str) or not c.value.strip() for c in rows[1]):
                    raise ValueError(f"{t['sheet']}: row2 descriptions required")
                records = []
                for line, row in enumerate(rows[3:], 4):
                    if all(c.value is None for c in row):
                        continue
                    if len(row) != len(names):
                        raise ValueError(f"{t['sheet']}:{line}: column count mismatch")
                    record = dict(zip(names, [c.value for c in row]))
                    records.append(record)
                result[(filename, t['sheet'])] = records
        finally:
            book.close()
    return result


def at(root, pointer):
    for key in pointer.strip('/').split('/'):
        root = root[int(key)] if isinstance(root, list) else root[key]
    return root


def assign(root, pointer, value):
    keys = pointer.strip('/').split('/')
    node = root
    for key in keys[:-1]:
        node = node[int(key)] if isinstance(node, list) else node[key]
    if isinstance(node, list):
        node[int(keys[-1])] = value
    else:
        node[keys[-1]] = value


def project_tables(tables, mainline, frozen, schema=None):
    """The same pure projection is used for XLSX and typed-data/shuffle fixtures."""
    schema = schema or load_schema()
    if set(tables) != {(t['workbook'], t['sheet']) for t in schema['tables']}:
        raise ValueError('Missing/extra entity tables')
    outputs = copy.deepcopy(schema['templates'])
    for t in schema['tables']:
        received = {}
        for raw in tables[(t['workbook'], t['sheet'])]:
            if set(raw) != {c['key'] for c in t['columns']}:
                raise ValueError(f"{t['sheet']}: column mismatch")
            row = {}
            for c in t['columns']:
                kind = raw.get('data_type') if c['type'] == 'typed_literal' else c['type']
                row[c['key']] = literal(raw[c['key']], kind, f"{t['sheet']}/{c['key']}")
            identity = tuple(row[k] for k in t['primary_key'])
            if identity in received:
                raise ValueError(f"{t['sheet']}: duplicate primary key {identity}")
            received[identity] = row
        if set(received) != {tuple(r['identity']) for r in t['rows']}:
            raise ValueError(f"{t['sheet']}: immutable identity/structure mismatch")
        # Manifest order and locked order columns jointly preserve RNG mapping.
        for expected in t['rows']:
            row = received[tuple(expected['identity'])]
            for key, value in expected['locked'].items():
                if key not in ('unit','description','constraint') and row[key] != value:
                    raise ValueError(f"{t['sheet']}/{key}: readonly value differs")
            for field, targets in expected['mappings'].items():
                for filename, pointer in targets:
                    assign(outputs[filename], pointer, row[field])
    cfg = outputs['hyperspace_config.json']
    candidates = outputs['space_enemy_candidates.json']
    recipes = outputs['space_enemy_reward_recipes.json']
    for gid, members in recipes['groups'].items():
        for member in members:
            member['enemy_id'] = candidates['groups'][gid]['slots'][member['slot']]
            member['jewelDropRolls'] = len(member['reference_member_ordinals_for_resource_blocks'])
    derive_catalog(outputs['space_enemy_reward_catalog.json'], mainline)
    validate_sources(frozen['space_enemy_reward_sources.json'],mainline,schema)
    validate_outputs(outputs, mainline, frozen)
    return outputs


def group_blocks(mainline, gid, count):
    group=mainline['groups'].get(str(gid))
    if not group:raise ValueError('Missing mainline reward group: '+str(gid))
    blocks=[copy.deepcopy(mainline['enemies'][str(eid)]['drops']) for eid in group['slots'] if eid is not None]
    if len(blocks)!=count:raise ValueError('Mainline reward member count changed: '+str(gid))
    return blocks


def derive_catalog(catalog, mainline):
    for ref in catalog['references'].values():
        count=ref['reference_member_count']
        ref['late_drop_blocks']=group_blocks(mainline,ref['late_reference_actual_group_id'],count)
        if ref['early_existing_encounters']:
            # The first documented source is a fixed, explicit fallback authority.
            # Actual matching sources continue to bind their own current group.
            for source in ref['early_existing_encounters']:
                level=next((l for l in mainline['levels'] if l['id']==source['level_id']),None)
                if level is None or not any(g['id']==source['group_id'] for g in level['groups']):raise ValueError('Early reward source association changed')
                group_blocks(mainline,source['group_id'],count)
            ref['early_drop_blocks']=group_blocks(mainline,ref['early_existing_encounters'][0]['group_id'],count)


def validate_sources(sources,mainline,schema):
    if sources.get('source_sha256')!=schema['sources_origin']['sha256'] or len(sources.get('waves',[]))!=schema['sources_origin']['verified_wave_count']:raise ValueError('Original source plan identity mismatch')
    levels={l['id']:l for l in mainline['levels']}
    for wave in sources['waves']:
        level=levels.get(wave['stage']);node=wave['node']
        if level is None or not 1<=node<=len(level['groups']) or level['groups'][node-1]['id']!=wave['group'] or str(wave['group']) not in mainline['groups'] or str(wave['source_group']) not in mainline['groups']:raise ValueError('Frozen1960 source mapping no longer matches mainline structure')


def validate_config(c):
    positive = ['energy_rate','energy_cap','ticket','minimum_duration','value_precision','amplification_rate','lock_cost_multiplier','reroll_guarantee_multiplier','modernization_cost_base','modernization_level_step','modernization_legendary_multiplier','modernization_base_coefficient','auto_duration_crew_base','auto_ticket_crew_base','late_energy_rate_multiplier','late_supply_ramp_seconds']
    positive_int = ['unlock_stage','minimum_level','warehouse_capacity','reforge_capacity_gain','retention_capacity_gain','maximum_equipped','maximum_legendary','maximum_ultimate','completion_budget','material_base_reward','material_reward_start_level','material_reward_level_step','maximum_filter_conditions','maximum_filter_string_length','maximum_forecast_attempts','late_supply_unlock_stage','late_material_reward_multiplier','amplification_start_level']
    for key in positive + positive_int:
        if not finite(c[key]) or c[key] <= 0 or (key in positive_int and int(c[key]) != c[key]):
            raise ValueError('Invalid positive config field: ' + key)
    scale = c.get('material_unit_scale')
    if not finite(scale) or int(scale) != scale or scale <= 0:
        raise ValueError('Invalid positive material unit scale')
    probability = c.get('ultimate_core_probability')
    if not finite(probability) or not 0 <= probability <= 1:
        raise ValueError('Invalid actual ultimate core probability')
    if c['hanging_modules']['hyperspace_charge']['effects'] != ['hyperspace_material_income']:
        raise ValueError('Collector must affect ordinary hyperspace materials only')
    for key in ['initial_retention_capacity','ultimate_weapon_bonus']:
        if not finite(c[key]) or int(c[key]) != c[key] or c[key] < 0:
            raise ValueError('Invalid nonnegative integer: ' + key)
    for key, maximum in [('maximum_equipped',5),('maximum_legendary',2),('maximum_ultimate',1),('maximum_filter_conditions',5)]:
        if c[key] > maximum:raise ValueError('Hard cap exceeded: '+key)
    if c['overflow_capacity'] != 10:raise ValueError('Overflow must remain10')
    for key in ['affix_initial_probability','hanging_initial_probability','additional_probability_factor']:
        if not finite(c[key]) or not 0 <= c[key] <= 1:raise ValueError('Invalid probability: '+key)
    for q, limits in c['quality_limits'].items():
        for field, cap in [('affixes',dict(white=0,blue=2,gold=3,legendary=3)[q]),('hangings',dict(white=4,blue=2,gold=1,legendary=0)[q])]:
            if not 0 <= limits[field] <= cap:raise ValueError('Invalid quality cap')
    for v in c['hull_capacities'].values():
        if not 1 <= v <= 5:raise ValueError('Invalid hull capacity')
    for name in ['quality_weights','tier_weights','modernization_tier_weights']:
        if any(not finite(v) or v < 0 or (name=='tier_weights' and v==0) for v in c[name].values()) or (name != 'modernization_tier_weights' and sum(c[name].values()) <= 0):raise ValueError('Invalid weights: '+name)
    for q in c['dismantle_amounts']:
        if c['dismantle_amounts'][q] < 1 or c['weapon_level_bonuses'][q] < 0:raise ValueError('Invalid quality reward')
    for cost in c['forge_costs'].values():
        if any(v<0 for v in cost.values()):raise ValueError('Negative forge cost')
    for row in c['hanging_modules'].values():
        if row['base_exp']<=0 or row['exp_growth']<0 or row['effect_growth']<0 or row['unlock_stage']<0:raise ValueError('Invalid hanging growth')
    for table, field in [('affixes','ranges'),('legendary_effects','parameters')]:
        for row in c[table].values():
            if row['weapon'] not in ['','laser','missile','cannon','longLaser']:raise ValueError('Unsupported weapon binding')
            for low,high in row[field].values():
                if not finite(low) or not finite(high) or low<0 or high<low or math.ceil(low/c['value_precision']-1e-7) > math.floor(high/c['value_precision']+1e-7):raise ValueError('Invalid/empty quantized parameter range')
    for e, row in c['legendary_effects'].items():
        for key,v in row['constants'].items():
            if key in ['period','cooldown','delay','absorption_duration'] and v<=0:raise ValueError('Invalid effect timing')
            if key in ['spawn_probability','blast_fraction'] and not 0<=v<=1:raise ValueError('Invalid effect probability/fraction')
            if key in ['kill_spawns','nearby_targets','maximum_stacks','attack_period','maximum_cannon_sources','stack_limit'] and v<0:raise ValueError('Invalid effect count')
        if 'maximum_dodge' in row['parameters'] and row['parameters']['maximum_dodge'][1]>1:raise ValueError('Dodge probability exceeds1')
        if e=='black_hole' and row['constants']['period']<row['constants']['absorption_duration']:raise ValueError('Black hole window exceeds period')
    fleet=c['legendary_effects']['drone_master'];ratios=fleet['constants']['quality_ratios']
    if ratios['ultimate']<=0 or any(v<0 or v>ratios['ultimate'] for v in ratios.values()) or fleet['parameters']['maximum_reduction'][1]>1:raise ValueError('Invalid fleet command normalization')


def validate_visuals(v, config):
    if not finite(v['version']) or int(v['version']) != v['version'] or v['version'] <= 0:
        raise ValueError('Visual version must be a positive integer')
    if not isinstance(v['animate'], bool):
        raise ValueError('Visual animate must be bool')
    for key, low, high, integer in [('emission',0,0.7,False),('high_tier_max',1,5,True),('ornament_scale',0.5,1.1,False),('body_tint',0,1,False),('tier_glyph_scale',1,3,False)]:
        value=v[key]
        if not finite(value) or not low <= value <= high or (integer and int(value) != value):
            raise ValueError('Invalid visual range/type: '+key)
    colors=[v['ultimate_color']]
    if set(v['quality']) != {'white','blue','gold','legendary'}:
        raise ValueError('Missing/extra visual quality reference')
    for quality, row in v['quality'].items():
        if quality not in config['quality_weights'] or quality not in config['quality_limits']:
            raise ValueError('Unknown visual quality reference: '+quality)
        rank=row['rank']
        if not finite(rank) or int(rank) != rank or not 0 <= rank <= 3:
            raise ValueError('Invalid visual rank: '+quality)
        colors.append(row['color'])
    if any(not isinstance(color,str) or not re.fullmatch(r'[0-9a-fA-F]{6}',color) for color in colors):
        raise ValueError('Visual colors must be six hex digits without #')


def validate_outputs(outputs, mainline, frozen):
    c=outputs['hyperspace_config.json'];validate_config(c)
    validate_visuals(outputs['hyperspace_visuals.json'],c)
    enemies=outputs['space_enemy_candidates.json']['enemies'];groups=outputs['space_enemy_candidates.json']['groups'];routes=outputs['space_enemy_routes.json']['routes'];recipes=outputs['space_enemy_reward_recipes.json']['groups']
    for eid,e in enemies.items():
        if eid in mainline['enemies'] or e['health']<=0 or e['size']<1 or e['armourType'] not in [0,1,2] or e['shieldType'] not in [0,1,2] or any(e[k]<0 for k in ['shield','shieldRecovery','shieldDelay','dmgMultiple']):raise ValueError('Invalid hyperspace enemy '+eid)
        for w in e['equipment']:
            if w['name'].replace('_mon','').replace('-mon','') not in mainline['enemy_weapon_base'] and w['name'] not in mainline['equipment']:raise ValueError('Unknown enemy weapon '+w['name'])
    seen=[]
    for route in c['routes'].values():
        for tier,size in [('normal',4),('elite',4),('boss',1),('ultimate',1)]:
            ids=routes[route['weapon']][tier]
            if len(ids)!=size:raise ValueError('Route group count mismatch')
            for gid in ids:
                if str(gid) not in groups or groups[str(gid)]['combatTier']!=tier:raise ValueError('Route tier/group mismatch')
                seen.append(gid)
    if len(set(seen))!=40:raise ValueError('Routes must uniquely cover all40 groups')
    refs=outputs['space_enemy_reward_catalog.json']['references']
    for gid,g in groups.items():
        if gid in mainline['groups'] or len(g['slots'])!=15:raise ValueError('Group identity/slot count invalid')
        if any(v is not None and str(v) not in enemies for v in g['slots']):raise ValueError('Unknown slot enemy')
        validate_formation(g,enemies)
        ref=g['rewardBinding']['rewardReferenceDesignId']
        if ref not in refs:raise ValueError('Unknown reward reference')
        ordinals=[];slots=[]
        for member in recipes[gid]:
            slot=member['slot'];aa=member['reference_member_ordinals_for_resource_blocks'];slots.append(slot);ordinals+=aa
            if g['slots'][slot] is None or member['enemy_id']!=g['slots'][slot] or member['jewelDropRolls']!=len(aa):raise ValueError('Recipe member mismatch')
        if len(set(slots))!=len(slots) or set(slots)!={i for i,v in enumerate(g['slots']) if v is not None} or sorted(ordinals)!=list(range(refs[ref]['reference_member_count'])):raise ValueError('Recipe coverage/ordinal mismatch')
    for ref in refs.values():
        for field in ['early_drop_blocks','late_drop_blocks']:
            if len(ref[field])!=ref['reference_member_count']:raise ValueError('Catalog block count mismatch')
            for block in ref[field]:
                for drop in block:
                    if not finite(drop['resourceId']) or int(drop['resourceId'])!=drop['resourceId'] or str(int(drop['resourceId'])) not in mainline['resources'] or not finite(drop['amount']) or drop['amount']<0 or not finite(drop['chance']) or not 0<=drop['chance']<=1:raise ValueError('Invalid catalog drop')
    for ref in refs.values():
        design=mainline['groups'].get(str(ref['source_design_group_id']))
        level=next((l for l in mainline['levels'] if l['id']==ref['late_reference_actual_level_id']),None)
        if not design or sum(v is not None for v in design['slots'])!=ref['reference_member_count'] or level is None or not any(g['id']==ref['late_reference_actual_group_id'] for g in level['groups']):raise ValueError('Frozen reward reference does not match mainline')


def read_bundle(raw_by_filename, mainline, data_directory):
    schema=load_schema();frozen={};snapshots={}
    for name,digest in schema['frozen_inputs'].items():
        raw=(data_directory/name).read_bytes()
        if hashlib.sha256(raw).hexdigest()!=digest:raise ValueError('Frozen reward baseline hash mismatch: '+name)
        frozen[name]=json.loads(raw);snapshots[data_directory/name]=raw
    outputs=project_tables(parse_tables(raw_by_filename,schema),mainline,frozen,schema)
    return outputs,snapshots
