"""Two real Godot processes against synthetic saves and the same native DLL."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess


ERROR_LINE = re.compile(
    r"^(?:SCRIPT ERROR:|Parse Error:|Traceback \(most recent call last\):|"
    r"(?:SyntaxError|IndentationError):|ERROR: .*\b(?:script|pars(?:e|ing|er)|compil(?:e|ation))\b)",
    re.IGNORECASE,
)
LOG_DIR = None
LOGS = []


def check_output(script, output):
    log = LOG_DIR / f"{len(LOGS):02d}-{script}.log"
    log.write_bytes(output.replace("\r\n", "\n").replace("\r", "\n").encode("utf-8"))
    LOGS.append({"file": log.name, "sha256": digest(log)})
    errors = [line.strip() for line in output.splitlines()
              if ERROR_LINE.match(line.strip())]
    assert not errors, f"{script}: unexpected diagnostics {errors}; full log {log}"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_artifacts(path):
    files = list(path.parent.glob(path.name + "*"))
    backup_root = path.parent / "save-import-backups"
    if backup_root.exists():
        files += list(backup_root.rglob("*"))
    return {str(item.relative_to(path.parent)): ("dir" if item.is_dir() else
            "locked-sidecar" if item.name.endswith(".writer-lock") else digest(item))
            for item in files}


def command(godot, project, script, *args):
    return [str(godot), "--headless", "--path", str(project),
            "--script", "res://test/" + script, "--", *map(str, args)]


def directory_alias(alias, target):
    try:
        os.symlink(target, alias, target_is_directory=True)
    except OSError:
        if os.name != "nt":
            raise
        result = subprocess.run(["cmd", "/c", "mklink", "/J", str(alias), str(target)],
                                text=True, encoding="utf-8", errors="replace", capture_output=True)
        assert result.returncode == 0, result.stdout + result.stderr
    assert alias.is_dir() and (alias / "progress.json").resolve() == (target / "progress.json").resolve()


def wait_line(proc, prefix):
    seen = []
    for line in proc.stdout:
        seen.append(line.rstrip())
        if line.startswith(prefix):
            return line[len(prefix):].strip(), seen
    raise AssertionError(f"worker exited before {prefix}: {seen}")


def run(godot, project, env, script, *args):
    result = subprocess.run(command(godot, project, script, *args), env=env,
                            text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=45)
    check_output(script, result.stdout)
    assert result.returncode == 0, result.stdout
    prefix = {"s04a_game_worker.gd": "S04A_GAME:",
              "s04a_ui_worker.gd": "S04A_UI:",
              "s04a_scene_reload_worker.gd": "S04A_RELOAD:"}.get(script, "S04A_ACQUIRE:")
    rows = [line[len(prefix):] for line in result.stdout.splitlines()
            if line.startswith(prefix)]
    assert len(rows) == 1, result.stdout
    return json.loads(rows[0]) if script in {"s04a_game_worker.gd", "s04a_ui_worker.gd",
                                          "s04a_scene_reload_worker.gd"} else rows[0]


def held(godot, project, env, script, *args):
    proc = subprocess.Popen(command(godot, project, script, *args, "hold"),
                            env=env, text=True, encoding="utf-8", errors="replace", stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, bufsize=1)
    prefix = "S04A_GAME:" if script == "s04a_game_worker.gd" else "S04A_ACQUIRE:"
    value, output = wait_line(proc, prefix)
    return proc, (json.loads(value) if script == "s04a_game_worker.gd" else value), output


def end_holder(proc, script, first_lines):
    proc.kill()
    remaining, _ = proc.communicate(timeout=10)
    check_output(script, "\n".join(first_lines) + "\n" + remaining)


def main():
    global LOG_DIR
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    LOG_DIR = args.output / "worker-logs"
    LOG_DIR.mkdir(exist_ok=True)
    env = os.environ.copy()
    for key, sub in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local"),
                     ("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"),
                     ("XDG_CACHE_HOME", "cache")):
        path = args.output / "userdata" / sub
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    lock_a = args.output / "archive-a"
    lock_b = args.output / "archive-b"
    assert run(args.godot, args.project, env, "s04a_lock_worker.gd", lock_a) == "true"
    sidecar_present = lock_a.with_name(lock_a.name + ".writer-lock").exists()
    assert sidecar_present
    assert run(args.godot, args.project, env, "s04a_lock_worker.gd", lock_a) == "true", "stale sidecar must not block"
    owner, acquired, owner_output = held(args.godot, args.project, env, "s04a_lock_worker.gd", lock_a)
    try:
        assert acquired == "true"
        same_save = run(args.godot, args.project, env, "s04a_lock_worker.gd", lock_a)
        other_save = run(args.godot, args.project, env, "s04a_lock_worker.gd", lock_b)
        assert same_save == "false"
        assert other_save == "true", "other save blocked"
    finally:
        end_holder(owner, "s04a_lock_worker.gd", owner_output)
    assert run(args.godot, args.project, env, "s04a_lock_worker.gd", lock_a) == "true", "crash did not release"

    game_owner, first, game_owner_output = held(args.godot, args.project, env, "s04a_game_worker.gd")
    try:
        assert first["owns"] and first["enabled"] and first["save"] == 0 and not first["startup"], first
        progress = Path(first["path"])
        before = save_artifacts(progress)
        alias = args.output / "save-directory-alias"
        directory_alias(alias, progress.parent)
        second = run(args.godot, args.project, env, "s04a_game_worker.gd", alias / progress.name)
        assert not second["owns"] and not second["enabled"] and not second["startup"], second
        errors = [second[key] for key in ("initial", "save", "import", "clear", "recovery")]
        assert errors[0] != 0 and len(set(errors)) == 1, second
        assert second["alias_export"] != 0 and second["alias_writer"] == errors[0], second
        assert save_artifacts(progress) == before, "second process changed primary, staging, backup, or lock file"
        ui = run(args.godot, args.project, env, "s04a_ui_worker.gd")
        assert ui["warned"] and ui["processing"] and not ui["save_enabled"] and not ui["startup"], ui
        assert save_artifacts(progress) == before, "read-only UI changed save artifacts"
    finally:
        end_holder(game_owner, "s04a_game_worker.gd", game_owner_output)
    third = run(args.godot, args.project, env, "s04a_game_worker.gd")
    assert third["owns"] and third["enabled"] and third["save"] == 0, third
    scene_reload = run(args.godot, args.project, env, "s04a_scene_reload_worker.gd")
    assert scene_reload["passed"], scene_reload
    summary = {
        "sidecar_remains_after_normal_exit": sidecar_present,
        "normal_exit_reacquire": True,
        "same_save_while_held": same_save,
        "other_save_while_held": other_save,
        "reacquire_after_kill": True,
        "first_game": {k: v for k, v in first.items() if k != "path"},
        "second_game": {k: v for k, v in second.items() if k != "path"},
        "read_only_ui": ui,
        "post_crash_game": {k: v for k, v in third.items() if k != "path"},
        "confirmed_import_scene_reload": scene_reload,
        "save_artifacts_during_denial": before,
        "denied_writes_left_artifacts_identical": True,
        "directory_alias_denied": True,
        "native_dll_sha256": digest(next(path for path in (args.project / "bin" / "space_native.dll",
                                                         args.project / "bin" / "space_native.so") if path.is_file())),
        "worker_logs": LOGS,
    }
    (args.output / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("S04A_SINGLE_WRITER_PASS: OS lock, two game processes, running read-only UI, crash retry, separate saves, write entry denials")


if __name__ == "__main__":
    main()
