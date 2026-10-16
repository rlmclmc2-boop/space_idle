"""Fixed five-suite graphical DPS comparison. Creates two projects, then reuses them."""
from pathlib import Path
from ctypes import wintypes
import ctypes
import gzip
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import tarfile
import threading
import time
import win32com.client
import psutil

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
BASE = ROOT / "test/evidence/five-environment-20261015/baseline"
WORK = ROOT / "test/work/battle-dps-perf-20261016"
ENGINE = Path("D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe")
DLL = ROOT / "space-battleship/bin/space_native.dll"
CASES = ("mixed", "laser", "cannon", "missile", "longLaser")
ORDER = ("main", "off", "on", "main")
MAIN = "e02501b38bff8069f2b15bd8947c54d1dc215a1a"
CANDIDATE = "222d0760f0c3a4cd823727ffbd347e087fa032c5"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class SystemLoad:
    def __init__(self):
        self.rows = []
        self.done = threading.Event()
        self.thread = threading.Thread(target=self.collect, daemon=True)

    def collect(self):
        api = ctypes.WinDLL("kernel32", use_last_error=True)
        api.GetSystemTimes.argtypes = [ctypes.POINTER(wintypes.FILETIME)] * 3
        previous = None
        while not self.done.is_set():
            stamps = [wintypes.FILETIME() for _ in range(3)]
            if api.GetSystemTimes(*[ctypes.byref(value) for value in stamps]):
                values = [(value.dwHighDateTime << 32) | value.dwLowDateTime for value in stamps]
                busy = None
                if previous:
                    idle = values[0] - previous[0]
                    total = values[1] + values[2] - previous[1] - previous[2]
                    busy = 100 * (1 - idle / total) if total else None
                self.rows.append({"unix": time.time(), "system_cpu_busy_percent": busy})
                previous = values
            self.done.wait(0.5)

    def start(self):
        self.thread.start()

    def stop(self):
        self.done.set()
        self.thread.join()


def focus_process(process, project):
    """Focus the new Godot window before its 240-step warm-up ends."""
    user = ctypes.WinDLL("user32", use_last_error=True)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    callback_type = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    user.EnumWindows.argtypes = [callback_type, wintypes.LPARAM]
    user.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user.GetForegroundWindow.restype = wintypes.HWND
    user.AttachThreadInput.argtypes = [wintypes.DWORD, wintypes.DWORD, wintypes.BOOL]
    user.SetForegroundWindow.argtypes = [wintypes.HWND]
    kernel.GetCurrentThreadId.restype = wintypes.DWORD
    shell = win32com.client.Dispatch("WScript.Shell")
    class Rect(ctypes.Structure):
        _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                    ("right", ctypes.c_long), ("bottom", ctypes.c_long)]

    def area(window):
        rect = Rect()
        return (rect.right - rect.left) * (rect.bottom - rect.top) if user.GetClientRect(window, ctypes.byref(rect)) else 0

    deadline = time.monotonic() + 45
    last_window_count = 0
    last_foreground_pid = 0
    while process.poll() is None and time.monotonic() < deadline:
        target_pids = {process.pid}
        try:
            target_pids.update(child.pid for child in psutil.Process(process.pid).children(recursive=True))
        except psutil.Error:
            pass
        for candidate in psutil.process_iter(["pid", "name", "cmdline"]):
            try:
                if "godot" in (candidate.info["name"] or "").lower() and str(project).lower() in " ".join(candidate.info["cmdline"] or []).lower():
                    target_pids.add(candidate.pid)
            except psutil.Error:
                continue
        windows = []

        @callback_type
        def collect(window, _):
            pid = wintypes.DWORD()
            user.GetWindowThreadProcessId(window, ctypes.byref(pid))
            if pid.value in target_pids and user.IsWindowVisible(window):
                windows.append(window)
            return True

        user.EnumWindows(collect, 0)
        last_window_count = len(windows)
        if windows:
            window = max(windows, key=area)
            current = kernel.GetCurrentThreadId()
            foreground = user.GetForegroundWindow()
            other = user.GetWindowThreadProcessId(foreground, None) if foreground else 0
            target = user.GetWindowThreadProcessId(window, None)
            for thread in (other, target):
                if thread and thread != current:
                    user.AttachThreadInput(current, thread, True)
            user.ShowWindow(window, 9)
            user.BringWindowToTop(window)
            user.SetForegroundWindow(window)
            if user.GetForegroundWindow() != window:
                try:
                    shell.AppActivate(process.pid)
                except Exception:
                    pass
                user.keybd_event(0x12, 0, 0, 0)
                user.keybd_event(0x12, 0, 2, 0)
                user.SwitchToThisWindow(window, True)
                user.SetForegroundWindow(window)
            for thread in (target, other):
                if thread and thread != current:
                    user.AttachThreadInput(current, thread, False)
            if user.GetForegroundWindow() == window:
                return True
            pid = wintypes.DWORD()
            user.GetWindowThreadProcessId(user.GetForegroundWindow(), ctypes.byref(pid))
            last_foreground_pid = pid.value
        time.sleep(0.2)
    print(f"FOCUS_FAILURE pid={process.pid} target_pids={sorted(target_pids)} windows={last_window_count} foreground_pid={last_foreground_pid} process_exit={process.poll()}", flush=True)
    return False


