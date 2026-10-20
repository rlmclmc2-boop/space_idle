import hashlib
import importlib.util
import json
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / 'tools' / 'play_main.py'
spec = importlib.util.spec_from_file_location('player_entry', SCRIPT)
entry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(entry)
ENGINE_VERSION = '4.7.2.stable.official.ed1daf0bf'
SOURCE_PATH = 'space-battleship/addons/native_battle/src/space_native.cpp'


class PlayerEntry(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.project = self.root / 'space-battleship'
        self.source = self.root / SOURCE_PATH
        self.evidence_csv = self.project / 'evidence' / 'sample' / 'labels.csv'
        self.bundle = self.root / entry.BUNDLED_DLL
        self.inventory = self.root / entry.NATIVE_INVENTORY
        self.installed = self.project / 'bin' / 'space_native.dll'
        self.engine = self.project / 'engine' / 'Godot_v4.7.2-stable_win64.exe'
        self.launcher = self.root / entry.ENTRY_CMD
        for path in (self.source, self.evidence_csv, self.bundle, self.inventory, self.installed, self.engine,
                     self.project / 'scripts' / 'game.gd', self.root / 'tools' / 'play_main.py',
                     self.launcher):
            path.parent.mkdir(parents=True, exist_ok=True)
        self.source.write_text('native v1', encoding='utf-8')
        self.evidence_csv.write_text('keys,en\nlabel,Label\n', encoding='utf-8')
        self.bundle.write_bytes(b'accepted DLL')
        self.installed.write_bytes(self.bundle.read_bytes())
        self.engine.write_bytes(b'engine')
        (self.project / 'space_native.gdextension').write_text(entry.DESCRIPTOR, encoding='utf-8')
        (self.project / 'scripts' / 'game.gd').write_text('game v1', encoding='utf-8')
        (self.root / 'tools' / 'play_main.py').write_text('entry v1', encoding='utf-8')
        self.launcher.write_text('launch v1', encoding='utf-8')
        (self.root / '.gitignore').write_text('space-battleship/bin/\nspace-battleship/engine/\n'
                                              'space-battleship/space_native.gdextension\n'
                                              'space-battleship/.runtime/\n', encoding='utf-8')
        self.git('init', '-q', '-b', 'main')
        self.git('config', 'user.name', 'Player Entry Test')
        self.git('config', 'user.email', 'player-entry@example.invalid')
        self.git('remote', 'add', 'origin', 'https://github.com/rlmclmc2-boop/space_idle.git')
        self.write_inventory()
        self.commit()
        self.accept_main()
        root_patch = patch.object(entry, 'ROOT', self.root)
        root_patch.start()
        self.addCleanup(root_patch.stop)
        original_run = entry.run

        def run_with_fake_engine(args, cwd, env=None):
            if args == [str(self.engine), '--version']:
                return ENGINE_VERSION
            return original_run(args, cwd, env)

        run_patch = patch.object(entry, 'run', side_effect=run_with_fake_engine)
        run_patch.start()
        self.addCleanup(run_patch.stop)

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, check=True,
                              capture_output=True, text=True, encoding='utf-8').stdout.strip()

    def write_inventory(self):
        sha = hashlib.sha256(self.bundle.read_bytes()).hexdigest()
        source_blob = self.git('hash-object', SOURCE_PATH)
        data = {'dll': {'runtime_path': 'space-battleship/bin/space_native.dll',
                        'runtime_sha256': sha,
                        'bundled_path': entry.BUNDLED_DLL.as_posix(),
                        'bundled_sha256': sha},
                'sources': [{'repository_path': SOURCE_PATH, 'repository_git_blob': source_blob}],
                'acceptance': {'engine': ENGINE_VERSION}}
        self.inventory.write_text(json.dumps(data), encoding='utf-8')

    def commit(self):
        self.git('add', '-A')
        self.git('commit', '-qm', 'accepted main update')
        return self.git('rev-parse', 'HEAD')

    def accept_main(self):
        self.git('update-ref', 'refs/remotes/origin/main', self.git('rev-parse', 'HEAD'))

    def test_current_fetched_main_starts(self):
        self.assertEqual(entry.validate(self.root)[0], self.project)

    def test_normal_main_update_needs_no_launcher_edit(self):
        (self.project / 'scripts' / 'game.gd').write_text('game v2', encoding='utf-8')
        self.commit()
        self.accept_main()
        self.assertEqual(entry.validate(self.root)[0], self.project)

    def test_local_commit_ahead_of_fetched_main_is_rejected(self):
        (self.project / 'scripts' / 'game.gd').write_text('local unreviewed', encoding='utf-8')
        self.commit()
        with self.assertRaisesRegex(RuntimeError, 'differs from fetched origin/main'):
            entry.validate(self.root)

    def test_dirty_runtime_and_launcher_are_rejected(self):
        for path in (self.project / 'scripts' / 'game.gd', self.root / 'tools' / 'play_main.py',
                     self.launcher):
            with self.subTest(path=path):
                original = path.read_bytes()
                path.write_bytes(b'local edit')
                with self.assertRaisesRegex(RuntimeError, 'Unreviewed local runtime changes'):
                    entry.validate(self.root)
                path.write_bytes(original)

    def test_untracked_runtime_script_is_rejected(self):
        extra = self.project / 'scripts' / 'unexpected.gd'
        extra.write_text('unreviewed', encoding='utf-8')
        with self.assertRaisesRegex(RuntimeError, 'Unreviewed local runtime changes'):
            entry.validate(self.root)

    def test_generated_csv_translations_do_not_break_second_launch(self):
        generated = self.evidence_csv.with_name('labels.en.translation')
        generated.write_bytes(b'Godot generated')
        self.assertEqual(entry.validate(self.root)[0], self.project)
        unrelated = self.evidence_csv.with_name('unexpected.translation')
        unrelated.write_bytes(b'unreviewed')
        with self.assertRaisesRegex(RuntimeError, 'Unreviewed local runtime changes'):
            entry.validate(self.root)

    def test_wrong_branch_or_origin_is_rejected(self):
        self.git('switch', '-q', '-c', 'candidate')
        with self.assertRaisesRegex(RuntimeError, 'requires main'):
            entry.validate(self.root)
        self.git('switch', '-q', 'main')
        self.git('remote', 'set-url', 'origin', str(self.root))
        with self.assertRaisesRegex(RuntimeError, 'origin remote is not'):
            entry.validate(self.root)

    def test_native_source_change_requires_matching_inventory(self):
        self.source.write_text('native v2', encoding='utf-8')
        self.commit()
        self.accept_main()
        with self.assertRaisesRegex(RuntimeError, 'Native source changed'):
            entry.validate(self.root)

    def test_new_native_source_requires_inventory_entry(self):
        extra = self.source.parent / 'new_native.h'
        extra.write_text('new native source', encoding='utf-8')
        self.commit()
        self.accept_main()
        with self.assertRaisesRegex(RuntimeError, 'does not cover'):
            entry.validate(self.root)

    def test_native_bundle_change_requires_matching_inventory(self):
        self.bundle.write_bytes(b'different DLL')
        self.commit()
        self.accept_main()
        with self.assertRaisesRegex(RuntimeError, 'Bundled native DLL'):
            entry.validate(self.root)

    def test_reviewed_native_update_uses_new_hash(self):
        self.source.write_text('native v2', encoding='utf-8')
        self.bundle.write_bytes(b'new accepted DLL')
        self.installed.write_bytes(self.bundle.read_bytes())
        self.write_inventory()
        self.commit()
        self.accept_main()
        self.assertEqual(entry.validate(self.root)[0], self.project)

    def test_installed_dll_and_engine_must_match(self):
        self.installed.write_bytes(b'wrong DLL')
        with self.assertRaises(RuntimeError):
            entry.validate(self.root)
        self.installed.write_bytes(self.bundle.read_bytes())
        self.engine.unlink()
        with self.assertRaises(RuntimeError):
            entry.validate(self.root)

    def test_explicit_install_backs_up_old_dll(self):
        self.installed.write_bytes(b'old DLL')
        entry.install_native(self.root)
        self.assertEqual(self.installed.read_bytes(), self.bundle.read_bytes())
        old_sha = hashlib.sha256(b'old DLL').hexdigest()
        backup = self.project / '.runtime' / 'native-backup' / ('space_native-' + old_sha + '.dll')
        self.assertEqual(backup.read_bytes(), b'old DLL')

    def test_dirty_checkout_gets_clean_mirror_without_losing_edit(self):
        game = self.project / 'scripts' / 'game.gd'
        game.write_text('personal work', encoding='utf-8')
        head = self.git('rev-parse', 'HEAD')
        mirror = entry.prepare_clean_mirror(self.root, head)
        self.assertEqual(game.read_text(encoding='utf-8'), 'personal work')
        self.assertEqual((mirror / 'space-battleship/scripts/game.gd').read_text(encoding='utf-8'), 'game v1')
        self.assertEqual(entry.run(['git', 'branch', '--show-current'], mirror), 'main')
        self.assertEqual(entry.run(['git', 'rev-parse', 'refs/remotes/origin/main'], mirror), head)

        launcher = self.root / 'tools' / 'play_main.py'
        launcher.write_text('accepted launcher v2', encoding='utf-8')
        self.git('add', '--', 'tools/play_main.py')
        self.git('commit', '-qm', 'next accepted main')
        self.accept_main()
        updated = entry.prepare_clean_mirror(self.root, self.git('rev-parse', 'HEAD'))
        self.assertEqual(updated, mirror)
        self.assertEqual((mirror / 'tools/play_main.py').read_text(encoding='utf-8'), 'accepted launcher v2')
        self.assertEqual(game.read_text(encoding='utf-8'), 'personal work')

        (mirror / 'tools/play_main.py').write_text('unexpected mirror edit', encoding='utf-8')
        launcher.write_text('accepted launcher v3', encoding='utf-8')
        self.git('add', '--', 'tools/play_main.py')
        self.git('commit', '-qm', 'another accepted main')
        self.accept_main()
        with self.assertRaisesRegex(RuntimeError, 'non-generated local edits'):
            entry.prepare_clean_mirror(self.root, self.git('rev-parse', 'HEAD'))

    def test_missing_engine_downloads_verified_official_archive(self):
        self.engine.unlink()
        source_zip = self.root / 'official-fixture.zip'
        with zipfile.ZipFile(source_zip, 'w') as archive:
            archive.writestr(entry.ENGINE_NAME, b'fresh engine')
            archive.writestr(entry.ENGINE_NAME.replace('.exe', '_console.exe'), b'console')
        archive_sha = hashlib.sha256(source_zip.read_bytes()).hexdigest()
        exe_sha = hashlib.sha256(b'fresh engine').hexdigest()
        with patch.object(entry, 'ENGINE_URL', source_zip.as_uri()), \
             patch.object(entry, 'ENGINE_ARCHIVE_SHA256', archive_sha), \
             patch.object(entry, 'ENGINE_EXE_SHA256', exe_sha):
            self.assertEqual(entry.prepare_engine(self.root), self.engine)
            self.assertEqual(self.engine.read_bytes(), b'fresh engine')
            self.assertEqual(entry.prepare_engine(self.root), self.engine)

    def test_initial_import_access_violation_retries_once_and_keeps_log(self):
        runtime = self.root / 'import-runtime'
        runtime.mkdir()
        outcomes = iter([3221225477, 0])
        def fake_run(args, **kwargs):
            code = next(outcomes)
            kwargs['stdout'].write('attempt ' + str(code))
            return subprocess.CompletedProcess(args, code)
        with patch.object(entry.subprocess, 'run', side_effect=fake_run) as mocked:
            entry.import_project(self.engine, self.project, runtime, {})
        self.assertEqual(mocked.call_count, 2)
        self.assertEqual((runtime / 'player-import-first-attempt.log').read_text(), 'attempt 3221225477')
        self.assertEqual((runtime / 'player-import.log').read_text(), 'attempt 0')


class RepositoryInventory(unittest.TestCase):
    def test_committed_bundle_and_native_sources_match_inventory(self):
        root = SCRIPT.parents[1]
        inventory = json.loads((root / entry.NATIVE_INVENTORY).read_text(encoding='utf-8'))
        self.assertEqual(entry.digest(root / entry.BUNDLED_DLL), inventory['dll']['bundled_sha256'])
        for source in inventory['sources']:
            actual = subprocess.run(['git', 'rev-parse', 'HEAD:' + source['repository_path']],
                                    cwd=root, check=True, capture_output=True, text=True).stdout.strip()
            self.assertEqual(actual, source['repository_git_blob'])


if __name__ == '__main__':
    unittest.main()
