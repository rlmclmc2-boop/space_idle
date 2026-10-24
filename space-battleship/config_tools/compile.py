"""Standalone Excel -> immutable ConfigBundle. No Godot or legacy loader imports."""
from __future__ import annotations
import argparse
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import tempfile
import openpyxl

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = Path(__file__).with_name('schema.json')


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False).encode('utf-8')


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def amount_literal(value):
    # Lexical validation only; all arithmetic/normalization stays in shared C++.
    return isinstance(value,str) and re.fullmatch(r'\+?[0-9]+(?:\.[0-9]*)?(?:[eE][+-]?[0-9]+)?',value) is not None


def drop_segments(text):
    if '{' not in text and '}' not in text:
        parts=[part.strip() for part in text.split(';')]
        return parts if all(parts) else None
    parts=re.findall(r'\{([^{}]+)\}',text)
    remainder=re.sub(r'\{[^{}]+\}','',text).replace(',','').replace(';','').strip()
    return parts if parts and not remainder else None


class CompilationError(Exception):
    def __init__(self, errors):
        self.errors = errors
        super().__init__(f'{len(errors)} configuration error(s)')


def compile_bundle(manifest_path: Path):
    manifest_path = Path(manifest_path).resolve()
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    schema = json.loads(SCHEMA.read_text(encoding='utf-8'))
    errors, tables, provenance, sources = [], {}, {}, {}
    specs = {}
    mode = manifest.get('kind')
    if mode not in ('production', 'test') or manifest.get('schemaVersion') != schema['version']:
        raise CompilationError([dict(workbook=str(manifest_path), sheet='', row=0, column='', key='', code='ManifestSchema', detail='kind/schemaVersion')])

    def error(book, sheet, row, column, key, code, detail):
        errors.append(dict(workbook=book, sheet=sheet, row=row, column=column, key=key, code=code, detail=detail))

    if manifest.get('entry')=='GameSession':
        declared_tables={s['table'] for e in manifest['workbooks'] for s in e['sheets']}
        for missing in set(schema.get('runtimeTables',[]))-declared_tables:
            error(str(manifest_path),'',0,'',missing,'MissingRuntimeTable','GameSession entry requires table')

    seen_inputs = set()
    for entry in manifest['workbooks']:
        rel = entry['path']
        path = (manifest_path.parent / rel).resolve()
        # A manifest cannot reach outside its declared input root or cross from
        # test fixtures into production. No directory discovery or fallback.
        input_root = (manifest_path.parent / manifest.get('inputRoot', '.')).resolve()
        if not path.is_relative_to(input_root) or ('tests' in path.parts) != (mode == 'test'):
            error(rel, '', 0, '', '', 'ManifestIsolation', 'input outside declared domain'); continue
        if path in seen_inputs:
            error(rel, '', 0, '', '', 'DuplicateWorkbook', 'workbook repeated'); continue
        seen_inputs.add(path)
        if entry.get('classification') not in ('active', 'retained', 'candidate', 'generated'):
            error(rel, '', 0, '', '', 'SourceClassification', 'explicit source classification required'); continue
        try:
            snapshot = path.read_bytes()
            sources[rel] = hashlib.sha256(snapshot).hexdigest()
            formulas = openpyxl.load_workbook(io.BytesIO(snapshot), data_only=False)
            values = openpyxl.load_workbook(io.BytesIO(snapshot), data_only=True)
        except Exception as exc:
            error(rel, '', 0, '', '', 'WorkbookRead', str(exc)); continue
        declared = {s['sheet'] for s in entry['sheets']}
        if set(formulas.sheetnames) != declared:
            error(rel, '', 0, '', '', 'UnexpectedSheet', str(sorted(set(formulas.sheetnames) ^ declared)))
        for sheet_spec in entry['sheets']:
            name, table = sheet_spec['sheet'], sheet_spec['table']
            if table not in schema['tables'] or table in tables:
                error(rel, name, 0, '', '', 'UnknownOrDuplicateTable', table); continue
            if name not in formulas: continue
            spec = schema['tables'][table]
            specs[table] = spec
            ws, cached = formulas[name], values[name]
            fields = spec['fields']
            actual = [ws.cell(1, i+1).value for i in range(ws.max_column)]
            while actual and actual[-1] is None: actual.pop()
            expected = spec['columns']
            if actual != expected:
                error(rel, name, 1, '', '', 'HeaderMismatch', 'header differs from versioned schema'); continue
            rows, ids = [], set()
            provenance[table] = {}
            for row_index in range(4, ws.max_row + 1):
                cells = [ws.cell(row_index, i+1) for i in range(len(expected))]
                if all(c.value is None for c in cells): continue
                row, locations = {}, {}
                for cell, field in zip(cells, expected):
                    if field is None:
                        if cell.value is not None: error(rel, name, row_index, cell.column_letter, '', 'UnnamedColumn', 'data under unnamed header')
                        continue
                    definition = fields[field]
                    value = cell.value
                    if cell.data_type == 'f':
                        if spec.get('literalOnly'):
                            error(rel, name, row_index, cell.column_letter, field, 'FormulaForbidden', 'typed literal required'); continue
                        value = cached.cell(row_index, cell.column).value
                        if value is None or cached.cell(row_index, cell.column).data_type == 'e':
                            error(rel, name, row_index, cell.column_letter, field, 'FormulaCacheMissing', 'trusted cached value required'); continue
                    if cell.data_type == 'e':
                        error(rel, name, row_index, cell.column_letter, field, 'ExcelError', str(value)); continue
                    kind = 'null' if value is None else 'bool' if isinstance(value, bool) else 'number' if isinstance(value, (int,float)) else 'string' if isinstance(value, str) else 'unsupported'
                    if kind not in definition['types'] or (kind == 'number' and not math.isfinite(value)):
                        error(rel, name, row_index, cell.column_letter, field, 'LiteralType', f'expected {definition["types"]}, got {kind}'); continue
                    if value is not None and definition.get('integer') and (kind != 'number' or int(value) != value or abs(value) > 2**53):
                        error(rel, name, row_index, cell.column_letter, field, 'IntegerRange', 'exact Excel integer required'); continue
                    if kind == 'number' and (value < definition.get('min', -math.inf) or value > definition.get('max', math.inf)):
                        error(rel, name, row_index, cell.column_letter, field, 'ValueRange', str(value)); continue
                    if value is not None and definition.get('literal')=='amount_text' and not amount_literal(value):
                        error(rel,name,row_index,cell.column_letter,field,'AmountLiteral','nonnegative decimal text required');continue
                    if value is not None and definition.get('literal')=='int64_text':
                        if not isinstance(value,str) or not re.fullmatch(r'0|[1-9][0-9]*',value) or len(value)>19 or int(value)>2**63-1:
                            error(rel,name,row_index,cell.column_letter,field,'IntegerRange','nonnegative canonical int64 text required');continue
                    if 'enum' in definition and value not in definition['enum']:
                        error(rel, name, row_index, cell.column_letter, field, 'UnknownRuleKey', str(value)); continue
                    row[field] = value
                    locations[field] = dict(workbook=rel, sheet=name, row=row_index, column=cell.column_letter)
                contracts=spec.get('contracts',{}).get(str(row.get(spec['primary'][0])),{})
                for field, contract in contracts.items():
                    value=row.get(field)
                    if value is None:continue # requiredness/type already reported
                    valid=type(value) in (float,int)
                    valid=valid and value>=contract.get('min',-math.inf) and value<=contract.get('max',math.inf)
                    valid=valid and ('exclusiveMin' not in contract or value>contract['exclusiveMin'])
                    valid=valid and (not contract.get('integer') or int(value)==value)
                    if not valid:error(rel,name,row_index,openpyxl.utils.get_column_letter(expected.index(field)+1),field,'ValueRange','runtime row contract')
                required = set()
                for condition in spec.get('requiredWhen', []):
                    if row.get(condition['field']) in condition['values']:
                        required.update(condition['required'])
                for group in spec.get('requiredGroups', []):
                    if any(row.get(field) is not None for field in group):
                        required.update(group)
                for field in sorted(required):
                    if row.get(field) is None:
                        column=openpyxl.utils.get_column_letter(expected.index(field)+1)
                        error(rel,name,row_index,column,field,'RequiredField','required for this row/resource group')
                primary = spec['primary']
                identity = [row.get(k) for k in primary]
                if any((v is None and k not in spec.get('nullablePrimary', [])) or v == '' for k,v in zip(primary,identity)):
                    error(rel, name, row_index, '', ','.join(primary), 'EmptyPrimaryKey', str(identity)); continue
                key = json.dumps(identity, ensure_ascii=False, separators=(',', ':'))
                if key in ids:
                    error(rel, name, row_index, '', ','.join(primary), 'DuplicateId', key); continue
                ids.add(key)
                rows.append(row)
                provenance[table][key] = locations
            def order_key(row):
                # Numeric order is numeric (2 precedes 10), not JSON text order.
                return tuple((0,0) if row[k] is None else (1,row[k]) if isinstance(row[k],(int,float)) else (2,row[k]) for k in spec.get('order',spec['primary']))
            rows.sort(key=order_key)
            tables[table] = rows
            if spec.get('requiredKeys'):
                present={r[spec['primary'][0]] for r in rows}
                for missing in set(spec['requiredKeys'])-present:
                    error(rel,name,0,'A',missing,'MissingRule','required runtime key')
        formulas.close(); values.close()

    def location_error(table, row, field, code, detail):
        key = json.dumps([row[k] for k in specs[table]['primary']], ensure_ascii=False, separators=(',', ':'))
        loc = provenance[table][key].get(field, {})
        error(loc.get('workbook',''), loc.get('sheet',''), loc.get('row',0), loc.get('column',''), key, code, detail)

    indices = {table: {json.dumps([r[k] for k in specs[table]['primary']], ensure_ascii=False, separators=(',', ':')): i for i,r in enumerate(rows)} for table,rows in tables.items()}
    drop_index={str(row['id']):[] for row in tables.get('mon',[])}
    for table, rows in tables.items():
        for relation in specs[table].get('structuredReferences', []):
            field, target, target_field = relation['field'], relation['table'], relation['target']
            valid = {str(r[target_field]) for r in tables.get(target, [])}
            for row in rows:
                value = row.get(field)
                if value is None: continue
                text = value.translate(str.maketrans('｛｝，','{},'))
                if relation['kind']=='resource_drop':
                    segments=drop_segments(text)
                    if segments is None:
                        location_error(table,row,field,'ReferenceSyntax',text);continue
                    for segment in segments:
                        parts=[p.strip() for p in segment.split(',')]
                        if len(parts)!=3:
                            location_error(table,row,field,'ReferenceSyntax',segment);continue
                        valid_row=True
                        if parts[0] not in valid:
                            location_error(table,row,field,'MissingReference',f'{target}: {parts[0]}');valid_row=False
                        if not amount_literal(parts[1]):
                            location_error(table,row,field,'AmountLiteral',parts[1]);valid_row=False
                        try:
                            chance=float(parts[2])
                            if not math.isfinite(chance) or not 0<=chance<=1:raise ValueError()
                        except ValueError:
                            location_error(table,row,field,'ValueRange','drop probability');valid_row=False
                        if valid_row:drop_index[str(row['id'])].append(dict(resource=parts[0],amount=parts[1],chance=chance))
                    continue
                if not text.startswith('{') or not text.endswith('}'):
                    location_error(table,row,field,'ReferenceSyntax',str(value)); continue
                tokens = text[1:-1].split(',')
                previous = -1.0
                for token in tokens:
                    if relation['kind']=='slots' and token.strip()=='null': continue
                    parts=token.split('|')
                    if parts[0] not in valid:
                        location_error(table,row,field,'MissingReference',f'{target}: {parts[0]}')
                    if relation['kind']=='positions':
                        try:
                            position=float(parts[1])
                            if len(parts)!=2 or not math.isfinite(position) or not 0<=position<=1 or position<=previous:raise ValueError()
                            previous=position
                        except (ValueError,IndexError):location_error(table,row,field,'BattlePointOrder',token)
                    if relation['kind']=='weapon_level':
                        try:
                            if len(parts)!=2 or not 1<=int(parts[1])<=2**63-1:raise ValueError()
                        except (ValueError,IndexError):location_error(table,row,field,'WeaponLevel',token)
        for relation in specs[table].get('references', []):
            field, target, target_field = relation['field'], relation['table'], relation['target']
            valid = {r[target_field] for r in tables.get(target, [])}
            for row in rows:
                value = row.get(field)
                if value is not None and value not in valid:
                    location_error(table,row,field,'MissingReference', f'{target}.{target_field}: {value}')
        for topology in specs[table].get('topologies', []):
            field, id_field = topology['field'], topology['id']
            graph = {}
            for row in rows:
                value = row.get(field)
                refs = [] if not value else [item.split(':')[0] for item in value.split(';')]
                graph[row[id_field]] = refs
                for ref in refs:
                    if ref not in {r[id_field] for r in rows}: location_error(table,row,field,'MissingReference',ref)
            visiting, visited = set(), set()
            def visit(node):
                if node in visiting: return False
                if node in visited: return True
                visiting.add(node)
                for dependency in graph.get(node, []):
                    if not visit(dependency): return False
                visiting.remove(node); visited.add(node); return True
            for row in rows:
                if not visit(row[id_field]): location_error(table,row,field,'DependencyCycle',str(row[id_field])); break
    # Literal contract tables select their value type in Excel, not by display format.
    for table, spec in specs.items():
        if table not in tables or not spec.get('typedValues'): continue
        for row in tables[table]:
            value, kind = row.get('value'), row.get('data_type')
            good = {'null':value is None,'string':isinstance(value,str),'bool':isinstance(value,bool),'int':type(value) is int,'float':type(value) in (int,float)}
            if not good.get(kind,False): location_error(table,row,'value','TypedLiteralMismatch',str(kind))
    if errors: raise CompilationError(errors)
    indices['dropRules']=drop_index
    classes = {sheet['table']: entry['classification'] for entry in manifest['workbooks'] for sheet in entry['sheets']}
    return dict(schemaVersion=schema['version'], kind=mode, entry=manifest.get('entry','data'), semanticHash=digest(tables), sourceManifestHash=digest(dict(manifest=manifest,sources=sources,schema=schema)), tables=tables,
                ruleParameters={}, indices=indices, provenance=provenance, sourceHashes=sources, sourceClasses=classes)


