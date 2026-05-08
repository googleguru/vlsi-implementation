#!/usr/bin/env bash
# ============================================================
# setup_pdk.sh — Install SKY130A via volare (PDK version manager)
#
# volare pins the PDK commit to the exact version OpenLane
# 2023.07.19-1 was qualified against, ensuring bit-exact
# reproducibility of DRC rules, cell libraries, and timing models.
#
# Usage:
#   export PDK_ROOT=$HOME/.pdks   # or any writable path
#   bash scripts/setup_pdk.sh
# ============================================================
set -euo pipefail

PDK_ROOT="${PDK_ROOT:-$HOME/.pdks}"
# OpenLane 2023.07.19-1 requires this exact PDK commit
PDK_COMMIT="0fe599b2afb6708d281543108caf8310912f54af"
PDK="sky130A"

echo "==> PDK_ROOT : $PDK_ROOT"
echo "==> PDK      : $PDK  (commit $PDK_COMMIT)"

# ── Install volare if absent ──────────────────────────────────
if ! command -v volare &>/dev/null; then
    echo "==> Installing volare …"
    pip3 install --quiet volare
fi

# ── Download and activate PDK ─────────────────────────────────
echo "==> Downloading SKY130A (this may take several minutes) …"
volare enable \
    --pdk sky130 \
    --pdk-root "$PDK_ROOT" \
    "$PDK_COMMIT"

echo ""
echo "==> PDK installed at: $PDK_ROOT/$PDK"
echo "==> Key paths:"
echo "      Tech LEF : $PDK_ROOT/$PDK/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd.tlef"
echo "      Lib  TT  : $PDK_ROOT/$PDK/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
echo ""
echo "==> Run 'make flow' to start the RTL-to-GDSII flow."
