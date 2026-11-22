#!/bin/bash
exec python3 -B "$(dirname "$0")/network-ping.py" "$@"
