"""Six process-level acceptance examples for the audit gate."""

import sys
import unittest

from gate import run


MARKER = "S01_COMPLETE:fixture"
DECLARED = "SCRIPT ERROR: deliberate fixture fault"
OTHER = "SCRIPT ERROR: unrelated fault"


def sample(body, expected=(), timeout=2):
    return run([sys.executable, "-c", body], MARKER, timeout, expected)[1]


class GateAcceptance(unittest.TestCase):
    def test_legitimate_success(self):
        self.assertEqual([], sample(f"print('{MARKER}')"))

    def test_nonzero_exit(self):
        self.assertTrue(any("exit code 7" in reason for reason in
                            sample(f"print('{MARKER}'); raise SystemExit(7)")))

    def test_timeout(self):
        self.assertTrue(any("exit code 124" in reason for reason in
                            sample("import time; time.sleep(2)", timeout=0.25)))

    def test_missing_completion(self):
        self.assertTrue(any("completion marker count 0" in reason for reason in
                            sample("print('work stopped early')")))

    def test_script_error_with_zero_exit(self):
        self.assertTrue(any("unexpected diagnostic" in reason for reason in
                            sample(f"print('{OTHER}'); print('{MARKER}')")))

    def test_exact_expected_error_cannot_hide_another(self):
        self.assertEqual([], sample(f"print('{DECLARED}'); print('{MARKER}')",
                                    expected=(DECLARED,)))
        self.assertTrue(any(OTHER in reason for reason in
                            sample(f"print('{DECLARED}'); print('{OTHER}'); print('{MARKER}')",
                                   expected=(DECLARED,))))
        self.assertTrue(any("missing declared diagnostic" in reason for reason in
                            sample(f"print('{MARKER}')", expected=(DECLARED,))))


if __name__ == "__main__":
    unittest.main(verbosity=2)
