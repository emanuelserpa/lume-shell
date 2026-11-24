"""Canonical XDG paths and idempotent legacy migration for Lume Shell."""

from __future__ import annotations

from contextlib import closing
import os
import shutil
import sqlite3
import tempfile
from pathlib import Path
from typing import Mapping

APP_NAME = "lume-shell"
LEGACY_APP_NAMES = ("quickshell", "lumeshell")


def _env_dir(env: Mapping[str, str] | None, var: str, default_rel: str) -> Path:
    source = env if env is not None else os.environ
    value = source.get(var, "")
    if value:
        return Path(value).expanduser()
    home = source.get("HOME", "")
    base = Path(home).expanduser() if home else Path.home()
    return base / default_rel


def config_home(env: Mapping[str, str] | None = None) -> Path:
    return _env_dir(env, "XDG_CONFIG_HOME", ".config")


def state_home(env: Mapping[str, str] | None = None) -> Path:
    return _env_dir(env, "XDG_STATE_HOME", ".local/state")


def data_home(env: Mapping[str, str] | None = None) -> Path:
    return _env_dir(env, "XDG_DATA_HOME", ".local/share")


def cache_home(env: Mapping[str, str] | None = None) -> Path:
    return _env_dir(env, "XDG_CACHE_HOME", ".cache")


def runtime_base(env: Mapping[str, str] | None = None) -> Path:
    source = env if env is not None else os.environ
    value = source.get("XDG_RUNTIME_DIR", "")
    if value:
        return Path(value).expanduser()
    return Path(tempfile.gettempdir())


def config_dir(env: Mapping[str, str] | None = None) -> Path:
    return config_home(env) / APP_NAME


def state_dir(env: Mapping[str, str] | None = None) -> Path:
    return state_home(env) / APP_NAME


def data_dir(env: Mapping[str, str] | None = None) -> Path:
    return data_home(env) / APP_NAME


def cache_dir(env: Mapping[str, str] | None = None) -> Path:
    return cache_home(env) / APP_NAME


def private_runtime_dir(env: Mapping[str, str] | None = None) -> Path:
    return runtime_base(env) / f"{APP_NAME}-{os.getuid()}"


def legacy_siblings(
    target: Path, legacy_names: tuple[str, ...] = LEGACY_APP_NAMES
) -> list[Path]:
    """Replace the rightmost `lume-shell` path component with legacy app names."""
    parts = list(target.parts)
    indices = [idx for idx, part in enumerate(parts) if part == APP_NAME]
    if not indices:
        return []
    pos = indices[-1]
    siblings: list[Path] = []
    for name in legacy_names:
        if name == APP_NAME:
            continue
        candidate_parts = list(parts)
        candidate_parts[pos] = name
        siblings.append(Path(*candidate_parts))
    return siblings


def ensure_compat_symlink(legacy_path: Path, target_path: Path) -> bool:
    """Keep a relative compatibility symlink at `legacy_path` -> `target_path`."""
    if legacy_path == target_path or not target_path.exists():
        return False
    try:
        if legacy_path.is_symlink():
            if legacy_path.resolve() == target_path.resolve():
                return True
            legacy_path.unlink()
        elif legacy_path.exists():
            return False
        legacy_path.parent.mkdir(parents=True, exist_ok=True)
        rel_target = os.path.relpath(target_path, legacy_path.parent)
        legacy_path.symlink_to(rel_target)
        return True
    except OSError:
        return False


def _move_file_atomic(src: Path, target: Path) -> bool:
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        src.replace(target)
        return True
    except OSError:
        pass
    tmp: Path | None = None
    try:
        fd, tmp_name = tempfile.mkstemp(prefix=f".{target.name}.", dir=str(target.parent))
        os.close(fd)
        tmp = Path(tmp_name)
        shutil.copy2(src, tmp)
        tmp.replace(target)
        tmp = None
        src.unlink(missing_ok=True)
        return True
    except OSError:
        if tmp is not None:
            try:
                tmp.unlink(missing_ok=True)
            except OSError:
                pass
        return False


def migrate_file(
    target: Path,
    *explicit_legacy: Path,
    compat_symlink: bool = False,
) -> Path:
    """Move a legacy file to `target` once, without clobbering existing targets."""
    sources = list(explicit_legacy) if explicit_legacy else legacy_siblings(target)
    if not target.exists():
        for src in sources:
            try:
                if src == target or src.is_symlink() or not src.is_file():
                    continue
            except OSError:
                continue
            if _move_file_atomic(src, target):
                break
    if compat_symlink and sources and target.exists():
        ensure_compat_symlink(sources[0], target)
    return target


