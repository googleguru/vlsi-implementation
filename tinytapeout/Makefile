# ============================================================
# Makefile — tt_um_inverter  OpenLane / SKY130HD flow
#
# Usage:
#   make pull          # pull openlane image
#   make setup-pdk     # download & install SKY130A (volare)
#   make sim           # RTL simulation (icarus verilog)
#   make flow          # full RTL-to-GDSII in Docker
#   make synthesis     # synthesis only (yosys/abc)
#   make floorplan     # floorplan (init_fp + io + pdn + tapcell)
#   make placement     # global + detail placement
#   make cts           # clock tree synthesis (trivial for inverter)
#   make routing       # global (FastRoute) + detail (TritonRoute)
#   make extraction    # OpenRCX parasitic extraction → SPEF
#   make gds           # GDS stream-out via Magic
#   make signoff       # DRC (Magic) + LVS (Netgen) + antenna
#   make clean         # remove all run outputs
#   make mount         # drop into an interactive Docker shell
# ============================================================

DESIGN_NAME     := tt_um_inverter
OPENLANE_IMAGE  := efabless/openlane:2023.07.19-1
PDK             := sky130A
STD_CELL_LIB    := sky130_fd_sc_hd

# ── Host paths ───────────────────────────────────────────────
PROJECT_DIR     := $(abspath .)
PDK_ROOT        ?= $(HOME)/.pdks
RUN_TAG         ?= run_$(shell date +%Y%m%d_%H%M%S)

# ── Docker base command ──────────────────────────────────────
# Mounts project at /project and PDK at /pdks.
# Symlinks the design directory into /openlane/designs/ before
# every flow command so flow.tcl finds the config.
DOCKER_BASE := docker run --rm \
    -v "$(PROJECT_DIR)":/project \
    -v "$(PDK_ROOT)":/pdks \
    -e PDK_ROOT=/pdks \
    -e PDK=$(PDK) \
    -e STD_CELL_LIBRARY=$(STD_CELL_LIB) \
    $(OPENLANE_IMAGE)

# Prefix that links the design then execs the payload
LINK_AND := bash -c ' \
    ln -sf /project/openlane/$(DESIGN_NAME) \
           /openlane/designs/$(DESIGN_NAME) &&

# ── Per-stage flow.tcl invocation helper ─────────────────────
# $(call STAGE, from, to) → flow.tcl with -from -to flags
STAGE = $(LINK_AND) \
    flow.tcl -design $(DESIGN_NAME) -tag $(RUN_TAG) \
    -from $(1) -to $(2) -overwrite'

# ============================================================
.PHONY: all pull setup-pdk sim \
        flow synthesis floorplan placement cts routing \
        extraction gds signoff mount clean

all: flow

# ── Pull Docker image ────────────────────────────────────────
pull:
	docker pull $(OPENLANE_IMAGE)

# ── Install SKY130A PDK via volare ──────────────────────────
setup-pdk:
	bash scripts/setup_pdk.sh

# ── RTL simulation (no Docker needed — uses host iverilog) ──
sim:
	@command -v iverilog >/dev/null 2>&1 || \
	    { echo "iverilog not found; install with: sudo apt install iverilog"; exit 1; }
	iverilog -g2012 -o /tmp/tb_tt_um_inverter \
	    test/tb_tt_um_inverter.v \
	    src/inverter.v \
	    src/ca235_cell.v \
	    src/ca235_row.v \
	    src/tt_um_inverter.v
	vvp /tmp/tb_tt_um_inverter

# ── Full RTL-to-GDSII ────────────────────────────────────────
flow:
	$(DOCKER_BASE) bash -c '\
	    ln -sf /project/openlane/$(DESIGN_NAME) \
	           /openlane/designs/$(DESIGN_NAME) && \
	    flow.tcl -design $(DESIGN_NAME) -tag $(RUN_TAG) -overwrite'

# ── Stage: synthesis (yosys → abc → OpenSTA) ────────────────
# Outputs:
#   openlane/tt_um_inverter/runs/<tag>/results/synthesis/
#     tt_um_inverter.v              — mapped netlist
#     tt_um_inverter.stat           — cell count / area
#   openlane/tt_um_inverter/runs/<tag>/reports/synthesis/
#     1-synthesis.AREA_0.stat.rpt   — synthesis report
#     opensta.min_max.rpt           — pre-place STA
synthesis:
	$(DOCKER_BASE) bash -c '\
	    ln -sf /project/openlane/$(DESIGN_NAME) \
	           /openlane/designs/$(DESIGN_NAME) && \
	    flow.tcl -design $(DESIGN_NAME) -tag $(RUN_TAG) \
	             -to synthesis -overwrite'