def private_env(name):
    target = WORK / "users" / name
    env = os.environ.copy()
    for key, folder in (("APPDATA", "roaming"), ("LOCALAPPDATA", "local"), ("TEMP", "temp"), ("TMP", "temp")):
        path = target / folder
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    env.update(PERF_NATIVE="1", MISSILE_CONTROL="legend",
               SPACE_BATTLESHIP_PYTHON="D:/CodexTools/venv/godot-native/Scripts/python.exe")
    return env


def driver_source():
    source = (BASE / "driver.gd").read_text(encoding="utf-8")
    assert sha(BASE / "driver.gd") == "789154ddaba074cdcad6a75c9e721d93f5fc3bafa4ea5f2685929d3fd0ab331c"
    source = source.replace("var admitted:=false", "var admitted:=false\nvar dps_refresh_marks:Array=[]", 1)
    source = source.replace(" scene.retained_contacts_enabled=true", """ if OS.get_environment("DPS_MODE")=="on":
  var panel=scene.get("damage_stats_ui")
  assert(panel!=null,"candidate DPS panel exists")
  panel.show();panel.enabled.button_pressed=true
  assert(g.damage_stats.enabled and g.native_execution!=null,"DPS enabled without native handoff")
  panel.timer.timeout.connect(func():dps_refresh_marks.append(Time.get_ticks_usec()))
 scene.retained_contacts_enabled=true""", 1)
    source = source.replace(" sample_events.clear()", " sample_events.clear();dps_refresh_marks.clear()", 1)
    source = source.replace(" row.sampling_config=sampling_config", " row.dps_mode=OS.get_environment(\"DPS_MODE\")\n row.dps_refresh_marks_us=dps_refresh_marks\n row.sampling_config=sampling_config", 1)
    assert "dps_refresh_marks_us" in source
    return source


