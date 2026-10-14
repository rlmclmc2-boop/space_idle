"""Current full-view frame ledger. Writes only to test/work isolated QA project."""

from collections import Counter, defaultdict
from ctypes import wintypes
from pathlib import Path
import ctypes
import hashlib
import json
import os
import statistics
import subprocess
import sys
import threading
import time

ROOT = Path("D:/CodexBuild/space_idle/stable-integration")
EVIDENCE = ROOT / "test/evidence/numeric-batch-incremental-20261014"
WORK = ROOT / "test/work/battle-fix-20261013"
ISO = WORK / "space-battleship"
RUNTIME = ISO / ".runtime"
PYTHON = Path("D:/CodexTools/venv/godot-native/Scripts/python.exe")
GODOT = Path("D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe")
PREPARE = ROOT / "test/evidence/presentation-strip-20261014/prepare_strip.py"
QA = ROOT / "test/evidence/typed-events-20261014/qa_original.gd"
FIXTURE = ROOT / "test/evidence/typed-events-20261014/fixture_original.gd"
EXPECTED_TREE = "9d79b2a2b9e3798fa258f6aa3f25786bf14c8491"
EXPECTED_DLL = "45c507c31570d021e9f04f4056c35a92f201f4f028e392b6a65aef2befdf1f1e"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


CANDIDATE = subprocess.check_output(["git","rev-parse","b6a81045"],cwd=ROOT,text=True).strip()
assert subprocess.check_output(["git", "rev-parse", "85ada8bc:space-battleship"], cwd=ROOT, text=True).strip() == EXPECTED_TREE
assert sha(WORK / "native-ray/contact-candidate.dll") == EXPECTED_DLL
assert GODOT.exists() and PYTHON.exists() and QA.exists() and FIXTURE.exists()
RUNTIME.mkdir(exist_ok=True)

api = ctypes.WinDLL("kernel32", use_last_error=True)
api.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
api.GetProcessTimes.restype = wintypes.BOOL
api.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
api.OpenProcess.restype = wintypes.HANDLE
api.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
api.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
api.CloseHandle.argtypes = [wintypes.HANDLE]


class Entry(ctypes.Structure):
    _fields_ = [("size", wintypes.DWORD), ("usage", wintypes.DWORD), ("pid", wintypes.DWORD),
               ("heap", ctypes.c_size_t), ("module", wintypes.DWORD), ("threads", wintypes.DWORD),
               ("parent", wintypes.DWORD), ("priority", wintypes.LONG), ("flags", wintypes.DWORD),
               ("exe", wintypes.WCHAR * 260)]


api.Process32FirstW.argtypes = [wintypes.HANDLE, ctypes.POINTER(Entry)]
api.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(Entry)]


def game_process(launcher):
    snapshot = api.CreateToolhelp32Snapshot(2, 0)
    entry = Entry()
    entry.size = ctypes.sizeof(entry)
    found = []
    okay = api.Process32FirstW(snapshot, ctypes.byref(entry))
    while okay:
        if entry.parent == launcher.pid and entry.exe.startswith("Godot") and "console" not in entry.exe:
            found.append((entry.pid, entry.exe))
        okay = api.Process32NextW(snapshot, ctypes.byref(entry))
    api.CloseHandle(snapshot)
    assert len(found) == 1, (launcher.pid, found)
    pid, name = found[0]
    handle = api.OpenProcess(0x1000, False, pid)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    return pid, name, handle


def cpu(handle):
    values = [wintypes.FILETIME() for _ in range(4)]
    if not api.GetProcessTimes(handle, *(ctypes.byref(v) for v in values)):
        raise ctypes.WinError(ctypes.get_last_error())
    us = lambda v: ((v.dwHighDateTime << 32) | v.dwLowDateTime) / 10
    return {"user_us": us(values[3]), "kernel_us": us(values[2]), "clock_ns": time.perf_counter_ns()}


