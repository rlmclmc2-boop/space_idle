"""Patch only two isolated QA scripts; branch production stays byte identical."""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[3]
PRELOAD = 'const QACost=preload("res://qa_cost.gd")\n'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def once(text, old, new):
    assert text.count(old) == 1, (old, text.count(old))
    return text.replace(old, new, 1)


def patch(project):
    result = {}
    for name in ('native_execution_session.gd', 'main.gd'):
        source = ROOT / 'space-battleship/scripts' / name
        target = project / 'scripts' / name
        assert target.read_bytes() == source.read_bytes(), name
        text = source.read_text(encoding='utf8')
        first = next(line + '\n' for line in text.splitlines() if line.startswith('extends '))
        text = once(text, first, first + PRELOAD)
        if name == 'native_execution_session.gd':
            signature = 'func consume_feedback(game:RefCounted)->void:\n'
            wrapper = ('func consume_feedback(game:RefCounted)->void:\n'
                       '\tvar qa_started=QACost.begin()\n'
                       '\t_qa_consume_feedback(game)\n'
                       '\tQACost.record("consume_feedback",qa_started)\n\n'
                       'func _qa_consume_feedback(game:RefCounted)->void:\n')
            text = once(text, signature, wrapper)
            text = once(text, '\tfor row in kernel.take_feedback():\n',
                        '\tvar qa_take_started=QACost.begin()\n'
                        '\tvar qa_rows:Array=kernel.take_feedback()\n'
                        '\tQACost.record("take_feedback",qa_take_started)\n'
                        '\tfor row in qa_rows:\n')
            text = once(text, '\t\tfeedback_rows+=1\n\t\tvar p:Vector2=row.position\n',
                        '\t\tfeedback_rows+=1\n'
                        '\t\tvar qa_kind:int=int(row.kind)\n'
                        '\t\tvar qa_scope:="fire_impact" if qa_kind in [0,1] else "hit" if qa_kind==2 else "chain_secondary" if qa_kind in [4,8] else "other"\n'
                        '\t\tvar qa_row_started=QACost.begin()\n'
                        '\t\tvar p:Vector2=row.position\n')
            text = once(text, '\t\t\tcontinue\n\t\tmatch int(row.kind):',
                        '\t\t\tQACost.record(qa_scope,qa_row_started)\n'
                        '\t\t\tcontinue\n\t\tmatch int(row.kind):')
            text = once(text, '\nfunc cancel(game:RefCounted)->void:',
                        '\n\t\tQACost.record(qa_scope,qa_row_started)\n\nfunc cancel(game:RefCounted)->void:')
        else:
            signature = 'func queue_damage_number(info: Dictionary) -> void:\n'
            wrapper = ('func queue_damage_number(info: Dictionary) -> void:\n'
                       '\tvar qa_started=QACost.begin()\n'
                       '\t_qa_queue_damage_number(info)\n'
                       '\tQACost.record("hit_label",qa_started)\n\n'
                       'func _qa_queue_damage_number(info: Dictionary) -> void:\n')
            text = once(text, signature, wrapper)
        target.write_text(text, encoding='utf8')
        result[name] = {'source_sha256': sha(source), 'qa_sha256': sha(target)}
    return result
