"""The shared display catalog; editing prose never changes parameter contracts."""
import collections
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'data/ui_text.json'
CONTRACT = ROOT / 'data/ui_text_contract.json'
TOKEN = re.compile(r'\{([^{}]*)\}')
_texts = None
_deleted = set()


def diagnostic(message_key, **values):
    # Validation diagnostics must work even when another catalog row is invalid.
    try:
        rows = json.loads(CATALOG.read_text(encoding='utf-8'))
        template = next(row['text'] for row in rows if row['key'] == message_key)
        return TOKEN.sub(lambda found: str(values[found[1]]), template)
    except (OSError, ValueError, KeyError, TypeError, StopIteration):
        return 'UI catalog invalid: ' + message_key + ' ' + str(values)


def parameters(text):
    result = TOKEN.findall(text)
    rest = TOKEN.sub('', text)
    if '{' in rest or '}' in rest:
        result.append('!invalid_braces')
    return result


def validate(rows, contracts=None):
    contracts = contracts or json.loads(CONTRACT.read_text(encoding='utf-8'))['entries']
    errors, seen = [], set()
    if not isinstance(rows, list):
        return [diagnostic('system.validation.table')]
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get('key'), str) or not isinstance(row.get('text'), str) or type(row.get('deleted', False)) is not bool:
            errors.append(diagnostic('system.validation.row'))
            continue
        key = row['key']
        if key in seen or key not in contracts:
            errors.append(diagnostic('system.validation.key', key=key))
            continue
        seen.add(key)
        expected = collections.Counter(contracts[key]['params'])
        actual = collections.Counter(parameters(row['text']))
        for name, count in (expected - actual).items():
            errors.append(diagnostic('system.validation.missing', key=key, parameter='{'+name+'}', count=count))
        for name in actual - expected:
            errors.append(diagnostic('system.validation.extra', key=key, parameter='{'+name+'}'))
    errors.extend(diagnostic('system.validation.missing_key', key=key) for key in contracts.keys() - seen)
    return errors


def t(text_key, **values):
    global _texts, _deleted
    if _texts is None:
        rows = json.loads(CATALOG.read_text(encoding='utf-8'))
        errors = validate(rows)
        if errors:
            raise ValueError('\n'.join(errors))
        _texts = {r['key']: r['text'] for r in rows}
        _deleted = {r['key'] for r in rows if r.get('deleted', False)}
    template = _texts[text_key]
    if set(parameters(template)) != values.keys():
        raise ValueError('UI parameter mismatch: ' + text_key)
    if text_key in _deleted:
        return ''
    return TOKEN.sub(lambda found: str(values[found[1]]), template)
