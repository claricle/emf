import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from seeds import HERE, validate


class SeedManifestTest(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((HERE / "seeds.json").read_text())

    def test_complete_original_corpus_and_extensions(self):
        self.assertEqual(validate(self.manifest), {
            "original-valid": 208, "original-corrupt": 21, "wmf": 18, "synthetic": 6})

    def test_missing_original_rejected(self):
        del self.manifest["seeds"][0]
        with self.assertRaises(AssertionError):
            validate(self.manifest)

    def test_wrong_checksum_rejected(self):
        self.manifest["seeds"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(AssertionError, "checksum"):
            validate(self.manifest)

    def test_duplicate_and_ineligible_seed_rejected(self):
        duplicate = copy.deepcopy(self.manifest)
        duplicate["seeds"].append(duplicate["seeds"][0])
        with self.assertRaisesRegex(AssertionError, "duplicate"):
            validate(duplicate)
        self.manifest["seeds"][0]["targets"] = ["parse"]
        with self.assertRaises(AssertionError):
            validate(self.manifest)


if __name__ == "__main__":
    unittest.main()