def migrate_dir(target: Path, *explicit_legacy: Path) -> Path:
    """Move a legacy Lume-owned directory tree to `target` without clobbering."""
    sources = list(explicit_legacy) if explicit_legacy else legacy_siblings(target)
    if target.exists():
        return target
    for src in sources:
        try:
            if src == target or src.is_symlink() or not src.is_dir():
                continue
        except OSError:
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        try:
            src.replace(target)
            return target
        except OSError:
            tmp_dir = Path(
                tempfile.mkdtemp(prefix=f".{target.name}.", dir=str(target.parent))
            )
            try:
                staged = tmp_dir / target.name
                shutil.copytree(src, staged, symlinks=True)
                staged.replace(target)
                shutil.rmtree(src, ignore_errors=True)
                return target
            except OSError:
                shutil.rmtree(tmp_dir, ignore_errors=True)
            finally:
                if tmp_dir.exists():
                    try:
                        tmp_dir.rmdir()
                    except OSError:
                        pass
    return target


def _rewrite_notification_image_prefixes(notifications_dir: Path) -> None:
    db_path = notifications_dir / "notifications.db"
    if not db_path.is_file():
        return
    new_dir = str((notifications_dir / "images").resolve())
    old_dirs = [str(p / "images") for p in legacy_siblings(notifications_dir)]
    try:
        with closing(sqlite3.connect(db_path, timeout=2.0)) as conn:
            for old_prefix in old_dirs:
                conn.execute(
                    "UPDATE notifications SET image = replace(image, ?, ?) "
                    "WHERE image LIKE ?",
                    (old_prefix, new_dir, f"{old_prefix}%"),
                )
            conn.commit()
    except sqlite3.Error:
        pass


def migrate_all(env: Mapping[str, str] | None = None) -> dict[str, list[str]]:
    """Migrate known Lume-owned XDG files/dirs without touching Quickshell runtime dirs."""
    migrated: list[str] = []
    symlinks: list[str] = []

    cfg = config_dir(env)
    st = state_dir(env)
    dt = data_dir(env)
    ca = cache_dir(env)

    for rel in ("bar.json", "workspaces.json", "power/cpu-boost.json", "power/power-profile.json"):
        target = cfg / rel
        existed = target.exists()
        migrate_file(target)
        if not existed and target.exists():
            migrated.append(str(target))

    state_files: tuple[tuple[str, bool], ...] = (
        ("adapters.json", False),
        ("chameleon-palette.json", False),
        ("clipboard-capture.json", False),
        ("current_palette.json", True),
        ("display-projection.json", False),
        ("glass.json", False),
        ("kitty-theme.conf", True),
        ("launcher-emoji-recent.json", False),
        ("launcher-emoji-usage.json", False),
        ("launcher-preferences.json", False),
        ("launcher-usage.json", False),
        ("nightlight.json", False),
        ("theme-manager.lock", False),
        ("theme.json", False),
        ("wallpaper-color-preferences.json", False),
        ("wallpaper.json", False),
        ("weather.json", False),
    )
    for rel, compat in state_files:
        target = st / rel
        existed = target.exists()
        migrate_file(target, compat_symlink=compat)
        if not existed and target.exists():
            migrated.append(str(target))
        if compat and target.exists():
            legacy_primary = legacy_siblings(target)[0]
            if legacy_primary.is_symlink():
                symlinks.append(str(legacy_primary))

    for target in (st / "ytdlp", dt / "clipboard", dt / "notifications", ca / "clipboard-thumbs", ca / "wallpaper-previews"):
        existed = target.exists()
        migrate_dir(target)
        if not existed and target.exists():
            migrated.append(str(target))

    _rewrite_notification_image_prefixes(dt / "notifications")

    for rel in ("clipboard-index.json", "clipboard-change", "update.log", "update.status.json"):
        target = ca / rel
        existed = target.exists()
        migrate_file(target)
        if not existed and target.exists():
            migrated.append(str(target))

    # Remove emptied legacy `lumeshell/power` and `lumeshell` directories if vacant.
    legacy_power = config_home(env) / "lumeshell" / "power"
    for folder in (legacy_power, legacy_power.parent):
        try:
            if folder.is_dir() and not any(folder.iterdir()):
                folder.rmdir()
        except OSError:
            pass

    return {"migrated": migrated, "symlinks": symlinks}
