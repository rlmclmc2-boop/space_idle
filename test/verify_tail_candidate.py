"""Verify unaccepted save changes in a private project; source remains unchanged."""
import os
import argparse
from pathlib import Path
import shutil
import subprocess
import sys

from saved_game_diagnosis import prepare
from saved_game_perf import ROOT, SOURCE
from tail_save_candidate import install


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", nargs="*")
    args=parser.parse_args()
    area = ROOT / "test/work/saved-diagnosis-tail-candidate-tests"
    area.mkdir(exist_ok=True)
    game = prepare(area, False)
    install(game)
    cache = ROOT / "test/work/saved-diagnosis-tail-baseline/space-battleship/.godot"
    if not (game / ".godot").exists():shutil.copytree(cache, game / ".godot")
    env = os.environ.copy()
    env["APPDATA"] = str(area / "userdata/roaming")
    env["LOCALAPPDATA"] = str(area / "userdata/local")
    for key in ["APPDATA", "LOCALAPPDATA"]:Path(env[key]).mkdir(parents=True, exist_ok=True)
    engine = SOURCE / "engine/Godot_v4.7.2-stable_win64.exe"
    for name in ["test_tail_save.gd", "test_frame_save_batch.gd", "test_jewel_combine_all.gd", "test_journey_resume.gd", "test_restart_save_failure.gd", "test_delete_save.gd", "test_tail_verify_probe.gd"]:
        shutil.copy2(ROOT / "test" / name, game / name)
    # Screenshot output is irrelevant to this IO/rollback verification and has
    # no texture in a headless viewport; preserve all behavioral assertions.
    path=game / "test_delete_save.gd"
    source=path.read_text(encoding="utf-8")
    source=source.replace('\tawait RenderingServer.frame_post_draw\n\tpanel.get_texture().get_image().save_png("res://preview-delete-save.png")\n', '')
    path.write_text(source,encoding="utf-8")
    tasks = [("import", ["--headless", "--editor", "--import", "--quit"])]
    selected=args.only if args.only is not None else ["test_tail_save", "test_frame_save_batch", "test_jewel_combine_all", "test_journey_resume", "test_restart_save_failure", "test_delete_save"]
    tasks += [(name, ["--headless", "--script", "res://"+name+".gd"]) for name in selected if name != "equivalence"]
    for label, flags in tasks:
        with (area / (label+".log")).open("w", encoding="utf-8") as log:
            result = subprocess.run([str(engine), "--path", str(game), *flags], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        output = (area / (label+".log")).read_text(encoding="utf-8", errors="replace")
        print(label, result.returncode, output[-1400:], flush=True)
        if result.returncode or "SCRIPT ERROR" in output or "Parse Error" in output:raise RuntimeError(label)
    if args.only is not None and "equivalence" not in args.only:return
    # Separate deterministic replay: freeze only the isolated fixture's wall clock.
    # Production clock calls and save schema remain unchanged.
    original = (ROOT / "test/work/saved-diagnosis-tail-baseline/original-game.gd").read_text(encoding="utf-8")
    original = original.replace("class_name BattleGame", "class_name TailOriginalGame").replace('"user://progress.json"', '"user://original.json"')
    original = original.replace("Time.get_unix_time_from_system()", "1700000000.0").replace("rng.randomize()", "rng.seed=1701")
    (game / "original_game.gd").write_text(original, encoding="utf-8")
    for path in (game / "scripts").glob("*.gd"):
        source = path.read_text(encoding="utf-8").replace("Time.get_unix_time_from_system()", "1700000000.0")
        if path.name == "game.gd":source=source.replace("rng.randomize()", "rng.seed=1701")
        path.write_text(source, encoding="utf-8")
    shutil.copy2(ROOT / "test/test_tail_save_equivalence.gd", game / "test_tail_save_equivalence.gd")
    snapshot = (ROOT / "test/work/performance-20260930/input-save.json").read_bytes()
    target = Path(env["APPDATA"]) / "Godot/app_userdata/太空战舰 · 深空远征"
    target.mkdir(parents=True, exist_ok=True)
    for filename in ["progress.json", "original.json"]:(target / filename).write_bytes(snapshot)
    for label, flags in [("equivalence-import", ["--headless", "--editor", "--import", "--quit"]), ("equivalence", ["--headless", "--script", "res://test_tail_save_equivalence.gd"])]:
        with (area / (label+".log")).open("w", encoding="utf-8") as log:
            result=subprocess.run([str(engine), "--path", str(game), *flags], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        output=(area / (label+".log")).read_text(encoding="utf-8", errors="replace")
        print(label,result.returncode,output[-1400:],flush=True)
        if result.returncode or "SCRIPT ERROR" in output or "Parse Error" in output:raise RuntimeError(label)


if __name__ == "__main__":main()
