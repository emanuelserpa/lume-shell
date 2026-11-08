#!/usr/bin/env python3
import importlib.util
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True

SCRIPT_PATH = Path(__file__).resolve().parents[1] / "scripts" / "theme-manager.py"
SPEC = importlib.util.spec_from_file_location("theme_manager", SCRIPT_PATH)
tm = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(tm)


def relative_luminance(hex_color):
    rgb = tm.hex_to_rgb_tuple(hex_color)
    linear = [channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4
              for channel in (component / 255 for component in rgb)]
    return sum(channel * weight for channel, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


def contrast_ratio(foreground, background):
    lighter = max(relative_luminance(foreground), relative_luminance(background))
    darker = min(relative_luminance(foreground), relative_luminance(background))
    return (lighter + 0.05) / (darker + 0.05)


class TestThemeManager(unittest.TestCase):
    def test_cli_holds_lock_during_adapter_application(self):
        import fcntl
        import io

        def apply_theme(theme_id):
            with (tm.STATE_DIR / "theme-manager.lock").open("a") as contender:
                with self.assertRaises(BlockingIOError):
                    fcntl.flock(contender, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return {"ok": True}

        with patch.object(sys, "argv", [str(SCRIPT_PATH), "set", "nord"]), \
                patch.object(tm, "cmd_set", side_effect=apply_theme), \
                patch("sys.stdout", new_callable=io.StringIO):
            self.assertEqual(tm.main(), 0)
        with (tm.STATE_DIR / "theme-manager.lock").open("a") as contender:
            fcntl.flock(contender, fcntl.LOCK_EX | fcntl.LOCK_NB)

    def setUp(self):
        # Isola os testes do estado real do usuário (~/.local/state,
        # ~/.cache, ~/.config/ghostty e ~/.config/kitty): escritas em tmp.
        import tempfile
        from unittest.mock import patch
        self._tmpdir = tempfile.TemporaryDirectory()
        t = Path(self._tmpdir.name)
        self._path_overrides = {
            "STATE_DIR": t / "state",
            "STATE_FILE": t / "state" / "theme.json",
            "CHAMELEON_PALETTE_FILE": t / "state" / "chameleon-palette.json",
            "CANONICAL_PALETTE_FILE": t / "state" / "current_palette.json",
            "ADAPTERS_FILE": t / "state" / "adapters.json",
            "DEFAULT_WALLPAPER_PATH": t / "current_wallpaper",
            "HYPR_CACHE_DIR": t / "hypr",
            "HYPR_THEME_LUA": t / "hypr" / "theme.lua",
            "HYPRLOCK_COLORS_CONF": t / "hypr" / "hyprlock_colors.conf",
            "GHOSTTY_CONFIG_PATH": t / "ghostty" / "config",
            "GHOSTTY_THEMES_DIR": t / "ghostty" / "themes",
            "KITTY_CONFIG_PATH": t / "home" / ".config" / "kitty" / "kitty.conf",
            "KITTY_THEME_FILE": t / "state" / "kitty-theme.conf",
            "KITTY_RUNTIME_DIR": t / "run",
            "FASTFETCH_CONFIG_PATH": t / "home" / ".config" / "fastfetch" / "config.jsonc",
            "MANGO_CONFIG_PATH": t / "home" / ".config" / "mango" / "config.conf",
        }
        self._orig_paths = {}
        for key, val in self._path_overrides.items():
            self._orig_paths[key] = getattr(tm, key)
            setattr(tm, key, val)
        tm.MANGO_CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
        tm.MANGO_CONFIG_PATH.write_text(
            "\n".join(f"{key}=0x00000000" for key in (
                "group_bar_decorate_fg_color", "group_bar_decorate_bg_color",
                "group_bar_decorate_focus_fg_color", "group_bar_decorate_focus_bg_color",
                "group_bar_decorate_border_color")) + "\n",
            encoding="utf-8",
        )
        tm.KITTY_CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
        tm.KITTY_CONFIG_PATH.write_text("font_size 11\n", encoding="utf-8")
        # Neutraliza contato com a sessão viva: Ghostty e Kitty nunca
        # recebem sinais ou comandos durante os testes.
        # A lógica de broadcast em si continua exercitada (entrega p/ zero
        # ptys), só sem destinatários.
        self._proc_patchers = [
            patch.object(tm, "get_ghostty_ptys", return_value=[]),
            patch.object(tm, "reload_ghostty", return_value=True),
            patch.object(tm, "reconfigure_labwc", return_value=True),
            patch.object(tm, "is_mango_session", return_value=False),
        ]
        for p in self._proc_patchers:
            p.start()
        # Verificação de adapters lê XDG_*/home em tempo de chamada:
        # aponta tudo para tmp.
        self._env_patch = patch.dict("os.environ", {
            "XDG_CONFIG_HOME": str(t / "home" / ".config"),
            "XDG_CACHE_HOME": str(t / "home" / ".cache"),
            "XDG_DATA_HOME": str(t / "home" / ".local" / "share"),
        })
        self._env_patch.start()
        self._home_patch = patch.object(Path, "home", return_value=t / "home")
        self._home_patch.start()

    def tearDown(self):
        for p in self._proc_patchers:
            p.stop()
        self._env_patch.stop()
        self._home_patch.stop()
        for key, val in self._orig_paths.items():
            setattr(tm, key, val)
        self._tmpdir.cleanup()

    def test_no_side_effects_on_real_user_state(self):
        from PIL import Image

        real_state = Path.home() / ".local" / "state" / "quickshell"
        watched = [
            real_state / "theme.json",
            real_state / "chameleon-palette.json",
            real_state / "current_palette.json",
            Path.home() / ".cache" / "current_wallpaper",
        ]
        before = {str(p): (p.read_bytes() if p.is_file() else None) for p in watched}

        img = Path(self._tmpdir.name) / "wallpaper.png"
        Image.new("RGB", (64, 64), color=(30, 80, 180)).save(img)
        tm.extract_chameleon_palette(img)
        tm.cmd_update_wallpaper()
        tm.export_canonical_palette(tm.THEMES["catppuccin-mocha"])

        for p in watched:
            current = p.read_bytes() if p.is_file() else None
            self.assertEqual(current, before[str(p)], f"test run modified real user file {p}")

    def test_no_live_process_contact(self):
        # Descoberta de ptys e reload do Ghostty estão neutralizados:
        # nenhum teste pode repintar ou recarregar terminais reais.
        self.assertEqual(tm.get_ghostty_ptys(), [])
        self.assertTrue(tm.reload_ghostty())

    def test_adapter_state_verified_not_assumed(self):
        sample = tm.THEMES["catppuccin-mocha"]
        # Sem registro: get relata fora de sync mesmo com arquivos presentes.
        res = tm.cmd_get("catppuccin-mocha")
        self.assertTrue(res["ok"])
        self.assertFalse(res["adapters"]["hyprland"])
        self.assertFalse(res["adapters"]["hyprlock"])
        self.assertFalse(res["adapters"]["fastfetch"])
        # Após aplicar de verdade: get relata em sync.
        import subprocess as _sp
        from unittest.mock import patch as _patch
        _fake_ok = _sp.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        with _patch.object(tm.subprocess, "run", return_value=_fake_ok):
            adapters = tm.apply_all_adapters(
                "catppuccin-mocha", sample,
                ghostty_config=Path(self._tmpdir.name) / "ghostty_config",
                ghostty_themes_dir=Path(self._tmpdir.name) / "ghostty_themes",
                hypr_cache_dir=Path(self._tmpdir.name) / "hypr",
                gtk_config_home=Path(self._tmpdir.name) / "home" / ".config",
                gtk_themes_dir=Path(self._tmpdir.name) / "home" / ".themes",
                btop_config_home=Path(self._tmpdir.name) / "home" / ".config",
            )
        # ghostty config inexistente -> False; hypr/hyprlock gravam tmp -> True
        self.assertFalse(adapters["ghostty"])
        self.assertTrue(adapters["hyprland"])
        self.assertTrue(adapters["hyprlock"])
        self.assertTrue(adapters["gtk"])
        self.assertTrue(adapters["labwc"])
        self.assertFalse(adapters["fastfetch"])
        res = tm.cmd_get("catppuccin-mocha")
        self.assertFalse(res["adapters"]["ghostty"])
        self.assertTrue(res["adapters"]["hyprland"])
        self.assertTrue(res["adapters"]["hyprlock"])
        self.assertTrue(res["adapters"]["gtk"])
        self.assertTrue(res["adapters"]["labwc"])
        self.assertFalse(res["adapters"]["fastfetch"])
        # Paleta diferente invalida o registro.
        other = dict(sample)
        other["colors"] = dict(sample["colors"], accent="#000000")
        self.assertFalse(tm.adapter_in_sync("hyprland", "catppuccin-mocha", other))

    def test_themes_catalog_contains_popular_themes(self):
        self.assertIn("catppuccin-mocha", tm.THEMES)
        self.assertIn("tokyo-night", tm.THEMES)
        self.assertIn("nord", tm.THEMES)
        self.assertIn("gruvbox", tm.THEMES)
        self.assertIn("dracula", tm.THEMES)
        self.assertIn("rose-pine", tm.THEMES)
        self.assertIn("catppuccin-latte", tm.THEMES)
        self.assertIn("ghostty", tm.THEMES)
        self.assertIn("chameleon", tm.THEMES)
        self.assertIn("chameleon-oled", tm.THEMES)
        self.assertIn("chameleon-light", tm.THEMES)
        self.assertEqual(
            {theme for theme in tm.THEMES if theme.startswith("chameleon")},
            {"chameleon", "chameleon-light", "chameleon-oled"},
        )

    def test_theme_tokens_contract(self):
        required_keys = {
            "backgroundAlpha", "backgroundOpaque", "surface", "surfaceHover",
            "foreground", "offWhite", "grey", "red", "green", "yellow",
            "blue", "pink", "cyan", "orange", "accent"
        }
        for tid, data in tm.THEMES.items():
            self.assertIn("colors", data)
            colors = data["colors"]
            for key in required_keys:
                self.assertIn(key, colors, f"Theme '{tid}' missing key '{key}'")

    def test_cmd_list_contract(self):
        res = tm.cmd_list()
        self.assertTrue(res["ok"])
        self.assertIsNone(res["error"])
        self.assertIsInstance(res["themes"], list)
        self.assertGreaterEqual(len(res["themes"]), 8)
        names = [t["name"].lower() for t in res["themes"]]
        self.assertEqual(names, sorted(names))

    def test_cmd_get_valid_and_invalid(self):
        res_mocha = tm.cmd_get("catppuccin-mocha")
        self.assertTrue(res_mocha["ok"])
        self.assertEqual(res_mocha["theme"]["name"], "Catppuccin Mocha")

        res_invalid = tm.cmd_get("nonexistent_theme_xyz")
        self.assertFalse(res_invalid["ok"])
        self.assertIn("não encontrado", res_invalid["error"])

    def test_cmd_set_and_next(self):
        with patch.object(tm, "write_current_theme_id", return_value="nord"), \
             patch.object(tm, "read_current_theme_id", return_value="catppuccin-mocha"), \
             patch.object(tm, "sync_ghostty_theme", return_value=True):
            res = tm.cmd_set("nord")
            self.assertTrue(res["ok"])
            self.assertEqual(res["current"], "nord")
            self.assertTrue(res.get("ghostty_synced"))

            res_next = tm.cmd_next()
            self.assertTrue(res_next["ok"])

    def test_sync_ghostty_theme(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg = Path(tmpdir) / "config"
            cfg.write_text("font-size = 12\ntheme = Catppuccin Mocha\nwindow-padding = 10\n", encoding="utf-8")

            # Update to tokyo-night
            ok = tm.sync_ghostty_theme("tokyo-night", config_path=cfg)
            self.assertTrue(ok)
            content = cfg.read_text(encoding="utf-8")
            self.assertIn("theme = TokyoNight", content)
            self.assertNotIn("Catppuccin Mocha", content)

            # Update to ghostty
            ok = tm.sync_ghostty_theme("ghostty", config_path=cfg)
            self.assertTrue(ok)
            content = cfg.read_text(encoding="utf-8")
            self.assertIn("theme = Ghostty Default Style Dark", content)

            # Nonexistent file
            no_file = Path(tmpdir) / "does_not_exist"
            self.assertFalse(tm.sync_ghostty_theme("nord", config_path=no_file))

            # Unknown theme id
            self.assertFalse(tm.sync_ghostty_theme("unknown-xyz", config_path=cfg))

    def test_sync_labwc_theme(self):
        sample = tm.THEMES["catppuccin-mocha"]
        # verify_adapter resolve via XDG_CONFIG_HOME (isolado no setUp):
        # escreve no mesmo lugar que a verificação lê.
        cfg_home = Path(os.environ["XDG_CONFIG_HOME"])
        ok = tm.sync_labwc_theme(palette=sample, config_home=cfg_home)
        self.assertTrue(ok)
        target = cfg_home / "labwc" / "themerc-override"
        content = target.read_text(encoding="utf-8")
        self.assertIn("window.active.border.color: #89b4fa", content)
        self.assertIn("menu.items.bg.color: #1e1e2e", content)
        # Registro + verificação releem o destino (nunca só existência).
        self.assertTrue(tm.adapter_in_sync("labwc", "catppuccin-mocha", sample))
        other = dict(sample)
        other["colors"] = dict(sample["colors"], accent="#000000")
        self.assertFalse(tm.adapter_in_sync("labwc", "catppuccin-mocha", other))
        # Sem paleta não escreve nem registra ok.
        self.assertFalse(tm.sync_labwc_theme(palette=None, config_home=cfg_home))

    def test_labwc_write_failure_preserves_previous_file_and_retry_recovers(self):
        sample = tm.THEMES["catppuccin-mocha"]
        cfg_home = Path(os.environ["XDG_CONFIG_HOME"])
        target = cfg_home / "labwc" / "themerc-override"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("previous-valid-config\n", encoding="utf-8")
        original_replace = Path.replace

        def fail_theme_replace(path, destination):
            if path == target.with_suffix(".tmp"):
                raise OSError("simulated interrupted write")
            return original_replace(path, destination)

        with patch.object(Path, "replace", new=fail_theme_replace):
            self.assertFalse(tm.sync_labwc_theme(sample, config_home=cfg_home))

        self.assertEqual(target.read_text(encoding="utf-8"), "previous-valid-config\n")
        self.assertFalse(tm.adapter_in_sync("labwc", "catppuccin-mocha", sample))
        self.assertTrue(tm.sync_labwc_theme(sample, config_home=cfg_home))
        self.assertTrue(tm.adapter_in_sync("labwc", "catppuccin-mocha", sample))

    def test_gtk_invalid_settings_are_reported_out_of_sync_until_repaired(self):
        sample = tm.THEMES["catppuccin-mocha"]
        cfg_home = Path(os.environ["XDG_CONFIG_HOME"])
        gtk3_settings = cfg_home / "gtk-3.0" / "settings.ini"
        gtk3_settings.parent.mkdir(parents=True, exist_ok=True)
        gtk3_settings.write_text("[Settings\ninvalid", encoding="utf-8")
        themes_dir = Path(self._tmpdir.name) / "home" / ".themes"

        with patch.object(tm.shutil, "which", return_value=None):
            self.assertTrue(tm.sync_gtk_theme(
                "catppuccin-mocha", sample,
                config_home=cfg_home, themes_dir=themes_dir))
        self.assertFalse(tm.adapter_in_sync("gtk", "catppuccin-mocha", sample))

        gtk3_settings.write_text("[Settings]\n", encoding="utf-8")
        with patch.object(tm.shutil, "which", return_value=None):
            self.assertTrue(tm.sync_gtk_theme(
                "catppuccin-mocha", sample,
                config_home=cfg_home, themes_dir=themes_dir))
        self.assertTrue(tm.adapter_in_sync("gtk", "catppuccin-mocha", sample))

    def test_sync_mango_theme(self):
        sample = tm.THEMES["catppuccin-mocha"]
        cfg_home = Path(os.environ["XDG_CONFIG_HOME"])
        config = cfg_home / "mango" / "config.conf"
        config.parent.mkdir(parents=True, exist_ok=True)
        config.write_text(
            "group_bar_decorate_fg_color=0x00000000\n"
            "group_bar_decorate_bg_color=0x00000000\n"
            "group_bar_decorate_focus_fg_color=0x00000000\n"
            "group_bar_decorate_focus_bg_color=0x00000000\n"
            "group_bar_decorate_border_color=0x00000000\n",
            encoding="utf-8",
        )
        self.assertTrue(tm.sync_mango_theme(sample))
        content = config.read_text(encoding="utf-8")
        accent = sample["colors"]["accent"]
        self.assertIn(f"group_bar_decorate_focus_bg_color={tm.to_theme_hex_rgba(accent, 0xEE)}", content)
        self.assertIn(f"group_bar_decorate_border_color={tm.to_theme_hex_rgba(accent, 0xEE)}", content)
        self.assertTrue(tm.adapter_in_sync("mango", "catppuccin-mocha", sample))
        self.assertFalse(tm.sync_mango_theme(None))

    def test_chameleon_palette_extraction(self):
        import tempfile
        from PIL import Image

        with tempfile.TemporaryDirectory() as tmpdir:
            img_path = Path(tmpdir) / "test_wallpaper.png"
            img = Image.new("RGB", (64, 64), color=(30, 80, 180))
            img.save(img_path)

            palette = tm.extract_chameleon_palette(img_path)
            self.assertEqual(palette["id"], "chameleon")
            self.assertEqual(palette["name"], "Chameleon")
            self.assertIn("colors", palette)
            self.assertTrue(palette["colors"]["backgroundOpaque"].startswith("#"))
            self.assertTrue(palette["colors"]["accent"].startswith("#"))

    def test_chameleon_fallback_when_missing(self):
        palette = tm.extract_chameleon_palette("/path/to/nonexistent/wallpaper_12345.png")
        self.assertEqual(palette["id"], "chameleon")
        self.assertIn("colors", palette)

    def test_sync_ghostty_theme_chameleon(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg = Path(tmpdir) / "config"
            cfg.write_text("font-size = 12\ntheme = Catppuccin Mocha\n", encoding="utf-8")
            themes_dir = Path(tmpdir) / "themes"

            ok = tm.sync_ghostty_theme("chameleon", config_path=cfg, themes_dir=themes_dir)
            self.assertTrue(ok)
            content = cfg.read_text(encoding="utf-8")
            self.assertIn("theme = chameleon", content)
            self.assertNotIn("Catppuccin Mocha", content)
            self.assertTrue((themes_dir / "chameleon").is_file())
            theme_content = (themes_dir / "chameleon").read_text(encoding="utf-8")
            self.assertIn("palette = 0=", theme_content)
            self.assertIn("palette = 15=", theme_content)
            self.assertIn("background = ", theme_content)
            self.assertIn("foreground = ", theme_content)
            self.assertIn("cursor-color = ", theme_content)

    def test_generate_ghostty_chameleon_theme(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            themes_dir = Path(tmpdir) / "themes"
            sample_palette = tm.get_chameleon_fallback()
            path = tm.generate_ghostty_chameleon_theme(palette=sample_palette, themes_dir=themes_dir)
            self.assertTrue(path.is_file())
            content = path.read_text(encoding="utf-8")
            self.assertIn(f"background = {sample_palette['colors']['backgroundOpaque']}", content)
            self.assertIn(f"cursor-color = {sample_palette['colors']['accent']}", content)

    def test_cmd_update_wallpaper(self):
        with patch.object(tm, "read_current_theme_id", return_value="catppuccin-mocha"):
            res = tm.cmd_update_wallpaper()
            self.assertTrue(res["ok"])
            self.assertEqual(res["theme"]["id"], "chameleon")
            self.assertFalse(res["ghostty_synced"])
            # Ramo estático: relata todos os adapters com estado verificado.
            self.assertEqual(
                set(res["adapters"]),
                {"quickshell", "kitty", "ghostty", "hyprland", "hyprlock",
                "gtk", "btop", "qt", "labwc", "mango", "fastfetch"})

        with patch.object(tm, "read_current_theme_id", return_value="chameleon"), \
             patch.object(tm, "write_current_theme_id", return_value="chameleon"), \
             patch.object(tm, "detect_current_wallpaper", return_value="/nonexistent.png"), \
             patch.object(tm, "sync_ghostty_theme", return_value=True):
            res = tm.cmd_update_wallpaper()
            self.assertTrue(res["ok"])
            self.assertTrue(res["ghostty_synced"])

    def test_oklch_science(self):
        L, C, h = tm.rgb_to_oklch(255, 0, 0)
        self.assertGreater(L, 0.5)
        self.assertGreater(C, 0.2)
        hex_col = tm.oklch_to_rgb(L, C, h)
        self.assertEqual(hex_col.lower(), "#ff0000")

    def test_harmonized_semantics(self):
        dom_h = 236.0  # Blue hue
        sem = tm.generate_harmonized_semantics(dom_h)
        for name in ["red", "orange", "yellow", "green", "cyan", "blue", "pink"]:
            self.assertIn(name, sem)
            self.assertTrue(sem[name].startswith("#"))

    def test_chameleon_variants_palette_extraction(self):
        import tempfile
        from PIL import Image

        with tempfile.TemporaryDirectory() as tmpdir:
            img_path = Path(tmpdir) / "test_wallpaper.png"
            img = Image.new("RGB", (64, 64), color=(30, 80, 180))
            img.save(img_path)

            for variant in ["chameleon", "chameleon-light", "chameleon-oled"]:
                palette = tm.extract_chameleon_palette(img_path, target_variant=variant)
                self.assertEqual(palette["id"], variant)
                self.assertIn("colors", palette)
                colors = palette["colors"]
                for ext_key in [
                    "surfaceElevated", "surfaceSelected", "border", "borderSubtle",
                    "textMuted", "textDisabled", "accentMuted",
                    "surfaceContainerLowest", "surfaceContainerLow", "surfaceContainer",
                    "surfaceContainerHigh", "surfaceContainerHighest", "outlineVariant",
                    "secondaryContainer", "onSecondaryContainer", "error",
                    "errorContainer", "onErrorContainer",
                ]:
                    self.assertIn(ext_key, colors, f"Variant '{variant}' missing key '{ext_key}'")
                for foreground, background in [
                    ("onSurface", "surfaceContainerHigh"),
                    ("onSurfaceVariant", "surfaceContainerHigh"),
                    ("onPrimary", "primary"),
                    ("onPrimaryContainer", "primaryContainer"),
                    ("onSecondaryContainer", "secondaryContainer"),
                    ("onErrorContainer", "errorContainer"),
                ]:
                    ratio = contrast_ratio(colors[foreground], colors[background])
                    self.assertGreaterEqual(
                        ratio, 4.5,
                        f"{variant} {foreground}/{background} contrast is {ratio:.2f}:1",
                    )
            variants = tm.get_cached_variants()
            self.assertEqual(variants["chameleon"]["colors"]["primary"], variants["chameleon-oled"]["colors"]["primary"])
            self.assertEqual(variants["chameleon-oled"]["colors"]["backgroundOpaque"], "#000000")
            self.assertEqual(variants["chameleon-light"]["category"], "light")

    def test_builtin_theme_text_contrast_on_card_surfaces(self):
        for theme_id, theme in tm.THEMES.items():
            if theme_id.startswith("chameleon"):
                continue
            colors = theme["colors"]
            card_surface = colors.get("surfaceContainerHigh", colors["surfaceHover"])
            ratio = contrast_ratio(colors["foreground"], card_surface)
            self.assertGreaterEqual(
                ratio, 4.5,
                f"{theme_id} foreground/card surface contrast is {ratio:.2f}:1",
            )

    def test_compute_top_luminance(self):
        from PIL import Image
        img_dark = Image.new("RGB", (100, 100), color=(10, 10, 10))
        lum_dark = tm.compute_top_luminance(img_dark)
        self.assertLess(lum_dark, 0.2)

        img_bright = Image.new("RGB", (100, 100), color=(240, 240, 240))
        lum_bright = tm.compute_top_luminance(img_bright)
        self.assertGreater(lum_bright, 0.8)

    def test_color_helpers(self):
        self.assertEqual(tm.hex_to_rgb_tuple("#89b4fa"), (137, 180, 250))
        self.assertEqual(tm.hex_to_rgb_tuple("fff"), (255, 255, 255))
        self.assertEqual(tm.to_hyprlang_rgb("#89b4fa"), "rgb(137, 180, 250)")
        self.assertEqual(tm.to_hyprlang_rgba("#89b4fa", 0.6), "rgba(137, 180, 250, 0.60)")
        self.assertEqual(tm.to_hyprland_hex_rgba("#89b4fa", "ee"), "rgba(89b4faee)")

    def test_sync_hyprland_theme(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            sample_palette = tm.THEMES["catppuccin-mocha"]
            cache_dir = Path(tmpdir) / "hypr"
            ok = tm.sync_hyprland_theme(sample_palette, cache_dir=cache_dir)
            self.assertTrue(ok)
            lua_file = cache_dir / "theme.lua"
            self.assertTrue(lua_file.is_file())
            content = lua_file.read_text(encoding="utf-8")
            self.assertIn("active_border = \"rgba(89b4faee)\"", content)
            self.assertIn("inactive_border = \"rgba(31324488)\"", content)
            self.assertIn("group_border_active = \"rgba(89b4faee)\"", content)
            self.assertIn("group_border_inactive = \"rgba(31324488)\"", content)
            self.assertIn("groupbar_active = \"rgba(89b4faee)\"", content)
            self.assertIn("groupbar_inactive = \"rgba(313244e8)\"", content)
            self.assertIn("groupbar_text_active = \"rgba(1e1e2eff)\"", content)
            self.assertIn("groupbar_text_inactive = \"rgba(cdd6f4ff)\"", content)

    def test_sync_hyprlock_theme(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            sample_palette = tm.THEMES["catppuccin-mocha"]
            cache_dir = Path(tmpdir) / "hypr"
            ok = tm.sync_hyprlock_theme(sample_palette, cache_dir=cache_dir)
            self.assertTrue(ok)
            conf_file = cache_dir / "hyprlock_colors.conf"
            self.assertTrue(conf_file.is_file())
            content = conf_file.read_text(encoding="utf-8")
            self.assertIn("$accent = rgba(137, 180, 250, 0.60)", content)
            self.assertIn("$surface = rgba(49, 50, 68, 0.90)", content)
            self.assertIn("$font = rgb(205, 214, 244)", content)
            self.assertIn("$check = rgba(166, 227, 161, 1.00)", content)
            self.assertIn("$fail = rgba(243, 139, 168, 1.00)", content)

    def test_apply_all_adapters(self):
        import subprocess as _sp
        import tempfile
        from unittest.mock import patch as _patch
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            cfg = tmp_path / "ghostty_config"
            cfg.write_text("theme = Catppuccin Mocha\n", encoding="utf-8")
            ghostty_themes = tmp_path / "ghostty_themes"
            hypr_cache = tmp_path / "hypr"
            fastfetch_config = tm.FASTFETCH_CONFIG_PATH
            fastfetch_config.parent.mkdir(parents=True)
            fastfetch_config.write_text('''{
  "logo": { "color": { "1": "#000000", "2": "#000000" } },
  "display": { "color": { "keys": "#000000", "title": "#000000" } }
}
''', encoding="utf-8")

            sample_palette = tm.THEMES["tokyo-night"]
            _fake_ok = _sp.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
            with _patch.object(tm.subprocess, "run", return_value=_fake_ok):
                adapters = tm.apply_all_adapters(
                    "tokyo-night",
                    sample_palette,
                    ghostty_config=cfg,
                    ghostty_themes_dir=ghostty_themes,
                    hypr_cache_dir=hypr_cache,
                    gtk_config_home=Path(self._tmpdir.name) / "home" / ".config",
                    gtk_themes_dir=Path(self._tmpdir.name) / "home" / ".themes",
                    btop_config_home=Path(self._tmpdir.name) / "home" / ".config",
                    qt_config_home=Path(self._tmpdir.name) / "home" / ".config",
                    qt_kvantum_dir=Path(self._tmpdir.name) / "home" / ".config" / "Kvantum",
                )
            self.assertTrue(adapters["quickshell"])
            self.assertTrue(adapters["kitty"])
            self.assertTrue(adapters["ghostty"])
            self.assertTrue(adapters["hyprland"])
            self.assertTrue(adapters["hyprlock"])
            self.assertTrue(adapters["gtk"])
            self.assertTrue(adapters["fastfetch"])
            self.assertTrue(tm.adapter_in_sync("fastfetch", "tokyo-night", sample_palette))
            fastfetch_text = fastfetch_config.read_text(encoding="utf-8")
            self.assertIn(sample_palette["colors"]["accent"], fastfetch_text)
            self.assertIn(sample_palette["colors"]["cyan"], fastfetch_text)
            self.assertIn(sample_palette["colors"]["pink"], fastfetch_text)

    def test_sync_kitty_theme_writes_palette_and_runtime_config(self):
        palette = tm.THEMES["tokyo-night"]
        config_path = tm.KITTY_CONFIG_PATH
        theme_file = tm.KITTY_THEME_FILE

        with patch.object(tm, "reload_kitty_config", return_value=True) as reload_config:
            self.assertTrue(tm.sync_kitty_theme("tokyo-night", palette=palette))
            reload_config.assert_called_once_with()
        config = config_path.read_text(encoding="utf-8")
        colors = theme_file.read_text(encoding="utf-8")
        self.assertIn("allow_remote_control socket-only", config)
        self.assertIn("listen_on unix:${XDG_RUNTIME_DIR}/quickshell-kitty-{kitty_pid}", config)
        self.assertIn("include " + str(theme_file), config)
        self.assertIn("foreground #c0caf5", colors)
        self.assertIn("background #1a1b26", colors)
        self.assertIn("color15 #c0caf5", colors)
        self.assertTrue(tm.verify_adapter("kitty", "tokyo-night", palette))

        first_config = config_path.read_text(encoding="utf-8")
        self.assertTrue(tm.sync_kitty_theme("tokyo-night", palette=palette))
        self.assertEqual(config_path.read_text(encoding="utf-8"), first_config)

        runtime_dir = tm.KITTY_RUNTIME_DIR
        runtime_dir.mkdir(parents=True)
        (runtime_dir / "quickshell-kitty-1234").touch()
        from subprocess import CompletedProcess
        completed = CompletedProcess(args=[], returncode=0)
        with patch.object(tm.shutil, "which", return_value="/usr/bin/kitten"), \
             patch.object(tm.subprocess, "run", return_value=completed) as run:
            self.assertTrue(tm.sync_kitty_theme("tokyo-night", palette=palette))
        command = run.call_args.args[0]
        self.assertEqual(command[1:3], ["@", "--to"])
        self.assertIn("set-colors", command)
        self.assertIn("--all", command)
        self.assertIn("--configured", command)

    def test_reload_kitty_config_signals_user_instances(self):
        import signal
        from subprocess import CompletedProcess
        completed = CompletedProcess(args=[], returncode=0, stdout="1234\n5678\n", stderr="")
        with patch.object(tm.subprocess, "run", return_value=completed), \
             patch.object(tm.os, "kill") as kill:
            self.assertTrue(tm.reload_kitty_config())
        self.assertEqual(kill.call_args_list, [
            unittest.mock.call(1234, signal.SIGUSR1),
            unittest.mock.call(5678, signal.SIGUSR1),
        ])


    def test_apply_all_adapters_isolates_failures(self):
        with patch.object(tm, "export_canonical_palette"), \
             patch.object(tm, "sync_ghostty_theme", side_effect=RuntimeError("unavailable")), \
             patch.object(tm, "sync_hyprland_theme", return_value=True), \
             patch.object(tm, "sync_hyprlock_theme", return_value=True), \
             patch.object(tm, "sync_gtk_theme", return_value=True), \
             patch.object(tm, "sync_btop_theme", return_value=True), \
             patch.object(tm, "sync_qt_theme", return_value=True), \
             patch.object(tm, "sync_labwc_theme", return_value=True), \
             patch.object(tm, "sync_fastfetch_theme", return_value=True):
            result = tm.apply_all_adapters("catppuccin-mocha", tm.THEMES["catppuccin-mocha"])

        self.assertFalse(result["ghostty"])
        self.assertTrue(result["hyprland"])
        self.assertTrue(result["fastfetch"])

    def test_sync_gtk_theme(self):
        import subprocess as _sp
        from unittest.mock import patch as _patch
        base = Path(self._tmpdir.name) / "home"
        cfg_home = base / ".config"
        calls = []

        def fake_run(cmd, **kwargs):
            calls.append(cmd)
            return _sp.CompletedProcess(args=cmd, returncode=0, stdout="", stderr="")

        with _patch.object(tm.subprocess, "run", side_effect=fake_run):
            ok = tm.sync_gtk_theme(
                "catppuccin-mocha", tm.THEMES["catppuccin-mocha"],
                config_home=cfg_home,
                themes_dir=base / ".themes")
        self.assertTrue(ok)
        flat = " ".join(" ".join(c) for c in calls)
        self.assertIn("prefer-dark", flat)
        ini = cfg_home / "gtk-3.0" / "settings.ini"
        self.assertTrue(ini.is_file())
        content = ini.read_text(encoding="utf-8")
        self.assertIn("gtk-theme-name", content)
        self.assertIn("quickshell-catppuccin-mocha", content)
        self.assertTrue(tm.adapter_in_sync(
            "gtk", "catppuccin-mocha", tm.THEMES["catppuccin-mocha"]))
        # light pede esquema claro sem quebrar quando nada instalado
        with _patch.object(tm.subprocess, "run", side_effect=fake_run):
            ok_light = tm.sync_gtk_theme(
                "catppuccin-latte", tm.THEMES["catppuccin-latte"],
                config_home=cfg_home,
                themes_dir=base / ".themes")
        self.assertTrue(ok_light)
        self.assertIn("prefer-light", " ".join(" ".join(c) for c in calls))

    def test_generate_gtk_chameleon_theme(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            tdir = Path(tmpdir) / "themes"
            out = tm.generate_gtk_chameleon_theme(
                palette=tm.THEMES["catppuccin-mocha"], themes_dir=tdir)
            for rel in ["gtk-3.0/gtk.css", "gtk-3.0/gtk-dark.css",
                        "gtk-4.0/gtk.css", "gtk-4.0/gtk-dark.css",
                        "index.theme"]:
                self.assertTrue((out / rel).is_file(), rel)
            css = (out / "gtk-3.0" / "gtk.css").read_text(encoding="utf-8")
            # Cores da paleta presentes e chaves balanceadas
            for hx in ["#1e1e2e", "#cdd6f4", "#89b4fa"]:
                self.assertIn(hx, css)
            self.assertEqual(css.count("{"), css.count("}"))
            self.assertNotIn("__QS_", css)

    def test_sync_btop_theme(self):
        base = Path(self._tmpdir.name) / "home"
        home = base / ".config"
        (home / "btop").mkdir(parents=True, exist_ok=True)
        (home / "btop" / "btop.conf").write_text(
            '# btop config\ncolor_theme = "Default"\n', encoding="utf-8")
        ok = tm.sync_btop_theme(
            "catppuccin-mocha", tm.THEMES["catppuccin-mocha"],
            config_home=home)
        self.assertTrue(ok)
        theme_file = home / "btop" / "themes" / "chameleon.theme"
        self.assertTrue(theme_file.is_file())
        content = theme_file.read_text(encoding="utf-8")
        self.assertIn('theme_bg="#1e1e2e"', content)
        self.assertIn('hi_fg="#89b4fa"', content)
        conf = (home / "btop" / "btop.conf").read_text(encoding="utf-8")
        self.assertIn('color_theme = "chameleon"', conf)
        self.assertTrue(tm.adapter_in_sync(
            "btop", "catppuccin-mocha", tm.THEMES["catppuccin-mocha"]))
        # Sem conf: gera o tema mas relata fora de sync
        home2 = base / "emptyhome" / ".config"
        self.assertFalse(tm.sync_btop_theme(
            "catppuccin-mocha", tm.THEMES["catppuccin-mocha"],
            config_home=home2))
        self.assertTrue((home2 / "btop" / "themes" / "chameleon.theme").is_file())

    def test_sync_qt_theme(self):
        base = Path(self._tmpdir.name) / "home"
        cfg = base / ".config"
        kv = cfg / "Kvantum"
        tpl = kv / "catppuccin-mocha-pink"
        tpl.mkdir(parents=True, exist_ok=True)
        (tpl / "catppuccin-mocha-pink.kvconfig").write_text(
            "window.color=#1E1E2E\ntext.color=#CDD6F4\n"
            "highlight.color=#F5C2E74D\nlink.color=#F5C2E7\n"
            "[Tab]\ninherits=PanelButtonCommand\nframe.top=2\n"
            "[TabBarFrame]\nframe=true\n",
            encoding="utf-8")
        (kv / "kvantum.kvconfig").write_text(
            "[General]\ntheme=catppuccin-mocha-pink\n", encoding="utf-8")
        (cfg / "qt6ct").mkdir(parents=True, exist_ok=True)
        (cfg / "qt6ct" / "qt6ct.conf").write_text(
            "[Appearance]\nstyle=kvantum\n", encoding="utf-8")
        ok = tm.sync_qt_theme(
            "catppuccin-mocha", tm.THEMES["catppuccin-mocha"],
            config_home=cfg, kvantum_dir=kv)
        self.assertTrue(ok)
        gen = kv / "chameleon" / "chameleon.kvconfig"
        self.assertTrue(gen.is_file())
        content = gen.read_text(encoding="utf-8")
        self.assertIn("window.color=#1e1e2e", content)
        self.assertIn("highlight.color=#89b4fa4d", content.lower())
        self.assertIn("theme=chameleon",
                      (kv / "kvantum.kvconfig").read_text(encoding="utf-8"))
        colors_text = (cfg / "qt6ct" / "qt6ct.conf").read_text(encoding="utf-8")
        self.assertIn("style=breeze", colors_text)
        tab_section = gen.read_text(encoding="utf-8").split("[Tab]")[1].split("[TabBarFrame]")[0]
        self.assertIn("frame=false", tab_section)
        self.assertTrue(tm.adapter_in_sync(
            "qt", "catppuccin-mocha", tm.THEMES["catppuccin-mocha"]))
        # Sem Kvantum configurado: fora de sync, sem falhar
        self.assertFalse(tm.sync_qt_theme(
            "catppuccin-mocha", tm.THEMES["catppuccin-mocha"],
            config_home=base / "nocfg", kvantum_dir=base / "nokv"))

    def test_breeze_colors_roles(self):
        txt = tm.build_breeze_colors(tm.THEMES["catppuccin-mocha"])
        self.assertIn("[Colors:Window]", txt)
        self.assertIn("[Colors:Selection]", txt)
        # Papéis breeze com matizes chameleon (mocha aqui)
        self.assertIn("BackgroundNormal=30, 30, 46", txt)
        self.assertIn("BackgroundNormal=137, 180, 250", txt)  # seleção = accent
        self.assertIn("ForegroundNormal=205, 214, 244", txt)

    def test_libadwaita_recolor(self):
        css = tm.libadwaita_recolor_css(tm.THEMES["catppuccin-mocha"])
        for var in ["@define-color accent_bg_color #89b4fa;",
                    "@define-color window_bg_color #1e1e2e;",
                    f"@define-color view_bg_color {tm.desaturate_hex('#313244')};",
                    "@define-color error_bg_color #f38ba8;"]:
            self.assertIn(var, css)
        self.assertEqual(tm._accent_color_name("#89b4fa"), "blue")
        self.assertEqual(tm._accent_color_name("#a6e3a1"), "green")
        self.assertEqual(tm._accent_color_name("#f5c2e7"), "pink")
        # Mesmo mapa de papéis do template GTK3: headerbar mantle, card surface
        self.assertIn(
            f"@define-color headerbar_bg_color {tm.desaturate_hex(tm.darken_hex('#1e1e2e', 0.035))};",
            css)
        self.assertIn(
            f"@define-color card_bg_color {tm.desaturate_hex('#313244')};",
            css)
        # Neutro de verdade: saturação cai, luminosidade fica
        import colorsys as _cs
        r, g, b = tm.hex_to_rgb(tm.desaturate_hex('#1f2111'))
        _, _, s_new = _cs.rgb_to_hls(r / 255, g / 255, b / 255)
        r, g, b = tm.hex_to_rgb('#1f2111')
        _, _, s_old = _cs.rgb_to_hls(r / 255, g / 255, b / 255)
        self.assertLess(s_new, s_old)

    def test_adapter_verify_reads_destinations(self):
        import tempfile
        from unittest.mock import patch as _patch
        from pathlib import Path as _Path
        with tempfile.TemporaryDirectory() as tmpdir:
            t = _Path(tmpdir)
            (t / ".config" / "ghostty").mkdir(parents=True)
            (t / ".config" / "ghostty" / "config").write_text(
                "theme = Dracula\n", encoding="utf-8")
            (t / ".cache" / "hypr").mkdir(parents=True)
            (t / ".cache" / "hypr" / "theme.lua").write_text(
                'active_border = "rgba(bd93f9ee)"\n', encoding="utf-8")
            (t / ".cache" / "hypr" / "hyprlock_colors.conf").write_text(
                "$accent = rgba(189, 147, 249, 0.60)\n", encoding="utf-8")
            (t / ".config" / "gtk-3.0").mkdir(parents=True)
            (t / ".config" / "gtk-3.0" / "settings.ini").write_text(
                "[Settings]\ngtk-theme-name = quickshell-dracula\n",
                encoding="utf-8")
            (t / ".themes" / "quickshell-dracula" / "gtk-3.0").mkdir(parents=True)
            (t / ".themes" / "quickshell-dracula" / "gtk-3.0" / "gtk.css").write_text(
                "button:active { background: #bd93f9; }\n", encoding="utf-8")
            (t / ".config" / "btop").mkdir(parents=True)
            (t / ".config" / "btop" / "btop.conf").write_text(
                'color_theme = "chameleon"\n', encoding="utf-8")
            (t / ".config" / "btop" / "themes").mkdir(parents=True)
            (t / ".config" / "btop" / "themes" / "chameleon.theme").write_text(
                'hi_fg="#bd93f9"\n', encoding="utf-8")
            (t / ".config" / "qt6ct").mkdir(parents=True)
            (t / ".config" / "qt6ct" / "qt6ct.conf").write_text(
                "style=breeze\n", encoding="utf-8")
            (t / ".config" / "qt6ct" / "colors").mkdir(parents=True)
            (t / ".config" / "qt6ct" / "colors" / "Chameleon.colors").write_text(
                "[Colors:Selection]\nBackgroundNormal=189, 147, 249\n",
                encoding="utf-8")
            env = {"XDG_CONFIG_HOME": str(t / ".config"),
                   "XDG_CACHE_HOME": str(t / ".cache")}
            with _patch.dict("os.environ", env), \
                 _patch.object(_Path, "home", return_value=t):
                dracula = tm.THEMES["dracula"]
                # Fixtures nos paths que o verify realmente lê (globais).
                tm.GHOSTTY_CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
                tm.GHOSTTY_CONFIG_PATH.write_text(
                    "theme = Dracula\n", encoding="utf-8")
                tm.HYPR_THEME_LUA.parent.mkdir(parents=True, exist_ok=True)
                colors = dracula["colors"]
                active_text = colors.get("onPrimary") or tm._readable_on(colors["accent"])
                tm.HYPR_THEME_LUA.write_text(
                    "\n".join((
                        f'groupbar_active = "{tm.to_hyprland_hex_rgba(colors["accent"], "ee")}"',
                        f'groupbar_inactive = "{tm.to_hyprland_hex_rgba(colors["surface"], "e8")}"',
                        f'groupbar_text_active = "{tm.to_hyprland_hex_rgba(active_text, "ff")}"',
                        f'groupbar_text_inactive = "{tm.to_hyprland_hex_rgba(colors["foreground"], "ff")}"',
                    )) + "\n", encoding="utf-8")
                tm.HYPRLOCK_COLORS_CONF.write_text(
                    "$accent = rgba(189, 147, 249, 0.60)\n", encoding="utf-8")
                self.assertTrue(tm.verify_adapter("ghostty", "dracula", dracula))
                self.assertTrue(tm.verify_adapter("hyprland", "dracula", dracula))
                self.assertTrue(tm.verify_adapter("hyprlock", "dracula", dracula))
                self.assertTrue(tm.verify_adapter("gtk", "dracula", dracula))
                self.assertTrue(tm.verify_adapter("btop", "dracula", dracula))
                self.assertTrue(tm.verify_adapter("qt", "dracula", dracula))
                other = dict(dracula)
                other["colors"] = dict(dracula["colors"], accent="#000000")
                self.assertFalse(tm.verify_adapter("hyprland", "dracula", other))
                self.assertFalse(tm.verify_adapter("ghostty", "unknown-xyz", dracula))

    def test_generate_gtk_template_recolor(self):
        import tempfile
        from unittest.mock import patch as _patch
        with tempfile.TemporaryDirectory() as tmpdir:
            t = Path(tmpdir)
            tpl = t / "tpl" / "catppuccin-mocha-pink-standard-default"
            for version in ("gtk-3.0", "gtk-4.0"):
                vdir = tpl / version
                vdir.mkdir(parents=True)
                (vdir / "gtk.css").write_text(
                    "window { background-color: #1e1e2e; color: #cdd6f4; }\n"
                    "button:active { background-color: #f5c2e7; }\n"
                    "box { border-color: rgba(239, 241, 245, 0.12); }\n",
                    encoding="utf-8")
            with _patch.object(tm, "_find_gtk_template", return_value=tpl), \
                 _patch.object(tm, "GTK_THEMES_DIR", t / "out"):
                out = tm.generate_gtk_chameleon_theme(
                    palette=tm.THEMES["catppuccin-mocha"])
            css = (out / "gtk-3.0" / "gtk.css").read_text(encoding="utf-8")
            self.assertIn("#1e1e2e", css)  # mocha base == mocha palette bg
            self.assertIn("rgba(205, 214, 244, 0.12)", css)
            # Accent aplicado no lugar do rosa do template
            self.assertNotIn("#f5c2e7", css.replace("#89b4fa", ""))
            self.assertIn("#89b4fa", css)

    def test_generate_gtk_per_theme_and_svg_recolor(self):
        import tempfile
        from unittest.mock import patch as _patch
        with tempfile.TemporaryDirectory() as tmpdir:
            t = Path(tmpdir)
            tpl = t / "tpl"
            (tpl / "gtk-3.0" / "assets").mkdir(parents=True)
            (tpl / "gtk-4.0").mkdir(parents=True)
            (tpl / "gtk-3.0" / "gtk.css").write_text(
                "button:active { background-color: #f5c2e7; }\n", encoding="utf-8")
            (tpl / "gtk-4.0" / "gtk.css").write_text(
                "button:active { background-color: #f5c2e7; }\n", encoding="utf-8")
            (tpl / "gtk-3.0" / "assets" / "check.svg").write_text(
                '<svg><rect fill="#f5c2e7"/></svg>', encoding="utf-8")
            with _patch.object(tm, "_find_gtk_template", return_value=tpl):
                with _patch.object(tm, "GTK_THEMES_DIR", t / "out"):
                    out = tm.generate_gtk_chameleon_theme(
                        palette=tm.THEMES["dracula"], name="quickshell-dracula")
            self.assertEqual(out.name, "quickshell-dracula")
            svg = (out / "gtk-3.0" / "assets" / "check.svg").read_text(encoding="utf-8")
            self.assertNotIn("#f5c2e7", svg)
            self.assertIn("#bd93f9", svg)

    def test_sync_gtk_chameleon_generates_and_selects(self):
        import subprocess as _sp
        import tempfile
        from unittest.mock import patch as _patch
        with tempfile.TemporaryDirectory() as tmpdir:
            t = Path(tmpdir)
            calls = []

            def fake_run(cmd, **kwargs):
                calls.append(cmd)
                return _sp.CompletedProcess(args=cmd, returncode=0, stdout="", stderr="")

            with _patch.object(tm.subprocess, "run", side_effect=fake_run):
                ok = tm.sync_gtk_theme(
                    "chameleon-oled", tm.get_chameleon_fallback("chameleon-oled"),
                    config_home=t / "cfg", themes_dir=t / "themes")
            self.assertTrue(ok)
            self.assertTrue((t / "themes" / "chameleon" / "gtk-3.0" / "gtk.css").is_file())
            ini = (t / "cfg" / "gtk-3.0" / "settings.ini").read_text(encoding="utf-8")
            self.assertIn("gtk-theme-name = chameleon", ini)


if __name__ == "__main__":
    unittest.main()
