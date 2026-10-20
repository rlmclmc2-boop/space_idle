"""Audit-only completion and error gate for the selected S02 tests.

Run from the repository root: python docs/audits/20261020-e3db2838/stages/S01/gate.py TEST [test/run.py options]
"""

import argparse
from collections import Counter
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[5]
RUNNER = ROOT / "test" / "run.py"
MARKERS = {
    "test_save_policy.gd": "S01_COMPLETE:test_save_policy.gd",
    "test_config_workbooks.py": "S01_COMPLETE:test_config_workbooks.py",
    "test_save_transfer.gd": "S01_COMPLETE:test_save_transfer.gd",
}
ERROR_LINE = re.compile(
    r"^(?:SCRIPT ERROR:|Parse Error:|Traceback \(most recent call last\):|"
    r"(?:SyntaxError|IndentationError):|ERROR: .*\b(?:script|pars(?:e|ing|er)|compil(?:e|ation))\b)",
    re.IGNORECASE,
)
DECLARABLE_ERROR_LINE = re.compile(
    r"^(?:SCRIPT ERROR: .+|Parse Error: .+|(?:SyntaxError|IndentationError): .+|"
    r"ERROR: .+\b(?:script|pars(?:e|ing|er)|compil(?:e|ation))\b.*)$",
    re.IGNORECASE,
)


def evaluate(output: str, code: int, marker: str, expected_errors=()):
    """Return rejection reasons; expected errors match full diagnostic lines exactly."""
    lines = [line.strip() for line in output.splitlines()]
    actual = Counter(line for line in lines if ERROR_LINE.match(line))
    expected = Counter(expected_errors)
    reasons = []
    if any("\n" in line or not DECLARABLE_ERROR_LINE.match(line)
           for line in expected):
        reasons.append("invalid expected diagnostic declaration")
    if code != 0:
        reasons.append(f"exit code {code}")
    if lines.count(marker) != 1:
        reasons.append(f"completion marker count {lines.count(marker)} (expected 1)")
    for line, count in (actual - expected).items():
        reasons.append(f"unexpected diagnostic ({count}): {line}")
    for line, count in (expected - actual).items():
        reasons.append(f"missing declared diagnostic ({count}): {line}")
    return reasons


def run(command, marker: str, timeout: float, expected_errors=()):
    try:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
        output = result.stdout.decode("utf-8", errors="replace")
        code = result.returncode
    except subprocess.TimeoutExpired as exc:
        output = (exc.stdout or b"").decode("utf-8", errors="replace")
        code = 124
        output += f"\nS01_GATE_TIMEOUT: {timeout} seconds\n"
    return output, evaluate(output, code, marker, expected_errors)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("test", choices=sorted(MARKERS))
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--expect-error", action="append", default=[], metavar="EXACT_LINE",
                        help="Exact full script/parse diagnostic line; repeat for each occurrence")
    args = parser.parse_args(argv)
    if args.timeout < 1:
        parser.error("--timeout must be positive")
    for line in args.expect_error:
        if "\n" in line or not DECLARABLE_ERROR_LINE.match(line):
            parser.error("--expect-error must be one complete recognized diagnostic line")
    command = [sys.executable, str(RUNNER), args.test, "--timeout", str(args.timeout)]
    if args.godot:
        command.extend(("--godot", str(args.godot)))
    if args.headless:
        command.append("--headless")
    output, reasons = run(command, MARKERS[args.test], args.timeout * 2 + 30,
                          args.expect_error)
    print(output, end="" if output.endswith("\n") else "\n")
    if reasons:
        for reason in reasons:
            print(f"S01_GATE_FAIL: {reason}", file=sys.stderr)
        return 1
    print(f"S01_GATE_PASS: {args.test}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
