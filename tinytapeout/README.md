# TinyTapeout CMOS Inverter — RTL-to-GDSII on SKY130HD

Complete OpenLane / OpenROAD-flow-scripts implementation of a TinyTapeout-compatible
CMOS inverter targeting the SkyWater SKY130 130 nm process node.
Packaged in Docker for deterministic, reproducible execution across systems.

---

## Table of Contents

1. [Design overview](#1-design-overview)
2. [TinyTapeout tile layout](#2-tinytapeout-tile-layout)
3. [RTL-to-GDSII pipeline](#3-rtl-to-gdsii-pipeline)
4. [Repository structure](#4-repository-structure)
5. [Quick start](#5-quick-start)
6. [Stage-by-stage reference](#6-stage-by-stage-reference)
   - 6.1 Synthesis (yosys / abc / OpenSTA)
   - 6.2 Floorplan (init\_fp / ioplacer / pdngen / tapcell)
   - 6.3 Placement (RePLace / Resizer / OpenDP)
   - 6.4 CTS (TritonCTS)
   - 6.5 Routing (FastRoute / TritonRoute)
   - 6.6 Parasitic extraction (OpenRCX)
   - 6.7 GDS stream-out (Magic / KLayout)
   - 6.8 Signoff (DRC / LVS / antenna / STA)
7. [Docker reference](#7-docker-reference)
8. [ORFS-native flow](#8-orfs-native-flow)
9. [Expected outputs](#9-expected-outputs)
10. [TinyTapeout signoff checklist](#10-tinytapeout-signoff-checklist)
11. [Technical constraints](#11-technical-constraints)

---

## 1. Design overview

| Parameter         | Value                              |
|-------------------|------------------------------------|
| Top module        | `tt_um_inverter`                   |
| Logic             | `uo_out[0] = ~ui_in[0]`           |
| PDK               | SkyWater SKY130A                   |
| Standard-cell lib | `sky130_fd_sc_hd` (high-density)  |
| Die area          | 160 µm × 100 µm (1 TT tile)       |
| Core area         | 140 µm × 80 µm (10 µm margins)    |
| Core utilisation  | 35 %                               |
| Target clock      | 100 MHz (10 ns period)             |
| Flow              | OpenLane 2023.07.19-1 / ORFS      |
| CTS               | Disabled (combinational design)    |

The inverter instantiates a single `sky130_fd_sc_hd__inv_X` cell.
All 35 TinyTapeout bus ports are present to satisfy the wrapper DRC;
unused ports are tied off inside the module with a constant-folded
AND to prevent inferred logic.

---

## 2. TinyTapeout tile layout

```
                    160 µm
     ┌──────────────────────────────────────────────────────────┐
     │◄──────────────── die boundary ─────────────────────────►│
     │  ┌────────────────────────────────────────────────────┐  │
     │  │  N edge — uio_out[7:0]  uio_oe[7:0]               │  │
     │  │  ┌──────────────────────────────────────────────┐  │  │ 1
     │  │  │                                              │  │  │ 0
  W  │  │  │   met5 horizontal strap (VDD/VSS)  ─────    │  │  │ 0
  e  │  │  │   ──────────────────────────────────         │  │  │
  s  │  │  │                                              │  │  │ µ
  t  │  │  │   ┌─────────────────────────────────┐       │  │  │ m
     │  │  │   │  sky130_fd_sc_hd__inv_1 (×1)   │       │  │  │
  u  │  │  │   │  sky130_fd_sc_hd__conb_1 (×N)  │       │  │  │
  i  │  │  │   │  sky130_fd_sc_hd__tapvpwrvgnd_1│       │  │  │
  _  │  │  │   │  sky130_fd_sc_hd__fill_X        │       │  │  │
  i  │  │  │   └─────────────────────────────────┘       │  │  │
  n  │  │  │                                              │  │  │
  [  │  │  │   met4 vertical strap (VDD/VSS)  │││        │  │  │
  7  │  │  │   ─────────────────────────────────          │  │  │
  : ─┤  │  │                              core area       │  │  ├─ u
  0  │  │  │   met1 followpin rails ══════════════        │  │  │  o
  ]  │  │  │   (VDD row / VSS row alternating)            │  │  │  _
     │  │  └──────────────────────────────────────────────┘  │  │  o
     │  │  S edge — uio_in[7:0]  ena  rst_n  clk             │  │  u
     │  └────────────────────────────────────────────────────┘  │  t
     │◄── 10 µm ring ──────────────────────────── 10 µm ring ──►│  [
     └──────────────────────────────────────────────────────────┘  7
                                                                    :
                    Pin placement (OpenLane ioplacer)               0
                                                                    ]
  West  (ui_in[7:0])      ──►  inverter  ──►  East  (uo_out[7:0])
  North (uio_out[7:0], uio_oe[7:0])
  South (uio_in[7:0], ena, rst_n, clk)
```

### TinyTapeout bus mapping

```
  TT wrapper (upstream)                  tt_um_inverter tile
  ─────────────────────                  ──────────────────────────────────
  ui_in[7:0]   ──────────────────────►  ui_in[7:0]
                                              │ [0]: active input
                                              ▼
                                         sky130_fd_sc_hd__inv_1
                                              │
  uo_out[7:0]  ◄──────────────────────  uo_out[7:0]
                                              [0]: inverted output
                                              [7:1]: tied LOW
  uio_in[7:0]  ──────────────────────►  uio_in[7:0]  (unused, tied off)
  uio_out[7:0] ◄──────────────────────  uio_out[7:0]  = 8'h00
  uio_oe[7:0]  ◄──────────────────────  uio_oe[7:0]   = 8'h00 (all inputs)
  clk          ──────────────────────►  clk     (present, unused by logic)
  rst_n        ──────────────────────►  rst_n   (present, unused by logic)
  ena          ──────────────────────►  ena     (present, unused by logic)
```

---

## 3. RTL-to-GDSII pipeline

```
  ╔══════════════════════════════════════════════════════════════════════╗
  ║                    RTL-to-GDSII Flow — tt_um_inverter               ║
  ║                    SKY130HD · OpenLane 2023.07.19-1                 ║
  ╚══════════════════════════════════════════════════════════════════════╝

  ┌──────────────┐
  │  RTL source  │  src/inverter.v
  │  (Verilog)   │  src/tt_um_inverter.v
  └──────┬───────┘
         │
         ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  STAGE 1 · SYNTHESIS                                                 │
  │  Tool: yosys + abc                                                   │
  │  ├─ yosys: parse RTL → RTLIL → logic optimisation                   │
  │  ├─ synth_sky130: technology mapping to sky130_fd_sc_hd Liberty      │
  │  └─ abc: area-optimised mapping (AREA 0 script)                      │
  │                                                                      │
  │  OpenSTA (pre-place): wire-load STA, no parasitics                  │
  │                                                                      │
  │  Output: tt_um_inverter.v  (mapped gate netlist)                     │
  └──────┬───────────────────────────────────────────────────────────────┘
         │  mapped netlist + constraints.sdc
         ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  STAGE 2 · FLOORPLAN                                                 │
  │  ├─ init_fp:   die 160×100, core 140×80, row/track creation          │
  │  ├─ ioplacer:  pin_order.cfg → West/East/North/South assignment      │
  │  ├─ pdngen:    met1 followpin + met4 vert + met5 horiz straps        │
  │  └─ tapcell:   tapvpwrvgnd_1 every 14 µm (well-contact DRC rule)    │
  │                                                                      │
  │  Output: tt_um_inverter.def  (floorplan DEF)                         │
  └──────┬───────────────────────────────────────────────────────────────┘
         │  floorplan DEF + ODB
         ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  STAGE 3 · PLACEMENT                                                 │
  │  ├─ RePLace:  global placement, density=0.50, routability-driven     │
  │  ├─ Resizer: timing opt (buffer insert / gate sizing / wire trim)    │
  │  └─ OpenDP:  detail placement legalisation, site alignment           │
  │                                                                      │
  │  Output: tt_um_inverter.def  (placed DEF)                            │
  └──────┬───────────────────────────────────────────────────────────────┘
         │  placed DEF + ODB
         ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  STAGE 4 · CTS — Clock Tree Synthesis                                │
  │  Tool: TritonCTS                                                     │
  │  ⚠  RUN_CTS=0 for this design (purely combinational inverter)        │
  │     Clock port exists on TT wrapper spec; no registers to drive.     │
  │     SDC false-paths rst_n / ena; clock constrained for STA only.    │
  │                                                                      │
  │  Output: tt_um_inverter.def  (= placed DEF, unmodified)              │
  └──────┬───────────────────────────────────────────────────────────────┘
         │  placed DEF
         ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  STAGE 5 · ROUTING                                                   │
  │  ├─ FastRoute:    global routing — net decomposition, layer assign   │
  │  │                GRT_ADJUSTMENT=0.3, OVERFLOW_ITERS=50             │
  │  └─ TritonRoute: detailed routing — DRC-correct segment geometry     │
  │                  Antenna repair: DIODE_INSERTION_STRATEGY=3          │
  │                                                                      │
  │  Output: tt_um_inverter.def (routed DEF)                             │
  │          tt_um_inverter.guide (global route guides)                  │
  └──────┬───────────────────────────────────────────────────────────────┘
         │  routed DEF
         ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  STAGE 6 · PARASITIC EXTRACTION                                      │
  │  Tool: OpenRCX                                                       │
  │  ├─ Reads routed DEF + rcx_patterns.rules (sky130hd)                │
  │  ├─ Builds distributed R/C network per net                           │
  │  └─ Writes SPEF; feeds back into OpenROAD for post-route STA        │
  │                                                                      │
  │  Output: tt_um_inverter.spef                                         │
  │          reports/routing/sta-rcx.min_max.rpt                         │
  └──────┬───────────────────────────────────────────────────────────────┘
         │  routed DEF + SPEF
         ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  STAGE 7 · GDS STREAM-OUT                                            │
  │  ├─ Magic:   def2stream with sky130A.tech                            │
  │  │           primary GDSII + abstract LEF (MAGIC_EXT_USE_GDS=1)     │
  │  └─ KLayout: secondary stream-out; XOR vs Magic GDS for cross-check  │
  │                                                                      │
  │  Output: results/magic/tt_um_inverter.gds    ← submission GDS        │
  │          results/magic/tt_um_inverter.lef    ← abstract LEF          │
  │          results/klayout/tt_um_inverter.gds  ← cross-check GDS       │
  └──────┬───────────────────────────────────────────────────────────────┘
         │  GDS
         ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  STAGE 8 · SIGNOFF                                                   │
  │  ├─ Magic DRC:   sky130A rules on GDS → violation count = 0 target  │
  │  ├─ Netgen LVS:  GDS-extracted netlist vs synthesis netlist          │
  │  │               pass condition: "Circuits match uniquely."          │
  │  ├─ CVC:         circuit validity check (antenna ratio per net)      │
  │  └─ OpenSTA:     post-route STA with SPEF back-annotation            │
  │                  WNS ≥ 0 ns, TNS = 0 ns target                      │
  │                                                                      │
  │  Output: reports/magic_drc/tt_um_inverter.drc                        │
  │          reports/lvs/tt_um_inverter.lvs.lef.log                      │
  │          reports/antenna/tt_um_inverter_antenna.rpt                  │
  └──────┬───────────────────────────────────────────────────────────────┘
         │
         ▼
  ┌──────────────┐
  │  GDSII ready │  → TinyTapeout submission portal
  │  for submit  │    results/magic/tt_um_inverter.gds
  └──────────────┘
```

### Power delivery cross-section

```
  met5 ══════════════════════════════════════  horizontal strap (VDD)
        ══════════════════════════════════════  horizontal strap (VSS)

  met4   ║   ║   ║   ║   ║   ║   ║   ║   ║   vertical straps (VDD/VSS alternating)

  met1  ───────────────────────────────────── followpin VDD (top of each row)
        ───────────────────────────────────── followpin VSS (bottom of each row)
                                                pitch = std-cell row height (2.72 µm)
  li1    standard-cell internal routing
  ─────  met1  ─────────────────────────────
  ─────  met2  (signal routing)
  ─────  met3  (signal routing)
  ═════  met4  (power strap, 1.6 µm wide, 27.14 µm pitch)
  ═════  met5  (power strap, 1.6 µm wide, 27.20 µm pitch)
```

---

## 4. Repository structure

```
vlsi-implementation/
│
├── flow/                                   OpenROAD-flow-scripts (ORFS)
│   ├── Makefile                            ← tt_inverter line activated
│   ├── designs/
│   │   ├── src/tt_inverter/
│   │   │   ├── inverter.v                  combinational primitive
│   │   │   └── tt_um_inverter.v            TinyTapeout v5 wrapper
│   │   └── sky130hd/tt_inverter/
│   │       ├── config.mk                   ORFS design config
│   │       └── constraint.sdc              SDC — 100 MHz, IO delays, false paths
│   └── platforms/sky130hd/                 (unchanged — reused)
│
└── tinytapeout/                            self-contained OpenLane project
    ├── Dockerfile                          extends efabless/openlane:2023.07.19-1
    ├── docker-compose.yml                  services: flow | shell | sim
    ├── Makefile                            per-stage make targets
    ├── info.yaml                           TinyTapeout submission metadata
    ├── README.md                           ← this file
    ├── src/
    │   ├── inverter.v                      RTL primitive
    │   └── tt_um_inverter.v               TT top-level
    ├── test/
    │   └── tb_tt_um_inverter.v            256-pattern sweep testbench
    ├── openlane/tt_um_inverter/
    │   ├── config.json                     OpenLane 1.x configuration
    │   ├── pin_order.cfg                   ioplacer pin assignment
    │   ├── pdn.tcl                         PDN (met1/met4/met5)
    │   └── constraints.sdc                 OpenSTA timing constraints
    └── scripts/
        ├── setup_pdk.sh                    volare → SKY130A commit 0fe599b2
        ├── run_flow.sh                     stage dispatcher (inside container)
        └── run_checks.sh                   signoff checklist parser
```

---

## 5. Quick start

```bash
# Clone if needed
git clone https://github.com/googleguru/vlsi-implementation
cd vlsi-implementation/tinytapeout

# Step 1 — install SKY130A PDK (one-time, ~1 GB)
export PDK_ROOT=$HOME/.pdks
bash scripts/setup_pdk.sh

# Step 2 — pull the OpenLane container
make pull

# Step 3 — RTL simulation (requires iverilog on host)
make sim

# Step 4 — full RTL-to-GDSII (~20 min, 4 cores)
make flow

# Step 5 — parse signoff reports
bash scripts/run_checks.sh
```

---

## 6. Stage-by-stage reference

### 6.1 Synthesis — `yosys / abc / OpenSTA`

**Purpose:** Convert RTL to a technology-mapped gate netlist; static timing
analysis without parasitics.

```bash
make synthesis
# inside container equivalent:
# flow.tcl -design tt_um_inverter -to synthesis -overwrite
```

**yosys pass sequence:**

| Pass | Action |
|------|--------|
| `read_verilog` | parse `inverter.v` + `tt_um_inverter.v` |
| `synth_sky130` | flatten, FSM extract, memory map, tech map |
| `dfflibmap` | map flip-flops to `sky130_fd_sc_hd` FF cells |
| `abc -liberty` | Boolean optimisation + cell mapping (AREA 0 script) |
| `clean` | remove dangling wires |
| `write_verilog` | emit gate netlist |

**Expected cell count for this inverter:** 1× `inv_1` + ~3× `conb_1` (tie-offs)

**Output files:**

```
runs/<tag>/results/synthesis/
  tt_um_inverter.v             gate-level netlist
  tt_um_inverter.stat          area/cell count summary

runs/<tag>/reports/synthesis/
  1-synthesis.AREA_0.stat.rpt  abc area report
  opensta.min_max.rpt          pre-place WNS/TNS
  opensta_pre_sta.rpt          full timing paths
```

---

### 6.2 Floorplan — `init_fp / ioplacer / pdngen / tapcell`

**Purpose:** Define physical die boundaries, place IO pins at tile edges,
generate power grid, insert well-tap cells.

```bash
make floorplan
# flow.tcl -design tt_um_inverter -from floorplan -to floorplan -overwrite
```

**Sub-steps:**

```
init_fp
  DIE_AREA  = 0 0 160 100 µm
  CORE_AREA = 10 10 150 90 µm
  Creates site rows (sky130_fd_sc_hd row height = 2.72 µm → 29 rows in 80 µm)
  Creates routing tracks from sky130_fd_sc_hd.tlef

ioplacer  (reads pin_order.cfg)
  West  → ui_in[7:0]
  East  → uo_out[7:0]
  North → uio_out[7:0], uio_oe[7:0]
  South → uio_in[7:0], ena, rst_n, clk

pdngen  (reads pdn.tcl)
  met1 followpin  width=0.48 µm, pitch=5.44 µm (one per row pair)
  met4 vert strap width=1.60 µm, pitch=27.14 µm, offset=13.57 µm
  met5 horiz strap width=1.60 µm, pitch=27.20 µm, offset=13.60 µm
  Connections: met1↔met4, met4↔met5

tapcell
  sky130_fd_sc_hd__tapvpwrvgnd_1
  distance = 14 µm  (required by SKY130 well-tap DRC rule)
```

**Output files:**

```
runs/<tag>/results/floorplan/
  tt_um_inverter.def   floorplan DEF (die, core, IO, rows, PDN)
  tt_um_inverter.odb   OpenDB binary snapshot

runs/<tag>/reports/floorplan/
  core_util.rpt        utilisation breakdown
```

---

### 6.3 Placement — `RePLace / Resizer / OpenDP`

**Purpose:** Optimally place standard cells minimising wirelength and
satisfying timing and routability constraints.

```bash
make placement
# flow.tcl -design tt_um_inverter -from placement -to placement -overwrite
```

**Sub-steps:**

```
RePLace  (global placement)
  PL_TARGET_DENSITY      = 0.50  (50% cell density target)
  PL_ROUTABILITY_DRIVEN  = 1     (congestion-aware spreading)
  Objective: HPWL + routability penalty

Resizer  (sizing / buffering)
  PL_RESIZER_DESIGN_OPTIMIZATIONS = 1  (gate sizing for area)
  PL_RESIZER_TIMING_OPTIMIZATIONS = 1  (buffer insertion for WNS)
  PL_RESIZER_MAX_WIRE_LENGTH       = 500 µm

OpenDP   (detail placement)
  Cell padding: 4 sites during global, 2 after legalization
  Legalizes to row/site grid; resolves overlaps
```

**Output files:**

```
runs/<tag>/results/placement/
  tt_um_inverter.def   legally placed DEF

runs/<tag>/reports/placement/
  replace.log          wirelength / overflow log
  resizer.log          buffer/sizing changes
  opendp.log           placement density
  opensta.timing.rpt   post-placement STA
```

---

### 6.4 CTS — `TritonCTS`

**Purpose:** Build a balanced clock tree to minimise skew across all
clock endpoints.

```
RUN_CTS = 0  (disabled for this design)
```

Rationale: `tt_um_inverter` is purely combinational. The `clk` port exists
to satisfy the TinyTapeout wrapper interface and is constrained in the SDC,
but drives zero registers. TritonCTS would insert unnecessary clock buffers.

The `clk` port is false-pathed from `rst_n`/`ena` in the SDC; OpenSTA still
analyses the clock domain for the combinational propagation delay.

---

### 6.5 Routing — `FastRoute / TritonRoute`

**Purpose:** Assign physical wire segments to routing layers, resolving all
DRC constraints including spacing, via, and antenna rules.

```bash
make routing
# flow.tcl -design tt_um_inverter -from routing -to routing -overwrite
```

**Sub-steps:**

```
FastRoute  (global routing)
  GRT_ADJUSTMENT     = 0.3   (30% capacity reduction for margin)
  GRT_OVERFLOW_ITERS = 50    (rip-up-and-reroute iterations)
  Layer assignment: li1/met1 (local) → met2/met3 (intermediate)

TritonRoute  (detailed routing)
  DRC-correct segment geometry on every layer
  Antenna repair: DIODE_INSERTION_STRATEGY=3
    → inserts sky130_fd_sc_hd__diode_2 during global-route phase
    → re-checks antenna ratios post-detail-route

SKY130HD routing stack:
  li1   0.17 µm min-width  (local interconnect, intra-cell)
  met1  0.14 µm            (horizontal preferred)
  met2  0.14 µm            (vertical preferred)
  met3  0.30 µm            (horizontal preferred)
  met4  0.30 µm            (vertical — PDN strap)
  met5  1.60 µm            (horizontal — PDN strap)
```

**Output files:**

```
runs/<tag>/results/routing/
  tt_um_inverter.def    fully routed DEF
  tt_um_inverter.guide  FastRoute global guides

runs/<tag>/reports/routing/
  tritonRoute.drc       post-route DRC (target: 0 violations)
  antenna.rpt           net antenna ratios
```

---

### 6.6 Parasitic extraction — `OpenRCX`

**Purpose:** Extract distributed R/C parasitics from the routed layout for
high-accuracy post-route static timing analysis.

```bash
make extraction
# flow.tcl -design tt_um_inverter -from extraction -to extraction -overwrite
```

```
OpenRCX
  Rules:    sky130hd rcx_patterns.rules
  Model:    field-solver-calibrated RC tables for met1–met5
  Output:   SPEF (Standard Parasitic Exchange Format)

  For each wire segment:
    R = sheet_resistance × length / width
    C = area_cap × area + fringe_cap × perimeter

  SPEF written back into OpenROAD database for:
    - Post-route STA (hold/setup with real wire delays)
    - IR-drop analysis (if enabled)
```

**Output files:**

```
runs/<tag>/results/routing/
  tt_um_inverter.spef         extracted parasitics

runs/<tag>/reports/routing/
  sta-rcx.min_max.rpt         final WNS / TNS with parasitics
  sta-rcx_hold.min.rpt        hold slack report
  sta-rcx_setup.max.rpt       setup slack report
```

---

### 6.7 GDS stream-out — `Magic / KLayout`

**Purpose:** Convert the routed database to GDSII for fabrication.

```bash
make gds
# flow.tcl -design tt_um_inverter -from magic -to magic -overwrite
```

```
Magic
  Technology: sky130A.tech
  Command:    def2stream → reads routed DEF + GDS for std cells
  Merges:     cell GDS from sky130_fd_sc_hd GDS library
  Output:     primary GDSII + abstract LEF
  MAGIC_EXT_USE_GDS=1 → Magic reads from GDS for LVS extraction

KLayout
  Independent stream-out using sky130hd.lyt + sky130hd.lyp
  XOR vs Magic GDS: any geometry difference flags a tool mismatch
  KLAYOUT_DRC_KLAYOUT_GDS=1 → KLayout runs its own DRC pass
```

**Output files:**

```
runs/<tag>/results/magic/
  tt_um_inverter.gds    primary GDSII  ← TinyTapeout submission file
  tt_um_inverter.lef    abstract LEF (used by wrapper integration)

runs/<tag>/results/klayout/
  tt_um_inverter.gds    KLayout secondary GDS
```

---

### 6.8 Signoff — `Magic DRC / Netgen LVS / CVC antenna / OpenSTA`

**Purpose:** Verify the final GDS meets all fabrication, connectivity,
and timing requirements before tape-out.

```bash
make signoff
bash scripts/run_checks.sh
```

**DRC (Magic)**

```
Magic reads tt_um_inverter.gds with sky130A DRC rules.
All SKY130 rules checked including:
  - Minimum width/spacing per layer
  - Enclosure and extension rules
  - Well/implant coverage
  - Via enclosure
Target: 0 DRC violations.
```

**LVS (Netgen)**

```
Netgen compares:
  Source:  synthesis netlist (tt_um_inverter.v)
  Layout:  GDS-extracted spice netlist (Magic lvs extraction)
Match criterion: "Circuits match uniquely."
Checks: net connectivity, device count, parameter matching.
```

**Antenna check (CVC / OpenROAD)**

```
Per net: (metal area connected to gate) / (gate oxide area) ≤ ratio limit
SKY130 antenna ratio limits (default):
  met1: 400×    met2: 400×    met3: 400×
  met4: 400×    met5: 400×
Diode insertion (DIODE_INSERTION_STRATEGY=3) resolves violations
by adding sky130_fd_sc_hd__diode_2 on long nets during routing.
```

**Post-route STA (OpenSTA + SPEF)**

```
Clock: 10 ns period
Setup check: launch_edge + combinational_delay + setup_margin ≤ capture_edge
             WNS target ≥ 0 ns  (no setup violation)
Hold  check: capture_edge + hold_margin ≤ launch_edge + min_delay
             WHS target ≥ 0 ns  (no hold violation)

For the inverter (no registers), STA verifies only:
  - Input→output combinational delay < (period − IO delay budget)
  - Slew on uo_out[0] meets max-slew DRC from Liberty
```

---

## 7. Docker reference

### Container image

```
efabless/openlane:2023.07.19-1
  OpenLane:   1.x (flow.tcl)
  yosys:      0.26+
  OpenROAD:   2023.07 (includes OpenDP, TritonCTS, FastRoute, TritonRoute,
                        OpenRCX, OpenSTA, Resizer, pdngen)
  Magic:      8.3.x
  KLayout:    0.28.x
  Netgen:     1.5.x
  PDK:        NOT included — mount from host via $PDK_ROOT
```

### Volume mounts

```
Host path          Container path    Purpose
─────────────────  ────────────────  ──────────────────────────────
$(pwd)             /project          project source + run outputs
$PDK_ROOT          /pdks             SKY130A PDK (LibreEDA / volare)
```

### Environment variables

```bash
PDK_ROOT=/pdks              # where SKY130A is installed inside container
PDK=sky130A                 # PDK variant
STD_CELL_LIBRARY=sky130_fd_sc_hd
DESIGN_NAME=tt_um_inverter
PROJECT_ROOT=/project
OPENLANE_ROOT=/openlane
```

### Manual stage commands (inside container shell)

```bash
# Enter interactive container
make mount          # from host

# Inside container — link design then run stages
ln -sf /project/openlane/tt_um_inverter /openlane/designs/tt_um_inverter
cd /openlane

# Run a single stage (both -from and -to required for stage isolation)
flow.tcl -design tt_um_inverter -tag debug -from synthesis  -to synthesis  -overwrite
flow.tcl -design tt_um_inverter -tag debug -from floorplan  -to floorplan  -overwrite
flow.tcl -design tt_um_inverter -tag debug -from placement  -to placement  -overwrite
flow.tcl -design tt_um_inverter -tag debug -from cts        -to cts        -overwrite
flow.tcl -design tt_um_inverter -tag debug -from routing    -to routing    -overwrite
flow.tcl -design tt_um_inverter -tag debug -from extraction -to extraction -overwrite
flow.tcl -design tt_um_inverter -tag debug -from magic      -to magic      -overwrite
flow.tcl -design tt_um_inverter -tag debug -from magic_drc  -to lvs        -overwrite

# Open OpenROAD GUI to inspect a stage snapshot
cd /project/openlane/tt_um_inverter/runs/debug
openroad -gui results/placement/tt_um_inverter.odb

# Open Magic for layout inspection
magic -T /pdks/sky130A/libs.tech/magic/sky130A.tech \
      results/magic/tt_um_inverter.gds

# Run Netgen LVS manually
netgen -batch lvs \
  "results/magic/tt_um_inverter.spice tt_um_inverter" \
  "results/synthesis/tt_um_inverter.v tt_um_inverter" \
  /pdks/sky130A/libs.tech/netgen/sky130A_setup.tcl \
  reports/lvs/tt_um_inverter.lvs.lef.log

# Rebuild from scratch
make clean && make flow
```

### docker compose shortcuts

```bash
docker compose run --rm flow          # full RTL-to-GDSII
docker compose run --rm shell         # interactive shell
docker compose run --rm sim           # iverilog simulation
```

---

## 8. ORFS-native flow

The design is also integrated into the OpenROAD-flow-scripts Makefile at
`flow/designs/sky130hd/tt_inverter/config.mk`.

```bash
# From repo root — ORFS must be set up with OpenROAD on PATH
cd flow

# tt_inverter is active in flow/Makefile
make                 # full flow (synth → route → finish)
make synth           # synthesis only
make floorplan       # floorplan only
make place           # placement only
make cts             # CTS only
make route           # routing only
make finish          # GDS + DRC + LVS + reports

# Override design at command line
make DESIGN_CONFIG=./designs/sky130hd/tt_inverter/config.mk route
```

ORFS outputs land in:
```
flow/logs/sky130hd/tt_inverter/<stage>.log
flow/results/sky130hd/tt_inverter/<stage>/
flow/reports/sky130hd/tt_inverter/<stage>/
flow/objects/sky130hd/tt_inverter/<stage>/
```

---

## 9. Expected outputs

| Stage | Key output file | Notes |
|-------|----------------|-------|
| Synthesis | `results/synthesis/tt_um_inverter.v` | 1 inv_1 + tie cells |
| Synthesis STA | `reports/synthesis/opensta.min_max.rpt` | no parasitics |
| Floorplan | `results/floorplan/tt_um_inverter.def` | die/core/IO/PDN |
| Placement | `results/placement/tt_um_inverter.def` | legal cell positions |
| CTS | (same as placement DEF) | RUN_CTS=0 |
| Routing | `results/routing/tt_um_inverter.def` | all nets routed |
| Routing | `results/routing/tt_um_inverter.guide` | FastRoute guides |
| Extraction | `results/routing/tt_um_inverter.spef` | R/C parasitics |
| Post-route STA | `reports/routing/sta-rcx.min_max.rpt` | with SPEF |
| GDS (Magic) | `results/magic/tt_um_inverter.gds` | submission file |
| GDS (KLayout) | `results/klayout/tt_um_inverter.gds` | cross-check |
| Abstract LEF | `results/magic/tt_um_inverter.lef` | for wrapper |
| DRC | `reports/magic_drc/tt_um_inverter.drc` | target: 0 viols |
| LVS | `reports/lvs/tt_um_inverter.lvs.lef.log` | "match uniquely" |
| Antenna | `reports/antenna/tt_um_inverter_antenna.rpt` | target: 0 viols |

---

## 10. TinyTapeout signoff checklist

Run `bash scripts/run_checks.sh` after `make flow` to get an automated
pass/fail summary. The checks map to the following criteria:

```
┌─────────────────────────────────────────────────────────┬────────┐
│ Check                                                   │ Target │
├─────────────────────────────────────────────────────────┼────────┤
│ Synthesized netlist present                             │  PASS  │
│ Floorplan DEF present                                   │  PASS  │
│ Placed DEF present                                      │  PASS  │
│ Routed DEF present                                      │  PASS  │
│ SPEF parasitics present                                 │  PASS  │
│ GDSII (Magic) present                                   │  PASS  │
│ GDSII (KLayout) present                                 │  PASS  │
│ Abstract LEF present                                    │  PASS  │
├─────────────────────────────────────────────────────────┼────────┤
│ Magic DRC — violation count                             │   = 0  │
│ Netgen LVS — "Circuits match uniquely"                  │  true  │
│ Antenna violations after diode insertion                │   = 0  │
│ Post-route WNS (setup slack, 100 MHz)                   │  ≥ 0 ns│
│ Post-route WHS (hold slack)                             │  ≥ 0 ns│
│ Chip area ≤ 16 000 µm² (160×100 µm tile)               │  true  │
└─────────────────────────────────────────────────────────┴────────┘
```

When all checks pass, upload `results/magic/tt_um_inverter.gds` to the
TinyTapeout submission portal and reference `info.yaml` for project metadata.

---

## 11. Technical constraints

| Constraint | Value |
|------------|-------|
| PDK | SkyWater SKY130A (`sky130A`) |
| Standard-cell library | `sky130_fd_sc_hd` (1.8 V, high-density) |
| Technology node | 130 nm |
| Die area | 160 µm × 100 µm |
| Core area | 140 µm × 80 µm |
| Core utilisation | 35 % |
| Row height (std-cell) | 2.72 µm |
| Metal layers used | li1, met1, met2, met3 (signal) + met4, met5 (PDN) |
| Min metal width | li1: 0.17 µm, met1: 0.14 µm, met2: 0.14 µm |
| VDD / VSS | 1.8 V nominal |
| Clock | 10 ns period (100 MHz), `sky130_fd_sc_hd__tt_025C_1v80.lib` |
| Tapcell spacing | 14 µm (`tapvpwrvgnd_1`) |
| Antenna strategy | Global-route diode insertion (strategy 3) |
| OpenLane image | `efabless/openlane:2023.07.19-1` |
| SKY130A PDK commit | `0fe599b2afb6708d281543108caf8310912f54af` (volare) |