def prepare_project(name, ref, patched_driver, instrument):
    target = WORK / name
    target.mkdir(parents=True, exist_ok=False)
    archive = target / "source.tar"
    subprocess.run(["git", "archive", "--format=tar", f"--output={archive}", ref, "space-battleship"],
                   cwd=ROOT, check=True)
    with tarfile.open(archive) as handle:
        handle.extractall(target, filter="data")
    archive.unlink()
    project = target / "space-battleship"
    (project / "bin").mkdir(exist_ok=True)
    (project / ".runtime").mkdir(exist_ok=True)
    shutil.copy2(DLL, project / "bin/space_native.dll")
    shutil.copy2(project / "addons/native_battle/space_native.gdextension.in", project / "space_native.gdextension")
    for original, destination in (("probe.gd", "probe.gd"), ("counter_probe.gd", "counter_probe.gd")):
        shutil.copy2(BASE / original, project / destination)
    (project / "port_perf.gd").write_text(patched_driver, encoding="utf-8")
    instrument(project)
    env = private_env(f"import-{name}")
    with (target / "import.log").open("w", encoding="utf-8") as output:
        result = subprocess.run([str(ENGINE), "--path", str(project), "--headless", "--editor", "--import", "--quit"],
                                env=env, stdout=output, stderr=subprocess.STDOUT, timeout=240)
    log = (target / "import.log").read_text(encoding="utf-8", errors="replace")
    assert result.returncode == 0 and "SCRIPT ERROR" not in log, f"{name} import failed: {target / 'import.log'}"
    print("Imported", name, flush=True)
    return project


def asset_manifest(project):
    paths = sorted((project / "assets").rglob("*"))
    paths = [path for path in paths if path.is_file() and not path.name.endswith((".import", ".uid"))]
    paths.append(project / "data/game_data.json")
    return {str(path.relative_to(project)).replace("\\", "/"): sha(path) for path in paths}


def run_one(case, position, mode, project, receipt, prefix="", receipt_name="receipt.json"):
    label = f"{prefix}{case}-{position}-{mode}"
    env = private_env(label)
    env.update(WEAPON_CASE=case, PERF_SIDE=case, DPS_MODE=mode)
    fixture = "mixed_fixture.gd" if case == "mixed" else "combat_stress_fixture.gd"
    shutil.copyfile(BASE / fixture, project / "combat_stress_fixture.gd")
    for old in (project / ".runtime/uncapped-port.json", project / ".runtime/uncapped-port.png"):
        old.unlink(missing_ok=True)
    command = [str(ENGINE), "--path", str(project), "--rendering-method", "gl_compatibility",
               "--max-fps", "0", "--disable-vsync", "--script", "res://port_perf.gd"]
    load = SystemLoad()
    load.start()
    started = time.time()
    focused = False
    try:
        with (EVIDENCE / f"{label}.log").open("w", encoding="utf-8") as output:
            process = subprocess.Popen(command, env=env, stdout=output, stderr=subprocess.STDOUT)
            focused = focus_process(process, project)
            returncode = process.wait(timeout=240)
    finally:
        load.stop()
    run = {"case": case, "position": position, "mode": mode, "exit": returncode, "focus_requested": focused,
           "started_unix": started, "completed_unix": time.time(), "dll_sha256": sha(project / "bin/space_native.dll"),
           "fixture_sha256": sha(project / "combat_stress_fixture.gd")}
    (EVIDENCE / f"{label}-system-load.json.gz").write_bytes(gzip.compress(json.dumps(load.rows).encode("utf-8")))
    output = project / ".runtime/uncapped-port.json"
    image = project / ".runtime/uncapped-port.png"
    assert returncode == 0 and output.exists() and image.exists(), f"Run failed: {label}"
    log = (EVIDENCE / f"{label}.log").read_text(encoding="utf-8", errors="replace")
    assert "SCRIPT ERROR" not in log and "ADMISSION true" in log, f"Native admission or script failed: {label}"
    data = json.loads(output.read_text(encoding="utf-8"))
    frames = data["frames_us_raw"]
    phases = data["phases"]
    assert len(frames) == len(phases) == len(data["frame_trace"])
    assert all([phase[key] for key in ("previous_post_us", "main_begin_us", "main_end_us", "pre_draw_us", "post_draw_us")] ==
               sorted(phase[key] for key in ("previous_post_us", "main_begin_us", "main_end_us", "pre_draw_us", "post_draw_us"))
               and phase["post_draw_us"] - phase["previous_post_us"] == frame
               for phase, frame in zip(phases, frames)), f"Frame closure failed: {label}"
    if not (data["native_admitted"] and data["handoffs"] == 0 and data["performance_sample_valid"]):
        raise AssertionError(f"Invalid owner/focus: {label} focus_requested={focused} sample_focus={data['sampling_focus']} valid={data['performance_sample_valid']} handoffs={data['handoffs']}")
    assert data["sample_steps"] == 480 and data["warm_steps"] == 240 and data["actual_1x_pass"]
    assert data["runtime_config_start"]["stat_cache_enabled"] and not data["runtime_config_start"]["save_enabled"]
    assert data["dps_mode"] == mode
    if prefix in ("final-", "long-final-", "mixed-repeat-final-"):
        assert data["enemies_alive"] == 15, f"Enemy died in sustained workload: {label}"
    if prefix and mode == "on":
        damage = data["dps_snapshot"]["damage"]
        assert (damage["m"] if isinstance(damage, dict) else damage) > 0, f"No actual damage in enabled workload: {label}"
    compressed = EVIDENCE / f"{label}.json.gz"
    with gzip.open(compressed, "wt", encoding="utf-8") as target:
        json.dump(data, target, ensure_ascii=False, separators=(",", ":"))
    shutil.copy2(image, EVIDENCE / f"{label}.png")
    run.update({"json_sha256": sha(compressed), "image_sha256": sha(EVIDENCE / f"{label}.png"),
                "frames": len(frames), "fires": data["fires"], "hits": data["hits"],
                "events": data["events"], "refreshes": len(data["dps_refresh_marks_us"])})
    receipt["runs"].append(run)
    (EVIDENCE / receipt_name).write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    print("Finished", label, "frames", len(frames), "refreshes", run["refreshes"], flush=True)


