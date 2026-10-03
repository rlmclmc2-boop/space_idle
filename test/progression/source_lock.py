"""Serialize local Excel edits and import; frozen QA packages do not need this lock."""
import fcntl
from pathlib import Path
def acquire(root: Path):
 path=root/'test/work/config-source.lock';path.parent.mkdir(parents=True,exist_ok=True)
 handle=path.open('a');fcntl.flock(handle,fcntl.LOCK_EX);return handle
