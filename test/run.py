"""Run one existing test in an isolated workspace beneath test/work."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    tests = Path(__file__).resolve().parent
    workspace = tests.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("test", choices=sorted(p.name for p in tests.iterdir()
                        if p.suffix in {".py", ".gd"} and p.name != "run.py"))
    parser.add_argument("--godot", type=Path, default=workspace / "space-battleship/engine/Godot_v4.7.2-stable_win64.exe")
    parser.add_argument("--timeout", type=int, default=180, help="Timeout in seconds for each isolated process")
    parser.add_argument("--headless", action="store_true", help="Disable rendering for logic benchmarks")
    parser.add_argument("--source-root", type=Path, default=workspace,
                        help="Runtime candidate checkout whose product files are under space-battleship")
    parser.add_argument("--native-dll", type=Path,
                        help="Compiled matching native DLL for isolated runtime validation")
    args = parser.parse_args()
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
    source = args.source_root.resolve() / "space-battleship"
    for name in ("scripts", "shaders", "tools", "data", "config_excel", "assets", "addons", "dev"):
        shutil.copytree(source / name, game / name,
                        ignore=shutil.ignore_patterns("__pycache__", ".import_state.json", "~$*", "*.blend", "*.blend1"))
    for name in ("project.godot", "main.tscn", "level_editor.tscn"):
        shutil.copy2(source / name, game / name)
    shutil.copy2(args.source_root.resolve() / "太空战舰.xlsx", area / "太空战舰.xlsx")
    isolated_tests = area / "test"
    isolated_tests.mkdir()
    for path in tests.iterdir():
        if path.is_file() and path.suffix in {".py", ".gd", ".uid"}:
            shutil.copy2(path, isolated_tests / path.name)
    if args.test in {"test_galaxy_ui.gd", "one_times_ablation.gd"}:
        shutil.copytree(tests / "fixtures", isolated_tests / "fixtures")
    (game / ".runtime").mkdir()
    if args.test == "test_progression_scene_equivalence.gd":
        (game / "qa").mkdir()
        adapter=(source/"scripts/balance_game.gd").read_text().replace("extends BattleGame",'extends "res://scripts/presented_battle_game.gd"',1)
        (game/"qa/presented_balance_game.gd").write_text(adapter)
    if args.test in {"test_weapon_scale_contract.gd", "probe_weapon_roles.gd"}:
        (game / "qa").mkdir(exist_ok=True)
        shutil.copy2(tests / "fixtures/opening_frozen_contract.json", game / "qa/opening_frozen_contract.json")
    if args.native_dll or args.test in {"test_native_weapon_scale.gd", "test_native_opening_art_integration.gd", "test_native_opening_event_closure.gd", "test_reactive_native_descriptor.gd", "test_shield_gap_recovery.gd"} or (args.test == "probe_weapon_roles.gd" and any(os.environ.get(key) == "1" for key in ("SPACE_BALANCE_NATIVE_ROLES", "SPACE_BALANCE_NATIVE_SCALE_CANDIDATE", "SPACE_BALANCE_TYPED_SCALES", "SPACE_BALANCE_TYPED_CANDIDATE", "SPACE_BALANCE_TYPED_LEVEL_SLOTS", "SPACE_BALANCE_FOUR_BUDGET", "SPACE_BALANCE_PRIORITY_BUDGET"))):
        native = args.native_dll or tests / "native-build/project/bin/space_native.dll"
        if not native.is_file():
            raise RuntimeError("isolated native build missing: " + str(native))
        if native.suffix not in {".dll", ".so"}:
            raise RuntimeError("isolated native build must be a Windows DLL or Linux shared object")
        (game / "bin").mkdir(exist_ok=True)
        shutil.copy2(native, game / "bin" / ("space_native" + native.suffix))
        descriptor = (source / "addons/native_battle/space_native.gdextension.in").read_text(encoding="utf-8")
        if native.suffix == ".so":
            descriptor += ('linux.debug.x86_64 = "res://bin/space_native.so"\n'
                           'linux.release.x86_64 = "res://bin/space_native.so"\n')
        (game / "addons/native_battle/space_native.gdextension").write_text(descriptor, encoding="utf-8")
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
        print((area / (label + ".log")).read_text(encoding="utf-8", errors="replace"))
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
    if args.test == "test_single_writer_s04a.py":
        if not args.native_dll:
            raise RuntimeError("S04a requires --native-dll built from the runtime candidate")
        (game / "test").mkdir(exist_ok=True)
        for name in ("s04a_lock_worker.gd", "s04a_game_worker.gd", "s04a_ui_worker.gd", "s04a_scene_reload_worker.gd"):
            shutil.copy2(tests / name, game / "test" / name)
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
    return run([godot, *(["--headless"] if args.headless else []), "--path", str(game), "--script", str(isolated_tests / args.test)], "test")


if __name__ == "__main__":
    raise SystemExit(main())
