"""Configuration generation capture/publication, shared with the native lock ABI.

Parsing and candidate validation happen outside the root lock. The critical
section only verifies identities, captures bytes, or installs/recovers a batch.
Readers never create manifests or accept a partially published generation.
"""
from contextlib import contextmanager, ExitStack
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

MANIFEST = 'configuration_manifest.json'
JOURNAL = '.configuration-transaction.json'
LOCK = '.configuration-lock'

class Busy(RuntimeError): pass
class RecoveryRequired(RuntimeError):
    def __init__(self,message,recovery_path=None,rollback_failed=()):
        super().__init__(message)
        self.recovery_path=recovery_path
        self.rollback_failed=list(rollback_failed)
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


@contextmanager
def stable_external_stream(path, writable=False, create_new=False, delete=False):
    """Capture external inputs through handles excluding writes and replacement."""
    if os.name != 'nt': raise Busy('External workbook requires a stable frozen input on this platform')
    import msvcrt
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    create = kernel.CreateFileW
    create.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32,
                       ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
    create.restype = ctypes.c_void_p
    access, share = (0xC0000000, 0) if writable else (0x80000000, 1)
    if delete:access |= 0x10000
    handle = create(str(Path(path).resolve()), access, share, None, 1 if create_new else 3, 0x80, None)
    if handle == ctypes.c_void_p(-1).value: raise Busy(str(path))
    with os.fdopen(msvcrt.open_osfhandle(handle, os.O_RDWR if writable else os.O_RDONLY),
                   'r+b' if writable else 'rb') as stream:
        yield stream


def remove_held_file(stream):
    """Delete the very file whose identity was checked, without releasing its lease."""
    import msvcrt
    kernel=ctypes.WinDLL('kernel32',use_last_error=True)
    dispose=kernel.SetFileInformationByHandle
    dispose.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p,ctypes.c_uint32]
    dispose.restype=ctypes.c_int
    flag=ctypes.c_int(1) # FILE_DISPOSITION_INFO.DeleteFile
    if not dispose(msvcrt.get_osfhandle(stream.fileno()),4,ctypes.byref(flag),ctypes.sizeof(flag)):
        raise ctypes.WinError(ctypes.get_last_error())


def stable_external_bytes(path):
    with stable_external_stream(path) as stream:return stream.read()


