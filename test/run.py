"""Run one existing test in an isolated workspace beneath test/work."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def completed(output, test, phase):
    """Require the existing test's completion output, not just a zero exit."""
    if test == "test_ordinary_entry.gd":
        prefix = ("PLANET_LOADING" if phase == "planet-loading" else
                  "REACTOR_PRODUCT " + phase if phase.startswith("reactor-") else
                  "FACTORY_ENTRY " + phase if phase.startswith("factory-") else
                  "PRODUCT_ENTRY " + phase)
        return re.search(r"^" + re.escape(prefix) + r" [1-9]\d* checks 0 failures(?: |$)", output, re.M) is not None
    if test == "test_save_boundaries.gd":
        return re.search(r"^Save boundaries: [1-9]\d* checks, 0 failures$", output, re.M) is not None
    if test == "probe_native_admission_stale_pose.gd":
        return re.search(r"^GEOMETRY LIFECYCLE: [1-9]\d* checks, 0 failures$", output, re.M) is not None
    if test == "test_crew_performance.gd":
        # Existing fixture: 2 ships * 2 pages * 3 modes * 3 budgets + 4 scheduler cases.
        return re.search(r"^CREW_PERF_COMPLETE 40 scenarios$", output, re.M) is not None
    if test == "test_dynamic_native_ports.gd":
        rows = re.findall(r"^DYNAMIC_PORTS (.+)$", output, re.M)
        if len(rows) != 1:
            return False
        try:
            result = json.loads(rows[0])
            return result["checks"] > 0 and result["failures"] == 0
        except (ValueError, KeyError, TypeError):
            return False
    if test == "test_player_mount_seating.gd":
        return re.search(r"^SEATING_DONE samples=[1-9]\d* max_error=\S+ failures=0$", output, re.M) is not None
    # Existing summaries use either human-readable counts or key=value counts.
    counts = re.findall(r"\b(\d+) checks[, ]+([0-9]+) failures\b", output, re.I)
    counts += re.findall(r"checks[=: ]+(\d+)[, ]+failures[=: ]+(\d+)\b", output, re.I)
    if counts:
        return all(int(checks) > 0 and int(failures) == 0 for checks, failures in counts)
    if test.endswith(".py"):
        if re.search(r"^Ran [1-9]\d* tests? in .+\n\s*\nOK$", output.strip(), re.M):
            return True
        last = output.strip().splitlines()[-1] if output.strip() else ""
        # Exact existing terminal summaries, keyed to their entry; no generic "passed".
        summaries = {
            "test_ai_tech_tree_config.py": r"AI_TECH_CONFIG=PASS rows=8",
            "test_config_input_matrix.py": r"Phase 8: [1-9]\d* input outcomes, [1-9]\d* fault outcomes, [1-9]\d* assertions passed\. Evidence: .+",
            "test_enemy_attack_pairs.py": re.escape("Attack pairs: current authored pairs, four source projections, legacy metadata and malformed/Lv1-order cases passed"),
            "test_enemy_intel_import.py": re.escape("Enemy intel import: full data valid; current opening mechanism mismatches and visual mismatch rejected; native reactive constants and integer-ms durations match"),
            "test_enemy_shield_schema.py": re.escape("Enemy shield schema: authored data, omitted legacy fields and 6 invalid cases passed"),
            "test_enhance_config.py": r"ENHANCE CONFIG: passed; [1-9]\d* invalid inputs rejected; growth1/2 valid; 68 rows match workbook",
            "test_full_restart.py": re.escape("PASS: busy guard, real new PID, updated source, same user directory, saved progress, current node, QA settings"),
            "test_import.py": re.escape("PASS: import, data rows, defaults preservation, failure preserves JSON"),
            "test_offline_config.py": re.escape("Chrono config: workbook projection and validation passed"),
            "test_planet_build_config.py": re.escape("Planet configuration: projection, four rules, rejection and incremental import passed"),
            "test_reactor_config.py": r"reactor config valid",
            "test_weapon_config.py": r"EXCEL MUTATIONS: [1-9]\d* official incremental exports; restored original source and projection",
            "test_weapon_config_validation.py": r"WEAPON TABLE VALIDATION: [1-9]\d* cases passed; 4 actual invalid Excel imports rejected; projection unchanged",
            "test_save_import_recovery.py": r"FRESH PROCESS IMPORT RECOVERY: [1-9]\d* scenarios, 0 failures",
        }
        return test in summaries and re.fullmatch(summaries[test], last) is not None
    # Do not retrofit historical probes: an unrecognized result is not acceptance.
    return False


