from config_snapshot import RecoveryRequired as ConfigurationRecoveryRequired
"""Synchronize single-sheet XLSX files and incrementally rebuild game configuration.

Split at the OOXML package level: retain cell formulas, cached values, styles,
column widths and sheet relationships. No spreadsheet recalculation/rewriting.
"""
from ui_text import t as ui_text
import argparse
import hashlib
import io
import json
import os
import pathlib
import posixpath
import re
import shutil
import sys
import uuid
import zipfile
from lxml import etree as ET

import openpyxl
from hyperspace_entities import (read_bundle as read_hyperspace_bundle, load_schema,
                                 SCHEMA_PATH, EARLY_FROZEN_PATH)
from import_workbook import ROOT, SECTIONS, read_rows, convert_sheet, projection_base, validate_projection, encode

NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKG = "http://schemas.openxmlformats.org/package/2006/relationships"
Q = "{" + NS + "}"
MANIFEST = ".split_manifest.json"
CACHE_VERSION = 13


def sha(value):
    return hashlib.sha256(value).hexdigest()


def read_json(path, default=None):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else ({} if default is None else default)


class RecoveryRequired(RuntimeError):
    def __init__(self, directory, problems):
        self.recovery_required = True
        self.recovery_path = str(directory)
        self.rollback_failed = [str(path) for path in problems]
        super().__init__(f"Recovery required; original files and manifest retained at {directory}; "
                         f"restore or retry these paths manually: {', '.join(self.rollback_failed)}")


def atomic_batch(files, recovery_root=None):
    """Stage replacements; retain a pre-install recovery journal if rollback fails.

    This is a recoverable best-effort batch, not a cross-file atomic commit.
    """
    if not files:
        return
    paths = [pathlib.Path(path) for path in files]
    recovery_root = pathlib.Path(recovery_root) if recovery_root else paths[0].parent / '.runtime/config-recovery'
    recovery = recovery_root / uuid.uuid4().hex
    staged, previous, completed = {}, {}, []
    installing = False
    recovery_needed = False
    try:
        for path, payload in files.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            previous[path] = path.read_bytes() if path.exists() else None
            temp = path.with_name("." + path.name + "." + uuid.uuid4().hex + ".tmp")
            temp.write_bytes(payload)
            staged[path] = temp
        recovery.mkdir(parents=True)
        entries = []
        for index, path in enumerate(staged):
            original = previous[path]
            saved = f'{index:04d}.original' if original is not None else None
            if saved:
                (recovery / saved).write_bytes(original)
            entries.append({'target': str(path.resolve()), 'original': saved,
                            'original_sha256': sha(original) if original is not None else None,
                            'replacement_sha256': sha(files[path])})
        (recovery / 'manifest.json').write_text(
            json.dumps({'version': 1, 'state': 'installing', 'entries': entries}, indent=2) + '\n',
            encoding='utf-8')
        installing = True
        for path, temp in staged.items():
            os.replace(temp, path)
            completed.append(path)
    except Exception as error:
        problems = []
        for path in reversed(completed) if installing else ():
            try:
                if previous[path] is None:
                    path.unlink()
                else:
                    staged[path].write_bytes(previous[path])
                    os.replace(staged[path], path)
            except OSError:
                problems.append(path)
        if problems:
            recovery_needed = True
            raise RecoveryRequired(recovery, problems) from error
        raise
    finally:
        for temp in staged.values():
            try:
                temp.unlink(missing_ok=True)
            except OSError:
                pass
        if not recovery_needed and recovery.exists():
            shutil.rmtree(recovery, ignore_errors=True)


def sheet_parts(archive):
    workbook = ET.fromstring(archive.read("xl/workbook.xml"))
    relationships = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
    targets = {}
    for item in relationships:
        path = item.attrib["Target"]
        targets[item.attrib["Id"]] = path.lstrip("/") if path.startswith("/") else posixpath.normpath("xl/" + path)
    return [(s.attrib["name"], targets[s.attrib["{" + REL + "}id"]]) for s in workbook.find(Q + "sheets")]


def logical_sheet_hash(archive, name):
    """Ignore unrelated shared strings and ZIP timestamps when comparing a sheet."""
    parts = dict(sheet_parts(archive))
    sheet = ET.fromstring(archive.read(parts[name]))
    strings = []
    if "xl/sharedStrings.xml" in archive.namelist():
        strings = [ET.tostring(s, encoding="utf-8").decode("utf-8") for s in ET.fromstring(archive.read("xl/sharedStrings.xml"))]
    for cell in sheet.iter(Q + "c"):
        if cell.get("t") == "s":
            value = cell.find(Q + "v")
            value.text = strings[int(value.text)]
    # Split comparison includes sheet formatting and workbook-wide styles.
    return sha(ET.tostring(sheet) + archive.read("xl/styles.xml"))


