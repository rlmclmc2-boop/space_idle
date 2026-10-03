# Exact Git handoff

CLI token expired; connected GitHub API uploaded an immutable bundle preserving source commits. Normal candidate branch remains8e648d1. This evidence branch transports7159cf3 without rewriting either source history or main.

```bash
git fetch origin candidate/progression-longrun-calibration
curl -fL https://raw.githubusercontent.com/rlmclmc2-boop/space_idle/evidence/progression-handoff-7159cf3/test/progression/deliverables/progression-7159cf3.bundle.base64 | base64 -d > /tmp/progression-7159cf3.bundle
sha256sum /tmp/progression-7159cf3.bundle
git bundle verify /tmp/progression-7159cf3.bundle
git fetch /tmp/progression-7159cf3.bundle refs/heads/candidate/progression-longrun-calibration:refs/remotes/qa-handoff/candidate
git worktree add /tmp/space-idle-7159cf3 refs/remotes/qa-handoff/candidate
cd /tmp/space-idle-7159cf3
python test/progression/build_qa.py --output /tmp/galaxy60-qa
python test/progression/run_entry.py --project /tmp/galaxy60-qa --entry res://qa/galaxy_clear60_unlock.gd --label independent-galaxy60
```

Bundle539255bytes; SHA256 b6cef0620f3e9ea78ea75d336a58ca9b17a8354be53bffe8d1b10b25503d1e22. Requires8e648d122385e648f198679f1059f92d1a75338f. Contains head7159cf3e1df6550d9b1af7776aabebd7f9d1b0eb. Source-only/core requiresGodot4.6.3 and Python3; exporter validation additionally requiresopenpyxl. Godot engine and credentials excluded.

9e69147: pending numerical v20 short late bosses; d2e8136: clear60 opens first galaxy, old subsequent condition types retained;7159cf3: preserved old noforge34 failure8.171h. v19/v20 bounded calibration is still running; do not call this full-fresh acceptance. For full native QA dependency closure, build_qa.py --scene. Policies120/300/900 seconds and optional MAX are declared sensitivity assumptions, never a user30min mandate.
