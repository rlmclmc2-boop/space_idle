"""Index committed Git bytes, not Windows working-tree newline conversions."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[6]
OUT = ROOT / "docs/audits/20261020-e3db2838/stages/S12/P1_BLOB_INDEX.json"


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


def main() -> None:
    commit = git("rev-parse", "HEAD").decode().strip()
    paths = set(git(
        "ls-tree", "-r", "--name-only", "HEAD", "--",
        "docs/audits/20261020-e3db2838/stages/S12/p1_proto",
    ).decode().splitlines())
    paths.update({
        "docs/audits/20261020-e3db2838/IMPLEMENTATION_PLAN.md",
        "docs/audits/20261020-e3db2838/stages/S12/P1_SCENARIOS_FROZEN.md",
        "docs/audits/20261020-e3db2838/stages/S12/P1_SCENARIOS_REVISION_1.md",
        "docs/audits/20261020-e3db2838/stages/S12/P1_SCENARIOS_V2_REVIEW.md",
        "docs/audits/20261020-e3db2838/stages/S12/P1_SCENARIOS_V3_AUTHORITY.md",
        "docs/audits/20261020-e3db2838/stages/S12/P1_EXPLORATORY_EVIDENCE.md",
        "docs/audits/20261020-e3db2838/stages/S12/P1_FEASIBILITY_AND_GAPS.md",
    })
    files = {}
    for path in sorted(paths):
        raw = git("show", f"HEAD:{path}")
        files[path] = {
            "git_blob": git("rev-parse", f"HEAD:{path}").decode().strip(),
            "sha256_git_bytes": hashlib.sha256(raw).hexdigest(),
            "bytes": len(raw),
        }
    output = {
        "subject_commit": commit,
        "semantics": "SHA-256 of the bytes in Git blobs; no ignored runtime/cache files",
        "file_count": len(files),
        "files": files,
    }
    OUT.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(commit, len(files), OUT)


if __name__ == "__main__":
    main()