def split_package(raw, sheet_name):
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        parts = sheet_parts(archive)
        chosen = dict(parts)[sheet_name]
        # A cross-sheet formula would be invalid in a truly independent workbook.
        sheet_xml = ET.fromstring(archive.read(chosen))
        other_names = [name for name, _ in parts if name != sheet_name]
        for cell in sheet_xml.iter(Q + "c"):
            formula = cell.find(Q + "f")
            if formula is not None and formula.text:
                if any(re.search(r"(?:'" + re.escape(other.replace("'", "''")) + r"'|(?<![\w])" + re.escape(other) + r")!", formula.text) for other in other_names):
                    raise ValueError(ui_text('debug.config_workbooks.message_11', sheet_name=sheet_name, r=cell.get('r')))
        removed = {path for name, path in parts if name != sheet_name}
        removed |= {posixpath.dirname(path) + "/_rels/" + posixpath.basename(path) + ".rels" for path in tuple(removed)}
        removed.add("xl/calcChain.xml")
        workbook = ET.fromstring(archive.read("xl/workbook.xml"))
        sheets = workbook.find(Q + "sheets")
        selected_index = [name for name, _ in parts].index(sheet_name)
        for item in list(sheets):
            if item.get("name") != sheet_name:
                sheets.remove(item)
            else:
                item.set("state", "visible")
        for view in workbook.iter(Q + "workbookView"):
            view.set("activeTab", "0")
            view.set("firstSheet", "0")
        definitions = workbook.find(Q + "definedNames")
        if definitions is not None:
            for item in list(definitions):
                if "localSheetId" in item.attrib and int(item.get("localSheetId")) != selected_index:
                    definitions.remove(item)
                elif item.get("localSheetId") is not None:
                    item.set("localSheetId", "0")
        relationships = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
        for item in list(relationships):
            target = item.get("Target")
            path = target.lstrip("/") if target.startswith("/") else posixpath.normpath("xl/" + target)
            if path in removed:
                relationships.remove(item)
        types = ET.fromstring(archive.read("[Content_Types].xml"))
        for item in list(types):
            if item.get("PartName", "").lstrip("/") in removed:
                types.remove(item)
        updates = {
            "xl/workbook.xml": ET.tostring(workbook, encoding="utf-8", xml_declaration=True),
            "xl/_rels/workbook.xml.rels": ET.tostring(relationships, encoding="utf-8", xml_declaration=True),
            "[Content_Types].xml": ET.tostring(types, encoding="utf-8", xml_declaration=True),
        }
        result = io.BytesIO()
        with zipfile.ZipFile(result, "w", zipfile.ZIP_DEFLATED) as output:
            for item in archive.infolist():
                if item.filename not in removed:
                    output.writestr(item, updates.get(item.filename, archive.read(item.filename)))
        return result.getvalue()


def sync_workbooks(source, directory):
    from config_publication import execute
    directory=pathlib.Path(directory).resolve()
    if directory.name!='config_excel':raise ValueError('Canonical config_excel directory required')
    return execute(directory.parent,'split',source=source)


def _prepare_sync_workbooks(source, directory):
    raw = source.read_bytes()
    directory.mkdir(parents=True, exist_ok=True)
    manifest = read_json(directory / MANIFEST)
    files, mapping, created, updated, unchanged = {}, {}, [], [], []
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        names = [name for name, _ in sheet_parts(archive) if name.strip() not in ("总览", "crew_level")]
        used = set()
        for name in names:
            filename = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", name).rstrip(". ") + ".xlsx"
            if filename.lower() in used or filename.lower().split(".")[0] in {"con", "prn", "aux", "nul", *("com" + str(i) for i in range(1, 10)), *("lpt" + str(i) for i in range(1, 10))}:
                raise ValueError(ui_text('debug.config_workbooks.message_10', name=name))
            used.add(filename.lower())
            mapping[name] = filename
            target = directory / filename
            same = False
            if target.exists():
                try:
                    with zipfile.ZipFile(target) as existing:
                        same = len(sheet_parts(existing)) == 1 and logical_sheet_hash(existing, name) == logical_sheet_hash(archive, name)
                except (KeyError, ValueError, zipfile.BadZipFile):
                    pass
            if same:
                unchanged.append(name)
            else:
                files[target] = split_package(raw, name)
                (updated if target.exists() else created).append(name)
        next_manifest = {"version":1, "source":str(source.resolve()), "sheets":mapping}
        if next_manifest != manifest:
            files[directory / MANIFEST] = encode(next_manifest)
    # No deleting unrelated files or worksheets removed from the master.
    atomic_batch(files, directory.parent / '.runtime/config-recovery')
    return {"ok":True,"action":"split","created":created,"updated":updated,"unchanged":unchanged,
            "directory":str(directory.resolve()),"message":ui_text('debug.config_workbooks.message_01', created=len(created), updated=len(updated), unchanged=len(unchanged))}


