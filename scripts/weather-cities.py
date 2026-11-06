#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
import tempfile
from pathlib import Path

from network_utils import prefer_ipv4_resolution

prefer_ipv4_resolution()

import requests

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "quickshell"
STATE_FILE = STATE_DIR / "weather.json"

DEFAULT_STATE = {
    "selected": "auto",
    "cities": [],
}


def load_state():
    try:
        with STATE_FILE.open(encoding="utf-8") as f:
            state = json.load(f)
        if not isinstance(state, dict):
            raise ValueError
        state.setdefault("selected", "auto")
        state.setdefault("cities", [])
        if not isinstance(state["cities"], list):
            state["cities"] = []
        return state
    except (OSError, ValueError, json.JSONDecodeError):
        return dict(DEFAULT_STATE)


def save_state(state):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=STATE_DIR,
        prefix="weather.",
        suffix=".tmp",
        delete=False,
    ) as f:
        json.dump(state, f, ensure_ascii=False, indent=2)
        f.write("\n")
        name = f.name
    os.replace(name, STATE_FILE)


def city_id(name, region, country, lat, lon):
    text = "-".join(x for x in (name, region, country) if x)
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    return f"{text}-{float(lat):.3f}-{float(lon):.3f}"


def public_state(state):
    items = [{
        "id": "auto",
        "name": "Localização automática",
        "region": "",
        "country": "",
        "subtitle": "Detectada pela rede",
        "automatic": True,
        "selected": state.get("selected") == "auto",
    }]
    for c in state.get("cities", []):
        item = dict(c)
        item["automatic"] = False
        item["selected"] = item.get("id") == state.get("selected")
        region_bits = [x for x in (item.get("region"), item.get("country")) if x]
        item["subtitle"] = ", ".join(region_bits)
        items.append(item)

    return {
        "ok": True,
        "version": 1,
        "selected": state.get("selected", "auto"),
        "cities": items,
        "count": len(items),
        "error": None,
    }


def cmd_list(_args):
    print(json.dumps(public_state(load_state()), ensure_ascii=False))


def cmd_search(args):
    query = args.query.strip()
    if len(query) < 2:
        print(json.dumps({"ok": True, "version": 1, "results": [], "error": None}, ensure_ascii=False))
        return

    try:
        r = requests.get(
            "https://geocoding-api.open-meteo.com/v1/search",
            params={
                "name": query,
                "count": 8,
                "language": "pt",
                "format": "json",
            },
            timeout=10,
            headers={"User-Agent": "Quickshell Weather City Manager"},
        )
        r.raise_for_status()
        raw = r.json()

        results = []
        for item in raw.get("results") or []:
            name = str(item.get("name") or "").strip()
            if not name:
                continue

            region = str(item.get("admin1") or "").strip()
            country = str(item.get("country") or "").strip()
            lat = item.get("latitude")
            lon = item.get("longitude")
            if lat is None or lon is None:
                continue

            results.append({
                "id": city_id(name, region, country, lat, lon),
                "name": name,
                "region": region,
                "country": country,
                "latitude": float(lat),
                "longitude": float(lon),
                "subtitle": ", ".join(x for x in (region, country) if x),
            })

        print(json.dumps({"ok": True, "version": 1, "results": results, "error": None}, ensure_ascii=False))
    except Exception as exc:
        print(json.dumps({
            "ok": False,
            "version": 1,
            "results": [],
            "error": f"Falha ao buscar cidades: {exc.__class__.__name__}",
        }, ensure_ascii=False))
        sys.exit(1)


def cmd_add(args):
    state = load_state()

    c = {
        "id": args.id,
        "name": args.name,
        "region": args.region or "",
        "country": args.country or "",
        "latitude": float(args.latitude),
        "longitude": float(args.longitude),
    }

    found = False
    new = []
    for old in state["cities"]:
        if old.get("id") == c["id"]:
            new.append(c)
            found = True
        else:
            new.append(old)

    if not found:
        new.append(c)

    state["cities"] = new
    state["selected"] = c["id"]
    save_state(state)
    print(json.dumps(public_state(state), ensure_ascii=False))


def cmd_select(args):
    state = load_state()
    target = args.id

    if target == "auto":
        state["selected"] = "auto"
    elif any(c.get("id") == target for c in state["cities"]):
        state["selected"] = target
    else:
        err_res = public_state(state)
        err_res["ok"] = False
        err_res["error"] = f"Cidade não encontrada: {target}"
        print(json.dumps(err_res, ensure_ascii=False))
        sys.exit(1)

    save_state(state)
    print(json.dumps(public_state(state), ensure_ascii=False))


def cmd_remove(args):
    state = load_state()
    target = args.id

    if target == "auto":
        print(json.dumps(public_state(state), ensure_ascii=False))
        return

    state["cities"] = [c for c in state["cities"] if c.get("id") != target]

    if state.get("selected") == target:
        state["selected"] = "auto"

    save_state(state)
    print(json.dumps(public_state(state), ensure_ascii=False))


def cmd_cycle(args):
    state = load_state()
    ids = ["auto"] + [c.get("id") for c in state["cities"] if c.get("id")]
    if not ids:
        ids = ["auto"]

    current = state.get("selected", "auto")
    try:
        idx = ids.index(current)
    except ValueError:
        idx = 0

    step = 1 if args.direction == "next" else -1
    state["selected"] = ids[(idx + step) % len(ids)]
    save_state(state)
    print(json.dumps(public_state(state), ensure_ascii=False))


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("list")
    sp.set_defaults(func=cmd_list)

    sp = sub.add_parser("search")
    sp.add_argument("query")
    sp.set_defaults(func=cmd_search)

    sp = sub.add_parser("add")
    sp.add_argument("--id", required=True)
    sp.add_argument("--name", required=True)
    sp.add_argument("--region", default="")
    sp.add_argument("--country", default="")
    sp.add_argument("--latitude", required=True, type=float)
    sp.add_argument("--longitude", required=True, type=float)
    sp.set_defaults(func=cmd_add)

    sp = sub.add_parser("select")
    sp.add_argument("id")
    sp.set_defaults(func=cmd_select)

    sp = sub.add_parser("remove")
    sp.add_argument("id")
    sp.set_defaults(func=cmd_remove)

    sp = sub.add_parser("cycle")
    sp.add_argument("direction", choices=["next", "prev"])
    sp.set_defaults(func=cmd_cycle)

    args = p.parse_args()
    try:
        args.func(args)
    except requests.RequestException as exc:
        print(json.dumps({
            "ok": False,
            "version": 1,
            "error": f"Falha de rede: {exc.__class__.__name__}",
            "results": [],
        }, ensure_ascii=False))
        sys.exit(1)


if __name__ == "__main__":
    main()