def main():
    tests = Path(__file__).resolve().parent
    workspace = tests.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("test", help="One existing test_*.gd/test_*.py or probe_native_admission_stale_pose.gd")
    parser.add_argument("--godot", type=Path, default=workspace / "space-battleship/engine/Godot_v4.7.2-stable_win64.exe")
    parser.add_argument("--timeout", type=int, default=180, help="Timeout in seconds for each isolated process")
    parser.add_argument("--headless", action="store_true", help="Disable rendering for logic benchmarks")
    parser.add_argument("--scenario", choices=("all", "game", "reactor", "planet", "factory"),
                        help="Original main-scene workflow for test_ordinary_entry.gd (default: all)")
    args = parser.parse_args()
    if (not re.fullmatch(r"test_[A-Za-z0-9_]+\.(gd|py)", args.test) and args.test != "probe_native_admission_stale_pose.gd") or not (tests / args.test).is_file():
        parser.error("Choose one existing test_*.gd or test_*.py from the relevant guide")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    if args.scenario and args.test != "test_ordinary_entry.gd":
        parser.error("--scenario belongs to test_ordinary_entry.gd")
    if args.test == "test_ordinary_entry.gd" and args.headless:
        parser.error("The original game workflow requires rendering; omit --headless")
    work = tests / "work"
    work.mkdir(exist_ok=True)
    area = Path(tempfile.mkdtemp(prefix=Path(args.test).stem + "-", dir=work))
    if os.name == "nt":
        # mkdtemp restricts Windows ACLs to its creator; artifact viewers also
        # need the workspace's inherited access. Apply before creating children.
        subprocess.run(["icacls", str(area), "/inheritance:e"], check=True,
                       stdout=subprocess.DEVNULL)
    game = area / "space-battleship"
    game.mkdir()
    source = workspace / "space-battleship"
    for name in ("scripts", "shaders", "tools", "data", "config_excel", "assets", "addons", "dev"):
        shutil.copytree(source / name, game / name,
                        ignore=shutil.ignore_patterns("__pycache__", ".import_state.json", "~$*", "*.blend", "*.blend1"))
    for name in ("project.godot", "main.tscn", "level_editor.tscn"):
        shutil.copy2(source / name, game / name)
    # Persistence fixtures need the same OS writer lock as the player entry.
    # Reuse its verified bundled runtime; specialized native tests may replace it.
    sys.path.insert(0, str(workspace / "tools"))
    from play_main import verified_bundle, DESCRIPTOR
    native_bundle, _, _ = verified_bundle(workspace)
    (game / "bin").mkdir(exist_ok=True)
    shutil.copy2(native_bundle, game / "bin/space_native.dll")
    (game / "space_native.gdextension").write_text(DESCRIPTOR, encoding="utf-8")
    shutil.copy2(workspace / "太空战舰.xlsx", area / "太空战舰.xlsx")
    isolated_tests = area / "test"
    isolated_tests.mkdir()
    for path in tests.iterdir():
        if path.is_file() and path.suffix in {".py", ".gd", ".uid"}:
            shutil.copy2(path, isolated_tests / path.name)
    if args.test in {"test_galaxy_ui.gd", "one_times_ablation.gd"}:
        shutil.copytree(tests / "fixtures", isolated_tests / "fixtures")
    if args.test == "test_analyzer_dependencies.py":
        # The entrypoint contract includes guide locations, not only code roots.
        shutil.copytree(tests / "guides", isolated_tests / "guides")
        shutil.copy2(tests / "README.md", isolated_tests / "README.md")
    (game / ".runtime").mkdir()
    if args.test == "test_progression_scene_equivalence.gd":
        (game / "qa").mkdir()
        adapter=(source/"scripts/balance_game.gd").read_text().replace("extends BattleGame",'extends "res://scripts/presented_battle_game.gd"',1)
        (game/"qa/presented_balance_game.gd").write_text(adapter)
    if args.test in {"test_weapon_scale_contract.gd", "probe_weapon_roles.gd"}:
        (game / "qa").mkdir(exist_ok=True)
        shutil.copy2(tests / "fixtures/opening_frozen_contract.json", game / "qa/opening_frozen_contract.json")
    if args.test in {"test_native_weapon_scale.gd", "test_native_opening_art_integration.gd", "test_native_opening_event_closure.gd", "test_reactive_native_descriptor.gd", "test_shield_gap_recovery.gd"} or (args.test == "probe_weapon_roles.gd" and any(os.environ.get(key) == "1" for key in ("SPACE_BALANCE_NATIVE_ROLES", "SPACE_BALANCE_NATIVE_SCALE_CANDIDATE", "SPACE_BALANCE_TYPED_SCALES", "SPACE_BALANCE_TYPED_CANDIDATE", "SPACE_BALANCE_TYPED_LEVEL_SLOTS", "SPACE_BALANCE_FOUR_BUDGET", "SPACE_BALANCE_PRIORITY_BUDGET"))):
        native = tests / "native-build/project/bin/space_native.dll"
        if not native.is_file():
            raise RuntimeError("isolated native build missing: " + str(native))
        (game / "bin").mkdir(exist_ok=True)
        shutil.copy2(native, game / "bin/space_native.dll")
        shutil.copy2(source / "addons/native_battle/space_native.gdextension.in",
                     game / "addons/native_battle/space_native.gdextension")
    env = os.environ.copy()
    env["APPDATA"] = str(area / "userdata/roaming")
    env["LOCALAPPDATA"] = str(area / "userdata/local")
    env["PYTHONPYCACHEPREFIX"] = str(area / "pycache")
    # Godot uses XDG rather than APPDATA on Linux. Keep every test isolated there too.
    for key, folder in (("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
        env[key] = str(area / "userdata" / folder)
        Path(env[key]).mkdir(parents=True)
    env["SPACE_BATTLESHIP_PYTHON"] = sys.executable
    for key in ("APPDATA", "LOCALAPPDATA"):
        Path(env[key]).mkdir(parents=True)
    print(f"Artifacts: {area}", flush=True)

    def run(command, label):
        with (area / (label + ".log")).open("w", encoding="utf-8") as log:
            try:
                result = subprocess.run(command, cwd=game, env=env, stdout=log,
                                        stderr=subprocess.STDOUT, timeout=args.timeout)
                code = result.returncode
            except subprocess.TimeoutExpired:
                log.write(f"\nTIMEOUT: {label} exceeded {args.timeout} seconds\n")
                code = 124
        output = (area / (label + ".log")).read_text(encoding="utf-8", errors="replace")
        # Godot may exit zero after a script error; never report that as acceptance.
        if code == 0 and ("SCRIPT ERROR:" in output or "Failed to load script" in output or re.search(r"^FAIL(?:ED)?[ :]+", output, re.M)):
            code = 1
        if code == 0 and label not in {"import", "fixture"} and not completed(output, args.test, label):
            print("INCOMPLETE: no recognized successful completion summary for " + label)
            code = 1
        print(output if code or label != "import" else "Godot import completed.")
        return code

    godot = str(args.godot.resolve())
    if args.test == "test_weapon_config.py":
        env["SPACE_BATTLESHIP_GODOT"] = godot
        code = run([godot, "--headless", "--editor", "--import", "--quit", "--path", str(game)], "import")
        if code:
            return code
    if args.test == "test_save_import_recovery.py":
        (isolated_tests / "fixtures").mkdir()
        shutil.copy2(tests / "fixtures/save_import_recovery_worker.gd",
                     isolated_tests / "fixtures/save_import_recovery_worker.gd")
        code = run([godot, "--headless", "--editor", "--import", "--quit", "--path", str(game)], "import")
        if code:
            return code
        return run([sys.executable, str(isolated_tests / args.test),
                    "--project", str(game), "--output", str(area / "driver-evidence"),
                    "--godot", godot], "test")
    if args.test.endswith(".py"):
        return run([sys.executable, str(isolated_tests / args.test)], "test")
    code = run([godot, "--headless", "--editor", "--import", "--quit", "--path", str(game)], "import")
    if code:
        return code
    if args.test == "test_hyperspace_catalog_consumers.gd":
        fixture = area / "reward-fixture.json"
        code = run([sys.executable, str(tests / "fixtures/hyperspace_reward_fixture_builder.py"),
                    str(fixture)], "fixture")
        if code:
            return code
        return run([godot, *(["--headless"] if args.headless else []), "--path", str(game),
                    "--script", str(isolated_tests / args.test), "--", str(fixture)], "test")
    command = [godot, *(["--headless"] if args.headless else []), "--path", str(game), "--script", str(isolated_tests / args.test)]
    if args.test == "test_ordinary_entry.gd":
        workflows = {
            "planet": ("planet-loading",),
            "game": ("product-write", "product-reopen", "product-claimed-reopen"),
            "reactor": ("reactor-write", "reactor-reopen"),
            "factory": ("factory-write", "factory-reopen"),
        }
        for name, phases in workflows.items():
            if args.scenario not in (None, "all", name):
                continue
            # Separate fresh saves per workflow; restart phases share that slot.
            for key, folder in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local"),
                                ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                                ("XDG_CACHE_HOME", "cache")):
                target = area / "userdata" / name / folder
                target.mkdir(parents=True)
                env[key] = str(target)
            for phase in phases:
                code = run([*command, "--", phase], phase)
                if code:
                    return code
        return 0
    if args.test == "test_save_boundaries.gd":
        for phase in ("write", "reopen", "latest", "recovery"):
            code = run([*command, "--", phase], "test-" + phase)
            if code:
                return code
        return 0
    return run(command, "test")


if __name__ == "__main__":
    raise SystemExit(main())
