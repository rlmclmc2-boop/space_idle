"""QA-only draw callback wrappers in the isolated copied Godot project."""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[3]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def once(source, old, new):
    assert source.count(old) == 1, (old, source.count(old))
    return source.replace(old, new, 1)


def patch(project):
    result = {}
    main = ROOT / 'space-battleship/scripts/main.gd'
    src = main.read_text(encoding='utf8')
    src = once(src, 'extends Node2D\n', 'extends Node2D\nconst QADraw=preload("res://qa_draw_cost.gd")\n')
    src = once(src, 'layer.draw.connect(func():draw_surface=layer;painter.call())',
               'layer.draw.connect(func():\n'
               '\t\t\tvar qa_started=QADraw.begin()\n'
               '\t\t\tdraw_surface=layer;painter.call()\n'
               '\t\t\tQADraw.finish("layer_"+str(index),qa_started))')
    target = project / 'scripts/main.gd'
    target.write_text(src, encoding='utf8')
    result['main.gd'] = {'source_sha256': sha(main), 'qa_sha256': sha(target)}

    battlefield = ROOT / 'space-battleship/scripts/battlefield.gd'
    src = battlefield.read_text(encoding='utf8')
    src = once(src, 'extends "res://scripts/main.gd"\n',
               'extends "res://scripts/main.gd"\nconst QAPulse=preload("res://qa_draw_cost.gd")\n')
    src = once(src, 'pulse_layer.draw.connect(_draw_muzzle_cues)',
               'pulse_layer.draw.connect(func():\n'
               '\t\tvar qa_started=QAPulse.begin()\n'
               '\t\t_draw_muzzle_cues()\n'
               '\t\tQAPulse.finish("pulse_layer",qa_started))')
    target = project / 'scripts/battlefield.gd'
    target.write_text(src, encoding='utf8')
    result['battlefield.gd'] = {'source_sha256': sha(battlefield), 'qa_sha256': sha(target)}

    retained = ROOT / 'space-battleship/scripts/retained_enemy_contacts.gd'
    src = retained.read_text(encoding='utf8')
    src = once(src, 'extends Node2D\n', 'extends Node2D\nconst QARetained=preload("res://qa_draw_cost.gd")\n')
    src = once(src,
               ' func _draw()->void:\n  builds+=1\n  if kind.begins_with("foreground") or not data.is_empty():host.paint(self,kind,data)\n',
               ' func _draw()->void:\n'
               '  var qa_started=QARetained.begin()\n'
               '  builds+=1\n'
               '  if kind.begins_with("foreground") or not data.is_empty():host.paint(self,kind,data)\n'
               '  QARetained.finish("retained_"+kind,qa_started)\n')
    target = project / 'scripts/retained_enemy_contacts.gd'
    target.write_text(src, encoding='utf8')
    result['retained_enemy_contacts.gd'] = {'source_sha256': sha(retained), 'qa_sha256': sha(target)}
    return result
