#!/usr/bin/env python3
import sys
import time
from pathlib import Path

Path(sys.argv[1]).write_text("started", encoding="utf-8")
print('{"ok":true,"version":1,"data":{"text":"stale"}}', flush=True)
time.sleep(12)
