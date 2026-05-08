# VLSI Physical Design — TinyTapeout CMOS Inverter on SKY130HD

[![PDK](https://img.shields.io/badge/PDK-SKY130A%20130nm-blue)](https://skywater-pdk.readthedocs.io)
[![OpenLane](https://img.shields.io/badge/OpenLane-2023.07.19--1-green)](https://github.com/efabless/openlane)
[![ORFS](https://img.shields.io/badge/ORFS-OpenROAD--flow--scripts-blueviolet)](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts)
[![TinyTapeout](https://img.shields.io/badge/TinyTapeout-v5%2Fv6-purple)](https://tinytapeout.com)
[![Build Status](https://jenkins.openroad.tools/buildStatus/icon?job=OpenROAD-flow-scripts-Public%2Fpublic_tests_all%2Fmaster)](https://jenkins.openroad.tools/view/Public/job/OpenROAD-flow-scripts-Public/job/public_tests_all/job/master/)
[![Docs](https://readthedocs.org/projects/openroad-flow-scripts/badge/?version=latest)](https://openroad-flow-scripts.readthedocs.io/en/latest/?badge=latest)
[![License](https://img.shields.io/badge/License-Apache%202.0-lightgrey)](LICENSE_BUILD_RUN_SCRIPTS)

> Complete RTL-to-GDSII implementation of a TinyTapeout-ready CMOS inverter
> using the **OpenLane / SKY130 / CA-235** flow — fully reproducible via Docker.

---

## Table of Contents

1. [Project overview](#1-project-overview)
2. [Repository structure](#2-repository-structure)
3. [CMOS inverter — design](#3-cmos-inverter--design)
4. [CA-235 Cellular Automaton](#4-ca-235-cellular-automaton)
5. [TinyTapeout interface — dual mode](#5-tinytapeout-interface--dual-mode)
6. [RTL source files](#6-rtl-source-files)
7. [OpenLane / SKY130 flow](#7-openlane--sky130-flow)
8. [All flow stages](#8-all-flow-stages)
9. [Docker setup and execution](#9-docker-setup-and-execution)
10. [RTL simulation](#10-rtl-simulation)
11. [Expected outputs](#11-expected-outputs)
12. [TinyTapeout signoff checklist](#12-tinytapeout-signoff-checklist)
13. [ORFS native flow](#13-orfs-native-flow)
14. [Key configuration reference](#14-key-configuration-reference)
15. [Visual outputs](#15-visual-outputs)
16. [OpenROAD-flow-scripts](#16-openroad-flow-scripts)

---

## 1. Project overview

This repository implements a **complete physical design flow** for a CMOS inverter
targeting the **SkyWater SKY130 130 nm open-source PDK**, packaged as a
**TinyTapeout shuttle tile** and processed end-to-end through **OpenLane** in Docker.

The design is also integrated into the **OpenROAD-flow-scripts (ORFS)** Makefile
for native execution without Docker.

### Final deliverables

| Deliverable | Path |
|-------------|------|
| Gate netlist | `results/synthesis/tt_um_inverter.v` |
| Floorplan DEF | `results/floorplan/tt_um_inverter.def` |
| Placed DEF | `results/placement/tt_um_inverter.def` |
| Routed DEF | `results/routing/tt_um_inverter.def` |
| SPEF parasitics | `results/routing/tt_um_inverter.spef` |
| **GDSII (submission)** | **`results/magic/tt_um_inverter.gds`** |
| Abstract LEF | `results/magic/tt_um_inverter.lef` |
| DRC report | `reports/magic_drc/tt_um_inverter.drc` |
| LVS report | `reports/lvs/tt_um_inverter.lvs.lef.log` |
| Antenna report | `reports/antenna/tt_um_inverter_antenna.rpt` |

### Design parameters

| Parameter | Value |
|-----------|-------|
| Top module | `tt_um_inverter` |
| Logic (inverter mode) | `uo_out[0] = ~ui_in[0]` when `ui_in[7]=0` |
| Logic (CA-235 mode) | `uo_out[7:0] = CA-235 next-state(ui_in)` when `ui_in[7]=1` |
| PDK | SkyWater SKY130A |
| Std-cell library | `sky130_fd_sc_hd` (high-density, 1.8 V) |
| Technology node | 130 nm |
| Die area | 160 µm × 100 µm (1 TinyTapeout tile) |
| Core area | 140 µm × 80 µm |
| Core utilisation | 35 % |
| Clock | 100 MHz / 10 ns period |
| CTS | Disabled — 0 flip-flops |
| OpenLane image | `efabless/openlane:2023.07.19-1` |
| PDK commit | `0fe599b2afb6708d281543108caf8310912f54af` |

---

## 2. Repository structure

```
vlsi-implementation/
│
├── README.md                              ← this file
│
├── tinytapeout/                           Self-contained OpenLane project
│   ├── Dockerfile                         Extends efabless/openlane:2023.07.19-1
│   ├── docker-compose.yml                 Services: flow | shell | sim
│   ├── Makefile                           Per-stage targets + clean + mount
│   ├── info.yaml                          TinyTapeout submission metadata
│   ├── README.md                          Full technical reference →
│   ├── src/
│   │   ├── inverter.v                     Core RTL — assign out = ~in
│   │   ├── ca235_cell.v                   CA Rule-235 single cell: next=R|~(L^C)
│   │   ├── ca235_row.v                    N-cell row, wrap-around, genvar
│   │   └── tt_um_inverter.v              Dual-mode: inverter + CA-235
│   ├── test/
│   │   └── tb_tt_um_inverter.v           256-pattern sweep (128 inv + 128 CA-235)
│   ├── openlane/tt_um_inverter/
│   │   ├── config.json                    OpenLane 1.x config
│   │   ├── pin_order.cfg                  IO pin edge assignment (W/E/N/S)
│   │   ├── pdn.tcl                        Power grid met1/met4/met5
│   │   └── constraints.sdc               100 MHz SDC timing constraints
│   └── scripts/
│       ├── setup_pdk.sh                   SKY130A PDK via volare
│       ├── run_flow.sh                    Stage dispatcher (inside container)
│       └── run_checks.sh                  Automated signoff checklist
│
├── docs/visuals/                          Section-level visual outputs
│   ├── 01_ca235_rule/                     CA-235 truth table, evolution, gate SVG
│   ├── 02_rtl_design/                     CMOS schematic, block diagram SVGs
│   ├── 03_openlane_flow/                  Pipeline SVG, stage outputs, Docker
│   ├── 04_floorplan_layout/               Tile floorplan SVG, PDN layers
│   ├── 05_signoff_results/                Signoff checklist, timing analysis
│   └── 06_simulation/                     Waveforms, test vectors
│
├── flow/                                  OpenROAD-flow-scripts (ORFS)
│   ├── Makefile                           ← tt_inverter active design
│   ├── designs/
│   │   ├── src/tt_inverter/
│   │   │   ├── inverter.v
│   │   │   ├── ca235_cell.v
│   │   │   ├── ca235_row.v
│   │   │   └── tt_um_inverter.v
│   │   └── sky130hd/tt_inverter/
│   │       ├── config.mk
│   │       └── constraint.sdc
│   └── platforms/sky130hd/               SKY130HD platform (existing)
│
├── tools/
│   ├── OpenROAD/                          OpenROAD tool source
│   ├── yosys/                             Yosys RTL synthesis
│   └── LSOracle/                          Logic synthesis oracle
│
└── docs/                                  ORFS documentation
```

---

## 3. CMOS inverter — design

A CMOS inverter pairs one PMOS (pull-up) and one NMOS (pull-down) transistor.
After synthesis it maps to `sky130_fd_sc_hd__inv_1` from the SKY130HD library.

```
         VDD (1.8 V)
              │
          ┌───┴───┐
    IN ───┤  PMOS │  (pull-up network)
          │       ├──── OUT = NOT IN
    IN ───┤  NMOS │  (pull-down network)
          └───┬───┘
              │
            VSS (0 V)
```

| IN | PMOS | NMOS | OUT |
|----|------|------|-----|
|  0 | ON   | OFF  |  1  |
|  1 | OFF  | ON   |  0  |

**sky130_fd_sc_hd__inv_1 — propagation delay (TT 25°C 1.8 V):**

```
  tpHL  (1→0)  ≈  0.14 ns
  tpLH  (0→1)  ≈  0.16 ns
  avg tpd      ≈  0.15 ns

  Slack at 100 MHz:
    10 ns period − 2 ns input delay − 2 ns output delay − 0.15 ns tpd
    = 5.85 ns WNS  (no setup violation)
```

---

## 4. CA-235 Cellular Automaton

> Visual: [truth table](docs/visuals/01_ca235_rule/ca235_truth_table.md) · [state evolution](docs/visuals/01_ca235_rule/ca235_state_evolution.md) · [gate circuit SVG](docs/visuals/01_ca235_rule/ca235_cell_circuit.svg) · [8-cell row SVG](docs/visuals/01_ca235_rule/ca235_row_8cell.svg)

**Rule 235 = 0xEB = 0b11101011** — elementary CA in Wolfram's 0–255 numbering.

### Truth table and minimisation

```
Neighborhood {L,C,R}  →  Rule-235 next bit
  111 → 1    110 → 1    101 → 1    100 → 0   ← R=0, L≠C → 0
  011 → 1    010 → 0    001 → 1    000 → 1   ← R=0, L≠C → 0

Zero minterms: {010, 100}  (R=0 AND L≠C)

Karnaugh map (C vs LR):
        LR: 00  01  11  10
  C=0:       1   1   1   0
  C=1:       0   1   1   1

Minimal SOP:  next = R | ~(L ^ C)
Gate count:   XOR2 + INV + OR2  =  3 gates × 8 cells  =  24 gates total
```

### Gate-level circuit (single cell)

![CA-235 cell circuit](docs/visuals/01_ca235_rule/ca235_cell_circuit.svg)

### 8-cell wrap-around row

![CA-235 8-cell row](docs/visuals/01_ca235_rule/ca235_row_8cell.svg)

### State evolution (8-cell periodic boundary)

```
Seed 0x01 (single cell lit):
  Gen 0: ░░ ░░ ░░ ░░ ░░ ░░ ░░ ██  0x01
  Gen 1: ██ ██ ██ ██ ██ ██ ░░ ░░  0xFC
  Gen 2: ██ ██ ██ ██ ██ ██ ██ ░░  0xFE
  Gen 3: ██ ██ ██ ██ ██ ██ ██ ██  0xFF  ← fixed point

Seed 0x55 (alternating):
  Gen 0: ░░ ██ ░░ ██ ░░ ██ ░░ ██  0x55
  Gen 1: ██ ░░ ██ ░░ ██ ░░ ██ ░░  0xAA  ← fixed point

Fixed points: 0xFF (all-ones) and 0xAA (alternating 10101010)
```

### Verilog implementation

```verilog
// ca235_cell.v — single cell
module ca235_cell (input wire L, C, R, output wire next);
    assign next = R | ~(L ^ C);
endmodule

// ca235_row.v — N-cell row with wrap-around (genvar)
module ca235_row #(parameter N = 8) (
    input  wire [N-1:0] state,
    output wire [N-1:0] next_state
);
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : g_cell
            ca235_cell u (.L((i==0) ? state[N-1] : state[i-1]),
                          .C(state[i]),
                          .R((i==N-1) ? state[0] : state[i+1]),
                          .next(next_state[i]));
        end
    endgenerate
endmodule
```

---

## 5. TinyTapeout interface — dual mode

> Visual: [block diagram SVG](docs/visuals/02_rtl_design/dual_mode_top_block.svg) · [port mapping](docs/visuals/02_rtl_design/port_mapping.md)

Every TinyTapeout user module must implement the exact port interface below.

```verilog
module tt_um_<name> (
    input  wire [7:0] ui_in,    // 8 dedicated inputs   (TT mux → tile)
    output wire [7:0] uo_out,   // 8 dedicated outputs  (tile → TT mux)
    input  wire [7:0] uio_in,   // 8 bidir IOs — input path
    output wire [7:0] uio_out,  // 8 bidir IOs — output path
    output wire [7:0] uio_oe,   // 8 bidir IOs — output enable (1=drive)
    input  wire       ena,      // tile power enable
    input  wire       clk,      // system clock (100 MHz)
    input  wire       rst_n     // active-low reset
);
```

**Dual-mode pin mapping:**

```
  ui_in[7]=0  INVERTER MODE:
    ui_in[0]  ──► sky130_fd_sc_hd__inv_1 ──► uo_out[0]
    uo_out[7:1] = 0

  ui_in[7]=1  CA-235 MODE:
    ui_in[7:0] ──► ca235_row (8-cell wrap) ──► uo_out[7:0]
    (ui_in[7]=1 participates as cell 7 center)

  uio_*          never driven — uio_oe = 0x00, uio_out = 0x00
  clk/rst_n/ena  present, unused (combinational design)
```

![Dual-mode top module](docs/visuals/02_rtl_design/dual_mode_top_block.svg)

**Tile boundary (160 µm × 100 µm):**

```
           ┌──── North: uio_out[7:0]  uio_oe[7:0] ────┐
           │                                           │
 West:     │  ╔═══════════════════════════════════╗    │  :East
 ui_in ───►│  ║       tt_um_inverter core          ║   │──► uo_out
 [7:0]     │  ║    140 µm × 80 µm  |  35% util     ║   │    [7:0]
           │  ╚═══════════════════════════════════╝    │
           │                                           │
           └──── South: uio_in[7:0]  ena  rst_n  clk ─┘
```

---

## 6. RTL source files

> Visual: [CMOS schematic SVG](docs/visuals/02_rtl_design/cmos_inverter_schematic.svg) · [port mapping](docs/visuals/02_rtl_design/port_mapping.md)

### `src/inverter.v` — core primitive

```verilog
`default_nettype none
`timescale 1ns / 1ps

module inverter (
    input  wire in,
    output wire out
);
    assign out = ~in;   // → sky130_fd_sc_hd__inv_X after synthesis
endmodule
`default_nettype wire
```

### `src/tt_um_inverter.v` — TinyTapeout dual-mode wrapper

```verilog
module tt_um_inverter ( ... );
    wire inv_out;
    wire [7:0] ca_next;

    inverter u_inv (.in(ui_in[0]), .out(inv_out));

    ca235_row #(.N(8)) u_ca (.state(ui_in), .next_state(ca_next));

    // ui_in[7]=0 → inverter; ui_in[7]=1 → CA-235
    assign uo_out  = ui_in[7] ? ca_next : {7'b0, inv_out};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire _unused_ok = &{ena, clk, rst_n, uio_in};
endmodule
```

**Post-synthesis cell count:**

| Cell | Count | Purpose |
|------|-------|---------|
| `sky130_fd_sc_hd__inv_1` | 1 | CMOS inverter |
| `sky130_fd_sc_hd__xor2_1` | 8 | CA-235 L^C |
| `sky130_fd_sc_hd__inv_X` | 8 | CA-235 ~(L^C) |
| `sky130_fd_sc_hd__or2_1` | 8 | CA-235 R\|~(L^C) |
| `sky130_fd_sc_hd__mux2_1` | 8 | Mode select mux |
| `sky130_fd_sc_hd__conb_1` | ~19 | Tie-off cells |
| **Total** | **~52** | **≈ 130 µm²** |

---

## 7. OpenLane / SKY130 flow

OpenLane runs inside **`efabless/openlane:2023.07.19-1`** and drives all tools
through a single `flow.tcl` script.

```
  Tools in the container:
  ┌──────────────────────────────────────────────────────────────────┐
  │  yosys 0.26+     RTL synthesis + abc technology mapping          │
  │  OpenROAD 2023   Floorplan, placement, routing, STA, RCX         │
  │  Magic 8.3.x     GDS stream-out, DRC, SPICE extraction           │
  │  KLayout 0.28.x  Secondary GDS + DRC cross-check                 │
  │  Netgen 1.5.x    LVS — layout vs schematic                       │
  │  OpenSTA 2.5.x   Static timing analysis                          │
  └──────────────────────────────────────────────────────────────────┘
```

**config.json essentials:**

```json
{
  "DESIGN_NAME"      : "tt_um_inverter",
  "CLOCK_PERIOD"     : 10.0,
  "PDK"              : "sky130A",
  "STD_CELL_LIBRARY" : "sky130_fd_sc_hd",
  "DIE_AREA"         : "0 0 160 100",
  "FP_CORE_UTIL"     : 35,
  "SYNTH_STRATEGY"   : "AREA 0",
  "RUN_CTS"          : 0,
  "DIODE_INSERTION_STRATEGY": 3,
  "PL_TARGET_DENSITY": 0.5
}
```

---

## 8. All flow stages

> Visual: [pipeline SVG](docs/visuals/03_openlane_flow/openlane_pipeline.svg) · [stage outputs table](docs/visuals/03_openlane_flow/stage_outputs.md) · [Docker volumes](docs/visuals/03_openlane_flow/docker_volumes.md)

![OpenLane pipeline](docs/visuals/03_openlane_flow/openlane_pipeline.svg)

```
  ╔═════════════════════════════════════════════════════════════════════╗
  ║       FULL RTL-to-GDSII PIPELINE — tt_um_inverter                  ║
  ║       OpenLane 2023.07.19-1  ·  SKY130HD  ·  160×100 µm tile      ║
  ╚═════════════════════════════════════════════════════════════════════╝

  ┌──────────────┐
  │  RTL Verilog │  inverter.v  +  tt_um_inverter.v
  └──────┬───────┘
         │
         ▼
  ┌══════════════════════════════════════════════════════════════════════┐
  │  STAGE 1 · SYNTHESIS                          [make synthesis]      │
  ├──────────────────────────────────────────────────────────────────────┤
  │  yosys   → parse RTL → RTLIL → synth_sky130 → abc (AREA 0)         │
  │  OpenSTA → pre-place STA (wire-load model, no parasitics)           │
  │  OUTPUT  → results/synthesis/tt_um_inverter.v  (1×inv_1 + conb)    │
  │            reports/synthesis/opensta.min_max.rpt                    │
  └══════════════════════════════╤═══════════════════════════════════════┘
                                 │
                                 ▼
  ┌══════════════════════════════════════════════════════════════════════┐
  │  STAGE 2 · FLOORPLAN                          [make floorplan]      │
  ├──────────────────────────────────────────────────────────────────────┤
  │  init_fp   → die=160×100µm  core=140×80µm  29 std-cell rows        │
  │  ioplacer  → W=ui_in[7:0]  E=uo_out[7:0]  N=uio_out/oe  S=ctrl    │
  │  pdngen    → met1 followpin + met4 vert strap + met5 horiz strap    │
  │  tapcell   → tapvpwrvgnd_1 every 14 µm                              │
  │  OUTPUT  → results/floorplan/tt_um_inverter.def                     │
  └══════════════════════════════╤═══════════════════════════════════════┘
                                 │
                                 ▼
  ┌══════════════════════════════════════════════════════════════════════┐
  │  STAGE 3 · PLACEMENT                          [make placement]      │
  ├──────────────────────────────────────────────────────────────────────┤
  │  RePLace → global placement  density=0.50  routability-driven       │
  │  Resizer → gate sizing + buffer insertion  max_wire=500µm           │
  │  OpenDP  → detail legalisation  cell_pad=4  row/site alignment      │
  │  OUTPUT  → results/placement/tt_um_inverter.def                     │
  └══════════════════════════════╤═══════════════════════════════════════┘
                                 │
                                 ▼
  ┌══════════════════════════════════════════════════════════════════════┐
  │  STAGE 4 · CTS                                        [SKIPPED]     │
  ├──────────────────────────────────────────────────────────────────────┤
  │  RUN_CTS=0 — design is purely combinational (0 flip-flops)          │
  │  clk port satisfies TT wrapper spec; no registers require a tree.   │
  └══════════════════════════════╤═══════════════════════════════════════┘
                                 │
                                 ▼
  ┌══════════════════════════════════════════════════════════════════════┐
  │  STAGE 5 · ROUTING                              [make routing]      │
  ├──────────────────────────────────────────────────────────────────────┤
  │  FastRoute   → global routing  GRT_ADJUSTMENT=0.3  ITERS=50        │
  │               li1/met1 local → met2/met3 intermediate               │
  │  TritonRoute → DRC-correct detailed routing on all layers           │
  │  Antenna fix → diode_2 inserted via global-route strategy 3         │
  │  OUTPUT  → results/routing/tt_um_inverter.def                       │
  │             results/routing/tt_um_inverter.guide                    │
  └══════════════════════════════╤═══════════════════════════════════════┘
                                 │
                                 ▼
  ┌══════════════════════════════════════════════════════════════════════┐
  │  STAGE 6 · PARASITIC EXTRACTION               [make extraction]     │
  ├──────────────────────────────────────────────────────────────────────┤
  │  OpenRCX → R=ρ×L/W  C=Carea+Cfringe  (rcx_patterns.rules)         │
  │            SPEF back-annotated into OpenROAD for post-route STA     │
  │  OUTPUT  → results/routing/tt_um_inverter.spef                      │
  │             reports/routing/sta-rcx.min_max.rpt  (WNS/TNS w/ RC)   │
  └══════════════════════════════╤═══════════════════════════════════════┘
                                 │
                                 ▼
  ┌══════════════════════════════════════════════════════════════════════┐
  │  STAGE 7 · GDS STREAM-OUT                           [make gds]     │
  ├──────────────────────────────────────────────────────────────────────┤
  │  Magic   → def2stream  sky130A.tech  merge std-cell GDS library     │
  │            primary GDSII + abstract LEF                             │
  │  KLayout → independent stream-out + XOR vs Magic GDS               │
  │  OUTPUT  → results/magic/tt_um_inverter.gds   ← SUBMISSION FILE     │
  │             results/magic/tt_um_inverter.lef                        │
  │             results/klayout/tt_um_inverter.gds                      │
  └══════════════════════════════╤═══════════════════════════════════════┘
                                 │
                                 ▼
  ┌══════════════════════════════════════════════════════════════════════┐
  │  STAGE 8 · SIGNOFF                              [make signoff]      │
  ├──────────────────────────────────────────────────────────────────────┤
  │  Magic DRC  → sky130A rules on GDS     target: 0 violations         │
  │  Netgen LVS → GDS netlist vs synth netlist                          │
  │               pass: "Circuits match uniquely."                      │
  │  CVC        → antenna ratio per net    limit: 400× per layer        │
  │  OpenSTA    → post-route STA with SPEF WNS ≥ 0 ns  TNS = 0 ns     │
  │  OUTPUT  → reports/magic_drc/tt_um_inverter.drc                     │
  │             reports/lvs/tt_um_inverter.lvs.lef.log                  │
  │             reports/antenna/tt_um_inverter_antenna.rpt              │
  └══════════════════════════════╤═══════════════════════════════════════┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │   GDSII  READY         │
                    │  tt_um_inverter.gds    │ → tinytapeout.com
                    └────────────────────────┘
```

### Power delivery network

> Visual: [floorplan SVG](docs/visuals/04_floorplan_layout/tt_tile_floorplan.svg) · [PDN layer stack](docs/visuals/04_floorplan_layout/pdn_layers.md)

![TT tile floorplan](docs/visuals/04_floorplan_layout/tt_tile_floorplan.svg)

```
  Layer   Width     Pitch      Offset    Direction   Role
  ──────  ────────  ─────────  ────────  ──────────  ────────────────
  met5    1.60 µm   27.20 µm   13.60 µm  Horizontal  PDN strap (VDD/VSS)
  met4    1.60 µm   27.14 µm   13.57 µm  Vertical    PDN strap (VDD/VSS)
  met1    0.48 µm    5.44 µm       0     Horizontal  Followpin rails
  li1     internal                        —           Intra-cell
```

---

## 9. Docker setup and execution

### Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Docker | 20.10+ | [Install guide](https://docs.docker.com/engine/install/) |
| Python 3 | 3.8+ | Required for `volare` PDK installer |
| Disk space | ~5 GB | Docker image (~2 GB) + PDK (~2 GB) |

### Complete workflow

```bash
# Clone the repository
git clone https://github.com/googleguru/vlsi-implementation
cd vlsi-implementation/tinytapeout

# Step 1 — Install SKY130A PDK (one-time, ~1 GB)
export PDK_ROOT=$HOME/.pdks
bash scripts/setup_pdk.sh

# Step 2 — Pull the OpenLane Docker image
make pull

# Step 3 — RTL simulation
make sim

# Step 4 — Full RTL-to-GDSII (all 8 stages, ~15–25 min)
make flow

# Step 5 — Run stages individually
make synthesis     # Stage 1: yosys + abc + OpenSTA
make floorplan     # Stage 2: init_fp + ioplacer + pdngen + tapcell
make placement     # Stage 3: RePLace + Resizer + OpenDP
make cts           # Stage 4: skipped (RUN_CTS=0)
make routing       # Stage 5: FastRoute + TritonRoute
make extraction    # Stage 6: OpenRCX → SPEF
make gds           # Stage 7: Magic + KLayout
make signoff       # Stage 8: DRC + LVS + antenna + STA

# Step 6 — Automated signoff report
bash scripts/run_checks.sh

# Step 7 — Interactive container shell
make mount
# Inside container:
# flow.tcl -design tt_um_inverter -tag debug -from synthesis -to synthesis -overwrite
# openroad -gui results/placement/tt_um_inverter.odb
# magic -T /pdks/sky130A/libs.tech/magic/sky130A.tech results/magic/tt_um_inverter.gds

# Clean rebuild
make clean && make flow
```

### docker compose shortcuts

```bash
docker compose run --rm flow     # full flow
docker compose run --rm shell    # interactive shell
docker compose run --rm sim      # simulation only
```

### Volume mounts

```
Host path       Container path   Content
──────────────  ───────────────  ───────────────────────────────
tinytapeout/    /project         RTL, configs, run outputs
$PDK_ROOT       /pdks            SKY130A PDK (volare-managed)
```

---

## 10. RTL simulation

> Visual: [waveform diagram](docs/visuals/06_simulation/waveform_dual_mode.md) · [test vectors](docs/visuals/06_simulation/test_vectors.md)

The testbench covers both operating modes — 256 patterns total:

| Mode | Patterns | Property checked |
|------|----------|-----------------|
| Inverter (`ui_in[7]=0`) | 128 | `uo_out == {7'b0, ~ui_in[0]}` |
| CA-235 (`ui_in[7]=1`) | 128 | `uo_out == ca235_ref(ui_in)` |
| Both modes | 256 | `uio_oe == 8'h00 && uio_out == 8'h00` |

**Expected output:**
```
VCD info: dumpfile tb_tt_um_inverter.vcd opened for output.
Inverter+CA-235 tests: 256 PASS  0 FAIL
ALL TESTS PASSED
```

**Inverter mode waveform:**
```
  clk        ┌────┐    ┌────┐    ┌────┐    ┌────┐   (100 MHz)
             └────┘    └────┘    └────┘    └────┘

  ui_in[0]   ──────────────┐              ┌──────────
             (0)            └──────────────┘  (0)
                            (1)

  uo_out[0]  ┌─────────────┐              ┌──────────
             │(1)           └──────────────┘  (1)
                            (0)
             │◄─ tpd ≈ 0.15 ns ─►│  inv_1, TT 25°C 1.8V

  uo_out[7:1]────────────────────────────────────────  always 0
  uio_out    ────────────────────────────────────────  always 0x00
  uio_oe     ────────────────────────────────────────  always 0x00
```

View with GTKWave:
```bash
gtkwave tb_tt_um_inverter.vcd &
# Add: clk | ui_in[7:0] (Hex) | uo_out[7:0] (Hex) | uio_oe | uio_out
```

---

## 11. Expected outputs

> Visual: [signoff checklist](docs/visuals/05_signoff_results/signoff_checklist.md) · [stage outputs detail](docs/visuals/03_openlane_flow/stage_outputs.md)

| Stage | Output file | Pass condition |
|-------|-------------|----------------|
| Synthesis | `results/synthesis/tt_um_inverter.v` | 1× inv_1 + conb cells |
| Pre-place STA | `reports/synthesis/opensta.min_max.rpt` | WNS ≥ 0 ns |
| Floorplan | `results/floorplan/tt_um_inverter.def` | die = 160×100 µm |
| Placement | `results/placement/tt_um_inverter.def` | 0 overlaps |
| CTS | *(placement DEF unchanged)* | RUN_CTS=0 |
| Routing | `results/routing/tt_um_inverter.def` | 0 TritonRoute DRC |
| Route guides | `results/routing/tt_um_inverter.guide` | file present |
| SPEF | `results/routing/tt_um_inverter.spef` | non-empty |
| Post-route STA | `reports/routing/sta-rcx.min_max.rpt` | WNS ≥ 0, TNS = 0 |
| GDS (Magic) | `results/magic/tt_um_inverter.gds` | non-zero size |
| GDS (KLayout) | `results/klayout/tt_um_inverter.gds` | XOR = 0 polygons |
| Abstract LEF | `results/magic/tt_um_inverter.lef` | file present |
| DRC | `reports/magic_drc/tt_um_inverter.drc` | 0 violations |
| LVS | `reports/lvs/tt_um_inverter.lvs.lef.log` | "match uniquely" |
| Antenna | `reports/antenna/tt_um_inverter_antenna.rpt` | 0 violations |

All runs land in:
```
tinytapeout/openlane/tt_um_inverter/runs/<RUN_TAG>/
```

---

## 12. TinyTapeout signoff checklist

```
┌─────────────────────────────────────────────────────┬──────────┬────────┐
│ Criterion                                           │ Tool     │ Result │
├─────────────────────────────────────────────────────┼──────────┼────────┤
│ RTL simulation — 256/256 patterns pass              │ iverilog │  PASS  │
│ Synthesized netlist present                         │ yosys    │  PASS  │
│ Pre-place timing — WNS ≥ 0 ns                       │ OpenSTA  │  PASS  │
│ Floorplan DEF — die = 160×100 µm                    │ init_fp  │  PASS  │
│ Placed DEF — 0 overlaps                             │ OpenDP   │  PASS  │
│ Routed DEF — 0 DRC from TritonRoute                 │ TR       │  PASS  │
│ SPEF extracted                                      │ OpenRCX  │  PASS  │
│ Post-route WNS ≥ 0 ns (setup, 100 MHz)              │ OpenSTA  │  PASS  │
│ Post-route WHS ≥ 0 ns (hold)                        │ OpenSTA  │  PASS  │
│ GDSII (Magic) present                               │ Magic    │  PASS  │
│ GDSII (KLayout) — XOR = 0                          │ KLayout  │  PASS  │
│ Magic DRC — 0 violations                            │ Magic    │  PASS  │
│ KLayout DRC — 0 violations                          │ KLayout  │  PASS  │
│ Netgen LVS — "Circuits match uniquely"              │ Netgen   │  PASS  │
│ Antenna — 0 violations after diode insertion        │ CVC      │  PASS  │
│ Area ≤ 16 000 µm² (single TT tile)                  │ yosys    │  PASS  │
└─────────────────────────────────────────────────────┴──────────┴────────┘
```

**Submit:**
1. Confirm all PASS via `bash scripts/run_checks.sh`
2. Upload `results/magic/tt_um_inverter.gds` → [tinytapeout.com](https://tinytapeout.com)
3. Reference `tinytapeout/info.yaml` for project metadata

---

## 13. ORFS native flow

The design is wired into `flow/designs/sky130hd/tt_inverter/config.mk`
for execution without Docker using a local OpenROAD installation.

```bash
cd flow

# tt_inverter is the active design in flow/Makefile
make                  # full flow
make synth            # synthesis only
make floorplan        # floorplan only
make place            # placement only
make cts              # CTS only
make route            # routing only
make finish           # GDS + DRC + LVS

# Run any specific design
make DESIGN_CONFIG=./designs/sky130hd/tt_inverter/config.mk route
```

**ORFS output paths:**
```
flow/logs/sky130hd/tt_inverter/          stage logs
flow/results/sky130hd/tt_inverter/       DEF, GDS, LEF, SPEF
flow/reports/sky130hd/tt_inverter/       timing, DRC, LVS reports
```

---

## 14. Key configuration reference

### OpenLane `config.json` parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `DESIGN_NAME` | `tt_um_inverter` | Matches Verilog module name |
| `CLOCK_PERIOD` | `10.0` ns | 100 MHz TinyTapeout standard |
| `DIE_AREA` | `0 0 160 100` | Single TT tile dimensions (µm) |
| `FP_CORE_UTIL` | `35` % | Low utilisation — mostly fill cells |
| `SYNTH_STRATEGY` | `AREA 0` | Minimise area; 1 inverter cell expected |
| `RUN_CTS` | `0` | No flip-flops → no clock tree needed |
| `DIODE_INSERTION_STRATEGY` | `3` | Global-route-based antenna fix |
| `PL_TARGET_DENSITY` | `0.5` | 50% prevents congestion in near-empty tile |
| `GRT_ADJUSTMENT` | `0.3` | 30% routing capacity margin |
| `PRIMARY_SIGNOFF_TOOL` | `magic` | Magic DRC/LVS is authoritative |

### SDC timing constraints

| Constraint | Value | Effect |
|------------|-------|--------|
| `create_clock clk` | 10 ns | Primary timing reference |
| `set_input_delay` | 2.0 ns | 20% of period — upstream FF hold |
| `set_output_delay` | 2.0 ns | 20% of period — downstream FF setup |
| `set_false_path rst_n` | — | No timing arc through reset |
| `set_false_path ena` | — | No timing arc through enable |
| `set_false_path uio_*` | — | Unused bidir ports excluded |
| `set_driving_cell buf_4` | — | Realistic input drive model |
| `set_load 0.01 pF` | — | Realistic output load model |

---

## 15. Visual outputs

All visual assets are saved under [`docs/visuals/`](docs/visuals/) in section-specific sub-folders.

| Folder | Contents |
|--------|---------|
| [`01_ca235_rule/`](docs/visuals/01_ca235_rule/) | [Truth table & derivation](docs/visuals/01_ca235_rule/ca235_truth_table.md) · [State evolution](docs/visuals/01_ca235_rule/ca235_state_evolution.md) · [Cell circuit SVG](docs/visuals/01_ca235_rule/ca235_cell_circuit.svg) · [8-cell row SVG](docs/visuals/01_ca235_rule/ca235_row_8cell.svg) |
| [`02_rtl_design/`](docs/visuals/02_rtl_design/) | [CMOS inverter schematic SVG](docs/visuals/02_rtl_design/cmos_inverter_schematic.svg) · [Dual-mode block SVG](docs/visuals/02_rtl_design/dual_mode_top_block.svg) · [Port mapping](docs/visuals/02_rtl_design/port_mapping.md) |
| [`03_openlane_flow/`](docs/visuals/03_openlane_flow/) | [Pipeline SVG](docs/visuals/03_openlane_flow/openlane_pipeline.svg) · [Stage outputs](docs/visuals/03_openlane_flow/stage_outputs.md) · [Docker volumes](docs/visuals/03_openlane_flow/docker_volumes.md) |
| [`04_floorplan_layout/`](docs/visuals/04_floorplan_layout/) | [Tile floorplan SVG](docs/visuals/04_floorplan_layout/tt_tile_floorplan.svg) · [PDN layer stack](docs/visuals/04_floorplan_layout/pdn_layers.md) |
| [`05_signoff_results/`](docs/visuals/05_signoff_results/) | [Signoff checklist](docs/visuals/05_signoff_results/signoff_checklist.md) |
| [`06_simulation/`](docs/visuals/06_simulation/) | [Waveforms (dual mode)](docs/visuals/06_simulation/waveform_dual_mode.md) · [Test vectors](docs/visuals/06_simulation/test_vectors.md) |

### Inline diagrams

**CA-235 cell gate circuit:**

![CA-235 cell circuit](docs/visuals/01_ca235_rule/ca235_cell_circuit.svg)

**CMOS inverter schematic:**

![CMOS inverter](docs/visuals/02_rtl_design/cmos_inverter_schematic.svg)

**8-stage OpenLane pipeline:**

![OpenLane pipeline](docs/visuals/03_openlane_flow/openlane_pipeline.svg)

**TT tile floorplan (160 × 100 µm):**

![TT tile floorplan](docs/visuals/04_floorplan_layout/tt_tile_floorplan.svg)

---

## 16. OpenROAD-flow-scripts

This repository is built on
[OpenROAD-flow-scripts (ORFS)](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts) —
a fully autonomous RTL-to-GDSII flow supporting multiple PDKs and design
styles through OpenROAD, Yosys, KLayout, and supporting tools.

![ORFS Flow](./docs/images/ORFS_Flow.svg)

### Installation options

| Method | Guide |
|--------|-------|
| Docker | [docs/user/BuildWithDocker.md](docs/user/BuildWithDocker.md) |
| Pre-built binaries | [docs/user/BuildWithPrebuilt.md](docs/user/BuildWithPrebuilt.md) |
| Local build | [docs/user/BuildLocally.md](docs/user/BuildLocally.md) |

### Resources

- ORFS docs: [openroad-flow-scripts.readthedocs.io](https://openroad-flow-scripts.readthedocs.io)
- OpenROAD docs: [openroad.readthedocs.io](https://openroad.readthedocs.io)
- Flow tutorial: [FlowTutorial.html](https://openroad-flow-scripts.readthedocs.io/en/latest/tutorials/FlowTutorial.html)
- Videos: [theopenroadproject.org/video](https://theopenroadproject.org/video)

### Citation

```bibtex
@article{ajayi2019openroad,
  title={OpenROAD: Toward a Self-Driving, Open-Source Digital Layout Implementation Tool Chain},
  author={Ajayi, T and Blaauw, D and Chan, TB and Cheng, CK and Chhabria, VA and others},
  journal={Proc. GOMACTECH},
  pages={1105--1110},
  year={2019}
}
```

### License

- OpenROAD-flow-scripts (build/run scripts): **BSD 3-Clause**
- TinyTapeout inverter design: **Apache 2.0**
- Tool licenses: `tools/{tool}/`
- Platform licenses: `flow/platforms/{platform}/`
- Design licenses: `flow/designs/src/{design}/`

