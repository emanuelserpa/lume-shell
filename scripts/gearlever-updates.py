#!/usr/bin/env python3
"""Query Gear Lever's machine-readable AppImage update list."""
import json
import shutil

from command_utils import run_command

APP_ID = "it.mijorus.gearlever"
VERSION = 1


def payload_for_updates(stdout, returncode=0, stderr=""):
    if returncode != 0:
        status = "timeout" if returncode == 124 else "error"
        detail = stderr.strip() or "Gear Lever não conseguiu consultar atualizações."
        return {
            "status": status,
            "text": "",
            "tooltip": f"AppImages (Gear Lever)\n\n{detail}",
            "count": 0,
            "items": [],
        }

    try:
        document = json.loads(stdout)
    except (TypeError, json.JSONDecodeError):
        document = None

    if (
        not isinstance(document, dict)
        or document.get("schema_version") != VERSION
        or not isinstance(document.get("updates"), list)
    ):
        return {
            "status": "error",
            "text": "",
            "tooltip": "AppImages (Gear Lever)\n\nResposta JSON inválida.",
            "count": 0,
            "items": [],
        }

    items = []
    for app in document["updates"]:
        if not isinstance(app, dict):
            continue
        name = str(app.get("name") or "").strip()
        if name:
            items.append(name)

    count = len(items)
    tooltip = "AppImages (Gear Lever)\n\n"
    tooltip += "\n".join(items[:20]) if items else "Tudo atualizado!"
    return {
        "status": "updates" if count else "ok",
        "text": f"󰏗 {count}" if count else "",
        "tooltip": tooltip,
        "count": count,
        "items": items,
    }


def query_updates(flatpak_binary=None):
    flatpak = flatpak_binary or shutil.which("flatpak") or "/usr/bin/flatpak"
    if not shutil.which(flatpak):
        return payload_for_updates("", returncode=127, stderr="Flatpak não encontrado.")

    returncode, stdout, stderr = run_command(
        [flatpak, "run", APP_ID, "--list-updates", "--json"],
        timeout=120,
        timeout_code=124,
        timeout_message="A consulta do Gear Lever expirou.",
    )
    return payload_for_updates(stdout, returncode, stderr)


def main():
    print(json.dumps(query_updates(), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
