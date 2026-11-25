import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[3]


class StableCompilationTest(unittest.TestCase):
    def test_runner_resolves_dependencies_from_exported_libraries(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            build = base / 'build'
            environment = os.environ.copy()
            # Native fuzz checks run before their pinned nightly is installed.
            # This regression needs only the runner's installed default Rust.
            environment.pop('RUSTUP_TOOLCHAIN', None)
            subprocess.run([
                'cargo', 'build', '--manifest-path', str(ROOT / 'emf-rs/Cargo.toml'),
                '--target-dir', str(build), '-p', 'emf-core', '-p', 'emf-ffi',
                '-p', 'dib-model', '-p', 'png-model', '--locked',
            ], check=True, capture_output=True, text=True, env=environment)

            target = base / 'target'
            (target / 'debug/deps').mkdir(parents=True)
            # The direct rustc builds must also find transitive dependencies
            # beside the exported libraries, without Cargo's hashed copies.
            exported = ['libemf_core.rlib', 'libemf_ffi.rlib', 'libdib_model.rlib',
                        'libpng_model.rlib']
            for name in exported:
                shutil.copy2(build / 'debug' / name, target / 'debug' / name)
            # Transitive closure of png-model (zlib codec and its libc):
            # cargo does not materialize unhashed links for non-selected
            # packages, and unit placement varies across cargo versions, so
            # search the fresh build tree and export the newest units under
            # their unhashed names.
            for dependency in ('liblibz_sys', 'liblibc'):
                units = sorted(build.rglob(dependency + '-*.rlib'))
                self.assertTrue(units, dependency + ' unit built')
                shutil.copy2(units[-1], target / 'debug' / (dependency + '.rlib'))

            environment['CARGO_TARGET_DIR'] = str(target)
            script = (ROOT / 'emf-rs/fuzz/check-stable.sh').read_text()
            commands = [line for line in script.replace('\\\n', '').splitlines()
                        if line.startswith('rustc ')]
            self.assertEqual(len(commands), 2)
            for command in commands:
                result = subprocess.run(
                    ['bash', '-c', command], cwd=ROOT, env=environment,
                    capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((target / 'fuzz-corpus-check').is_file())


if __name__ == '__main__':
    unittest.main()