def main():
    assert os.name == "nt" and ENGINE.is_file() and DLL.is_file()
    assert subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == CANDIDATE
    resume = WORK.exists()
    if resume:
        assert (WORK / "main/space-battleship/project.godot").is_file()
        assert (WORK / "candidate/space-battleship/project.godot").is_file()
    if not resume:
        assert not any(EVIDENCE.glob("*-main.json.gz"))
        assert not any(EVIDENCE.glob("*-off.json.gz"))
        assert not any(EVIDENCE.glob("*-on.json.gz"))
    spec = importlib.util.spec_from_file_location("baseline_counters", BASE / "instrument_counters.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    receipt = {"source": {"main": MAIN, "candidate": CANDIDATE}, "case_order": list(CASES),
               "run_order": list(ORDER), "driver_sha256": sha(BASE / "driver.gd"),
               "new_dll_sha256": sha(DLL), "engine_sha256": sha(ENGINE), "runs": []}
    patched = driver_source()
    receipt["patched_driver_sha256"] = hashlib.sha256(patched.encode("utf-8")).hexdigest()
    if resume:
        previous = json.loads((EVIDENCE / "receipt.json").read_text(encoding="utf-8"))
        assert all(previous[key] == receipt[key] for key in ("source", "case_order", "run_order", "driver_sha256", "new_dll_sha256", "engine_sha256", "patched_driver_sha256"))
        receipt = previous
    main_project = WORK / "main/space-battleship" if resume else prepare_project("main", MAIN, patched, module.instrument_counters)
    candidate_project = WORK / "candidate/space-battleship" if resume else prepare_project("candidate", CANDIDATE, patched, module.instrument_counters)
    assert asset_manifest(main_project) == asset_manifest(candidate_project), "Asset or game-data mismatch"
    completed = {(run["case"], run["position"], run["mode"]) for run in receipt["runs"]}
    for case in CASES:
        for index, mode in enumerate(ORDER, 1):
            if (case, index, mode) in completed:
                continue
            project = main_project if mode == "main" else candidate_project
            run_one(case, index, mode, project, receipt)


if __name__ == "__main__":
    main()