def read_changed_file(path, name, raw, *, ignored_formula_columns=()):
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        parts = sheet_parts(archive)
        if len(parts) != 1 or parts[0][0] != name:
            raise ValueError(ui_text('debug.config_workbooks.message_04', name=path.name, value_2=name))
        tree = ET.fromstring(archive.read(parts[0][1]))
        for cell in tree.iter(Q + "c"):
            if re.sub(r'\d', '', cell.get('r', '')) in ignored_formula_columns:
                continue
            if cell.find(Q + "f") is not None:
                value = cell.find(Q + "v")
                if value is None or value.text is None:
                    raise ValueError(ui_text('debug.config_workbooks.message_12', name=path.name, value_2=name, r=cell.get('r')))
    book = openpyxl.load_workbook(io.BytesIO(raw), read_only=True, data_only=True)
    try:
        return convert_sheet(name, read_rows(book[name]))
    finally:
        book.close()


def entity_cache_signature(raw_by_filename, data_directory, outputs=None):
    """Cover schema, frozen authority and every derived output, without opening XLSX."""
    schema = load_schema()
    dependencies = [SCHEMA_PATH, EARLY_FROZEN_PATH]
    dependencies.extend(data_directory / name for name in schema['frozen_inputs'])
    signature = {'workbooks': {name: sha(raw) for name, raw in raw_by_filename.items()},
                 'dependencies': {str(path): sha(path.read_bytes()) for path in dependencies}}
    if outputs is None:
        return signature
    signature['outputs'] = {name: sha(raw) for name, raw in outputs.items()}
    return signature


def cached_entities_valid(state, raw_by_filename, data_directory):
    cached = state.get('entity_cache', {})
    current = entity_cache_signature(raw_by_filename, data_directory)
    if any(cached.get(key) != value for key, value in current.items()):
        return False
    outputs = cached.get('outputs', {})
    return bool(outputs) and all(pathlib.Path(name).name == name and
        (data_directory / name).is_file() and sha((data_directory / name).read_bytes()) == digest
        for name, digest in outputs.items())


def incremental_import(directory, target):
    from config_publication import execute
    root=pathlib.Path(target).resolve().parent.parent
    if pathlib.Path(directory).resolve()!=root/'config_excel' or pathlib.Path(target).resolve()!=root/'data/game_data.json':
        raise ValueError('Configuration import requires the canonical project inputs')
    return execute(root,'import')


