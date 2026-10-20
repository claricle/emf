import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import run


class RunReportTest(unittest.TestCase):
    def exercise(self, waits):
        with tempfile.TemporaryDirectory() as directory:
            here = Path(directory)
            (here / 'seeds.json').write_text('{}')
            (here / 'corpus/parse').mkdir(parents=True)
            (here / 'corpus/parse/seed').write_bytes(b'input')
            process = Mock(pid=1234)
            process.wait.side_effect = waits
            with patch.object(run, 'HERE', here), patch.object(run, 'validate', return_value={}), \
                    patch.object(sys, 'argv', ['run.py', 'parse']), \
                    patch.object(run.subprocess, 'check_output', return_value='version'), \
                    patch.object(run.subprocess, 'Popen', return_value=process) as launch, \
                    patch.object(run.os, 'killpg') as kill, patch('builtins.print'):
                with self.assertRaises(SystemExit) as result:
                    run.main()
                report = json.loads((here / 'reports/parse.json').read_text())
            return result.exception.code, report, process, launch, kill

    def test_success_records_budget_seed_and_limits(self):
        code, report, _, launch, kill = self.exercise([0])
        self.assertEqual((code, report['status'], report['seed_count']), (0, 'passed', 1))
        self.assertEqual(report['budget_seconds'], 30)
        self.assertIn('-seed=12345', report['command'])
        self.assertIn('-rss_limit_mb=2048', report['command'])
        self.assertTrue(launch.call_args.kwargs['start_new_session'])
        kill.assert_not_called()

    def test_crash_is_failure(self):
        code, report, _, _, _ = self.exercise([77])
        self.assertEqual((code, report['status'], report['exit_code']), (1, 'failed', 77))

    def test_timeout_kills_and_reaps_never_reports_success(self):
        code, report, process, _, kill = self.exercise([
            subprocess.TimeoutExpired('fuzzer', 90), 0])
        self.assertEqual((code, report['status']), (1, 'wall_timeout'))
        kill.assert_called_once_with(1234, run.signal.SIGKILL)
        self.assertEqual(process.wait.call_count, 2)

    def test_cargo_fuzz_commands_use_emf_rs_workspace_from_any_caller_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            workspace = base / 'emf-rs'
            fuzz = workspace / 'fuzz'
            (fuzz / 'corpus/serialize').mkdir(parents=True)
            (fuzz / 'Cargo.toml').write_text('\n'.join(['[package]', 'name = "fuzz"', '']))
            (fuzz / 'seeds.json').write_text('{}')
            (fuzz / 'corpus/serialize/seed').write_bytes(b'input')
            caller = base / 'caller'
            caller.mkdir()
            bin_dir = base / 'bin'
            bin_dir.mkdir()
            cargo_log = base / 'cargo.log'
            cargo = bin_dir / 'cargo'
            cargo.write_text('\n'.join([
                '#!/bin/sh',
                'if [ ! -f fuzz/Cargo.toml ]; then exit 42; fi',
                'printf "%s\\n" "$*" >> "$CARGO_TEST_LOG"',
                'exit 0',
                '',
            ]))
            cargo.chmod(cargo.stat().st_mode | stat.S_IXUSR)
            rustc = bin_dir / 'rustc'
            rustc.write_text('\n'.join(['#!/bin/sh', 'printf "fake rustc\\n"', '']))
            rustc.chmod(rustc.stat().st_mode | stat.S_IXUSR)

            environment = os.environ.copy()
            environment['PATH'] = f'{bin_dir}:{environment["PATH"]}'
            environment['CARGO_TEST_LOG'] = str(cargo_log)
            old_build = subprocess.run(
                ['cargo', 'fuzz', 'build', '--fuzz-dir', 'emf-rs/fuzz', 'serialize'],
                cwd=caller, env=environment, check=False)
            self.assertEqual(old_build.returncode, 42)
            build = subprocess.run(
                ['cargo', 'fuzz', 'build', '--fuzz-dir', 'fuzz', 'serialize'],
                cwd=workspace, env=environment, check=False)
            self.assertEqual(build.returncode, 0)

            with (patch.object(run, 'HERE', fuzz), patch.object(run, 'WORKSPACE', workspace),
                  patch.object(run, 'validate', return_value={}),
                  patch.object(sys, 'argv', ['run.py', 'serialize']),
                  patch.dict(os.environ, environment, clear=True), patch('builtins.print')):
                previous_cwd = Path.cwd()
                os.chdir(caller)
                try:
                    with self.assertRaises(SystemExit) as result:
                        run.main()
                finally:
                    os.chdir(previous_cwd)
                report = json.loads((fuzz / 'reports/serialize.json').read_text())

            self.assertEqual(result.exception.code, 0)
            self.assertEqual(report['status'], 'passed')
            self.assertEqual(report['command'][3:5], ['--fuzz-dir', 'fuzz'])
            self.assertTrue((fuzz / 'artifacts/serialize').is_dir())
            self.assertIn('fuzz build --fuzz-dir fuzz serialize', cargo_log.read_text())
            self.assertIn('fuzz run --fuzz-dir fuzz serialize', cargo_log.read_text())

            workflow = Path(__file__).resolve().parents[3] / '.github/workflows/native-fuzz.yml'
            self.assertIn('Build instrumented target\n        working-directory: emf-rs\n        run: cargo fuzz build --fuzz-dir fuzz',
                          workflow.read_text())


if __name__ == '__main__':
    unittest.main()
