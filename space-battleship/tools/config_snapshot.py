"""Configuration generation capture/publication, shared with the native lock ABI.

Parsing and candidate validation happen outside the root lock. The critical
section only verifies identities, captures bytes, or installs/recovers a batch.
Readers never create manifests or accept a partially published generation.
"""
from contextlib import contextmanager
from dataclasses import dataclass
import ctypes
import hashlib
import json
import os
import re
from pathlib import Path, PurePosixPath
import shutil
from types import MappingProxyType
import uuid

MANIFEST = '.configuration.json'
JOURNAL = '.configuration-transaction.json'
LOCK = '.configuration-lock'

class Busy(RuntimeError): pass
class RecoveryRequired(RuntimeError): pass
class Stale(RuntimeError): pass


def digest(raw): return hashlib.sha256(raw).hexdigest()
def encoded(value): return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()


@contextmanager
def exclusive(path):
    """Same CreateFile share=0 / POSIX flock ABI as SpaceSaveLock.acquire."""
    path = Path(path).resolve()
    if os.name == 'nt':
        import msvcrt
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        create = kernel.CreateFileW
        create.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32,
                           ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
        create.restype = ctypes.c_void_p
        handle = create(str(path), 0xC0000000, 0, None, 4, 0x80, None)
        if handle == ctypes.c_void_p(-1).value: raise Busy(str(path))
        fd = msvcrt.open_osfhandle(handle, os.O_RDWR)
    else:
        import fcntl
        fd = os.open(path, os.O_CREAT | os.O_RDWR, 0o600)
        try: fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            os.close(fd)
            raise Busy(str(path))
    try: yield
    finally: os.close(fd)


def stable_external_bytes(path):
    """Deny external write/delete for the entire workbook capture on Windows.

    POSIX advisory locks cannot exclude arbitrary spreadsheet editors. Refuse
    this external-file adapter there instead of treating mtime as a snapshot.
    """
    if os.name != 'nt': raise Busy('External workbook requires a stable frozen input on this platform')
    import msvcrt
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    create = kernel.CreateFileW
    create.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32,
                       ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
    create.restype = ctypes.c_void_p
    handle = create(str(Path(path).resolve()), 0x80000000, 1, None, 3, 0x80, None)
    if handle == ctypes.c_void_p(-1).value: raise Busy(str(path))
    with os.fdopen(msvcrt.open_osfhandle(handle, os.O_RDONLY), 'rb') as stream:
        return stream.read()


@dataclass(frozen=True)
class Snapshot:
    identity: str
    files: object
    manifest: bytes

    def materialize(self, target):
        target = Path(target)
        for name, raw in self.files.items():
            path = target / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        (target / MANIFEST).write_bytes(self.manifest)


