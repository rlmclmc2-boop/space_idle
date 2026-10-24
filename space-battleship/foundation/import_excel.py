"""Convert the agreed Excel directory to plain runtime JSON."""
import argparse
import json
from pathlib import Path
import openpyxl

ROOT = Path(__file__).resolve().parents[1]


def convert(source: Path, output: Path) -> None:
    configuration = {}
    for path in sorted(source.glob('*.xlsx')):
        workbook = openpyxl.load_workbook(path, read_only=True, data_only=True)
        sheets = {}
        for sheet in workbook:
            rows = sheet.iter_rows(values_only=True)
            columns = next(rows, ())
            next(rows, None)  # Descriptions.
            next(rows, None)  # Existing type/annotation row.
            sheets[sheet.title] = [
                {field: value for field, value in zip(columns, row) if field is not None}
                for row in rows if any(value is not None for value in row)
            ]
        configuration[path.stem] = sheets
        workbook.close()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(configuration, ensure_ascii=False, indent=2, default=str) + '\n', encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=ROOT / 'config_excel')
    parser.add_argument('--output', type=Path, default=ROOT / 'generated/config.json')
    arguments = parser.parse_args()
    convert(arguments.source, arguments.output)