def _prepare_incremental_import(directory, target):
    manifest_path = directory / MANIFEST
    manifest_raw = manifest_path.read_bytes() if manifest_path.exists() else None
    manifest = json.loads(manifest_raw) if manifest_raw is not None else {}
    if not manifest:
        raise ValueError(ui_text('debug.config_workbooks.message_02'))
    state_path = target.with_name(".import_state.json")
    state_raw = state_path.read_bytes() if state_path.exists() else None
    state = json.loads(state_raw) if state_raw is not None else {}
    target_raw = target.read_bytes() if target.exists() else None
    original = target_raw if target_raw is not None else b""
    current = json.loads(original) if original else {}
    hyperspace_paths = {name: directory / name for name in ('hyperspace_config.xlsx', 'hyperspace_enemies.xlsx')}
    entity_required = any(p.exists() for p in hyperspace_paths.values()) or target.with_name('hyperspace_config.json').exists()
    if entity_required and not all(p.is_file() for p in hyperspace_paths.values()):
        raise ValueError('Both authoritative hyperspace entity workbooks are required')
    hyperspace_raw = {name: path.read_bytes() for name,path in hyperspace_paths.items()} if entity_required else {}
    trustworthy = state.get("version") == CACHE_VERSION and state.get("directory") == str(directory.resolve()) and state.get("target_hash") == sha(original)
    hashes = state.get("hashes", {}) if trustworthy else {}
    snapshot, paths, changed = {}, {}, []
    for name, section in SECTIONS.items():
        filename = manifest.get("sheets", {}).get(name)
        if name in ('ship','unlock','crew','crew_assignment','crew_config','planet','planet_build','planet_buff','galaxy','galaxy_build','galaxy_config','enhance_config','weapon_motion','enemy_weapon_base','battle_design') and not filename:
            filename = f'{name}.xlsx'
            if not (directory / filename).is_file():
                if current.get(SECTIONS[name]):
                    raise ValueError(ui_text('debug.config_workbooks.message_13', filename=filename))
                continue
        if not filename or pathlib.Path(filename).name != filename:
            raise ValueError(ui_text('debug.config_workbooks.message_05', name=name))
        path = directory / filename
        if not path.is_file():
            raise ValueError(ui_text('debug.config_workbooks.message_06', filename=filename))
        raw = path.read_bytes()
        digest = sha(raw)
        snapshot[name] = digest
        paths[name] = path
        if digest != hashes.get(name) or section not in current:
            changed.append((name, raw))
    data = projection_base(current, directory.name) if changed else current
    for name, raw in changed:
        try:
            data[SECTIONS[name]] = read_changed_file(paths[name], name, raw)
        except Exception as error:
            raise ValueError(ui_text('debug.config_workbooks.message_101', name=paths[name].name, error=error)) from error
    if changed:
        validate_projection(data)
        data["source_files"] = {name:str(path.resolve()) for name,path in paths.items()}
    entity_outputs, frozen_snapshot = {}, {}
    entity_cache = state.get("entity_cache", {})
    entity_inputs = entity_cache_signature(hyperspace_raw, target.parent) if hyperspace_raw else {}
    if hyperspace_raw and (changed or not trustworthy or not cached_entities_valid(state, hyperspace_raw, target.parent)):
        projected, frozen_snapshot = read_hyperspace_bundle(hyperspace_raw, data, target.parent)
        projected_payloads = {}
        for filename, values in projected.items():
            entity_target = target.with_name(filename)
            entity_payload = (json.dumps(values, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
            projected_payloads[filename] = entity_payload
            if not entity_target.exists() or entity_target.read_bytes() != entity_payload:
                entity_outputs[entity_target] = entity_payload
        entity_cache = entity_cache_signature(hyperspace_raw, target.parent, projected_payloads)
    if not changed and not entity_outputs and entity_cache == state.get("entity_cache", {}):
        return {"ok":True,"action":"import","changed":[],"parsed":[],"message":ui_text('debug.config_workbooks.message_07')}
    payload = encode(data) if changed else original
    # Never commit a snapshot that was changed again while it was being parsed.
    for name, path in paths.items():
        if sha(path.read_bytes()) != snapshot[name]:
            raise ValueError(ui_text('debug.config_workbooks.message_08', name=path.name))
    next_state = {"version":CACHE_VERSION,"directory":str(directory.resolve()),"target_hash":sha(payload),"hashes":snapshot}
    next_state['entity_cache'] = entity_cache
    next_state['hyperspace_hashes'] = {name:sha(raw) for name,raw in hyperspace_raw.items()}
    outputs = {target:payload, state_path:encode(next_state)} if changed else {state_path:encode(next_state)}
    for name, raw in hyperspace_raw.items():
        if hyperspace_paths[name].read_bytes() != raw:
            raise ValueError('Hyperspace workbook changed during import: ' + name)
    for path, raw in frozen_snapshot.items():
        if path.read_bytes() != raw:
            raise ValueError('Frozen reward baseline changed during import: ' + path.name)
    if hyperspace_raw and entity_cache_signature(hyperspace_raw, target.parent) != entity_inputs:
        raise ValueError("Hyperspace schema or frozen baseline changed during import")
    outputs.update(entity_outputs)
    # Protect concurrent editor/import writes as well as workbook inputs.
    for path, expected in ((manifest_path, manifest_raw), (target, target_raw), (state_path, state_raw)):
        actual = path.read_bytes() if path.exists() else None
        if actual != expected:
            raise ValueError(ui_text("debug.config_workbooks.message_08", name=path.name))
    atomic_batch(outputs, target.parent.parent / '.runtime/config-recovery')
    names = [name for name, _ in changed]
    names.extend(path.stem for path in entity_outputs)
    return {"ok":True,"action":"import","changed":names,"parsed":names,"message":ui_text('debug.config_workbooks.message_03', names="、".join(names))}


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["split", "import", "initialize"])
    parser.add_argument("--source", type=pathlib.Path, default=ROOT.parent / "太空战舰.xlsx")
    parser.add_argument("--directory", type=pathlib.Path, default=ROOT / "config_excel")
    parser.add_argument("--target", type=pathlib.Path, default=ROOT / "data/game_data.json")
    args = parser.parse_args()
    try:
        if args.action=="initialize":
            from config_publication import execute
            result=execute(args.target.resolve().parent.parent,"initialize")
        else:result = sync_workbooks(args.source, args.directory) if args.action == "split" else incremental_import(args.directory, args.target)
    except Exception as error:
        result = {"ok":False,"action":args.action,"message":str(error),
                  "recovery_required": isinstance(error, (RecoveryRequired, ConfigurationRecoveryRequired))}
        if isinstance(error, (RecoveryRequired, ConfigurationRecoveryRequired)):
            result.update(recovery_path=(getattr(error,"recovery_path",None) or str(ROOT/".configuration-transaction.json")), rollback_failed=getattr(error,"rollback_failed",[]))
        print(json.dumps(result, ensure_ascii=True))
        return 1
    # ASCII transport avoids Windows OS.execute code-page corruption; JSON restores Unicode.
    print(json.dumps(result, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
