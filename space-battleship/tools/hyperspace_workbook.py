"""Typed XLSX authority for independent hyperspace configuration.

Container rows retain ordering and distinguish object keys from array indices.
Numeric cells are editable values; formulas are rejected without cached values.
"""
import io
import json
import math
import openpyxl

SHEET = 'hyperspace_config'
HEADER = ('path', 'type', 'value')


def pointer(parent, key):
    return parent + '/' + str(key).replace('~', '~0').replace('/', '~1')


def export_config(config, path):
    book = openpyxl.Workbook()
    sheet = book.active
    sheet.title = SHEET
    sheet.append(HEADER)
    def visit(value, name):
        if isinstance(value, dict):
            sheet.append((name, 'object', None))
            for key, child in value.items():
                visit(child, pointer(name, key))
        elif isinstance(value, list):
            sheet.append((name, 'array', len(value)))
            for index, child in enumerate(value):
                visit(child, pointer(name, index))
        else:
            kind = 'null' if value is None else 'bool' if isinstance(value, bool) else 'int' if isinstance(value, int) else 'float' if isinstance(value, float) else 'string'
            sheet.append((name, kind, value))
    visit(config, '')
    sheet.freeze_panes = 'C2'
    sheet.column_dimensions['A'].width = 65
    sheet.column_dimensions['B'].width = 12
    sheet.column_dimensions['C'].width = 38
    book.save(path)
    book.close()


def read_config(raw):
    book = openpyxl.load_workbook(io.BytesIO(raw), read_only=True, data_only=False)
    try:
        if book.sheetnames != [SHEET]:
            raise ValueError('Hyperspace workbook must contain its one authoritative sheet')
        rows = list(book[SHEET].iter_rows())
        if tuple(cell.value for cell in rows[0]) != HEADER:
            raise ValueError('Hyperspace workbook header mismatch')
        values = {}
        for row in rows[1:]:
            if all(cell.value is None for cell in row):
                continue
            if len(row) != 3 or any(cell.data_type == 'f' for cell in row):
                raise ValueError('Hyperspace values require exactly three columns and literal cells')
            name, kind, value = (cell.value for cell in row)
            name = '' if name is None else name
            if not isinstance(name, str) or name in values or (name and not name.startswith('/')):
                raise ValueError('Duplicate or invalid hyperspace path')
            if kind == 'object':
                if value is not None: raise ValueError('Object row value must be empty')
                parsed = {}
            elif kind == 'array':
                if isinstance(value, bool) or not isinstance(value, (int,float)) or not math.isfinite(value) or int(value) != value or value < 0:
                    raise ValueError('Array size must be a nonnegative integer')
                parsed = [None] * int(value)
            elif kind in ('int', 'float'):
                if isinstance(value, bool) or not isinstance(value, (int,float)) or not math.isfinite(value) or (kind == 'int' and int(value) != value):
                    raise ValueError('Invalid finite hyperspace number at ' + name)
                parsed = int(value) if kind == 'int' else float(value)
            elif kind == 'bool':
                if not isinstance(value, bool): raise ValueError('Expected boolean at ' + name)
                parsed = value
            elif kind == 'string':
                if value is not None and not isinstance(value, str): raise ValueError('Expected string at ' + name)
                parsed = '' if value is None else value
            elif kind == 'null':
                if value is not None: raise ValueError('Expected null at ' + name)
                parsed = None
            else:
                raise ValueError('Unknown hyperspace value type at ' + name)
            values[name] = (kind, parsed)
            if name:
                parent, key = name.rsplit('/', 1)
                key = key.replace('~1', '/').replace('~0', '~')
                if parent not in values:
                    raise ValueError('Parent must precede child at ' + name)
                parent_kind, container = values[parent]
                if parent_kind == 'object':
                    container[key] = parsed
                elif parent_kind == 'array' and key.isdigit() and str(int(key)) == key and int(key) < len(container):
                    container[int(key)] = parsed
                else:
                    raise ValueError('Invalid container child at ' + name)
        if '' not in values or values[''][0] != 'object':
            raise ValueError('Hyperspace root must be an object')
        for name, (kind, value) in values.items():
            if kind == 'array' and any(pointer(name, i) not in values for i in range(len(value))):
                raise ValueError('Incomplete hyperspace array at ' + name)
        result = values[''][1]
        if result.get('version') != 2:
            raise ValueError('Unsupported hyperspace configuration version')
        for key in ('energy_rate', 'energy_cap', 'ticket', 'minimum_duration'):
            value = result.get(key)
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
                raise ValueError('Hyperspace time/energy must be finite and positive: ' + key)
        weights = result.get('quality_weights')
        if not isinstance(weights, dict) or not weights or any(key not in ('white', 'blue', 'gold', 'legendary', 'ultimate_core') for key in weights):
            raise ValueError('Invalid hyperspace quality outcomes')
        if any(isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value < 0 for value in weights.values()) or sum(weights.values()) <= 0:
            raise ValueError('Invalid hyperspace quality weights')
        if 'late_supply_unlock_stage' in result:
            for key in ('late_supply_unlock_stage', 'late_material_reward_multiplier'):
                if isinstance(result.get(key), bool) or not isinstance(result.get(key), int) or result[key] < 1:
                    raise ValueError('Late supply stage/material multiplier must be a positive integer')
            value = result.get('late_energy_rate_multiplier')
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
                raise ValueError('Late supply energy multiplier must be finite and positive')
        return result
    finally:
        book.close()