def publish(bundle, output):
    output = Path(output); output.mkdir(parents=True, exist_ok=True)
    data = canonical(bundle)
    content_hash = hashlib.sha256(data).hexdigest()
    versions = output / 'versions'; versions.mkdir(exist_ok=True)
    target = versions / (content_hash + '.json')
    def replace(path, body):
        fd, temp = tempfile.mkstemp(dir=path.parent, suffix='.tmp')
        try:
            with os.fdopen(fd,'wb') as handle:
                handle.write(body); handle.flush(); os.fsync(handle.fileno())
            if Path(temp).read_bytes() != body: raise OSError('ReadbackMismatch')
            os.replace(temp,path)
        finally:
            if Path(temp).exists(): Path(temp).unlink()
    replace(target,data)
    replace(output/'active-manifest.json', canonical(dict(schemaVersion=bundle['schemaVersion'], semanticHash=bundle['semanticHash'], bundle='versions/'+target.name, checksum=content_hash)))
    return target


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        bundle = compile_bundle(args.manifest)
        path = publish(bundle,args.output)
        print(json.dumps(dict(ok=True,semanticHash=bundle['semanticHash'],tables=len(bundle['tables']),rows=sum(map(len,bundle['tables'].values())),bundle=str(path))))
        return 0
    except CompilationError as exc:
        args.output.mkdir(parents=True,exist_ok=True)
        (args.output/'errors.json').write_bytes(canonical(exc.errors))
        print(json.dumps(dict(ok=False,errors=exc.errors[:10],report=str(args.output/'errors.json')),ensure_ascii=True))
        return 1


if __name__ == '__main__': raise SystemExit(main())
