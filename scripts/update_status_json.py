"""Serialize the common update-provider JSON envelope."""
import json
import sys


def build_payload(arguments):
    status, text, tooltip, count, *items = arguments
    return {
        "status": status,
        "text": text,
        "tooltip": tooltip,
        "count": int(count),
        "items": items,
    }


def main(arguments=None):
    values = sys.argv[1:] if arguments is None else arguments
    print(json.dumps(build_payload(values), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
