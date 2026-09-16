"""Synchronize single-sheet XLSX files and incrementally rebuild game configuration.

Split at the OOXML package level: retain cell formulas, cached values, styles,
column widths and sheet relationships. No spreadsheet recalculation/rewriting.
"""
import argparse
import hashlib
import io
import json
import os
import pathlib
import posixpath
import re
import sys
import uuid
import zipfile
from lxml import etree as ET

import openpyxl
from import_workbook import ROOT, SECTIONS, read_rows, convert_sheet, projection_base, validate_projection, encode

NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKG = "http://schemas.openxmlformats.org/package/2006/relationships"
Q = "{" + NS + "}"
MANIFEST = ".split_manifest.json"
CACHE_VERSION = 5


def sha(value):
    return hashlib.sha256(value).hexdigest()


def read_json(path, default=None):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else ({} if default is None else default)


def atomic_batch(files):
    """Stage every file first; rollback already-replaced files on a commit error."""
    staged, previous, completed = {}, {}, []
    try:
        for path, payload in files.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            previous[path] = path.read_bytes() if path.exists() else None
            temp = path.with_name("." + path.name + "." + uuid.uuid4().hex + ".tmp")
            temp.write_bytes(payload)
            staged[path] = temp
        for path, temp in staged.items():
            os.replace(temp, path)
            completed.append(path)
    except Exception as error:
        problems = []
        for path in reversed(completed):
            try:
                if previous[path] is None:
                    path.unlink()
                else:
                    staged[path].write_bytes(previous[path])
                    os.replace(staged[path], path)
            except OSError:
                problems.append(str(path))
        if problems:
            raise RuntimeError("提交失败且部分文件无法恢复，请检查：" + ", ".join(problems)) from error
        raise
    finally:
        for temp in staged.values():
            if temp.exists():
                temp.unlink()


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
                    raise ValueError(f"{sheet_name}!{cell.get('r')} 含跨表公式，不能直接拆成独立文件；请先改为本表引用或数值")
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
    raw = source.read_bytes()
    directory.mkdir(parents=True, exist_ok=True)
    manifest = read_json(directory / MANIFEST)
    files, mapping, created, updated, unchanged = {}, {}, [], [], []
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        names = [name for name, _ in sheet_parts(archive) if name.strip() != "总览"]
        used = set()
        for name in names:
            filename = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", name).rstrip(". ") + ".xlsx"
            if filename.lower() in used or filename.lower().split(".")[0] in {"con", "prn", "aux", "nul", *("com" + str(i) for i in range(1, 10)), *("lpt" + str(i) for i in range(1, 10))}:
                raise ValueError("工作表名称不能安全映射为独立文件：" + name)
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
    atomic_batch(files)
    return {"ok":True,"action":"split","created":created,"updated":updated,"unchanged":unchanged,
            "directory":str(directory.resolve()),"message":f"拆分同步成功：新建 {len(created)}，更新 {len(updated)}，未变 {len(unchanged)}。"}


def read_changed_file(path, name, raw, *, ignored_formula_columns=()):
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        parts = sheet_parts(archive)
        if len(parts) != 1 or parts[0][0] != name:
            raise ValueError(f"{path.name} 必须仅包含名为 {name} 的工作表")
        tree = ET.fromstring(archive.read(parts[0][1]))
        for cell in tree.iter(Q + "c"):
            if re.sub(r'\d', '', cell.get('r', '')) in ignored_formula_columns:
                continue
            if cell.find(Q + "f") is not None:
                value = cell.find(Q + "v")
                if value is None or value.text is None:
                    raise ValueError(f"{path.name} / {name}!{cell.get('r')} 公式缺少计算缓存，请在 Excel 中计算并保存")
    book = openpyxl.load_workbook(io.BytesIO(raw), read_only=True, data_only=True)
    try:
        return convert_sheet(name, read_rows(book[name]))
    finally:
        book.close()


def incremental_import(directory, target):
    manifest = read_json(directory / MANIFEST)
    if not manifest:
        raise ValueError("请先点击「拆分／同步 Excel」，建立独立配置表")
    state_path = target.with_name(".import_state.json")
    state = read_json(state_path)
    original = target.read_bytes() if target.exists() else b""
    current = json.loads(original) if original else {}
    trustworthy = state.get("version") == CACHE_VERSION and state.get("directory") == str(directory.resolve()) and state.get("target_hash") == sha(original)
    hashes = state.get("hashes", {}) if trustworthy else {}
    snapshot, paths, changed = {}, {}, []
    for name, section in SECTIONS.items():
        filename = manifest.get("sheets", {}).get(name)
        if name in ('charge','ship') and not filename:
            filename = f'{name}.xlsx'
            if not (directory / filename).is_file():
                if current.get(SECTIONS[name]):
                    raise ValueError(f'缺少 {filename}；原配置保留，请恢复文件')
                continue
        if not filename or pathlib.Path(filename).name != filename:
            raise ValueError("分表清单缺少或包含无效路径：" + name)
        path = directory / filename
        if not path.is_file():
            raise ValueError(f"缺少 {filename}；原配置保留，请恢复文件或重新同步")
        raw = path.read_bytes()
        digest = sha(raw)
        snapshot[name] = digest
        paths[name] = path
        if digest != hashes.get(name) or section not in current:
            changed.append((name, raw))
    if not changed:
        return {"ok":True,"action":"import","changed":[],"parsed":[],"message":"没有配置变化，未读取工作表，也未改写 JSON。"}
    data = projection_base(current, directory.name)
    for name, raw in changed:
        try:
            data[SECTIONS[name]] = read_changed_file(paths[name], name, raw)
        except Exception as error:
            raise ValueError(f"{paths[name].name}：{error}") from error
    # Cross-table checks run against the merged JSON, not unchanged Excel files.
    validate_projection(data)
    data["source_files"] = {name:str(path.resolve()) for name,path in paths.items()}
    payload = encode(data)
    # Never commit a snapshot that was changed again while it was being parsed.
    for name, path in paths.items():
        if sha(path.read_bytes()) != snapshot[name]:
            raise ValueError(f"{path.name} 在读取过程中又被修改，请保存完成后重试")
    next_state = {"version":CACHE_VERSION,"directory":str(directory.resolve()),"target_hash":sha(payload),"hashes":snapshot}
    atomic_batch({target:payload, state_path:encode(next_state)})
    names = [name for name, _ in changed]
    return {"ok":True,"action":"import","changed":names,"parsed":names,"message":"导入成功：更新 " + "、".join(names) + "；其余配置保持不变。"}


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["split", "import"])
    parser.add_argument("--source", type=pathlib.Path, default=ROOT.parent / "太空战舰.xlsx")
    parser.add_argument("--directory", type=pathlib.Path, default=ROOT / "config_excel")
    parser.add_argument("--target", type=pathlib.Path, default=ROOT / "data/game_data.json")
    args = parser.parse_args()
    try:
        result = sync_workbooks(args.source, args.directory) if args.action == "split" else incremental_import(args.directory, args.target)
    except Exception as error:
        print(json.dumps({"ok":False,"action":args.action,"message":str(error)}, ensure_ascii=True))
        return 1
    # ASCII transport avoids Windows OS.execute code-page corruption; JSON restores Unicode.
    print(json.dumps(result, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
