"""Validate independent Galaxy work, macro slots and presentation configuration."""
import math

def validate(data):
    galaxies=data.get('galaxy',{})
    if not galaxies:return
    def num(value,label,zero=False,integer=False):
        if type(value) not in (int,float) or not math.isfinite(value) or value<0 or (not zero and value==0) or (integer and value!=int(value)):
            raise ValueError(f'galaxy: invalid {label}: {value}')
    cfg=data.get('galaxy_config',{})
    for key in ('visible_tick','hidden_tick','chunk_size','disable_hidden_visual','income_interval','iron_resource_id','max_transport_ships','max_visual_pulses','camera_zoom_min','camera_zoom_max'):
        num(cfg.get(key,{}).get('value'),key,integer=key in ('chunk_size','disable_hidden_visual','iron_resource_id','max_transport_ships','max_visual_pulses'))
    # Presentation-only traffic parameters never enter construction/crew work.
    for key in ('transport_buildings_per_ship','transport_initial_delay','transport_departure_interval'):
        num(cfg.get(key,{}).get('value'),key,zero=key!='transport_buildings_per_ship')
    if cfg['disable_hidden_visual']['value']!=1 or cfg['camera_zoom_min']['value']>cfg['camera_zoom_max']['value']:raise ValueError('galaxy: invalid visibility/camera settings')
    if str(int(cfg['iron_resource_id']['value'])) not in data['resources']:raise ValueError('galaxy: unknown iron resource')
    retired={'colony_grid_w','colony_grid_h','core_grid_w','core_grid_h','upgrade_interval','base_attempt_full','attempt_per_crew_full','hidden_steps_per_paint','wander_chance','visible_tick','hidden_tick'}
    for key,row in galaxies.items():
        if retired.intersection(row):raise ValueError('galaxy: retired grid/timing fields')
        for field in ('id','order','map_w','map_h','start_w','start_h','building_slot_count','ship_per_crew','special_cycle','concurrent_upgrade_count'):num(row.get(field),f'{key}.{field}',integer=True)
        num(row.get('slot_seed'),f'{key}.slot_seed',zero=True,integer=True)
        for field in ('explore_work_total','explore_power_base','upgrade_power_base','build_interval','upgrade_cost_lv2','upgrade_cost_lv3','upgrade_cost_lv4','upgrade_cost_lv5'):num(row.get(field),f'{key}.{field}')
        for field in ('explore_power_per_crew','upgrade_power_per_crew','construction_time'):num(row.get(field),f'{key}.{field}',zero=True)
        for axis in ('w','h'):
            if not 0<row[f'start_{axis}']<=row[f'map_{axis}'] or (row[f'map_{axis}']-row[f'start_{axis}'])%2:raise ValueError('galaxy: invalid centered map')
        if row.get('next_galaxy') and row['next_galaxy'] not in galaxies:raise ValueError('galaxy: unknown successor')
        if row.get('unlock_type')=='conquered_planet_count':num(row.get('unlock_value'),f'{key}.unlock_value',zero=True,integer=True)
        elif row.get('unlock_type')!='galaxy_complete' or row.get('unlock_value') not in galaxies:raise ValueError('galaxy: unsupported unlock')
        seen={key};following=row.get('next_galaxy')
        while following:
            if following in seen:raise ValueError('galaxy: successor cycle')
            seen.add(following);following=galaxies[following].get('next_galaxy')
    allowed={'crew_exp','equipment_value','charge_max','gem_fragment','iron_auto_ratio','uranium_auto_ratio'}
    for key,row in data.get('galaxy_build',{}).items():
        if row.get('galaxy_key') not in galaxies or row.get('group') not in ('normal','special') or row.get('effect_type') not in allowed:raise ValueError(f'galaxy_build: invalid {key}')
        num(row.get('id'),key,integer=True)
        if row.get('max_lv')!=5:raise ValueError('galaxy: five building levels required')
        num(row.get('base_effect'),key,zero=True)
        if 'construction_time' in row:raise ValueError('galaxy: construction time belongs to galaxy')
        for level in range(1,6):
            path=row.get(f'asset_lv{level}','')
            if path and not path.lower().endswith(('.glb','.gltf','.tscn','.scn')):raise ValueError('galaxy: model path required')
    for key in galaxies:
        if not any(r['galaxy_key']==key and r['group']=='normal' for r in data['galaxy_build'].values()):raise ValueError('galaxy: missing normal pool')
