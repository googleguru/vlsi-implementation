#!/usr/bin/env bash
# ============================================================
# run_checks.sh — TinyTapeout signoff checklist for tt_um_inverter
#
# Parses OpenLane run output reports and emits a pass/fail
# checklist against TinyTapeout submission criteria.
#
# Usage (from project root, after 'make flow'):
#   bash scripts/run_checks.sh [RUN_TAG]
#
# If RUN_TAG is omitted, the most-recent run/ directory is used.
# ============================================================
set -euo pipefail

DESIGN="${DESIGN_NAME:-tt_um_inverter}"
PROJECT="${PROJECT_ROOT:-$(pwd)}"
RUNS_BASE="${PROJECT}/openlane/${DESIGN}/runs"

# ── Find run directory ────────────────────────────────────────
if [ -n "${1:-}" ]; then
    RUN_DIR="${RUNS_BASE}/${1}"
else
    RUN_DIR=$(ls -1dt "${RUNS_BASE}"/run_* 2>/dev/null | head -1)
fi

if [ -z "${RUN_DIR}" ] || [ ! -d "${RUN_DIR}" ]; then
    echo "ERROR: No run directory found under ${RUNS_BASE}" >&2
    echo "       Run 'make flow' first, or pass a tag: $0 run_YYYYMMDD_HHMMSS" >&2
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " TinyTapeout Signoff Checklist — ${DESIGN}"
printf " Run dir: %-52s\n" "$(basename "${RUN_DIR}")"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PASS=0; FAIL=0; WARN=0

check_file() {
    local label="$1" path="$2"
    if [ -f "$path" ]; then
        echo "  [PASS] $label"
        PASS=$((PASS+1))
    else
        echo "  [FAIL] $label — file not found: $path"
        FAIL=$((FAIL+1))
    fi
}

check_grep() {
    local label="$1" pattern="$2" path="$3" invert="${4:-}"
    if [ ! -f "$path" ]; then
        echo "  [SKIP] $label — report not found"
        return
    fi
    local hit
    if [ -n "$invert" ]; then
        hit=$(grep -c "$pattern" "$path" 2>/dev/null || true)
        [ "$hit" -eq 0 ] && { echo "  [PASS] $label"; PASS=$((PASS+1)); } \
                          || { echo "  [FAIL] $label ($hit matches for '$pattern')"; FAIL=$((FAIL+1)); }
    else
        hit=$(grep -c "$pattern" "$path" 2>/dev/null || true)
        [ "$hit" -gt 0 ] && { echo "  [PASS] $label"; PASS=$((PASS+1)); } \
                          || { echo "  [FAIL] $label (pattern '$pattern' not found)"; FAIL=$((FAIL+1)); }
    fi
}

check_metric() {
    local label="$1" file="$2" key="$3" max="$4"
    if [ ! -f "$file" ]; then
        echo "  [SKIP] $label — metrics file missing"
        return
    fi
    local val
    val=$(python3 -c "import json,sys; d=json.load(open('$file')); print(d.get('$key','N/A'))" 2>/dev/null || echo "N/A")
    if [ "$val" = "N/A" ]; then
        echo "  [SKIP] $label — key '$key' not in metrics"
    elif python3 -c "import sys; sys.exit(0 if float('$val') <= $max else 1)" 2>/dev/null; then
        echo "  [PASS] $label = $val (≤ $max)"
        PASS=$((PASS+1))
    else
        echo "  [WARN] $label = $val (> $max — check tolerance)"
        WARN=$((WARN+1))
    fi
}

RESULTS="${RUN_DIR}/results"
REPORTS="${RUN_DIR}/reports"
METRICS="${RUN_DIR}/metrics.csv"

# ── 1. Artifacts present ─────────────────────────────────────
echo ""
echo "── Artifacts ────────────────────────────────────────────"
check_file "Synthesized netlist"  "${RESULTS}/synthesis/${DESIGN}.v"
check_file "Floorplan DEF"        "${RESULTS}/floorplan/${DESIGN}.def"
check_file "Placed DEF"           "${RESULTS}/placement/${DESIGN}.def"
check_file "Routed DEF"           "${RESULTS}/routing/${DESIGN}.def"
check_file "SPEF parasitics"      "${RESULTS}/routing/${DESIGN}.spef"
check_file "GDSII (Magic)"        "${RESULTS}/magic/${DESIGN}.gds"
check_file "GDSII (KLayout)"      "${RESULTS}/klayout/${DESIGN}.gds"
check_file "Abstract LEF"         "${RESULTS}/magic/${DESIGN}.lef"

# ── 2. DRC clean ─────────────────────────────────────────────
echo ""
echo "── DRC (Magic) ──────────────────────────────────────────"
DRC_LOG="${REPORTS}/magic_drc/${DESIGN}.drc"
if [ -f "$DRC_LOG" ]; then
    DRC_COUNT=$(grep -c "^\[" "$DRC_LOG" 2>/dev/null || true)
    if [ "$DRC_COUNT" -eq 0 ]; then
        echo "  [PASS] Magic DRC — 0 violations"
        PASS=$((PASS+1))
    else
        echo "  [FAIL] Magic DRC — $DRC_COUNT violation(s) found"
        FAIL=$((FAIL+1))
        grep "^\[" "$DRC_LOG" | head -5 | sed 's/^/         /'
    fi
