"""Title-bar lifecycle and window-action regression tests with a fake compositor."""
import argparse
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("titlebars", Path(__file__).parents[1] / "scripts/familiar-titlebars.py")
tb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tb)


class TitlebarsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name) / "titlebars"
        self.directory.mkdir()
        self.config = Path(self.temp.name) / "looknfeel.lua"
        self.original = "-- personal overrides\nhl.config({ decoration = { rounding = 9 } })\n"
        self.config.write_text(self.original)
        self.library = Path(self.temp.name) / "hyprbars.so"
        self.library.touch()
        self.args = argparse.Namespace(operation="apply", owner="200-new", if_owner=False,
                                       style="mac", background="#202020", foreground="#ffffff",
                                       exclude="", library=str(self.library), install_dependency=False, enable=False)
        self.loaded = False
        self.errors = ""
        self.calls = []
        self.reloading_fails = False
        self.load_on_reload = True
        self.mock = patch.object(tb, "hypr", side_effect=self.hypr)
        self.mock.start()
        self.addCleanup(self.mock.stop)

    def hypr(self, *args):
        self.calls.append(args)
        if args == ("-j", "plugin", "list"):
            return json.dumps([{"name": "hyprbars"}] if self.loaded else [])
        if args[:2] == ("plugin", "load"):
            self.loaded = True
        if args[:2] == ("plugin", "unload"):
            self.loaded = False
        if args == ("reload",):
            if self.reloading_fails:
                return "error: reload rejected"
            content = (self.directory / "titlebars.lua").read_text()
            self.loaded = "hl.plugin.load" in content and self.load_on_reload
        if args == ("configerrors",):
            return self.errors
        return "ok"

    def setup(self):
        return tb.setup(self.args, self.directory, self.config)

    def reconcile(self):
        return tb.reconcile(self.args, self.directory, self.config)

    def test_missing_dependency_requires_setup_without_touching_personal_config(self):
        self.assertEqual(self.reconcile()["state"], "setup-required")
        self.assertEqual(self.config.read_text(), self.original)

    def test_setup_is_idempotent_and_removable_with_personal_overrides_preserved(self):
        self.setup()
        self.setup()
        text = self.config.read_text()
        self.assertEqual(text.count(tb.BEGIN), 1)
        self.assertEqual(tb.strip_hook(text).rstrip(), self.original.rstrip())
        self.assertFalse(self.loaded)

    def test_existing_hyprbars_is_not_adopted(self):
        self.loaded = True
        with self.assertRaisesRegex(tb.Failure, "already in use"):
            self.setup()
        self.assertFalse((self.directory / "owner.json").exists())
        self.assertEqual(self.config.read_text(), self.original)

    def test_enable_theme_update_disable_and_reload_are_idempotent(self):
        self.setup()
        self.assertEqual(self.reconcile()["state"], "active")
        self.calls.clear()
        self.reconcile()
        self.assertNotIn(("reload",), self.calls)
        self.args.background = "#123456"
        self.reconcile()
        self.assertIn("rgb(123456)", (self.directory / "titlebars.lua").read_text())
        self.args.operation = "disable"
        self.assertEqual(self.reconcile()["state"], "off")
        self.assertFalse(self.loaded)

    def test_old_teardown_and_late_apply_cannot_overwrite_new_instance(self):
        self.setup()
        self.reconcile()
        active = (self.directory / "titlebars.lua").read_text()
        self.args.owner = "100-old"
        self.args.operation = "disable"
        self.args.if_owner = True
        self.reconcile()
        self.assertEqual((self.directory / "titlebars.lua").read_text(), active)
        self.args.operation = "apply"
        self.args.if_owner = False
        self.args.style = "windows"
        self.reconcile()
        self.assertEqual((self.directory / "titlebars.lua").read_text(), active)

    def test_a_new_instance_can_disable_a_previous_sessions_controls(self):
        self.setup()
        self.reconcile()
        self.args.owner = "300-restart"
        self.args.operation = "disable"
        self.assertEqual(self.reconcile()["state"], "off")
        self.assertFalse(self.loaded)

    def test_configuration_error_fails_closed(self):
        self.setup()
        self.errors = "invalid window rule"
        with self.assertRaisesRegex(tb.Failure, "invalid window rule"):
            self.reconcile()
        self.assertNotIn("hl.plugin.load", (self.directory / "titlebars.lua").read_text())
        self.assertFalse(self.loaded)

    def test_binary_mismatch_does_not_leave_active_configuration(self):
        self.setup()
        self.load_on_reload = False
        with self.assertRaisesRegex(tb.Failure, "did not load"):
            self.reconcile()
        self.assertNotIn("hl.plugin.load", (self.directory / "titlebars.lua").read_text())

    def test_failed_reload_does_not_persist_active_configuration(self):
        self.setup()
        self.reloading_fails = True
        with self.assertRaises(tb.Failure):
            self.reconcile()
        self.assertNotIn("hl.plugin.load", (self.directory / "titlebars.lua").read_text())

    def test_broken_markers_are_never_rewritten(self):
        self.config.write_text(self.original + tb.BEGIN + "\n")
        with self.assertRaisesRegex(tb.Failure, "markers"):
            self.setup()
        self.assertEqual(self.config.read_text(), self.original + tb.BEGIN + "\n")

    def test_theme_input_cannot_inject_lua(self):
        with self.assertRaises(tb.Failure):
            tb.render(self.library, "mac", '#ffffff); os.execute("bad")', "#ffffff", [])
        text = tb.render(Path("a ' quoted path/hyprbars.so"), "mac", "#123456", "#ffffff", ['org.app+name', 'a"; os.execute("bad")'])
        self.assertIn('class = "^(org\\\\.app\\\\+name)$"', text)
        self.assertIn('a\\";', text)

    def test_styles_change_order_and_alignment(self):
        mac = tb.render(self.library, "mac", "#202020", "#ffffff", [])
        win = tb.render(self.library, "windows", "#202020", "#ffffff", [])
        self.assertIn('bar_buttons_alignment = "left"', mac)
        self.assertIn('bar_buttons_alignment = "right"', win)
        # Compare rendered argv actions rather than text labels.
        self.assertLess(mac.index('action minimize'), mac.index('action maximize', mac.index('add_button')))
        self.assertLess(win.index('action maximize', win.index('add_button')), win.index('action minimize'))

    def test_minimise_reuses_dock_helper_with_an_explicit_address(self):
        with patch.object(tb, "hypr", return_value='{"address":"0xABC"}'), patch.object(tb, "run") as run:
            tb.window_action("minimize")
            self.assertEqual(run.call_args.args[0][-2:], ["minimize-instance", "0xABC"])

    def test_close_and_maximise_do_not_use_an_unqualified_active_dispatch(self):
        for action in ("close", "maximize"):
            with patch.object(tb, "hypr", return_value='{"address":"0xABC"}'), patch.object(tb, "checked") as checked:
                tb.window_action(action)
                self.assertIn('address:0xABC', checked.call_args.args[1])

    def test_invalid_address_cannot_become_a_command(self):
        with patch.object(tb, "hypr", return_value='{"address":"0xA; bad"}'), patch.object(tb, "run") as run:
            with self.assertRaises(tb.Failure):
                tb.window_action("minimize")
            run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