def prepare(profile):
    subprocess.run([str(PYTHON), str(PREPARE)] + (["--profile"] if profile else []), check=True, cwd=ROOT)
    text = QA.read_text(encoding="utf-8")
    assert '"source":"346c67f8"' in text
    text = text.replace('"source":"346c67f8"', '"source":"85ada8bc"')
    needle = ' var row={"retained_before":retained_before,'
    assert needle in text
    calibration = ''' Gate.spans.clear();Gate.sampled=true;Gate.profiling=true
 var calibration_start:=Time.get_ticks_usec()
 for j in 10000:
  var stamp=Gate.begin()
  Gate.end(stamp,"calibration")
 var calibration_us:=Time.get_ticks_usec()-calibration_start
 Gate.sampled=false;Gate.spans.clear()
'''
    text = text.replace(needle, calibration + needle.replace('var row={', 'var row={"calibration_10000_pairs_us":calibration_us,'))
    (ISO / "qa_current_frame.gd").write_text(text, encoding="utf-8")
    (ISO / "combat_stress_fixture.gd").write_bytes(FIXTURE.read_bytes())
    if profile:
        file = ISO / "scripts/native_execution_session.gd"
        source = file.read_text(encoding="utf-8")
        needle = "\tfor row in kernel.take_feedback():"
        assert source.count(needle) == 1
        source = source.replace(needle, '''\tvar feedback_stamp=preload("res://strip_gate.gd").begin()
\tvar feedback=kernel.take_feedback()
\tpreload("res://strip_gate.gd").end(feedback_stamp,"native.take_feedback")
\tfor row in feedback:''')
        file.write_text(source, encoding="utf-8")
    return {name: sha(ISO / "scripts" / name) for name in [
        "game.gd", "main.gd", "battlefield.gd", "battle_slice_runtime.gd",
        "native_execution_session.gd", "simulation_geometry_authority.gd"]}


def run_case(label, profile):
    hashes = prepare(profile)
    env = os.environ.copy()
    env.update(APPDATA=str(WORK / "roaming"), LOCALAPPDATA=str(WORK / "local"),
               PERF_NATIVE="1", STRIP_CASE=label, STRIP_MODE="0", STRIP_PROFILE="1" if profile else "0",
               GPU_CONTACT_CASE="GPU", RETAINED_CASE="GPU")
    for phase in ("begin", "end"):
        ack = RUNTIME / f"cpu-ack-{label}-{phase}"
        if ack.exists():
            ack.unlink()
    command = [str(GODOT), "--path", str(ISO), "--rendering-method", "gl_compatibility",
               "--script", "res://qa_current_frame.gd"]
    log = RUNTIME / f"current-ledger-{label}.txt"
    marks = {}
    with log.open("w", encoding="utf-8") as output:
        proc = subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, encoding="utf-8", errors="replace")
        watchdog = threading.Timer(90, proc.kill)  # Own child only.
        watchdog.start()
        try:
            for line in proc.stdout:
                output.write(line)
                output.flush()
                if line.startswith("CPU_MARK "):
                    _, case, phase = line.strip().split()
                    assert case == label
                    if "handle" not in marks:
                        pid, name, handle = game_process(proc)
                        marks.update(pid=pid, exe=name, handle=handle)
                    marks[phase] = cpu(marks["handle"])
                    (RUNTIME / f"cpu-ack-{label}-{phase}").write_text("ack", encoding="ascii")
            code = proc.wait()
        finally:
            watchdog.cancel()
    output = log.read_text(encoding="utf-8")
    assert code == 0 and "SCRIPT ERROR" not in output and "STRIP_RESULT" in output, output[-2400:]
    assert "begin" in marks and "end" in marks
    api.CloseHandle(marks.pop("handle"))
    raw = json.loads((RUNTIME / f"strip-{label}.json").read_text(encoding="utf-8"))
    assert raw["steps"] == raw["native_steps"] == 240
    assert raw["dll_sha256"].lower() == EXPECTED_DLL
    assert raw["config"]["save_enabled"] is False and raw["config"]["stat_cache_enabled"] is True
    assert raw["config"]["speed"] == 1
    cpu_us = sum(marks["end"][key] - marks["begin"][key] for key in ("user_us", "kernel_us"))
    assert cpu_us > 0
    marks.update(label=label, cpu_us=cpu_us, cpu_window_seconds=(marks["end"]["clock_ns"] - marks["begin"]["clock_ns"]) / 1e9,
                 script_sha256=hashes, dll_sha256=EXPECTED_DLL)
    (RUNTIME / f"current-ledger-cpu-{label}.json").write_text(json.dumps(marks, indent=2), encoding="utf-8")
    print(label, "frames", len(raw["frames_us"]), "frame_ms", round(statistics.mean(raw["frames_us"]) / 1000, 3),
          "cpu_ms", round(cpu_us / 1000, 3), flush=True)
    return raw, marks


