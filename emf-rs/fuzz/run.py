#!/usr/bin/env python3
"""Run one bounded libFuzzer job, retaining provenance and failure artifacts."""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import time

from seeds import HERE, TARGETS, validate

WORKSPACE = HERE.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=sorted(TARGETS))
    parser.add_argument("--seconds", type=int, choices=(30, 1800), default=30)
    args = parser.parse_args()
    counts = validate(json.loads((HERE / "seeds.json").read_text()))
    reports = HERE / "reports"
    reports.mkdir(exist_ok=True)
    artifacts = HERE / "artifacts" / args.target
    artifacts.mkdir(parents=True, exist_ok=True)
    corpus = HERE / "corpus" / args.target
    assert corpus.is_dir(), "materialize corpus with seeds.py first"
    command = ["cargo", "fuzz", "run", "--fuzz-dir", "fuzz", args.target,
               str(corpus), "--", "-seed=12345", f"-max_total_time={args.seconds}",
               "-max_len=8388608", "-rss_limit_mb=2048", "-malloc_limit_mb=512",
               "-timeout=10", f"-artifact_prefix={artifacts}/", "-print_final_stats=1"]
    report = {"target": args.target, "seed": 12345, "budget_seconds": args.seconds,
              "seed_count": len(list(corpus.iterdir())), "manifest_counts": counts,
              "rss_limit_mb": 2048, "malloc_limit_mb": 512, "input_limit_bytes": 8388608,
              "command": command, "toolchain": {}, "status": "starting"}
    start = time.monotonic()
    exit_code = 1
    try:
        for label, cmd in {"rustc": ["rustc", "-Vv"], "cargo": ["cargo", "-V"],
                           "cargo_fuzz": ["cargo", "fuzz", "--version"]}.items():
            report["toolchain"][label] = subprocess.check_output(
                cmd, text=True, timeout=15, cwd=WORKSPACE).strip()
        with (reports / f"{args.target}.log").open("w") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=True, cwd=WORKSPACE)
            try:
                exit_code = process.wait(timeout=args.seconds + 60)
                report["status"] = "passed" if exit_code == 0 else "failed"
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
                report["status"] = "wall_timeout"
    except Exception as error:
        report["status"] = "execution_error"
        report["error"] = str(error)
    finally:
        report["exit_code"] = exit_code
        report["elapsed_seconds"] = round(time.monotonic() - start, 3)
        (reports / f"{args.target}.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, sort_keys=True))
    raise SystemExit(0 if report["status"] == "passed" else 1)


if __name__ == "__main__":
    main()
