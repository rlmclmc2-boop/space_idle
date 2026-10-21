"""S06 audit-only import log gate probes for the runtime builder."""
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import sys

builder = Path(sys.argv[1]).resolve()
spec = spec_from_file_location("s06_builder", builder)
module = module_from_spec(spec)
spec.loader.exec_module(module)
cert = "ERROR: Failed to read the root certificate store.\n   at: get_system_ca_certificates (platform/windows/os_windows.cpp:2582)\n"
cases = [
    ("clean", "Godot Engine v4.7.2\n", True),
    ("known_certificate", cert, True),
    ("resource_error_exit_zero", cert + "ERROR: Failed loading resource: res://assets/fonts/NotoSansSC.ttf\n", False),
    ("duplicate_certificate", cert + cert, False),
    ("unknown_certificate_trace", "ERROR: Failed to read the root certificate store.\n   at: other_function\n", False),
    ("parse_error", "Parse Error: missing script\n", False),
    ("script_error", "SCRIPT ERROR: invalid call\n", False),
]
for label, text, expected in cases:
    try:
        module.check_import_log(text, Path("synthetic-exit-zero.log"))
        passed = True
    except RuntimeError:
        passed = False
    if passed != expected:
        raise AssertionError(f"{label}: expected {expected}, got {passed}")
    print(f"S06_GATE_PASS {label}: {'accepted' if passed else 'rejected'}")