def ledger(raw):
    total = Counter()
    calls = Counter()
    for frame in raw["phases"]:
        a, b = frame["start"], frame["end"]
        sections = [(a, frame["signal"], "gap.postdraw_to_signal", 0),
                    (frame["signal"], frame["main_start"], "gap.signal_to_main", 0),
                    (frame["main_start"], frame["main_end"], "main.unwrapped", 0),
                    (frame["main_end"], frame["pre_draw"], "gap.after_main_before_render", 0),
                    (frame["pre_draw"], b, "render_submission_gpu_wait_unsplit", 0)]
        for x, y, name in frame["spans"]:
            sections.append((x, y, name, 1))
            calls[name] += 1
        endpoints = defaultdict(list)
        for i, (x, y, _, _) in enumerate(sections):
            x, y = max(a, x), min(b, y)
            if y > x:
                endpoints[x].append((i, True))
                endpoints[y].append((i, False))
        endpoints[a]
        endpoints[b]
        active = set()
        previous = a
        for tick, changes in sorted(endpoints.items()):
            if tick > previous:
                chosen = max(active, key=lambda i: (sections[i][3], -(sections[i][1] - sections[i][0]))) if active else None
                total[sections[chosen][2] if chosen is not None else "gap.unassigned"] += tick - previous
            for i, on in changes:
                (active.add if on else active.discard)(i)
            previous = tick
    assert sum(total.values()) == sum(raw["frames_us"])
    return {"exclusive_us": dict(total), "calls": dict(calls), "closure_us": sum(total.values()) - sum(raw["frames_us"])}


import gzip,shutil
BASELINE="63b93069"
CASE_REF=BASELINE
CHANGED=subprocess.check_output(["git","diff","--name-only","85ada8bc",CANDIDATE,"--","space-battleship/scripts","space-battleship/shaders"],cwd=ROOT,text=True).splitlines()
def prepare(profile):
    shutil.copy2(WORK/"native-ray/contact-candidate.dll",ISO/"bin/space_native.dll")
    names=set(subprocess.check_output(["git","ls-tree","-r","--name-only",CASE_REF,"--","space-battleship"],cwd=ROOT,text=True).splitlines())
    selected=[n for n in CHANGED if n in names]
    source=PREPARE.read_text(encoding="utf-8");marker="gate="+chr(39)*3+"extends RefCounted"
    overlay="import subprocess\nfor name in CHANGED:\n data=subprocess.check_output(['git','show',CASE_REF+':'+name],cwd=r)\n (iso/Path(name).relative_to('space-battleship')).write_bytes(data)\n"
    exec(source.replace(marker,overlay+marker,1),{"CASE_REF":CASE_REF,"CHANGED":selected})
    text=QA.read_text(encoding="utf-8").replace('"source":"346c67f8"','"source":"'+CASE_REF+'"').replace('480','240')
    text=text.replace('var initial_ticks:int=g.native_execution.ticks','var initial_ticks:int=g.native_execution.ticks;var kernel_metrics_before:Dictionary=g.native_execution.kernel.metrics();var beams_before:Dictionary=scene.retained_contacts.beam_layer.metrics()' if CASE_REF==CANDIDATE else 'var initial_ticks:int=g.native_execution.ticks;var kernel_metrics_before:Dictionary=g.native_execution.kernel.metrics();var beams_before:Dictionary={}')
    extra='"beam_metrics_before":beams_before,"beam_metrics_after":scene.retained_contacts.beam_layer.metrics(),' if CASE_REF==CANDIDATE else '"beam_metrics_before":beams_before,"beam_metrics_after":{},'
    text=text.replace(' var row={"retained_before":',' var row={'+extra+'"kernel_metrics_before":kernel_metrics_before,"kernel_metrics_after":g.native_execution.kernel.metrics(),"loaded_dll_path":ProjectSettings.globalize_path("res://bin/space_native.dll"),"extension_open":GDExtensionManager.get_extension("res://space_native.gdextension").is_library_open(),"retained_before":')
    text=text.replace("scene.retained_contacts_enabled=true;", "scene.retained_contacts_enabled=true;scene.retained_gpu_beams_enabled=false;scene.damage_display_cache_enabled=false;")
    text=text.replace(' var row={',' var row={"gpu_beams_enabled":scene.retained_gpu_beams_enabled,"damage_cache_enabled":'+'scene.damage_display_cache_enabled'+',')
    if CASE_REF==CANDIDATE:
        text=text.replace('var initial_ticks:int=g.native_execution.ticks','var damage_before:Dictionary={"metric_builds":scene.damage_display_index.metric_builds,"obstacle_builds":scene.damage_display_index.obstacle_builds};var initial_ticks:int=g.native_execution.ticks')
        text=text.replace(' var row={',' var row={"damage_before":damage_before,"damage_after":{"metric_builds":scene.damage_display_index.metric_builds,"obstacle_builds":scene.damage_display_index.obstacle_builds},')
    (ISO/"qa_current_frame.gd").write_text(text,encoding="utf-8")
    (ISO/"combat_stress_fixture.gd").write_bytes(FIXTURE.read_bytes())
    return {name:sha(ISO/name.removeprefix("space-battleship/")) for name in selected}

