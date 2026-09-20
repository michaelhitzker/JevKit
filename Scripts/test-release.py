#!/usr/bin/env python3
"""Exercise changelog generation against isolated Git histories."""
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("generate-changelog.py").resolve()


class ReleaseTests(unittest.TestCase):
    def test_release_history(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def git(*args):
                return subprocess.run(["git", *args], cwd=root, check=True,
                                      capture_output=True, text=True)

            def generate(version, succeeds=True):
                result = subprocess.run(
                    ["python3", str(SCRIPT), version, "--notes", "notes.md"],
                    cwd=root, capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, succeeds, result.stderr)
                return (root / "CHANGELOG.md").read_text()

            git("init")
            git("config", "user.name", "Test")
            git("config", "user.email", "test@example.invalid")
            git("commit", "--allow-empty", "-m", "Initial implementation")
            first = generate("0.1.0")
            self.assertIn("Initial implementation", first)
            self.assertEqual(first, "# Changelog\n\n" + (root / "notes.md").read_text())
            git("add", "CHANGELOG.md")
            git("commit", "-m", "chore(release): 0.1.0")
            git("tag", "0.1.0")
            git("commit", "--allow-empty", "-m", "Add feature")
            second = generate("0.2.0")
            notes = (root / "notes.md").read_text()
            self.assertIn("Add feature", notes)
            self.assertNotIn("Initial implementation", notes)
            self.assertNotIn("chore(release)", second)
            self.assertEqual(second.count("Initial implementation"), 1)
            self.assertLess(second.index("## 0.2.0"), second.index("## 0.1.0"))
            generate("0.1.0", succeeds=False)
            generate("0.0.9", succeeds=False)
            generate("v0.2.0", succeeds=False)
            self.assertEqual((root / "CHANGELOG.md").read_text(), second)


if __name__ == "__main__":
    unittest.main()
