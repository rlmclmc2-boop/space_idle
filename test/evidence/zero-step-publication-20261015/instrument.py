"""Wrap only isolated QA publication/display boundaries; no gameplay edits."""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[3]
QA_PATH = 'res://qa_publication_cost.gd'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_once(text, old, new):
    assert text.count(old) == 1, (old, text.count(old))
    return text.replace(old, new, 1)


def wrap(text, signature, args, scope, symbol, indent='\t'):
    name = signature[5:signature.index('(')]
    alias_name = '_qa_' + scope
    alias = signature.replace('func ' + name + '(', 'func ' + alias_name + '(', 1)
    wrapper = (signature + f'{indent}var qa_started={symbol}.begin()\n'
               f'{indent}{alias_name}({args})\n'
               f'{indent}{symbol}.finish("{scope}",qa_started)\n\n' + alias)
    return replace_once(text, signature, wrapper)


def patch(project):
    result = {}
    definitions = {
        'battle_slice_runtime.gd': ('QASlice', [
            ('func snapshot()->void:\n', '', 'snapshot'),
            ('func apply_nodes()->void:\n', '', 'apply_nodes'),
        ]),
        'main.gd': ('QAMain', [
            ('func refresh_draw_layers(dt: float) -> void:\n', 'dt', 'refresh_draw_layers'),
            ('func draw_battle() -> void:\n', '', 'draw_battle_core'),
            ('func draw_battle_particles(offset: Vector2, core: bool) -> void:\n', 'offset,core', 'draw_particles'),
        ]),
        'battlefield.gd': ('QAField', [
            ('func _process_battlefield(delta: float) -> void:\n', 'delta', 'battlefield_process'),
            ('func _draw_muzzle_cues() -> void:\n', '', 'muzzle_draw'),
            ('func advance_projectile_visuals(dt:float)->void:\n', 'dt', 'advance_visuals'),
            ('func draw_battle() -> void:\n', '', 'draw_battle_scene'),
        ]),
        'retained_enemy_contacts.gd': ('QARetained', [
            ('func sync(offset:Vector2,boss:bool)->void:\n', 'offset,boss', 'retained_sync'),
            ('func stage_foreground(flights:Variant,shots:Array,offset:Vector2)->void:\n', 'flights,shots,offset', 'foreground_stage'),
        ]),
    }
    for name, (symbol, methods) in definitions.items():
        source = ROOT / 'space-battleship/scripts' / name
        target = project / 'scripts' / name
        assert target.read_bytes() == source.read_bytes(), name
        text = source.read_text(encoding='utf8')
        first = next(line + '\n' for line in text.splitlines() if line.startswith('extends '))
        text = replace_once(text, first, first + f'const {symbol}=preload("{QA_PATH}")\n')
        for signature, args, scope in methods:
            text = wrap(text, signature, args, scope, symbol, ' ' if name == 'retained_enemy_contacts.gd' else '\t')
        if name == 'retained_enemy_contacts.gd':
            text = replace_once(text, 'class Part extends Node2D:\n',
                                f'class Part extends Node2D:\n const QAPart=preload("{QA_PATH}")\n')
            text = replace_once(text,
                                ' func _draw()->void:\n  builds+=1\n  if kind.begins_with("foreground") or not data.is_empty():host.paint(self,kind,data)\n',
                                ' func _draw()->void:\n'
                                '  var qa_started=QAPart.begin()\n'
                                '  builds+=1\n'
                                '  if kind.begins_with("foreground") or not data.is_empty():host.paint(self,kind,data)\n'
                                '  var qa_static=kind in ["hull","deck_physical_body","deck_physical_strokes","deck_energy_body","deck_energy_strokes","weapon_body","weapon_strokes"]\n'
                                '  QAPart.finish("static_part_draw" if qa_static else "dynamic_part_draw",qa_started)\n')
        target.write_text(text, encoding='utf8')
        result[name] = {'source_sha256': sha(source), 'qa_sha256': sha(target)}
    return result