else
    echo "  [SKIP] DRC report not found"
fi

# ── 3. LVS clean ─────────────────────────────────────────────
echo ""
echo "── LVS (Netgen) ─────────────────────────────────────────"
LVS_LOG=$(find "${REPORTS}/lvs" -name "*.lvs.lef.log" 2>/dev/null | head -1)
if [ -n "$LVS_LOG" ]; then
    if grep -q "Circuits match uniquely" "$LVS_LOG" 2>/dev/null; then
        echo "  [PASS] LVS — circuits match uniquely"
        PASS=$((PASS+1))
    else
        echo "  [FAIL] LVS — mismatch detected"
        FAIL=$((FAIL+1))
        grep -E "Error|mismatch|FAIL" "$LVS_LOG" | head -5 | sed 's/^/         /'
    fi
else
    echo "  [SKIP] LVS log not found"
fi

# ── 4. Antenna clean ─────────────────────────────────────────
echo ""
echo "── Antenna (OpenROAD / Magic) ───────────────────────────"
ANTENNA_RPT=$(find "${REPORTS}" -name "*antenna*" 2>/dev/null | head -1)
if [ -n "$ANTENNA_RPT" ]; then
    ANT_VIOL=$(grep -c "Antenna violation" "$ANTENNA_RPT" 2>/dev/null || true)
    if [ "$ANT_VIOL" -eq 0 ]; then
        echo "  [PASS] Antenna — 0 violations"
        PASS=$((PASS+1))
    else
        echo "  [WARN] Antenna — $ANT_VIOL violation(s) (check if inserted diodes resolved them)"
        WARN=$((WARN+1))
    fi
else
    echo "  [SKIP] Antenna report not found"
fi

# ── 5. Timing clean ──────────────────────────────────────────
echo ""
echo "── Timing (OpenSTA post-route) ──────────────────────────"
STA_RPT=$(find "${REPORTS}" -name "*sta*" -name "*.rpt" 2>/dev/null | grep -v "synth" | head -1)
if [ -n "$STA_RPT" ]; then
    WNS=$(grep "wns" "$STA_RPT" 2>/dev/null | awk '{print $NF}' | head -1 || echo "N/A")
    TNS=$(grep "tns" "$STA_RPT" 2>/dev/null | awk '{print $NF}' | head -1 || echo "N/A")
    echo "  [INFO] WNS = ${WNS} ns  |  TNS = ${TNS} ns"
    if python3 -c "import sys; sys.exit(0 if float('${WNS:-0}') >= 0 else 1)" 2>/dev/null; then
        echo "  [PASS] No setup violations (WNS ≥ 0)"
        PASS=$((PASS+1))
    else
        echo "  [WARN] Setup violation — WNS < 0 ns (may need clock relaxation)"
        WARN=$((WARN+1))
    fi
else
    echo "  [SKIP] Post-route STA report not found"
fi

# ── 6. TinyTapeout area constraint ───────────────────────────
echo ""
echo "── Area constraint (≤ 160×100 µm) ──────────────────────"
SYNTH_STAT=$(find "${REPORTS}/synthesis" -name "*.stat.rpt" 2>/dev/null | head -1)
if [ -n "$SYNTH_STAT" ]; then
    CHIP_AREA=$(grep "Chip area" "$SYNTH_STAT" 2>/dev/null | awk '{print $NF}' || echo "N/A")
    echo "  [INFO] Synthesised chip area = ${CHIP_AREA} µm²"
    # 160×100 = 16000 µm² — single TT tile
    if python3 -c "import sys; sys.exit(0 if float('${CHIP_AREA:-0}') <= 16000 else 1)" 2>/dev/null; then
        echo "  [PASS] Area within single TT tile (≤ 16000 µm²)"
        PASS=$((PASS+1))
    else
        echo "  [WARN] Area exceeds single tile — may need multi-tile submission"
        WARN=$((WARN+1))
    fi
fi

# ── Summary ───────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf " Signoff result:  PASS=%d  FAIL=%d  WARN=%d  SKIP=%d\n" \
       "$PASS" "$FAIL" "$WARN" \
       "$(( (PASS+FAIL+WARN) - (PASS+FAIL+WARN) ))"

if [ "$FAIL" -eq 0 ]; then
    if [ "$WARN" -eq 0 ]; then
        echo " Status: READY FOR TINYTAPEOUT SUBMISSION"
    else
        echo " Status: CONDITIONAL — review WARNs before submission"
    fi
else
    echo " Status: NOT READY — fix FAILs then re-run signoff"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Exit non-zero so CI fails on hard errors
[ "$FAIL" -eq 0 ]
