"""Isolated save-stage and tail-frame replay; never opens the player's save."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

from saved_game_diagnosis import prepare, wrap, SNAPSHOT
from saved_game_perf import ROOT, SOURCE
from tail_save_candidate import install


def instrument_candidate(source):
    lines = source.splitlines()
    function = "startup"
    for i, line in enumerate(lines):
        if line.startswith("func "):function = line[5:].split("(")[0]
        if not line.startswith("func ") and "save_progress()" in line and function != "request_ordinary_progress_save":
            lines[i] = line.replace("save_progress()", f'_tail_request_save("{function}")')
        if not line.startswith("func ") and "request_ordinary_progress_save()" in lines[i]:
            lines[i] = lines[i].replace("request_ordinary_progress_save()",f'_tail_request_ordinary_save("{function}")')
    source = "\n".join(lines) + "\n"
    source += '\nfunc _tail_request_save(reason: String) -> void:\n\tif save_enabled:Engine.get_meta("diag_meter").save_reason(reason)\n\tsave_progress()\n'
    source += '\nfunc _tail_request_ordinary_save(reason: String) -> void:\n\tif save_enabled:Engine.get_meta("diag_meter").save_reason(reason)\n\trequest_ordinary_progress_save()\n'
    source = source.replace('JSON.stringify(_build_save_data(), "\\t").to_utf8_buffer()', '_tail_encode()')
    source = source.replace('progress_writer.enqueue(_tail_encode())', 'progress_writer.enqueue(_tail_encode("ordinary"))\n\t\t\tEngine.get_meta("diag_meter").save_blocking_end()')
    source = source.replace('\t_accept_save_result(progress_writer.immediate(_tail_encode()))', '\tvar _tail_sync_started := Time.get_ticks_usec()\n\t_accept_save_result(progress_writer.immediate(_tail_encode("immediate")))\n\tEngine.get_meta("diag_meter").save_blocking_end(_tail_sync_started)')
    source = source.replace('func _build_save_data() -> Dictionary:\n', 'func _build_save_data() -> Dictionary:\n\tvar _tail = Engine.get_meta("diag_meter")\n\t_tail.save_start()\n')
    source = source.replace('\tvar saved := profile.duplicate()', '\t_tail.save_stage("build")\n\tvar saved := profile.duplicate()')
    source = source.replace('\treturn saved\n', '\t_tail.save_stage("copy_transform")\n\treturn saved\n', 1)
    source += '''
func _tail_encode(mode: String) -> PackedByteArray:
	var _tail = Engine.get_meta("diag_meter")
	var saved := _build_save_data()
	var text := JSON.stringify(saved, "\\t")
	_tail.save_stage("serialize_stringify")
	var bytes := text.to_utf8_buffer()
	_tail.save_stage("encode")
	_tail.save_end(bytes.size(), true)
	_tail.save_row.mode=mode
	return bytes
'''
    return source


def instrument_writer(source):
    source = source.replace('\trevision += 1', '\trevision += 1\n\tEngine.get_meta("diag_meter").register_revision(revision)')
    source = source.replace('\tvar result := _write_payload(bytes)', '\tvar result := _write_payload(bytes)\n\tEngine.get_meta("diag_meter").io_completed(revision,result)')
    source = source.replace('\tvar result: Dictionary = worker.wait_to_finish()', '\tvar result: Dictionary = worker.wait_to_finish()\n\tEngine.get_meta("diag_meter").io_completed(active_revision,result)')
    start=source.index('func _write_payload(')
    end=source.index('\nfunc _store_buffer',start)
    measured='''func _write_payload(bytes: PackedByteArray) -> Dictionary:
	var _tail_begin := Time.get_ticks_usec()
	var _tail_clock := _tail_begin
	var _tail_stages := {}
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE_READ)
	_tail_stages.open=Time.get_ticks_usec()-_tail_clock
	_tail_clock=Time.get_ticks_usec()
	if file == null:return _tail_io_result(FileAccess.get_open_error(),_tail_stages,_tail_begin)
	var written := _store_buffer(file,bytes)
	_tail_stages.write=Time.get_ticks_usec()-_tail_clock
	_tail_clock=Time.get_ticks_usec()
	file.flush()
	var error := file.get_error()
	_tail_stages.flush_close=Time.get_ticks_usec()-_tail_clock
	_tail_clock=Time.get_ticks_usec()
	if not written or error != OK:
		file.close()
		_tail_stages.flush_close+=Time.get_ticks_usec()-_tail_clock
		return _tail_io_result(ERR_FILE_CANT_WRITE,_tail_stages,_tail_begin)
	file.seek(0)
	var verified := file.get_buffer(bytes.size())
	_tail_stages.verify_read=Time.get_ticks_usec()-_tail_clock
	_tail_clock=Time.get_ticks_usec()
	var complete := verified == bytes and file.get_length() == bytes.size() and file.get_error() == OK
	_tail_stages.verify_compare=Time.get_ticks_usec()-_tail_clock
	_tail_clock=Time.get_ticks_usec()
	file.close()
	_tail_stages.flush_close+=Time.get_ticks_usec()-_tail_clock
	_tail_clock=Time.get_ticks_usec()
	if not complete:return _tail_io_result(ERR_FILE_CANT_WRITE,_tail_stages,_tail_begin)
	var _tail_error := _commit_temp()
	_tail_stages.replace=Time.get_ticks_usec()-_tail_clock
	return _tail_io_result(_tail_error,_tail_stages,_tail_begin)
'''
    source=source[:start]+measured+source[end:]
    source += '''
func _tail_io_result(error: Error, stages: Dictionary, started: int) -> Dictionary:
	var end := Time.get_ticks_usec()
	return {"error":error,"io_stages_us":stages,"io_total_us":end-started,"completed_us":end}
'''
    return source


def instrument_save(source):
    # Preserve call sites, batching, mutations, open-before-projection and rename order.
    lines = source.splitlines()
    function = "startup"
    for i, line in enumerate(lines):
        if line.startswith("func "):
            function = line[5:].split("(")[0]
        if line.strip() == "save_progress()":
            lines[i] = line.replace("save_progress()", f'_tail_request_save("{function}")')
    source = "\n".join(lines) + "\n"
    source += '\nfunc _tail_request_save(reason: String) -> void:\n\tEngine.get_meta("diag_meter").save_reason(reason)\n\tsave_progress()\n'
    a = source.index("func save_progress()")
    b = source.index("\nfunc first_equipment_entry", a)
    body = source[a:b]
    body = body.replace('\tprofile.hightechOrder', '\tvar _tail = Engine.get_meta("diag_meter")\n\t_tail.save_start()\n\tprofile.hightechOrder', 1)
    body = body.replace('\tvar file :=', '\t_tail.save_stage("build")\n\tvar file :=', 1)
    body = body.replace('\tif file == null:', '\t_tail.save_stage("open")\n\tif file == null:', 1)
    body = body.replace('\t\tevent.emit("save_error", {})\n\t\treturn', '\t\tevent.emit("save_error", {})\n\t\t_tail.save_end(0, false)\n\t\treturn', 1)
    body = body.replace('\tfile.store_string(JSON.stringify(saved, "\\t"))', '\t_tail.save_stage("copy_transform")\n\tvar _tail_json := JSON.stringify(saved, "\\t")\n\t_tail.save_stage("serialize_stringify")\n\tvar _tail_bytes := _tail_json.to_utf8_buffer()\n\t_tail.save_stage("encode")\n\tfile.store_buffer(_tail_bytes)\n\t_tail.save_stage("write")')
    body = body.replace('\tfile.close()', '\tfile.close()\n\t_tail.save_stage("flush_close")')
    body = body.replace('\tif err != OK:', '\t_tail.save_stage("replace")\n\tif err != OK:')
    body += '\t_tail.save_end(_tail_bytes.size(), err == OK)\n'
    return source[:a] + body + source[b:]


def prepare_tail(area, events, variant):
    game = prepare(area, False)
    if variant == "candidate":install(game)
    path = game / "scripts/game.gd"
    source=path.read_text(encoding="utf-8")
    candidate = "ordinary_save_async_enabled" in source
    path.write_text(instrument_candidate(source) if candidate else instrument_save(source), encoding="utf-8")
    if candidate:
        path=game / "scripts/progress_writer.gd"
        path.write_text(instrument_writer(path.read_text(encoding="utf-8")), encoding="utf-8")
    # External save callers need a reason too (focus/close and galaxy changes).
    for module in ["main", "galaxy_system", "crew_system"]:
        path=game / "scripts" / (module+".gd")
        lines=path.read_text(encoding="utf-8").splitlines()
        function="startup"
        for i,line in enumerate(lines):
            if line.startswith("func "):function=line[5:].split("(")[0]
            for receiver in ["game", "g"]:
                call=receiver+".save_progress()"
                if call in line:
                    reason=f'"{module}.{function}"'
                    if module=="main" and function=="_notification":reason+='+"/"+str(what)'
                    lines[i]=line.replace(call,f'{receiver}._tail_request_save({reason})')
        path.write_text("\n".join(lines)+"\n",encoding="utf-8")
    if events:
        targets = {"game": ["tick", "change_state", "hit_player", "hit_enemy", "advance_planets", "add_crew_exp"], "main": ["refresh_structure", "on_event"], "crew_panel": ["refresh", "refresh_member"], "crew_system": ["advance", "gain_exp"]}
        for module, names in targets.items():
            path = game / "scripts" / (module + ".gd")
            source = path.read_text(encoding="utf-8")
            for name in names:
                source, found = wrap(source, name, "event", module)
                assert found, (module, name)
            path.write_text(source, encoding="utf-8")
    probe = (ROOT / "test/saved_game_diagnosis.gd").read_text(encoding="utf-8")
    meter = (ROOT / "test/saved_game_tail_meter.gd").read_text(encoding="utf-8")
    probe = probe.replace("class Meter:\n\textends RefCounted", "class Meter:\n\textends RefCounted" + meter)
    probe = probe.replace("\t\tcurrent.clear()", "\t\tsave_frame_begin()\n\t\tcurrent.clear()")
    probe = probe.replace('var row := {"page":page,"index":index', 'var row := {"saves":meter.frame_saves.duplicate(true),"page":page,"index":index')
    probe = probe.replace("meter.enabled=detail", "meter.enabled=true")
    probe = probe.replace("\treturn row\n", '\tmeter.attach_frame(row)\n\treturn row\n', 1)
    probe = probe.replace('\tFileAccess.open("res://.runtime/"+name', '\treport.save_traces=meter.all_saves\n\treport.long_frame_count=meter.long_frame_count\n\treport.long_frame_max=meter.long_frame_max\n\tFileAccess.open("res://.runtime/"+name')
    probe = probe.replace('\t\tvar long_start :=', '\t\tmeter.in_longrun=true\n\t\tvar long_start :=')
    probe = probe.replace('\t\tvar last_reported := 0', '\t\tvar last_reported := 0\n\t\tvar long_frame_serial := 0')
    probe = probe.replace('sample_frame(scene,5,recent.size(),detail)', 'sample_frame(scene,5,long_frame_serial,detail)\n\t\t\tlong_frame_serial+=1')
    # One independent last-state container census after measurements.
    probe = probe.replace('\treport.save_traces=', '\treport.profile_container_counts=meter.census(scene.game.profile)\n\treport.container_counts=meter.census(JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH)))\n\treport.save_traces=')
    if candidate:probe=probe.replace('\treport.profile_container_counts=', '\tscene.game.finish_pending_saves()\n\treport.profile_container_counts=')
    (game / "saved_game_diagnosis.gd").write_text(probe, encoding="utf-8")
    return game


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--area", type=Path, required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--fps", type=int, default=60)
    parser.add_argument("--speed", type=float, default=1)
    parser.add_argument("--long-minutes", type=int, default=0)
    parser.add_argument("--events", action="store_true")
    parser.add_argument("--variant", default="baseline")
    args = parser.parse_args()
    area = args.area.resolve()
    assert area.parent == (ROOT / "test/work").resolve() and area.name.startswith("saved-diagnosis-tail-")
    area.mkdir(exist_ok=True)
    game = prepare_tail(area, args.events, args.variant)
    cache=ROOT / "test/work/saved-diagnosis-tail-baseline/space-battleship/.godot"
    if args.variant=="candidate" and not (game / ".godot").exists():shutil.copytree(cache,game / ".godot")
    snapshot = SNAPSHOT.read_bytes()
    env = os.environ.copy()
    env["APPDATA"] = str(area / "userdata/roaming")
    env["LOCALAPPDATA"] = str(area / "userdata/local")
    target = Path(env["APPDATA"]) / "Godot/app_userdata/太空战舰 · 深空远征/progress.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(snapshot)
    Path(env["LOCALAPPDATA"]).mkdir(parents=True, exist_ok=True)
    engine = SOURCE / "engine/Godot_v4.7.2-stable_win64.exe"
    tasks = [] if (game / ".godot").exists() else [("import", ["--headless", "--editor", "--import", "--quit"])]
    tasks.append((args.label, ["--resolution", "1373x883", "--script", "res://saved_game_diagnosis.gd", "--", "--diag-mode=baseline", f"--diag-fps={args.fps}", f"--diag-speed={args.speed}", f"--diag-long-minutes={args.long_minutes}", f"--diag-name={args.label}"]))
    print("EVIDENCE", area, flush=True)
    for label, flags in tasks:
        with (area / (label + ".log")).open("w", encoding="utf-8") as log:
            result = subprocess.run([str(engine), "--path", str(game), *flags], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=max(240, args.long_minutes * 75 + 120))
        output = (area / (label + ".log")).read_text(encoding="utf-8", errors="replace")
        if result.returncode or "SCRIPT ERROR" in output or "Parse Error" in output:
            raise RuntimeError(f"{label} exit={result.returncode}\n" + output[-6000:])
    report = json.loads((game / ".runtime" / (args.label + ".json")).read_text(encoding="utf-8"))
    report["save_sha256"] = hashlib.sha256(snapshot).hexdigest()
    report["events_instrumented"] = args.events
    report["config_sha256"]=hashlib.sha256((SOURCE / "data/game_data.json").read_bytes()).hexdigest()
    (area / (args.label + ".json")).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    for row in report["pages"]:
        print(row["page"], row["frame_stats"], flush=True)
    print("SAVES", len(report["save_traces"]), "LONG", report["long_frame_count"], report["long_frame_max"], flush=True)
    assert SNAPSHOT.read_bytes() == snapshot


if __name__ == "__main__":
    main()
