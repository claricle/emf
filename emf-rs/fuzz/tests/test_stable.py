"""The stable gate replays the seed corpus end to end on the default toolchain."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


class StableGateTest(unittest.TestCase):
    def test_stable_gate_replays_corpus_end_to_end(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = os.environ.copy()
            # Native fuzz checks run before their pinned nightly is installed.
            # This regression needs only the runner's installed default Rust.
            environment.pop('RUSTUP_TOOLCHAIN', None)
            environment['CARGO_TARGET_DIR'] = str(Path(directory) / 'target')
            result = subprocess.run(
                ['bash', 'emf-rs/fuzz/check-stable.sh'],
                cwd=ROOT, env=environment, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr[-4000:])
            self.assertIn('test result: ok. 1 passed', result.stdout)


if __name__ == '__main__':
    unittest.main()
