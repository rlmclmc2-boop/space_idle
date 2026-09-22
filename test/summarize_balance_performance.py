"""Summarize completed fixed-step benchmarks; never extrapolate unfinished runs."""
import argparse
import json
from pathlib import Path


def summarize(directory):
    results = {}
    for path in sorted(Path(directory).glob("long_*.json")):
        run = json.loads(path.read_text(encoding="utf-8"))
        records = [json.loads(line) for line in Path(run["performance"]["path"]).read_text(encoding="utf-8").splitlines() if line.strip()]
        windows = []
        previous = 0.0
        peaks = {}
        for record in records:
            elapsed = record.get("window_seconds", record["real_seconds"] - previous)
            previous = record["real_seconds"]
            if elapsed >= 1:
                windows.append(record["steps_per_second"])
            for key, value in record["containers"].items():
                peaks[key] = max(peaks.get(key, 0), value)
        results[int(run["duration"])] = {
            "average_steps_per_second": run["steps_per_second"],
            "start_steps_per_second": windows[0] if windows else None,
            "end_steps_per_second": windows[-1] if windows else None,
            "end_start_ratio": windows[-1] / windows[0] if windows else None,
            "sampled_peaks": peaks,
            "core_hash": run["core_hash"],
            "data_hash": run["data_hash"],
            "stage": run["core"]["stage"],
            "wall_seconds": run["wall_seconds"],
        }
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before")
    parser.add_argument("after")
    parser.add_argument("output")
    args = parser.parse_args()
    before, after = summarize(args.before), summarize(args.after)
    rows = []
    for duration in [600, 3600, 36000, 360000]:
        old, new = before.get(duration), after.get(duration)
        rows.append({"duration": duration, "before": old, "after": new,
                     "core_identical": old["core_hash"] == new["core_hash"] if old and new else None,
                     "data_identical": old["data_hash"] == new["data_hash"] if old and new else None})
    Path(args.output).write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    print("duration | before steps/s | after steps/s | after END/START | core identical")
    for row in rows:
        old, new = row["before"], row["after"]
        print(row["duration"], old and round(old["average_steps_per_second"]),
              new and round(new["average_steps_per_second"]),
              new and round(new["end_start_ratio"], 3), row["core_identical"], sep=" | ")
    if any(row["core_identical"] is False or row["data_identical"] is False for row in rows):
        raise SystemExit("Completed benchmark fingerprints differ")


if __name__ == "__main__":
    main()
