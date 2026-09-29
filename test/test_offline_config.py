"""Offline hour limit conversion and validation, using isolated test inputs."""
import copy
import json
from pathlib import Path
import sys
import openpyxl

root = Path(__file__).resolve().parents[1] / "space-battleship"
sys.path.insert(0, str(root / "tools"))
from import_workbook import convert_sheet, read_rows, validate_projection

book = openpyxl.load_workbook(root / "config_excel/config.xlsx", data_only=True, read_only=True)
try:
    config = convert_sheet("config", read_rows(book["config"]))
finally:
    book.close()
data = json.loads((root / "data/game_data.json").read_text(encoding="utf-8"))
assert config["offlineMax"] == data["config"]["offlineMax"]
for key in ("chronoParticlesPerSecond", "chronoDefaultSpeed", "chronoSpeeds"):
    assert config[key] == data["config"][key]
validate_projection(data)
for value in (0, 0.5, 4):
    probe = copy.deepcopy(data)
    probe["config"]["offlineMax"] = value
    validate_projection(probe)
for value in (-1, "bad", float("inf")):
    probe = copy.deepcopy(data)
    probe["config"]["offlineMax"] = value
    try:
        validate_projection(probe)
    except ValueError:
        pass
    else:
        raise AssertionError(value)
for key, value in (("chronoParticlesPerSecond", 0), ("chronoDefaultSpeed", 11),
                   ("chronoSpeeds", "1|0,2|-1"), ("chronoSpeeds", "1|1,2|0")):
    probe = copy.deepcopy(data)
    probe["config"][key] = value
    try:
        validate_projection(probe)
    except ValueError:
        pass
    else:
        raise AssertionError((key, value))
print("Chrono config: workbook projection and validation passed")
