#!/usr/bin/env bash
# lets yay build as the user while elevating only its pacman commands via Polkit.
set -u

if [[ "${1:-}" == "-v" ]]; then
  # yay may probe sudo before installation; the real authorization is requested
  # by pkexec when pacman is actually invoked.
  exit 0
fi

if [[ "${1:-}" == "pacman" || "${1:-}" == "/usr/bin/pacman" ]]; then
  shift
  exec pkexec /usr/bin/pacman "$@"
fi

exec pkexec "$@"
