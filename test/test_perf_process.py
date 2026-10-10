"""Windows performance launch cleanup, including descendants after leader exit."""
import ctypes
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest

from whole_game_perf import run_guarded


@unittest.skipUnless(os.name == 'nt', 'Windows job ownership')
class Cleanup(unittest.TestCase):
    def test_owned_descendants(self):
        area = Path(tempfile.mkdtemp(prefix='perf-cleanup-', dir=Path(__file__).parent / 'work'))
        api = ctypes.WinDLL('kernel32', use_last_error=True)
        api.OpenProcess.argtypes = [ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
        api.OpenProcess.restype = ctypes.c_void_p
        api.GetExitCodeProcess.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_ulong)]
        api.CloseHandle.argtypes = [ctypes.c_void_p]
        for mode in ('normal', 'error', 'timeout'):
            with self.subTest(mode=mode):
                pid_file = area / (mode + '.pid')
                action = {'normal': 'sys.exit(0)',
                          'error': "print('SCRIPT ERROR cleanup test',flush=True);time.sleep(90)",
                          'timeout': 'time.sleep(90)'}[mode]
                code = ("import subprocess,sys,time;from pathlib import Path;"
                        "child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(90)']);"
                        f"Path({str(pid_file)!r}).write_text(str(child.pid));time.sleep(.5);{action}")
                result = run_guarded([sys.executable, '-c', code], os.environ.copy(),
                                     area / (mode + '.log'), timeout=2)
                self.assertEqual(result, 0 if mode == 'normal' else 1)
                time.sleep(.2)
                handle = api.OpenProcess(0x1000, False, int(pid_file.read_text()))
                try:
                    if handle:
                        status = ctypes.c_ulong()
                        self.assertTrue(api.GetExitCodeProcess(handle, ctypes.byref(status)))
                        self.assertNotEqual(status.value, 259, 'Owned child is still running')
                finally:
                    if handle:
                        api.CloseHandle(handle)


if __name__ == '__main__':
    unittest.main()
