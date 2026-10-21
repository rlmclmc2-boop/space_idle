"""Reproducible audit-only Godot runner with isolated user data and raw output.

This runner is also useful for a future confirmed ten-process P1 protocol. A
single invocation here remains exploratory and does not claim a gate result.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import time

import psutil

ROOT = Path(__file__).resolve().parent
GODOT = Path(r"D:\CodexTools\godot-4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe")


def main() -> int:
    if len(sys.argv) != 3 or sys.argv[1] not in {"bench_sparse.gd", "research_probe.gd", "price_probe.gd", "max_probe.gd", "max_chunk_probe.gd", "max_binary_probe.gd", "verify_binary_prices.gd", "verify_float_bits.gd", "export_prices_3873.gd", "reactor_quote_probe.gd", "save_size_probe.gd"}:
        print("usage: run_probe.py {bench_sparse.gd|research_probe.gd|price_probe.gd|max_probe.gd|max_chunk_probe.gd|max_binary_probe.gd|verify_binary_prices.gd|verify_float_bits.gd|export_prices_3873.gd|reactor_quote_probe.gd|save_size_probe.gd} OUTPUT_STEM", file=sys.stderr)
        return 2
    script, stem = sys.argv[1:]
    if Path(stem).name != stem or not stem.startswith("exploratory_"):
        print("output stem must be a simple exploratory_ name", file=sys.stderr)
        return 2
    runtime = ROOT / ".runtime" / stem
    roaming, local = runtime / "Roaming", runtime / "Local"
    roaming.mkdir(parents=True, exist_ok=True)
    local.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["APPDATA"] = str(roaming)
    env["LOCALAPPDATA"] = str(local)
    command = [str(GODOT), "--headless", "--path", str(ROOT), "--script", script]
    start = time.perf_counter()
    out_path = ROOT / f"{stem}.stdout.log"
    err_path = ROOT / f"{stem}.stderr.log"
    peak_rss = 0
    timed_out = False
    with out_path.open("wb") as out_file, err_path.open("wb") as err_file:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdin=subprocess.DEVNULL, stdout=out_file, stderr=err_file)
        monitored = psutil.Process(process.pid)
        deadline = time.perf_counter() + 30
        while process.poll() is None:
            try:
                family = [monitored] + monitored.children(recursive=True)
                peak_rss = max(peak_rss, sum(member.memory_info().rss for member in family if member.is_running()))
            except psutil.Error:
                pass
            if time.perf_counter() > deadline:
                timed_out = True
                for child in monitored.children(recursive=True):
                    child.kill()
                process.kill()
                break
            time.sleep(0.001)
        process.wait()
    stdout, stderr = out_path.read_bytes(), err_path.read_bytes()
    elapsed_ms = (time.perf_counter() - start) * 1000
    virtual = psutil.virtual_memory()
    meta = {
        "classification": "exploratory, not official P1 repetition",
        "command": command,
        "cwd": str(ROOT),
        "appdata": str(roaming),
        "localappdata": str(local),
        "exit_code": process.returncode,
        "timed_out": timed_out,
        "elapsed_ms": elapsed_ms,
        "sampled_peak_process_family_rss_bytes": peak_rss,
        "rss_sample_interval_target_ms": 1,
        "godot_sha256": hashlib.sha256(GODOT.read_bytes()).hexdigest(),
        "godot_banner_observed": stdout.splitlines()[0].decode("utf-8", errors="replace") if stdout else "missing",
        "cpu_model": platform.processor(),
        "physical_cores": psutil.cpu_count(logical=False),
        "logical_cores": psutil.cpu_count(logical=True),
        "os": platform.platform(),
        "ram_total_bytes": virtual.total,
        "ram_available_before_record_bytes": virtual.available,
        "stdout_sha256": hashlib.sha256(stdout).hexdigest(),
        "stderr_sha256": hashlib.sha256(stderr).hexdigest(),
    }
    (ROOT / f"{stem}.meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(meta, ensure_ascii=False))
    return process.returncode


if __name__ == "__main__":
    raise SystemExit(main())
