import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "scripts" / "workflow_config.py"


def load_module():
    if not MODULE_PATH.is_file():
        raise FileNotFoundError(f"Missing {MODULE_PATH}")
    spec = importlib.util.spec_from_file_location("workflow_config", MODULE_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class WorkflowConfigTests(unittest.TestCase):
    def setUp(self):
        self.module = load_module()
        self.temp = tempfile.TemporaryDirectory(prefix="zimeiti-python-config-test-")
        self.root = Path(self.temp.name)
        (self.root / "config").mkdir()
        (self.root / "config" / "workflow.example.json").write_text(
            json.dumps({"mode": "example"}), encoding="utf-8"
        )
        (self.root / "config" / "workflow.local.json").write_text(
            json.dumps(
                {
                    "mode": "local",
                    "nested": {"required": "present"},
                    "secret": "do-not-print-this-value",
                }
            ),
            encoding="utf-8",
        )
        self.explicit = self.root / "explicit.json"
        self.explicit.write_text(
            json.dumps({"mode": "explicit", "nested": {"required": "present"}}),
            encoding="utf-8",
        )

    def tearDown(self):
        self.temp.cleanup()

    def test_local_config_is_default(self):
        config = self.module.load_workflow_config(
            self.root, "workflow", required_keys=("nested.required",)
        )
        self.assertEqual(config["mode"], "local")

    def test_explicit_config_wins(self):
        config = self.module.load_workflow_config(
            self.root,
            "workflow",
            explicit_path=self.explicit,
            required_keys=("nested.required",),
        )
        self.assertEqual(config["mode"], "explicit")

    def test_example_is_not_a_runtime_fallback(self):
        (self.root / "config" / "workflow.local.json").unlink()
        with self.assertRaises(FileNotFoundError) as context:
            self.module.load_workflow_config(self.root, "workflow")
        message = str(context.exception)
        self.assertIn("workflow.example.json", message)
        self.assertNotIn("do-not-print-this-value", message)

    def test_required_key_error_does_not_leak_config(self):
        (self.root / "config" / "workflow.local.json").write_text(
            json.dumps({"secret": "do-not-print-this-value"}), encoding="utf-8"
        )
        with self.assertRaises(ValueError) as context:
            self.module.load_workflow_config(
                self.root, "workflow", required_keys=("nested.required",)
            )
        message = str(context.exception)
        self.assertIn("nested.required", message)
        self.assertNotIn("do-not-print-this-value", message)

    def test_relative_path_resolves_from_repo_root(self):
        resolved = self.module.resolve_config_path(self.root, "assets/voice.wav")
        self.assertEqual(resolved, (self.root / "assets" / "voice.wav").resolve())


if __name__ == "__main__":
    unittest.main()