# ── Stage: floorplan (init_fp + ioplacer + pdngen + tapcell) ─
# Outputs:
#   results/floorplan/tt_um_inverter.def  — floorplan DEF
#   results/floorplan/tt_um_inverter.odb  — OpenDB snapshot
#   reports/floorplan/                    — core-utilization log
floorplan:
	$(DOCKER_BASE) bash -c '\
	    ln -sf /project/openlane/$(DESIGN_NAME) \
	           /openlane/designs/$(DESIGN_NAME) && \
	    flow.tcl -design $(DESIGN_NAME) -tag $(RUN_TAG) \
	             -from floorplan -to floorplan -overwrite'

# ── Stage: placement (RePLace → Resizer → OpenDP) ────────────
# Outputs:
#   results/placement/tt_um_inverter.def  — placed DEF
#   reports/placement/                    — timing / DRC reports
placement:
	$(DOCKER_BASE) bash -c '\
	    ln -sf /project/openlane/$(DESIGN_NAME) \
	           /openlane/designs/$(DESIGN_NAME) && \
	    flow.tcl -design $(DESIGN_NAME) -tag $(RUN_TAG) \
	             -from placement -to placement -overwrite'

# ── Stage: CTS (TritonCTS) ───────────────────────────────────
# Outputs:
#   results/cts/tt_um_inverter.def        — CTS DEF
#   reports/cts/                          — skew / buffer reports
cts:
	$(DOCKER_BASE) bash -c '\
	    ln -sf /project/openlane/$(DESIGN_NAME) \
	           /openlane/designs/$(DESIGN_NAME) && \
	    flow.tcl -design $(DESIGN_NAME) -tag $(RUN_TAG) \
	             -from cts -to cts -overwrite'

# ── Stage: routing (FastRoute → TritonRoute) ─────────────────
# Outputs:
#   results/routing/tt_um_inverter.def    — routed DEF
#   results/routing/tt_um_inverter.guide  — global route guides
#   reports/routing/                      — DRC / antenna reports
routing:
	$(DOCKER_BASE) bash -c '\
	    ln -sf /project/openlane/$(DESIGN_NAME) \
	           /openlane/designs/$(DESIGN_NAME) && \
	    flow.tcl -design $(DESIGN_NAME) -tag $(RUN_TAG) \
	             -from routing -to routing -overwrite'

# ── Stage: extraction (OpenRCX → SPEF) ───────────────────────
# Outputs:
#   results/routing/tt_um_inverter.spef   — extracted parasitics
#   reports/routing/sta-rcx*.rpt          — post-extraction STA
extraction:
	$(DOCKER_BASE) bash -c '\
	    ln -sf /project/openlane/$(DESIGN_NAME) \
	           /openlane/designs/$(DESIGN_NAME) && \
	    flow.tcl -design $(DESIGN_NAME) -tag $(RUN_TAG) \
	             -from extraction -to extraction -overwrite'

# ── Stage: GDS stream-out (Magic + KLayout) ──────────────────
# Outputs:
#   results/magic/tt_um_inverter.gds      — primary GDSII
#   results/magic/tt_um_inverter.lef      — abstract LEF
#   results/klayout/tt_um_inverter.gds    — secondary GDSII (XOR check)
gds:
	$(DOCKER_BASE) bash -c '\
	    ln -sf /project/openlane/$(DESIGN_NAME) \
	           /openlane/designs/$(DESIGN_NAME) && \
	    flow.tcl -design $(DESIGN_NAME) -tag $(RUN_TAG) \
	             -from magic -to magic -overwrite'

# ── Stage: signoff (DRC + antenna + LVS + CVC) ───────────────
# Outputs:
#   reports/magic_drc/                    — DRC violations
#   reports/lvs/                          — LVS comparison log
#   reports/antenna/                      — antenna violation list
signoff:
	$(DOCKER_BASE) bash -c '\
	    ln -sf /project/openlane/$(DESIGN_NAME) \
	           /openlane/designs/$(DESIGN_NAME) && \
	    flow.tcl -design $(DESIGN_NAME) -tag $(RUN_TAG) \
	             -from magic_drc -overwrite'
	@echo ""
	@echo "Run scripts/run_checks.sh for a consolidated signoff summary."

# ── Interactive shell ────────────────────────────────────────
mount:
	docker run --rm -it \
	    -v "$(PROJECT_DIR)":/project \
	    -v "$(PDK_ROOT)":/pdks \
	    -e PDK_ROOT=/pdks \
	    -e PDK=$(PDK) \
	    -e STD_CELL_LIBRARY=$(STD_CELL_LIB) \
	    $(OPENLANE_IMAGE) \
	    bash -c '\
	        ln -sf /project/openlane/$(DESIGN_NAME) \
	               /openlane/designs/$(DESIGN_NAME) && \
	        exec bash'

# ── Clean all run outputs ─────────────────────────────────────
clean:
	rm -rf openlane/$(DESIGN_NAME)/runs/
	@echo "Cleaned openlane/$(DESIGN_NAME)/runs/"
