"""Compatibility entry for the manifest-validated Excel publisher."""

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from config_tools.compile import DEFAULT_MANIFEST, compile_config  # noqa: E402


def convert(source: Path, output: Path, manifest: Path = DEFAULT_MANIFEST,
            report: Path | None = None) -> None:
    result = compile_config(manifest, output, report or output.with_suffix(".validation.json"), source)
    if not result["ok"]:
        print(json.dumps(result, ensure_ascii=False, indent=2), file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=ROOT / "config_excel")
    parser.add_argument("--output", type=Path, default=ROOT / "generated/config.json")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--report", type=Path, help="full machine-readable validation report")
    arguments = parser.parse_args()
    convert(arguments.source, arguments.output, arguments.manifest, arguments.report)
