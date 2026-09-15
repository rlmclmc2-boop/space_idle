"""Level editor source transaction. Uses the existing XLSX projection contract."""
import argparse
import ast
from decimal import Decimal, ROUND_HALF_UP
import io
import json
import math
from pathlib import Path
import re
import sys
import uuid
import zipfile

import openpyxl
from openpyxl.utils import get_column_letter
from lxml import etree as ET
from config_workbooks import (Q, MANIFEST, CACHE_VERSION, atomic_batch, sha,
                              sheet_parts, read_changed_file)
from import_workbook import ROOT, SECTIONS, validate_projection, encode

EDITABLE = ('mon', 'monGroup', 'level')


class Store:
    def __init__(self, root=ROOT):
        self.root = Path(root)
        self.directory = self.root / 'config_excel'
        self.target = self.root / 'data/game_data.json'
        self.manifest = self.directory / MANIFEST
        mapping = json.loads(self.manifest.read_text(encoding='utf-8'))['sheets']
        self.paths = {}
        for name in SECTIONS:
            if name == 'charge' and name not in mapping:
                if not (self.directory / 'charge.xlsx').is_file():
                    continue
                mapping[name] = 'charge.xlsx'
            filename = mapping[name]
            if Path(filename).name != filename or '/' in filename or '\\' in filename:
                raise ValueError('分表清单路径无效：' + name)
            self.paths[name] = self.directory / filename

    def snapshot(self):
        return {str(p): sha(p.read_bytes()) for p in [*self.paths.values(), self.target, self.manifest]}

    def load(self):
        before = self.snapshot()
        tables = {}
        for name in EDITABLE:
            book = openpyxl.load_workbook(self.paths[name], data_only=False)
            try:
                sheet = book[name]
                headers = [c.value for c in sheet[1] if c.value is not None]
                rows = [{key: sheet.cell(r, c + 1).value for c, key in enumerate(headers)}
                        for r in range(4, sheet.max_row + 1) if sheet.cell(r, 1).value is not None]
                tables[name] = {'headers': headers, 'rows': rows}
            finally:
                book.close()
        if before != self.snapshot():
            raise ValueError('读取时配置被修改，请重新加载')
        data = json.loads(self.target.read_text(encoding='utf-8'))
        return {'tables': tables, 'snapshot': before, 'equipment': data['equipment'], 'resources': data['resources']}

    def workbook_bytes(self, name, table):
        """Patch sheet XML only; preserve styles, headers and other package parts.

        Formula addresses stay explicit in the editor. Evaluate the project's
        arithmetic/ROUND subset and refresh caches; unsupported syntax fails closed.
        """
        headers, rows = table['headers'], table['rows']
        cells = {f'{get_column_letter(c+1)}{r+4}': row.get(key)
                 for r, row in enumerate(rows) for c, key in enumerate(headers)}
        memo = {}

        def value(address, visiting=frozenset()):
            if address in memo:
                return memo[address]
            if address in visiting:
                raise ValueError(f'{name}!{address}：公式循环引用')
            raw = cells.get(address)
            if not isinstance(raw, str) or not raw.startswith('='):
                return raw
            expression = re.sub(r'\$?([A-Z]+)\$?(\d+)', lambda m: f'CELL("{m[1]}{m[2]}")', raw[1:])

            def walk(node):
                if isinstance(node, ast.Constant) and type(node.value) in (str, int, float):
                    return Decimal(str(node.value)) if type(node.value) in (int, float) else node.value
                if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub)):
                    return walk(node.operand) * (-1 if isinstance(node.op, ast.USub) else 1)
                if isinstance(node, ast.BinOp):
                    a, b = walk(node.left), walk(node.right)
                    if isinstance(node.op, ast.Add): return a + b
                    if isinstance(node.op, ast.Sub): return a - b
                    if isinstance(node.op, ast.Mult): return a * b
                    if isinstance(node.op, ast.Div): return a / b
                if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and not node.keywords:
                    args = [walk(a) for a in node.args]
                    if node.func.id == 'CELL' and len(args) == 1:
                        result = value(args[0], visiting | {address})
                        if type(result) not in (int, float): raise ValueError('引用不是数字：' + str(args[0]))
                        return Decimal(str(result))
                    if node.func.id.upper() == 'ROUND' and len(args) == 2:
                        return args[0].quantize(Decimal(1).scaleb(-int(args[1])), rounding=ROUND_HALF_UP)
                raise ValueError('仅支持本表单元格引用、四则运算和 ROUND')
            try:
                result = float(walk(ast.parse(expression, mode='eval').body))
                if not math.isfinite(result): raise ValueError('非有限结果')
            except Exception as error:
                raise ValueError(f'{name}!{address} {raw}：{error}') from error
            memo[address] = result
            return result

        with zipfile.ZipFile(self.paths[name]) as archive:
            part = dict(sheet_parts(archive))[name]
            tree = ET.fromstring(archive.read(part))
            body = tree.find(Q + 'sheetData')
            styles, exact_styles, row_attributes = {}, {}, {}
            for row in list(body):
                if int(row.get('r')) >= 4:
                    row_attributes[int(row.get('r'))] = dict(row.attrib)
                    for cell in row:
                        styles.setdefault(re.sub(r'\d', '', cell.get('r')), cell.get('s'))
                        exact_styles[cell.get('r')] = cell.get('s')
                    body.remove(row)
            for r, record in enumerate(rows, 4):
                row = ET.SubElement(body, Q + 'row', **row_attributes.get(r, {'r': str(r)}))
                for c, key in enumerate(headers, 1):
                    letter = get_column_letter(c)
                    address = f'{letter}{r}'
                    raw = record.get(key)
                    if raw is None: continue
                    cell = ET.SubElement(row, Q + 'c', r=address)
                    style = exact_styles.get(address, styles.get(letter))
                    if style: cell.set('s', style)
                    if isinstance(raw, str) and raw.startswith('='):
                        ET.SubElement(cell, Q + 'f').text = raw[1:]
                        ET.SubElement(cell, Q + 'v').text = str(value(address))
                    elif type(raw) in (int, float):
                        if not math.isfinite(raw): raise ValueError(f'{name}!{address}：非有限数字')
                        ET.SubElement(cell, Q + 'v').text = str(int(raw)) if raw == int(raw) else str(raw)
                    else:
                        cell.set('t', 'inlineStr')
                        text = ET.SubElement(ET.SubElement(cell, Q + 'is'), Q + 't')
                        text.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
                        text.text = str(raw)
            tree.find(Q + 'dimension').set('ref', f'A1:{get_column_letter(len(headers))}{len(rows)+3}')
            output = io.BytesIO()
            with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as result:
                for item in archive.infolist():
                    result.writestr(item, ET.tostring(tree) if item.filename == part else archive.read(item.filename))
            return output.getvalue()

    def prepare(self, request):
        current = self.load()
        if current['snapshot'] != request['snapshot']:
            raise ValueError('配置已被 Excel、QA 或另一个编辑器修改。请重新加载后再编辑，未覆盖文件。')
        tables = request['tables']
        files = {}
        for name in EDITABLE:
            if tables[name]['headers'] != current['tables'][name]['headers']:
                raise ValueError('不允许修改字段结构：' + name)
            ids = [r.get('id') for r in tables[name]['rows']]
            if any(type(i) not in (int, float) or not math.isfinite(i) or i < 1 or i != int(i) for i in ids) or len(set(ids)) != len(ids):
                raise ValueError(name + '：ID 必须为不重复的正整数')
            if tables[name] != current['tables'][name]:
                files[self.paths[name]] = self.workbook_bytes(name, tables[name])
        data = json.loads(self.target.read_text(encoding='utf-8'))
        raw_files = {n: files.get(p, p.read_bytes()) for n, p in self.paths.items()}
        for name, raw in raw_files.items():
            data[SECTIONS[name]] = read_changed_file(self.paths[name], name, raw)
        validate_projection(data)
        warnings = []
        data['source_files'] = {n: str(p.resolve()) for n, p in self.paths.items()}
        payload = encode(data)
        state = {'version': CACHE_VERSION, 'directory': str(self.directory.resolve()),
                 'target_hash': sha(payload), 'hashes': {n: sha(raw) for n, raw in raw_files.items()}}
        files[self.target] = payload
        files[self.target.with_name('.import_state.json')] = encode(state)
        return files, warnings

    def execute(self, request, save=False):
        files, warnings = self.prepare(request)
        if save:
            if request['snapshot'] != self.snapshot(): raise ValueError('保存前文件发生变化，请重新加载')
            backup = self.root / '.runtime/level-editor-backups' / uuid.uuid4().hex
            backups = {backup / p.relative_to(self.root): p.read_bytes() for p in files if p.exists()}
            atomic_batch({**backups, **files})
            return {**self.load(), 'warnings': warnings, 'backup': str(backup), 'message': '已保存分表并导入配置。请在 QA 重启游戏使用新配置。'}
        return {'warnings': warnings, 'message': '校验通过；尚未写入文件。'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['load', 'validate', 'save'])
    parser.add_argument('--request', type=Path)
    args = parser.parse_args()
    try:
        store = Store()
        result = store.load() if args.action == 'load' else store.execute(json.loads(args.request.read_text(encoding='utf-8')), args.action == 'save')
        print(json.dumps({'ok': True, **result}, ensure_ascii=True, allow_nan=False))
    except Exception as error:
        print(json.dumps({'ok': False, 'message': str(error)}, ensure_ascii=True))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
