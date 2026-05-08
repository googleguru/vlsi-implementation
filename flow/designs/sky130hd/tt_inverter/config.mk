# ============================================================
# OpenROAD-flow-scripts (ORFS) design config — tt_um_inverter
# Target: SKY130HD (sky130_fd_sc_hd) | TinyTapeout tile area
# ============================================================

export DESIGN_NICKNAME = tt_inverter
export DESIGN_NAME     = tt_um_inverter
export PLATFORM        = sky130hd

# ── RTL sources ─────────────────────────────────────────────
export VERILOG_FILES = \
    $(DESIGN_DIR)/../../src/$(DESIGN_NICKNAME)/inverter.v \
    $(DESIGN_DIR)/../../src/$(DESIGN_NICKNAME)/tt_um_inverter.v

# ── Timing constraints ───────────────────────────────────────
# 10 ns period = 100 MHz — standard TinyTapeout clock
export SDC_FILE = $(DESIGN_DIR)/constraint.sdc

# ── Floorplan ────────────────────────────────────────────────
# TinyTapeout single tile: 160 µm × 100 µm
# Core area leaves 10 µm margins on every side for rings/IO
export DIE_AREA  = 0 0 160 100
export CORE_AREA = 10 10 150 90

# Override FP_SIZING; fixed absolute coordinates above take precedence
export CORE_UTILIZATION  = 35
export CORE_ASPECT_RATIO = 1
export CORE_MARGIN       = 2

# ── Cell padding & density ───────────────────────────────────
# 2 site-widths per cell; combats detailed-routing congestion
export CELL_PAD_IN_SITES_GLOBAL_PLACEMENT = 2
export CELL_PAD_IN_SITES_DETAIL_PLACEMENT = 1

export PLACE_DENSITY = 0.50

# ── Synthesis ────────────────────────────────────────────────
# AREA 0 — no buffering for area opt; pure logic mapping
export ABC_AREA = 1

# Disable arithmetic adder mapping (not needed for inverter)
export ADDER_MAP_FILE :=

# ── CTS ──────────────────────────────────────────────────────
# Inverter is combinational; CTS still runs to satisfy ORFS flow
# but produces a trivial clock tree through clkbuf_1
export CTS_CLOCK_BUFFER_LIST = \
    sky130_fd_sc_hd__clkbuf_1 \
    sky130_fd_sc_hd__clkbuf_2 \
    sky130_fd_sc_hd__clkbuf_4

# ── Tapcells ─────────────────────────────────────────────────
# 14 µm spacing — matches platform tapcell.tcl default
export TAPCELL_TCL = $(PLATFORM_DIR)/tapcell.tcl

# ── Timing endpoint ──────────────────────────────────────────
export TNS_END_PERCENT = 100

# ── GDS / SPEF ───────────────────────────────────────────────
# Stream-out uses Magic; KLayout provides secondary DRC check
export USE_FILL = 1
