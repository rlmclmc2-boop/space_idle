"""Project the AI technology source workbook into the Godot JSON table.

Rows 2-3 document columns, matching the existing split workbook convention.
Use --check in CI or --write after an intentional table edit.
"""
import argparse
import json
import math
from pathlib import Path

import openpyxl


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "config_excel" / "ai_tech_tree.xlsx"
TARGET = ROOT / "data" / "ai_tech_tree.json"
FIELDS = ("id", "name", "description", "tier", "base_seconds", "growth", "effect", "factor", "unlock", "requirements")


def positive(value, field, key):
    if type(value) not in (int, float) or not math.isfinite(value) or value <= 0:
        raise ValueError(f"{key}: {field} must be a positive finite number")
    return value


def project(source=SOURCE):
    book = openpyxl.load_workbook(source, read_only=True, data_only=True)
    try:
        sheet = book["ai_tech_tree"]
        rows = sheet.iter_rows(values_only=True)
        if tuple(next(rows)[:len(FIELDS)]) != FIELDS:
            raise ValueError("ai_tech_tree: unexpected header")
        next(rows, None)  # descriptions
        next(rows, None)  # types
        result = {}
        for values in rows:
            if not values or values[0] is None:
                continue
            cells = dict(zip(FIELDS, values))
            key = cells.pop("id")
            if not isinstance(key, str) or not key.strip() or key in result:
                raise ValueError(f"ai_tech_tree: missing or duplicate ID {key!r}")
            for field in ("name", "description", "tier", "effect"):
                if not isinstance(cells[field], str) or not cells[field].strip():
                    raise ValueError(f"{key}: missing {field}")
            cells["base_seconds"] = positive(cells["base_seconds"], "base_seconds", key)
            cells["growth"] = positive(cells["growth"], "growth", key)
            cells["factor"] = positive(cells["factor"], "factor", key)
            if cells["growth"] <= 1:
                raise ValueError(f"{key}: growth must exceed 1")
            cells["unlock"] = cells["unlock"] or ""
            if cells["unlock"] not in ("", "enhancement"):
                raise ValueError(f"{key}: unsupported unlock")
            requirements = {}
            for term in str(cells.pop("requirements") or "").split(";"):
                if not term.strip():
                    continue
                predecessor, separator, value = term.partition(":")
                if not separator or not predecessor or predecessor in requirements:
                    raise ValueError(f"{key}: invalid prerequisite {term!r}")
                requirements[predecessor] = value if value == "10*k+1" else int(value)
            if not cells["unlock"]:
                cells.pop("unlock")
            if requirements:
                cells["requirements"] = requirements
            result[key] = cells
        for key, row in result.items():
            for predecessor, condition in row.get("requirements", {}).items():
                if predecessor not in result or predecessor == key or condition != "10*k+1" and (not isinstance(condition, int) or condition <= 0):
                    raise ValueError(f"{key}: invalid prerequisite {predecessor}")
        return result
    finally:
        book.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--write", action="store_true")
    args = parser.parse_args()
    projected = project()
    encoded = json.dumps(projected, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
    if args.check:
        committed = json.loads(TARGET.read_text(encoding="utf-8"))
        if committed != projected:
            raise SystemExit("AI_TECH_PROJECTION=STALE: run import_ai_tech_tree.py --write")
        print(f"AI_TECH_PROJECTION=PASS rows={len(projected)}")
    else:
        TARGET.write_text(encoded, encoding="utf-8")
        print(f"AI_TECH_PROJECTION=WROTE rows={len(projected)}")


if __name__ == "__main__":
    main()
