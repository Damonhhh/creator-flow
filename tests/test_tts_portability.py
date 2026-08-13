import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


REPO_ROOT = Path(__file__).resolve().parents[1]


class PortableRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import sys

        sys.path.insert(0, str(REPO_ROOT / "scripts"))
        import portable_runtime

        cls.runtime = portable_runtime

    def test_cli_directory_wins_over_environment(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            cli_dir = root / "cli"
            env_dir = root / "env"
            cli_dir.mkdir()
            env_dir.mkdir()
            with patch.dict(os.environ, {"INDEXTTS_REPO": str(env_dir)}):
                resolved = self.runtime.resolve_required_directory(
                    str(cli_dir), "INDEXTTS_REPO", "IndexTTS repository"
                )
            self.assertEqual(resolved, cli_dir.resolve())

    def test_environment_is_used_when_cli_is_empty(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            env_dir = Path(temp_dir)
            with patch.dict(os.environ, {"INDEXTTS_REPO": str(env_dir)}):
                resolved = self.runtime.resolve_required_directory(
                    None, "INDEXTTS_REPO", "IndexTTS repository"
                )
            self.assertEqual(resolved, env_dir.resolve())

    def test_missing_required_directory_is_clear(self):
        with patch.dict(os.environ, {}, clear=True):
            with self.assertRaises(ValueError) as context:
                self.runtime.resolve_required_directory(
                    None, "INDEXTTS_REPO", "IndexTTS repository"
                )
        self.assertIn("INDEXTTS_REPO", str(context.exception))

    def test_hf_home_precedes_platform_default(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            cache = Path(temp_dir)
            with patch.dict(os.environ, {"HF_HOME": str(cache)}):
                resolved = self.runtime.resolve_cache_directory(
                    None,
                    "HF_HOME",
                    Path.home() / ".cache" / "huggingface" / "hub",
                )
            self.assertEqual(resolved, cache.resolve())

    def test_target_scripts_use_portable_runtime(self):
        targets = {
            "run-indextts2-batch.py": "resolve_required_directory",
            "run-indextts2-long.py": "resolve_required_directory",
            "rebuild-hyperframes-captions-from-asr.py": "resolve_cache_directory",
        }
        for name, helper in targets.items():
            text = (REPO_ROOT / "scripts" / name).read_text(encoding="utf-8")
            self.assertIn("from portable_runtime import", text)
            self.assertIn(helper, text)


if __name__ == "__main__":
    unittest.main()
