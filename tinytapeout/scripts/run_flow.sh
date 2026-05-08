#!/usr/bin/env bash
# ============================================================
# run_flow.sh — OpenLane RTL-to-GDSII driver for tt_um_inverter
#
# Must be called INSIDE the OpenLane Docker container, or via:
#   docker compose run --rm flow bash /project/scripts/run_flow.sh [MODE]
#
# MODE (optional, default = full):
#   full        — run every stage end-to-end
#   synthesis   — yosys / abc / OpenSTA (pre-place)
#   floorplan   — init_fp + ioplacer + pdngen + tapcell
#   placement   — RePLace + Resizer + OpenDP
#   cts         — TritonCTS
#   routing     — FastRoute + TritonRoute
#   extraction  — OpenRCX (SPEF)
#   gds         — Magic + KLayout stream-out
#   signoff     — Magic DRC + Netgen LVS + antenna check
#
# Stage boundaries map to OpenLane internal stage names:
#   synthesis → floorplan → placement → cts → routing →
#   extraction → magic → magic_drc → lvs → antenna
# ============================================================
set -euo pipefail

DESIGN="${DESIGN_NAME:-tt_um_inverter}"
OPENLANE="${OPENLANE_ROOT:-/openlane}"
PROJECT="${PROJECT_ROOT:-/project}"
TAG="run_$(date +%Y%m%d_%H%M%S)"
MODE="${1:-full}"

# Link design into OpenLane's designs directory
ln -sf "${PROJECT}/openlane/${DESIGN}" "${OPENLANE}/designs/${DESIGN}"

# ── Stage dispatch ────────────────────────────────────────────
run_stage() {
    local from="$1" to="$2"
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║  OpenLane stage: ${from} → ${to}"
    printf "║  Tag: %-43s║\n" "$TAG"
    echo "╚══════════════════════════════════════════════════╝"
    cd "${OPENLANE}"
    flow.tcl -design "${DESIGN}" -tag "${TAG}" \
             -from "${from}" -to "${to}" -overwrite
}

case "$MODE" in
  full)
      echo "==> Full RTL-to-GDSII flow (tag: $TAG)"
      cd "${OPENLANE}"
      flow.tcl -design "${DESIGN}" -tag "${TAG}" -overwrite
      ;;
  synthesis)
      run_stage synthesis synthesis
      ;;
  floorplan)
      run_stage floorplan floorplan
      ;;
  placement)
      run_stage placement placement
      ;;
  cts)
      run_stage cts cts
      ;;
  routing)
      run_stage routing routing
      ;;
  extraction)
      run_stage extraction extraction
      ;;
  gds)
      run_stage magic magic
      ;;
  signoff)
      run_stage magic_drc lvs
      ;;
  *)
      echo "ERROR: unknown mode '$MODE'" >&2
      echo "Valid modes: full synthesis floorplan placement cts routing extraction gds signoff" >&2
      exit 1
      ;;
esac

# ── Output summary ────────────────────────────────────────────
RUNS_DIR="${PROJECT}/openlane/${DESIGN}/runs/${TAG}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Stage outputs in: $RUNS_DIR"
echo ""

print_if_exists() { [ -f "$1" ] && echo "  ✓ $2: $1" || echo "  ✗ $2: not yet generated"; }

print_if_exists "${RUNS_DIR}/results/synthesis/${DESIGN}.v"         "Synthesized netlist"
print_if_exists "${RUNS_DIR}/results/floorplan/${DESIGN}.def"       "Floorplan DEF"
print_if_exists "${RUNS_DIR}/results/placement/${DESIGN}.def"       "Placed DEF"
print_if_exists "${RUNS_DIR}/results/cts/${DESIGN}.def"             "CTS DEF"
print_if_exists "${RUNS_DIR}/results/routing/${DESIGN}.def"         "Routed DEF"
print_if_exists "${RUNS_DIR}/results/routing/${DESIGN}.spef"        "SPEF (parasitics)"
print_if_exists "${RUNS_DIR}/results/magic/${DESIGN}.gds"           "GDSII (Magic)"
print_if_exists "${RUNS_DIR}/results/klayout/${DESIGN}.gds"         "GDSII (KLayout)"
print_if_exists "${RUNS_DIR}/reports/magic_drc/${DESIGN}.drc"       "DRC report"
print_if_exists "${RUNS_DIR}/reports/lvs/${DESIGN}.lvs.lef.log"     "LVS report"
print_if_exists "${RUNS_DIR}/reports/antenna/${DESIGN}_antenna.rpt" "Antenna report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