cases={}
for label in ["A1","B1","B2","A2","A3","B3"]:
    CASE_REF=BASELINE if label.startswith("A") else CANDIDATE
    raw,marks=run_case(label,False)
    assert raw["extension_open"] and raw["gpu_beams_enabled"] is False and raw["damage_cache_enabled"] is False
    cases[label]={"source":CASE_REF,"dll_sha256":EXPECTED_DLL,"frame_ms":statistics.mean(raw["frames_us"])/1000,"frame_median_ms":statistics.median(raw["frames_us"])/1000,"frames":len(raw["frames_us"]),"steps":raw["steps"],"events":raw["events"],"beam_metrics_before":raw["beam_metrics_before"],"beam_metrics_after":raw["beam_metrics_after"]}
    with gzip.open(EVIDENCE/(label+".json.gz"),"wt",encoding="utf-8") as f:json.dump(raw,f)
    (EVIDENCE/("cpu-"+label+".json")).write_text(json.dumps(marks,indent=2),encoding="utf-8")
    shutil.copy2(RUNTIME/("strip-"+label+".png"),EVIDENCE/(label+".png"))
    shutil.copy2(RUNTIME/("current-ledger-"+label+".txt"),EVIDENCE/(label+".txt"))
    (EVIDENCE/(label+"-summary.json")).write_text(json.dumps(cases[label],indent=2),encoding="utf-8")
diffs=[cases["A"+str(i)]["frame_ms"]-cases["B"+str(i)]["frame_ms"] for i in [1,2,3]]
summary={"baseline":BASELINE,"candidate":CANDIDATE,"dll_sha256":EXPECTED_DLL,"cases":cases,"paired_A_minus_B_ms":diffs,"mean_paired_gain_ms":statistics.mean(diffs),"baseline_range_ms":[min(cases[x]["frame_ms"] for x in cases if x.startswith("A")),max(cases[x]["frame_ms"] for x in cases if x.startswith("A"))],"candidate_range_ms":[min(cases[x]["frame_ms"] for x in cases if x.startswith("B")),max(cases[x]["frame_ms"] for x in cases if x.startswith("B"))]}
(EVIDENCE/"comparison.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
print("COMPARISON",{k:v for k,v in summary.items() if k!="cases"},flush=True)