class Store:
    def __init__(self, root):
        self.root = Path(root).resolve(strict=True)

    def path(self, name):
        pure = PurePosixPath(name)
        if pure.is_absolute() or '..' in pure.parts or '\\' in name or ':' in name:
            raise ValueError('Invalid configuration member: ' + name)
        path = self.root.joinpath(*pure.parts)
        if not path.resolve().is_relative_to(self.root): raise ValueError('Configuration member escapes root')
        return path

    def member(self, name):
        pure = PurePosixPath(name)
        if len(pure.parts) < 2 or pure.parts[0] not in ('data', 'config_excel') or pure.suffix not in ('.json', '.xlsx'):
            raise ValueError('Not a configuration member: ' + name)
        return self.path(name)

    def _read(self, name):
        path = self.path(name)
        return stable_external_bytes(path) if path.suffix.lower() == '.xlsx' else path.read_bytes()

    @staticmethod
    def manifest(files):
        return encoded({'version': 1, 'files': {name: {'sha256': digest(raw), 'size': len(raw)}
                       for name, raw in sorted(files.items())}})

    def _capture(self):
        raw = (self.root / MANIFEST).read_bytes()
        manifest = json.loads(raw)
        if manifest.get('version') != 1 or not manifest.get('files'): raise RecoveryRequired('Invalid generation manifest')
        files = {}
        for name, expected in manifest['files'].items():
            if name in (MANIFEST, JOURNAL, LOCK): raise RecoveryRequired('Invalid generation member')
            self.member(name)
            payload = self._read(name)
            if expected != {'sha256': digest(payload), 'size': len(payload)}:
                raise RecoveryRequired('Configuration generation mismatch: ' + name)
            files[name] = payload
        return Snapshot(digest(raw), MappingProxyType(files), raw)

    def capture(self):
        with exclusive(self.root / LOCK):
            self._recover()
            return self._capture()

    def _atomic(self, path, raw):
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_name('.' + path.name + '.' + uuid.uuid4().hex + '.tmp')
        try:
            with temp.open('wb') as stream:
                stream.write(raw); stream.flush(); os.fsync(stream.fileno())
            os.replace(temp, path)
        finally: temp.unlink(missing_ok=True)

    def _recover(self):
        journal = self.root / JOURNAL
        if not journal.exists(): return
        state = json.loads(journal.read_bytes())
        recovery_name = state.get('recovery', '')
        if state.get('version') != 1 or not re.fullmatch(r'\.runtime/config-transactions/[0-9a-f]{32}', recovery_name):
            raise RecoveryRequired('Invalid recovery identity; journal retained')
        recovery = self.path(recovery_name)
        for name, entry in state.get('originals', {}).items():
            if name != MANIFEST: self.member(name)
            if entry is not None and (not re.fullmatch(r'[0-9]+\.old', entry.get('file', '')) or
                    not re.fullmatch(r'[0-9a-f]{64}', entry.get('sha256', ''))):
                raise RecoveryRequired('Invalid recovery backup identity; journal retained')
        if state['state'] == 'committed':
            if self._capture().identity != state['generation']:
                raise RecoveryRequired('Committed generation cannot be verified')
        elif state['state'] in ('installing', 'recovery_required'):
            try:
                # Restore every original, including targets replaced just before a crash.
                for name, entry in state['originals'].items():
                    target = self.path(name)
                    if entry is None: target.unlink(missing_ok=True)
                    else:
                        saved = recovery / entry['file']
                        raw = saved.read_bytes()
                        if digest(raw) != entry['sha256']: raise RecoveryRequired('Recovery backup mismatch')
                        self._atomic(target, raw)
                if state['previous'] is not None and self._capture().identity != state['previous']:
                    raise RecoveryRequired('Restored generation cannot be verified')
            except Exception as error:
                state['state'] = 'recovery_required'
                self._atomic(journal, encoded(state))
                raise RecoveryRequired('Configuration recovery retained: ' + str(recovery)) from error
        else: raise RecoveryRequired('Unknown configuration transaction state')
        journal.unlink()
        shutil.rmtree(recovery)

    def publish(self, expected, files, validate):
        """Publish a complete candidate; validate must check the whole candidate.

        expected=None is an explicit initial publication. Ordinary capture never
        takes that path. No caller is allowed to publish only a parsed subset.
        """
        files = dict(files)
        if not files or any(name in (MANIFEST, JOURNAL, LOCK) for name in files):
            raise ValueError('Empty/reserved configuration member')
        for name, raw in files.items():
            self.member(name)
            if not isinstance(raw, bytes): raise TypeError('Configuration payload must be bytes')
        validate(MappingProxyType(files))  # expensive parsing happens before locking
        manifest = self.manifest(files)
        if expected is not None and set(files) != set(expected.files):
            raise ValueError('Generation membership changes require an explicit publisher schema change')
        recovery = self.root / '.runtime/config-transactions' / uuid.uuid4().hex
        recovery.mkdir(parents=True)
        staged = {}
        try:
            # Private candidate preparation, outside the root critical section.
            for index, (name, raw) in enumerate({**files, MANIFEST: manifest}.items()):
                path = recovery / (str(index) + '.new')
                with path.open('wb') as stream:
                    stream.write(raw); stream.flush(); os.fsync(stream.fileno())
                staged[name] = path
            with exclusive(self.root / LOCK):
                self._recover()
                if expected is None:
                    if (self.root / MANIFEST).exists(): raise Stale('Generation already initialized')
                elif self._capture().identity != expected.identity: raise Stale('Configuration generation changed')
                originals = {}
                for index, name in enumerate(staged):
                    target = self.path(name)
                    if target.exists():
                        raw = self._read(name)
                        saved = recovery / (str(index) + '.old')
                        with saved.open('wb') as stream:
                            stream.write(raw); stream.flush(); os.fsync(stream.fileno())
                        originals[name] = {'file': saved.name, 'sha256': digest(raw)}
                    else: originals[name] = None
                state = {'version': 1, 'state': 'installing', 'recovery': recovery.relative_to(self.root).as_posix(),
                         'originals': originals, 'previous': expected.identity if expected else None,
                         'generation': digest(manifest)}
                self._atomic(self.root / JOURNAL, encoded(state))
                try:
                    for name, source in staged.items():
                        target = self.path(name); target.parent.mkdir(parents=True, exist_ok=True)
                        os.replace(source, target)
                    if self._capture().identity != state['generation']: raise RecoveryRequired('Published generation mismatch')
                    state['state'] = 'committed'
                    self._atomic(self.root / JOURNAL, encoded(state))
                except BaseException:
                    self._recover()
                    raise
                self._recover()
        finally:
            # Never discard the only recovery evidence for an unresolved journal.
            if not (self.root / JOURNAL).exists() and recovery.exists(): shutil.rmtree(recovery)
        return self.capture()
