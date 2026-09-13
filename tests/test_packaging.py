"""Checks for the repository tree installed by the marketplace."""
import pathlib
import subprocess
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


class PackagingTests(unittest.TestCase):
    def test_installable_tree_excludes_repository_instructions(self):
        tracked = subprocess.check_output(
            ["git", "ls-files", "--cached", "-z"], cwd=ROOT
        ).decode().split("\0")
        instructions = [
            name for name in tracked
            if pathlib.PurePosixPath(name).name.casefold() == "agents.md"
        ]
        self.assertEqual(instructions, [], "Repository instructions must stay untracked")


if __name__ == "__main__":
    unittest.main()