@dataclass(frozen=True)
class Snapshot:
    identity: str
    files: object
    manifest: bytes

    def runtime(self):
        files={name:raw for name,raw in self.files.items()
               if not any(part.startswith('.') for part in PurePosixPath(name).parts)}
        manifest=json.loads(Store.manifest(files));manifest['source_generation']=self.identity
        raw=encoded(manifest)
        return Snapshot(digest(raw),MappingProxyType(files),raw)

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
    def manifest(files, inputs=None):
        result={'version':1,'files':{name:{'sha256':digest(raw),'size':len(raw)} for name,raw in sorted(files.items())}}
        if inputs is not None:
            result['inputs']={name:{'sha256':digest(raw),'size':len(raw),'model':'external_workbook'} for name,raw in sorted(inputs.items())}
        return encoded(result)

    def _capture(self):
        raw = (self.root / MANIFEST).read_bytes()
        manifest = json.loads(raw)
        if manifest.get('version') != 1 or not manifest.get('files'): raise RecoveryRequired('Invalid generation manifest',str(self.root/MANIFEST))
        files = {}
        for name, expected in manifest['files'].items():
            if name in (MANIFEST, JOURNAL, LOCK): raise RecoveryRequired('Invalid generation member',str(self.root/MANIFEST))
            self.member(name)
            payload = self._read(name)
            if expected != {'sha256': digest(payload), 'size': len(payload)}:
                raise RecoveryRequired('Configuration generation mismatch: ' + name,str(self.root/MANIFEST),[str(self.path(name))])
            files[name] = payload
        return Snapshot(digest(raw), MappingProxyType(files), raw)

    def capture(self):
        with exclusive(self.root / LOCK):
            if (self.root/JOURNAL).exists():raise RecoveryRequired('Configuration publication unresolved; run publisher recovery',str(self.root/JOURNAL))
            return self._capture()

    def capture_publication(self, initialize=False):
        """Explicit writer input capture. XLSX sources are not a JSON generation.

        Existing readers still require the published manifest. Only the complete
        publisher may request uninitialized inputs, and must validate before publish.
        """
        with exclusive(self.root / LOCK):
            self._recover()
            if (self.root / MANIFEST).is_file():
                expected = self._capture()
                files = dict(expected.files)
            elif initialize:
                expected = None
                files = {p.relative_to(self.root).as_posix(): p.read_bytes()
                         for folder in ('data', 'config_excel') for p in (self.root/folder).rglob('*.json')}
            else:raise RecoveryRequired('Configuration manifest required; run complete publication first',str(self.root/MANIFEST))
            inputs = {}
            with ExitStack() as leases:
                for path in sorted((self.root/'config_excel').glob('*.xlsx')):
                    if path.name.startswith('~$'):continue
                    self.member(path.relative_to(self.root).as_posix())
                    stream=leases.enter_context(stable_external_stream(path))
                    inputs[path.relative_to(self.root).as_posix()]=stream.read()
            return expected, MappingProxyType(files), MappingProxyType(inputs)

    def _atomic(self, path, raw):
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_name('.' + path.name + '.' + uuid.uuid4().hex + '.tmp')
        try:
            with temp.open('wb') as stream:
                stream.write(raw); stream.flush(); os.fsync(stream.fileno())
            os.replace(temp, path)
        finally: temp.unlink(missing_ok=True)

    def _recover(self):
        try:return self._recover_locked()
        except RecoveryRequired as error:
            if error.recovery_path is None:error.recovery_path=str(self.root/JOURNAL)
            raise

    def _recover_locked(self):
        journal = self.root / JOURNAL
        if not journal.exists(): return
        state = json.loads(journal.read_bytes())
        if state.get('source_conflict'):raise RecoveryRequired('External source conflict retained: '+state['source_conflict'])
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
                with ExitStack() as leases:
                    sources={}
                    # Acquire all source leases first; verify and restore through
                    # those same handles, retained through generation verification.
                    for name,wanted in state.get('source_targets',{}).items():
                        entry=state['originals'][name];target=self.path(name)
                        if not target.exists():
                            if entry is not None:raise RecoveryRequired('Original source is missing: '+name)
                            continue
                        stream=leases.enter_context(stable_external_stream(target,True,delete=entry is None))
                        actual=digest(stream.read());allowed={wanted}
                        if entry is not None:allowed.add(entry['sha256'])
                        if actual not in allowed:raise RecoveryRequired('External source changed or incomplete: '+name)
                        sources[name]=stream
                    for name,entry in state['originals'].items():
                        target=self.path(name)
                        raw=None
                        if entry is not None:
                            raw=(recovery/entry['file']).read_bytes()
                            if digest(raw)!=entry['sha256']:raise RecoveryRequired('Recovery backup mismatch: '+name)
                        if name in sources:
                            stream=sources[name]
                            if entry is None:remove_held_file(stream)
                            else:
                                stream.seek(0);stream.write(raw);stream.truncate();stream.flush();os.fsync(stream.fileno())
                                stream.seek(0)
                                if stream.read()!=raw:raise RecoveryRequired('Source restore readback mismatch: '+name)
                        elif name in state.get('source_targets',{}):
                            continue # Missing newly created target; do not delete a later arrival.
                        elif entry is None:target.unlink(missing_ok=True)
                        else:self._atomic(target,raw)
                    if state['previous'] is not None and self._capture().identity != state['previous']:
                        raise RecoveryRequired('Restored generation cannot be verified')
            except Exception as error:
                state['state']='recovery_required'
                self._atomic(journal,encoded(state))
                raise RecoveryRequired('Configuration recovery retained: '+str(error),str(recovery),
                                       [str(self.path(name)) for name in state.get('source_targets',{})]) from error
        else: raise RecoveryRequired('Unknown configuration transaction state')
        journal.unlink()
        shutil.rmtree(recovery)

    def publish(self, expected, files, validate, *, inputs=None, source_updates=None, initial_files=None, external_inputs=None):
        """Publish a complete candidate; validate must check the whole candidate.

        expected=None is an explicit initial publication. Ordinary capture never
        takes that path. No caller is allowed to publish only a parsed subset.
        """
        files = dict(files)
        check_input_set=inputs is not None
        inputs, source_updates = dict(inputs or {}), dict(source_updates or {})
        for name in (*inputs, *source_updates):
            self.member(name)
            if not name.startswith('config_excel/') or not name.endswith('.xlsx'):
                raise ValueError('External source must be an explicit workbook')
        if set(files) & set(source_updates):raise ValueError('Source inputs cannot also claim published generation membership')
        if not files or any(name in (MANIFEST, JOURNAL, LOCK) for name in files):
            raise ValueError('Empty/reserved configuration member')
        for name, raw in files.items():
            self.member(name)
            if not isinstance(raw, bytes): raise TypeError('Configuration payload must be bytes')
        validate(MappingProxyType(files))  # expensive parsing happens before locking
        manifest_value=json.loads(self.manifest(files, {**inputs, **source_updates} if inputs or source_updates else None))
        if external_inputs is not None:manifest_value["external_inputs"]=external_inputs
        manifest=encoded(manifest_value)
        if expected is not None and not set(expected.files).issubset(files):
            raise ValueError('Publication cannot silently remove generation members')
        recovery = self.root / '.runtime/config-transactions' / uuid.uuid4().hex
        recovery.mkdir(parents=True)
        staged = {}
        source_leases = None
        try:
            # Private candidate preparation, outside the root critical section.
            for index, (name, raw) in enumerate({**files, **source_updates, MANIFEST: manifest}.items()):
                path = recovery / (str(index) + '.new')
                with path.open('wb') as stream:
                    stream.write(raw); stream.flush(); os.fsync(stream.fileno())
                staged[name] = path
            with exclusive(self.root / LOCK):
                self._recover()
                if expected is None:
                    if (self.root / MANIFEST).exists(): raise Stale('Generation already initialized')
                    if initial_files is not None:
                        current={p.relative_to(self.root).as_posix():p.read_bytes() for folder in ('data','config_excel') for p in (self.root/folder).rglob('*.json')}
                        if current!=dict(initial_files):raise Stale('Initial publication inputs changed')
                elif self._capture().identity != expected.identity: raise Stale('Configuration generation changed')
                # Hold every workbook source through publication. Updated existing
                # workbooks are written through their exclusive handle: closing it
                # before rename would reopen an external-editor race.
                if check_input_set:
                    current_sources={p.relative_to(self.root).as_posix() for p in (self.root/'config_excel').glob('*.xlsx') if not p.name.startswith('~$')}
                    if current_sources!=set(inputs):raise Stale('Workbook source membership changed')
                source_leases=ExitStack()
                source_streams={}
                try:
                    for name, raw in inputs.items():
                        stream=source_leases.enter_context(stable_external_stream(self.path(name),name in source_updates))
                        if stream.read()!=raw:raise Stale('Workbook changed: '+name)
                        source_streams[name]=stream
                    for name in source_updates.keys()-inputs.keys():
                        if self.path(name).exists():raise Stale('New workbook already exists: '+name)
                except BaseException:
                    source_leases.close();raise
                # A verified no-op keeps file identities/mtimes; still rechecks the
                # current generation and every held source before returning.
                if expected is not None and manifest==expected.manifest and not source_updates:
                    return expected
                originals = {}
                for index, name in enumerate(staged):
                    target = self.path(name)
                    if target.exists():
                        raw = inputs[name] if name in source_streams else self._read(name)
                        saved = recovery / (str(index) + '.old')
                        with saved.open('wb') as stream:
                            stream.write(raw); stream.flush(); os.fsync(stream.fileno())
                        originals[name] = {'file': saved.name, 'sha256': digest(raw)}
                    else: originals[name] = None
                state = {'version': 1, 'state': 'installing', 'recovery': recovery.relative_to(self.root).as_posix(),
                         'originals': originals, 'previous': expected.identity if expected else None,
                         'generation': digest(manifest),
                         'source_targets':{name:digest(raw) for name,raw in source_updates.items()}}
                self._atomic(self.root / JOURNAL, encoded(state))
                try:
                    for name, source in staged.items():
                        target = self.path(name); target.parent.mkdir(parents=True, exist_ok=True)
                        if name in source_updates and name not in source_streams:
                            try:source_streams[name]=source_leases.enter_context(stable_external_stream(target,True,True))
                            except Busy:
                                state['source_conflict']=name
                                self._atomic(self.root / JOURNAL,encoded(state))
                                raise
                        if name in source_streams and name in source_updates:
                            stream=source_streams[name];stream.seek(0);stream.write(source_updates[name]);stream.truncate();stream.flush();os.fsync(stream.fileno())
                            stream.seek(0)
                            if stream.read()!=source_updates[name]:raise RecoveryRequired('Published workbook mismatch: '+name)
                        else:os.replace(source, target)
                    if self._capture().identity != state['generation']: raise RecoveryRequired('Published generation mismatch')
                    state['state'] = 'committed'
                    self._atomic(self.root / JOURNAL, encoded(state))
                except BaseException:
                    source_leases.close()
                    self._recover()
                    raise
                finally:
                    source_leases.close()
                self._recover()
        finally:
            if source_leases is not None:source_leases.close()
            # Never discard the only recovery evidence for an unresolved journal.
            if not (self.root / JOURNAL).exists() and recovery.exists(): shutil.rmtree(recovery)
        # The committed result belongs to this operation even if another writer
        # publishes immediately after release. Never recapture a different generation.
        return Snapshot(digest(manifest),MappingProxyType(files),manifest)
