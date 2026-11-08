#!/usr/bin/env python3
import os
import sys
import time
from pathlib import Path

starts = Path(os.environ["LUME_STORE_STARTS_FILE"])
with starts.open("a", encoding="utf-8") as stream:
    stream.write(f"{time.monotonic_ns()}\n")
print("controlled notification store failure", file=sys.stderr, flush=True)
raise SystemExit(23)
