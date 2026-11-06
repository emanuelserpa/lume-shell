import unittest
from subprocess import CompletedProcess
from unittest.mock import patch

from helpers import import_script


projection = import_script("display_projection", "display-projection.py")


class DisplayProjectionTests(unittest.TestCase):
    def setUp(self):
        self.monitors = [
            {
                "name": "eDP-1",
                "description": "Built-in Display",
                "width": 1920,
                "height": 1080,
                "refreshRate": 60.05,
                "scale": 1.2,
                "x": 0,
                "y": 0,
                "transform": 0,
                "vrr": 0,
                "disabled": False,
                "focused": True,
            },
            {
                "name": "HDMI-A-1",
                "description": "External Monitor",
                "width": 1440,
                "height": 900,
                "refreshRate": 75.89,
                "scale": 1,
                "x": 1600,
                "y": 0,
                "transform": 0,
                "vrr": 0,
                "disabled": False,
            },
        ]
        self.baseline = [projection.baseline_entry(item) for item in self.monitors]

    def test_status_offers_windows_projection_modes_for_two_displays(self):
        options = projection.mode_options(self.monitors, "extend")
        self.assertEqual(
            [item["id"] for item in options],
            ["computer", "duplicate", "extend", "external"],
        )
        self.assertTrue(options[2]["selected"])

    def test_single_display_does_not_offer_duplicate_or_external_only(self):
        options = projection.mode_options(self.monitors[:1], "computer")
        self.assertEqual([item["id"] for item in options], ["computer", "extend"])

    def test_computer_only_preserves_internal_and_disables_external(self):
        plan = projection.build_plan("computer", self.monitors, self.baseline)
        self.assertEqual(plan[0]["output"], "eDP-1")
        self.assertEqual(plan[1], {"output": "HDMI-A-1", "disabled": True})

    def test_external_only_preserves_external_and_disables_internal(self):
        plan = projection.build_plan("external", self.monitors, self.baseline)
        self.assertEqual(plan[0]["output"], "HDMI-A-1")
        self.assertEqual(plan[1], {"output": "eDP-1", "disabled": True})

    def test_switching_back_to_disabled_output_uses_saved_good_mode(self):
        monitors = [dict(item) for item in self.monitors]
        monitors[0].update({"disabled": True, "width": 0, "height": 0, "x": 0, "y": 0})
        plan = projection.build_plan("computer", monitors, self.baseline)
        self.assertEqual(plan[0], self.baseline[0])
        self.assertEqual(plan[0]["mode"], "1920x1080@60.05")

    def test_duplicate_mirrors_each_non_source_monitor_to_internal_panel(self):
        plan = projection.build_plan("duplicate", self.monitors, self.baseline)
        self.assertEqual(plan[0]["output"], "eDP-1")
        self.assertEqual(plan[1]["mirror"], "eDP-1")
        self.assertEqual(plan[1]["output"], "HDMI-A-1")

    def test_projection_modes_preserve_configured_icc_profile(self):
        configured = {"eDP-1": {"icc": "/color/panel.icm"}}
        plan = projection.build_plan("computer", self.monitors, self.baseline, configured)
        self.assertEqual(plan[0]["icc"], "/color/panel.icm")

    def test_extend_uses_configured_vrr_policy_not_live_boolean(self):
        saved = {"output": "HDMI-A-1", "mode": "1440x900@59.89", "vrr": False}
        self.assertEqual(
            projection.merge_configured_monitor(saved, None),
            {"output": "HDMI-A-1", "mode": "1440x900@59.89"},
        )
        self.assertEqual(
            projection.merge_configured_monitor(saved, {"vrr": 0})["vrr"],
            0,
        )

    def test_configured_monitor_properties_reads_output_icc_pair(self):
        source = '''
        hl.monitor({
            output = "eDP-1",
            scale = 1,
            vrr = 0,
            icc = "/color/panel.icm",
        })
        '''
        self.assertEqual(
            projection.configured_monitor_properties(source),
            {
                "eDP-1": {
                    "output": "eDP-1",
                    "scale": 1,
                    "vrr": 0,
                    "icc": "/color/panel.icm",
                },
            },
        )

    def test_extend_restores_captured_modes_positions_scale_and_disabled_state(self):
        plan = projection.build_plan("extend", self.monitors, self.baseline)
        self.assertEqual(plan, self.baseline)
        self.assertEqual(plan[0]["position"], "0x0")
        self.assertEqual(plan[0]["scale"], 1.2)
        self.assertEqual(plan[1]["position"], "1600x0")

    def test_mode_inference_recognizes_duplicate_and_single_output(self):
        mirrored = [dict(item) for item in self.monitors]
        mirrored[1]["mirrorOf"] = "eDP-1"
        self.assertEqual(projection.active_mode(mirrored), "duplicate")
        self.assertEqual(projection.active_mode([self.monitors[0]]), "computer")

    def test_mode_inference_treats_hyprland_none_mirror_sentinel_as_extended(self):
        monitors = [dict(item, mirrorOf="none") for item in self.monitors]
        self.assertEqual(projection.active_mode(monitors), "extend")

    def test_lua_command_escapes_untrusted_monitor_names(self):
        command = projection.lua_monitor_command({
            "output": 'HDMI-1", disabled = true, output = "x',
            "disabled": True,
        })
        self.assertEqual(
            command,
            'hl.monitor({ output = "HDMI-1\\", disabled = true, output = \\"x", disabled = true })',
        )

    def test_unknown_projection_mode_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "desconhecido"):
            projection.build_plan("all-off", self.monitors, self.baseline)

    def test_apply_detects_hyprctl_eval_errors_even_with_zero_exit_status(self):
        replies = [
            CompletedProcess([], 0, "ok", ""),
            CompletedProcess([], 0, "VRR policy must be an integer", ""),
            CompletedProcess([], 0, "ok", ""),
            CompletedProcess([], 0, "ok", ""),
        ]
        with (
            patch.object(projection, "run_json_command", return_value=self.monitors),
            patch.object(projection, "read_baseline", return_value=self.baseline),
            patch.object(projection, "configured_monitors", return_value={}),
            patch.object(projection.subprocess, "run", side_effect=replies) as run,
        ):
            with self.assertRaisesRegex(RuntimeError, "VRR policy"):
                projection.apply("extend")
        self.assertEqual(run.call_count, 4)  # two layout calls, then two rollback calls


if __name__ == "__main__":
    unittest.main()
