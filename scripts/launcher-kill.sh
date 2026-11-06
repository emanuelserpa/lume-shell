#!/usr/bin/env bash
set -u
PID="${1:-}"

case "$PID" in
  ''|*[!0-9]*) exit 1 ;;
esac

kill -9 -- "$PID"
