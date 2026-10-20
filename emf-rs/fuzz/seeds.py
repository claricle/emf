#!/usr/bin/env python3
"""Validate every referenced seed before optionally materializing a fuzz corpus."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
TARGETS = {"parse", "serialize", "ffi"}


def validate(manifest):
    assert manifest["schema_version"] == 1
    baseline = json.loads((ROOT / "spec/fixtures/manifest.json").read_text())
    originals = {row["path"]: row for row in baseline["fixtures"]}
    assert len(originals) == 229
    seen = set()
    counts = collections.Counter()
    for seed in manifest["seeds"]:
        assert set(seed) == {"path", "sha256", "size_bytes", "provenance", "targets", "kind"}
        path = seed["path"]
        assert path not in seen, f"duplicate path: {path}"
        seen.add(path)
        source = (ROOT / path).resolve()
        assert source.is_relative_to(ROOT), f"escaping path: {path}"
        data = source.read_bytes()
        assert hashlib.sha256(data).hexdigest() == seed["sha256"], f"checksum: {path}"
        assert len(data) == seed["size_bytes"], f"size: {path}"
        assert len(data) <= 8 * 1024 * 1024
        assert seed["provenance"] and set(seed["targets"]) == TARGETS
        assert len(seed["targets"]) == len(TARGETS)
        assert seed["kind"] in {"original-valid", "original-corrupt", "wmf", "synthetic"}
        counts[seed["kind"]] += 1
        if path in originals:
            assert seed["sha256"] == originals[path]["sha256"]
            expected = "original-corrupt" if "/emf-corrupted/" in path else "original-valid"
            assert seed["kind"] == expected
    assert set(originals) <= seen, "original corpus seed missing"
    assert counts["original-valid"] == 208 and counts["original-corrupt"] == 21
    return dict(counts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    manifest = json.loads((HERE / "seeds.json").read_text())
    counts = validate(manifest)
    report = {"manifest_rows": len(manifest["seeds"]), "counts": counts, "targets": {}}
    for target in sorted(TARGETS):
        eligible = [s for s in manifest["seeds"] if target in s["targets"]]
        report["targets"][target] = {"seed_count": len(eligible)}
        if args.corpus:
            output = args.corpus / target
            output.mkdir(parents=True, exist_ok=True)
            for number, seed in enumerate(eligible):
                shutil.copyfile(ROOT / seed["path"], output / f'{number:04d}-{seed["sha256"]}')
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
