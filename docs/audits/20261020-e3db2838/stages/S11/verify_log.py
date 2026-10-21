from pathlib import Path

log = Path(__file__).with_name("godot-test.log").read_text(encoding="utf-8")
lines = log.splitlines()
allowed = {"ERROR: Failed to read the root certificate store."}
errors = [line for line in lines if ("ERROR" in line or line.startswith("FAIL ")) and line not in allowed]
summary = [line for line in lines if line.startswith("S11 checks=")]
cert = sum(line == next(iter(allowed)) for line in lines)
passes = sum(line.startswith("PASS ") for line in lines)
assert not errors, errors
assert summary == ["S11 checks=69 failures=0"], summary
assert passes == 69, passes
assert cert == 1, cert
print(f"PASS log gate: {passes} PASS lines, one exact Windows certificate diagnostic, no other errors")
