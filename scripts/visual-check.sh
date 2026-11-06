#!/usr/bin/env bash
# =============================================================================
# visual-check.sh — Lightweight Visual Regression & Environment Verification
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
RESET="\033[0m"

echo -e "${BOLD}${CYAN}=== Quickshell Visual Regression & Surface Verification ===${RESET}\n"

FAIL_COUNT=0
CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-}"
CURRENT_DESKTOP="${CURRENT_DESKTOP,,}"

# 1. Quickshell Service Health
echo -e "${BOLD}[1/4] Checking quickshell.service status...${RESET}"
if systemctl --user is-active --quiet quickshell.service; then
    echo -e "  ${GREEN}✓${RESET} quickshell.service is running (active)"
else
    echo -e "  ${RED}✗${RESET} quickshell.service is NOT running"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 2. Wayland Layer-Shell Surfaces (hyprctl layers)
echo -e "\n${BOLD}[2/4] Verifying Wayland Layer-Shell surfaces...${RESET}"
if [[ ":${CURRENT_DESKTOP}:" == *:hyprland:* ]] && command -v hyprctl >/dev/null 2>&1; then
    layers_output="$(hyprctl layers 2>/dev/null || true)"
    if echo "$layers_output" | grep "namespace: quickshell" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${RESET} quickshell layer-shell surface detected"

        # Check height metric (expected 37px)
        if echo "$layers_output" | grep -E "namespace: quickshell" -B 1 | grep -E "xywh: [0-9]+ [0-9]+ [0-9]+ 37" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${RESET} Bar height verified: 37px exact (exclusiveZone standard)"
        else
            echo -e "  ${YELLOW}!${RESET} Notice: bar height may differ from 37px"
        fi
    else
        echo -e "  ${RED}✗${RESET} No quickshell layer surface found in hyprctl layers"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "  ${YELLOW}!${RESET} Hyprland layer check skipped for this session"
fi

# 3. Typography Verification (Noto Sans & JetBrainsMono)
echo -e "\n${BOLD}[3/4] Checking required typography...${RESET}"
if command -v fc-list >/dev/null 2>&1; then
    has_noto=false
    has_mono=false
    if fc-list : family | grep -i "Noto Sans" >/dev/null 2>&1; then
        has_noto=true
        echo -e "  ${GREEN}✓${RESET} Primary UI font found: Noto Sans"
    else
        echo -e "  ${RED}✗${RESET} Primary UI font missing: Noto Sans"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    if fc-list : family | grep -i "JetBrainsMono" >/dev/null 2>&1; then
        has_mono=true
        echo -e "  ${GREEN}✓${RESET} Monospace & Nerd Font found: JetBrainsMono Nerd Font"
    else
        echo -e "  ${YELLOW}!${RESET} Monospace font warning: JetBrainsMono Nerd Font"
    fi
else
    echo -e "  ${YELLOW}!${RESET} fc-list not available (skipped font check)"
fi

# 4. Visual Checklist Summary
echo -e "\n${BOLD}[4/4] Visual Checklist Reference:${RESET}"
echo -e "  Detailed contract: ${CYAN}docs/visual-regression-checklist.md${RESET}"
echo -e "  Key visual items to confirm visually on desktop:"
echo -e "    - [ ] Top bar margins (3px inset, 9px radius, centered clusters)"
echo -e "    - [ ] Center dashboard (Escape dismiss, 3 proportional columns, page dots < 840px)"
echo -e "    - [ ] Spotlight launcher (SUPER+D: 560px modal, SUPER+C: 820x500px split-view)"
echo -e "    - [ ] Hardware popups (Network after Tray, Bluetooth, Audio sliders, Media blur)"
echo -e "    - [ ] Notification toasts (Top-right 12px margins, zero ghost bubbles)"

echo ""
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}Visual environment verification passed!${RESET}\n"
    exit 0
else
    echo -e "${RED}${BOLD}Visual verification reported $FAIL_COUNT issue(s).${RESET}\n"
    exit 1
fi
