#!/usr/bin/env python3
"""Resolve update logs and expose their last result to the shell UI."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


def log_paths(env: dict[str, str] | None = None, fallback: Path | None = None) -> tuple[Path, Path]:
    env = env or os.environ
    cache = Path(env.get("XDG_CACHE_HOME") or (Path(env.get("HOME", str(Path.home()))) / ".cache"))
    primary = cache / "quickshell" / "update.log"
    fallback = fallback or Path("/tmp") / f"quickshell-update-{os.getuid()}.log"
    return primary, fallback


def prepare_log(env: dict[str, str] | None = None, fallback: Path | None = None) -> Path:
    """Create/truncate the preferred log, falling back to /tmp if needed."""
    for path in log_paths(env, fallback):
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("", encoding="utf-8")
            for candidate in log_paths(env, fallback):
                try:
                    candidate.with_suffix(".status.json").unlink(missing_ok=True)
                except OSError:
                    pass
            return path
        except OSError:
            continue
    raise OSError("não foi possível criar o log no cache nem no caminho temporário")


def existing_log(env: dict[str, str] | None = None, fallback: Path | None = None) -> Path:
    for path in log_paths(env, fallback):
        try:
            if path.is_file() and os.access(path, os.R_OK) and path.stat().st_size > 0:
                return path
        except OSError:
            continue
    raise FileNotFoundError("nenhum log de atualização disponível")


def envelope(ok: bool, data: dict[str, Any] | None = None, error: str | None = None) -> dict[str, Any]:
    return {"ok": ok, "version": 1, "data": data or {}, "error": error}


def read_status(env: dict[str, str] | None = None, fallback: Path | None = None) -> dict[str, Any]:
    candidates = []
    for log_path in log_paths(env, fallback):
        status_path = log_path.with_suffix(".status.json")
        try:
            if status_path.is_file():
                candidates.append((status_path.stat().st_mtime, status_path))
        except (OSError, json.JSONDecodeError):
            continue
    for _, status_path in sorted(candidates, reverse=True):
        try:
            saved = json.loads(status_path.read_text(encoding="utf-8"))
            if isinstance(saved, dict) and isinstance(saved.get("text"), str):
                return envelope(True, {"has_status": True, "succeeded": bool(saved.get("succeeded")), "text": saved["text"]})
        except (OSError, json.JSONDecodeError):
            continue
    return envelope(True, {"has_status": False, "succeeded": False, "text": ""})


def record_status(succeeded: bool, text: str, env: dict[str, str] | None = None,
                  fallback: Path | None = None, log_path: Path | None = None) -> None:
    paths = log_paths(env, fallback)
    log_path = log_path or next((p for p in paths if p.exists()), paths[0])
    status_path = log_path.with_suffix(".status.json")
    temp_path = status_path.with_suffix(status_path.suffix + ".tmp")
    temp_path.write_text(json.dumps({"succeeded": succeeded, "text": text}, ensure_ascii=False), encoding="utf-8")
    temp_path.replace(status_path)


def open_log(env: dict[str, str] | None = None, fallback: Path | None = None,
             kitty: str | None = None) -> dict[str, Any]:
    terminal = kitty or shutil.which("kitty")
    if not terminal:
        return envelope(False, error="Kitty não está instalado; não foi possível abrir o log.")
    try:
        log_path = existing_log(env, fallback)
        subprocess.Popen(
            [terminal, "--hold", "tail", "-n", "100", "-f", "--", str(log_path)],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except (OSError, FileNotFoundError) as error:
        return envelope(False, error=str(error))
    return envelope(True, {"path": str(log_path)})


def main(argv: list[str]) -> int:
    command = argv[1] if len(argv) > 1 else "status"
    if command == "prepare":
        try:
            print(prepare_log())
            return 0
        except OSError as error:
            print(str(error), file=sys.stderr)
            return 1
    if command == "open":
        response = open_log()
        print(json.dumps(response, ensure_ascii=False))
        return 0 if response["ok"] else 1
    if command == "status":
        print(json.dumps(read_status(), ensure_ascii=False))
        return 0
    if command == "record-status" and len(argv) >= 4:
        try:
            record_status(argv[2].lower() in ("true", "1", "yes"), argv[3], log_path=Path(argv[4]) if len(argv) > 4 else None)
            return 0
        except OSError as error:
            print(str(error), file=sys.stderr)
            return 1
    print("uso: update-log.py {prepare|open|status|record-status <ok> <texto>}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
