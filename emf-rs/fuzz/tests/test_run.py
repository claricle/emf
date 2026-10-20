import json
from pathlib import Path
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


if __name__ == '__main__':
    unittest.main()
