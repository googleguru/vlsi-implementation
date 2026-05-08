# TinyTapeout CMOS Inverter — RTL-to-GDSII on SKY130HD

[![PDK](https://img.shields.io/badge/PDK-SKY130A%200fe599b2-blue?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik0xMiAyQzYuNDggMiAyIDYuNDggMiAxMnM0LjQ4IDEwIDEwIDEwIDEwLTQuNDggMTAtMTBTMTcuNTIgMiAxMiAyem0tMiAxNWwtNS01IDEuNDEtMS40MUwxMCAxNC4xN2w3LjU5LTcuNTlMMTkgOGwtOSA5eiIvPjwvc3ZnPg==)](https://github.com/efabless/volare)
[![OpenLane](https://img.shields.io/badge/OpenLane-2023.07.19--1-green?logo=docker)](https://github.com/efabless/openlane)
[![Process](https://img.shields.io/badge/Process-SKY130%20130nm-orange)](https://skywater-pdk.readthedocs.io)
[![Cell Library](https://img.shields.io/badge/Std--Cell-sky130__fd__sc__hd-yellow)](https://github.com/google/skywater-pdk)
[![License](https://img.shields.io/badge/License-Apache%202.0-lightgrey)](../LICENSE_BUILD_RUN_SCRIPTS)
[![TinyTapeout](https://img.shields.io/badge/TinyTapeout-v5%20compatible-purple)](https://tinytapeout.com)

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
6. [Simulation and waveforms](#6-simulation-and-waveforms)
7. [Stage-by-stage reference](#7-stage-by-stage-reference)
   - 7.1 Synthesis (yosys / abc / OpenSTA)
   - 7.2 Floorplan (init\_fp / ioplacer / pdngen / tapcell)
   - 7.3 Placement (RePLace / Resizer / OpenDP)
   - 7.4 CTS (TritonCTS)
   - 7.5 Routing (FastRoute / TritonRoute)
   - 7.6 Parasitic extraction (OpenRCX)
   - 7.7 GDS stream-out (Magic / KLayout)
   - 7.8 Signoff (DRC / LVS / antenna / STA)
8. [Docker reference](#8-docker-reference)
9. [ORFS-native flow](#9-orfs-native-flow)
10. [Expected outputs](#10-expected-outputs)
11. [TinyTapeout signoff checklist](#11-tinytapeout-signoff-checklist)
12. [Technical constraints](#12-technical-constraints)

---

## 1. Design overview

| Parameter           | Value                                          |
|---------------------|------------------------------------------------|
| Top module          | `tt_um_inverter`                               |
| Logic function      | `uo_out[0] = ~ui_in[0]`                       |
| PDK                 | SkyWater SKY130A                               |
| Standard-cell lib   | `sky130_fd_sc_hd` (high-density, 1.8 V)       |
| Die area            | 160 µm × 100 µm (1 TT tile)                   |
| Core area           | 140 µm × 80 µm (10 µm margins)                |
| Core utilisation    | 35 %                                           |
| Target clock        | 100 MHz (10 ns period)                         |
| Flow                | OpenLane 2023.07.19-1 / ORFS                  |
| CTS                 | Disabled (combinational design)                |
| Synthesised cells   | 1× `inv_1` + ~3× `conb_1` (tie-offs)          |
| SKY130A PDK commit  | `0fe599b2afb6708d281543108caf8310912f54af`     |

The inverter instantiates a single `sky130_fd_sc_hd__inv_X` cell after
synthesis. All 35 TinyTapeout bus ports are present to satisfy the wrapper
DRC; unused ports are tied off inside the module with a constant-folded AND
to prevent inferred logic.

---

## 2. TinyTapeout tile layout

```
                           160 µm (die width)
        ◄─────────────────────────────────────────────────────────►
     ┌──────────────────────────────────────────────────────────────┐ ▲
     │                    die boundary                              │ │
     │  ┌────────────────────────────────────────────────────────┐  │ │
     │  │         N edge pins: uio_out[7:0]  uio_oe[7:0]        │  │ │
     │  │  ┌──────────────────────────────────────────────────┐  │  │ │
     │  │  │                                                  │  │  │ 1
     │  │  │  ═══════════════════════════════════════ met5    │  │  │ 0
     │  │  │  (VDD strap, 1.6 µm wide, 27.2 µm pitch)        │  │  │ 0
     │  │  │                                                  │  │  │ │
 W   │  │  │  ─────────────────────────────────────── met1   │  │  │ µ
 e   │  │  │  (VDD followpin, per std-cell row)               │  │  │ m
 s   │  │  │                                                  │  │  │ │
 t   │  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐      │  │  │ │
     │  │  │  │  fill_8  │  │  inv_1   │  │  fill_8  │      │  │  │ │
 u   │  │  │  │          │  │  A─►Y    │  │          │      │  │  ├─┤ E
 i   │  │  │  └──────────┘  └──────────┘  └──────────┘      │  │  │ a
 _   │  │  │                                                  │  │  │ s
 i   │  │  │  tap tap tap tap tap tap tap tap tap tap tap     │  │  │ t
 n   │  │  │  (tapvpwrvgnd_1  every 14 µm)                    │  │  │ │
 [   │  │  │                                                  │  │  │ │
 7   │  │  │  ─────────────────────────────────────── met1   │  │  │ │
 :   │  │  │  (VSS followpin, per std-cell row)               │  │  │ u
 0   │  │  │                                                  │  │  │ o
 ]   │  │  │  ║   ║   ║   ║   ║   ║   ║   ║   ║   ║  met4  │  │  │ _
     │  │  │  (VSS/VDD straps, 1.6 µm wide, 27.14 µm pitch) │  │  │ o
     │  │  │                                                  │  │  │ u
     │  │  │  ═══════════════════════════════════════ met5    │  │  │ t
     │  │  │  (VSS strap)                    core area        │  │  │ [
     │  │  └──────────────────────────────────────────────────┘  │  │ 7
     │  │         S edge pins: uio_in[7:0]  ena  rst_n  clk      │  │ :
     │  └────────────────────────────────────────────────────────┘  │ 0
     │◄── 10 µm I/O ring ────────────────────── 10 µm I/O ring ───►│ ]
     └──────────────────────────────────────────────────────────────┘ ▼
```

### TinyTapeout bus mapping

```
  TT wrapper (upstream)                    tt_um_inverter tile
  ──────────────────────                   ─────────────────────────────────────
  ui_in[7:0]   ──────────────────────────► ui_in[7:0]
                                                │
                                           [0]──┤ active inverter input
                                                ▼
                                          ┌─────────────────────────────┐
                                          │  sky130_fd_sc_hd__inv_1     │
                                          │  A ──►── Y                  │
                                          │  VPWR=VDD  VGND=VSS         │
                                          └─────────────────────────────┘
                                                │
                                           [0]──┤ inverted output
                                                ▼
  uo_out[7:0]  ◄──────────────────────── uo_out[7:0]
                                              [7:1] = 8'b0 (tied LOW via conb_1)
                                              [0]   = inv_1 output

  uio_in[7:0]  ──────────────────────────► uio_in[7:0]  (tied off, no logic)
  uio_out[7:0] ◄──────────────────────── uio_out[7:0]   = 8'h00
  uio_oe[7:0]  ◄──────────────────────── uio_oe[7:0]    = 8'h00 (all inputs)
  clk          ──────────────────────────► clk     (port present, unused by logic)
  rst_n        ──────────────────────────► rst_n   (port present, unused by logic)
  ena          ──────────────────────────► ena     (port present, unused by logic)
```

### Pin placement (ioplacer — `pin_order.cfg`)

```
                    ┌─── N: uio_out[7]…[0]  uio_oe[7]…[0] ───┐
                    │                                          │
  W: ui_in[7]…[0] ─┤          CORE (140×80 µm)               ├─ E: uo_out[7]…[0]
                    │                                          │
                    └─── S: uio_in[7]…[0]  ena  rst_n  clk ──┘
```

---

## 3. RTL-to-GDSII pipeline

```
  ╔══════════════════════════════════════════════════════════════════════════╗
  ║              RTL-to-GDSII Flow — tt_um_inverter                         ║
  ║              SKY130HD · OpenLane 2023.07.19-1 · 160×100 µm tile         ║
  ╚══════════════════════════════════════════════════════════════════════════╝

  ┌──────────────────────────┐
  │       RTL source         │  src/inverter.v         (assign out = ~in)
  │       (Verilog)          │  src/tt_um_inverter.v   (TT v5 wrapper)
  └────────────┬─────────────┘
               │
               ▼
  ┌════════════════════════════════════════════════════════════════════════┐
  ║  STAGE 1 · SYNTHESIS          [make synthesis]                        ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  yosys: read_verilog → synth_sky130 → abc (AREA 0) → write_verilog   ║
  ║  OpenSTA (pre-place, wire-load model, no parasitics)                  ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  OUT → results/synthesis/tt_um_inverter.v   (1×inv_1 + 3×conb_1)     ║
  ║         reports/synthesis/opensta.min_max.rpt                         ║
  ╚════════════════════════════════════════════════════════════════════════╝
               │  gate netlist + constraints.sdc
               ▼
  ┌════════════════════════════════════════════════════════════════════════┐
  ║  STAGE 2 · FLOORPLAN          [make floorplan]                        ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  init_fp  → die=160×100  core=140×80  29 std-cell rows               ║
  ║  ioplacer → pin_order.cfg  W/E/N/S pin assignment                     ║
  ║  pdngen   → met1 followpin + met4 vert strap + met5 horiz strap       ║
  ║  tapcell  → tapvpwrvgnd_1 every 14 µm                                 ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  OUT → results/floorplan/tt_um_inverter.def  (floorplan DEF)          ║
  ╚════════════════════════════════════════════════════════════════════════╝
               │  floorplan DEF + ODB
               ▼
  ┌════════════════════════════════════════════════════════════════════════┐
  ║  STAGE 3 · PLACEMENT          [make placement]                        ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  RePLace → global placement  density=0.50  routability-driven         ║
  ║  Resizer → gate sizing + buffer insertion  max_wire=500 µm            ║
  ║  OpenDP  → detail legalisation  cell_pad=4  row/site alignment        ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  OUT → results/placement/tt_um_inverter.def  (placed DEF)             ║
  ╚════════════════════════════════════════════════════════════════════════╝
               │  placed DEF + ODB
               ▼
  ┌════════════════════════════════════════════════════════════════════════┐
  ║  STAGE 4 · CTS — TritonCTS    [RUN_CTS=0, skipped]                   ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  Combinational design — clk port exists for TT wrapper spec only.     ║
  ║  No registers → no clock tree needed. DEF unchanged from placement.   ║
  ╚════════════════════════════════════════════════════════════════════════╝
               │  placed DEF (unchanged)
               ▼
  ┌════════════════════════════════════════════════════════════════════════┐
  ║  STAGE 5 · ROUTING            [make routing]                          ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  FastRoute   → global routing  GRT_ADJUSTMENT=0.3  ITERS=50           ║
  ║                layer assignment: li1/met1 local → met2/met3 inter     ║
  ║  TritonRoute → detailed DRC-correct segment geometry                   ║
  ║                antenna repair: diode_2 inserted (STRATEGY=3)          ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  OUT → results/routing/tt_um_inverter.def    (routed DEF)             ║
  ║         results/routing/tt_um_inverter.guide  (global route guides)   ║
  ╚════════════════════════════════════════════════════════════════════════╝
               │  routed DEF
               ▼
  ┌════════════════════════════════════════════════════════════════════════┐
  ║  STAGE 6 · PARASITIC EXTRACTION  [make extraction]                    ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  OpenRCX → rcx_patterns.rules  R=ρ·L/W  C=Carea+Cfringe             ║
  ║            SPEF written into OpenROAD for post-route STA              ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  OUT → results/routing/tt_um_inverter.spef                            ║
  ║         reports/routing/sta-rcx.min_max.rpt   (WNS/TNS with R/C)     ║
  ╚════════════════════════════════════════════════════════════════════════╝
               │  routed DEF + SPEF
               ▼
  ┌════════════════════════════════════════════════════════════════════════┐
  ║  STAGE 7 · GDS STREAM-OUT     [make gds]                             ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  Magic   → def2stream  sky130A.tech  merge std-cell GDS               ║
  ║            primary GDSII + abstract LEF  (MAGIC_EXT_USE_GDS=1)       ║
  ║  KLayout → independent stream-out + XOR vs Magic GDS cross-check     ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  OUT → results/magic/tt_um_inverter.gds     ← SUBMISSION FILE         ║
  ║         results/magic/tt_um_inverter.lef    ← abstract LEF            ║
  ║         results/klayout/tt_um_inverter.gds  ← cross-check             ║
  ╚════════════════════════════════════════════════════════════════════════╝
               │  GDSII
               ▼
  ┌════════════════════════════════════════════════════════════════════════┐
  ║  STAGE 8 · SIGNOFF            [make signoff]                          ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  Magic DRC  → sky130A rules on GDS   target: 0 violations             ║
  ║  Netgen LVS → GDS netlist vs synth netlist  "Circuits match uniquely" ║
  ║  CVC        → antenna ratio per net  met1–met5 limit: 400×            ║
  ║  OpenSTA    → post-route STA with SPEF  WNS ≥ 0 ns, TNS = 0 ns      ║
  ╠════════════════════════════════════════════════════════════════════════╣
  ║  OUT → reports/magic_drc/tt_um_inverter.drc                           ║
  ║         reports/lvs/tt_um_inverter.lvs.lef.log                        ║
  ║         reports/antenna/tt_um_inverter_antenna.rpt                    ║
  ╚════════════════════════════════════════════════════════════════════════╝
               │
               ▼
  ┌──────────────────────────┐
  │   GDSII ready            │  → upload results/magic/tt_um_inverter.gds
  │   for TT submission      │     to TinyTapeout portal with info.yaml
  └──────────────────────────┘
```

### Power delivery cross-section (SKY130HD)

```
  Layer   Role                          Width      Pitch      Direction
  ──────  ────────────────────────────  ─────────  ─────────  ─────────
  met5    horizontal power strap        1.60 µm    27.20 µm   H
  met4    vertical power strap          1.60 µm    27.14 µm   V
  met3    signal routing                0.30 µm    variable   H preferred
  met2    signal routing                0.14 µm    variable   V preferred
  met1    signal + VDD/VSS followpin    0.48 µm    5.44 µm    H
  li1     intra-cell local interconnect 0.17 µm    variable   —

  Physical stack (Z-axis view, not to scale):

  ═══════════════════════════════════════  met5  VDD strap
  ───────────────────────────────────────  met4  VDD/VSS vert straps (via to met5)
  ───────────────────────────────────────  met3  signal
  ───────────────────────────────────────  met2  signal
  ═══════════════════════════════════════  met1  VDD followpin (top of each row)
                    std-cell row
  ═══════════════════════════════════════  met1  VSS followpin (bottom of each row)
  ───────────────────────────────────────  li1   local interconnect
  ███████  gate  ███████  source/drain  █  poly / diffusion (silicon)
```

### Timing diagram (combinational path)

```
  clk      100 MHz
  ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
  ┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─

  ui_in[0]  (input, registered at TT wrapper before this tile)
  ──────────┐                         ┌──────────
            └─────────────────────────┘
                     logic 0                  logic 1

  uo_out[0]  (combinational, ~0.2 ns delay through inv_1 TT corner)
            ┌─────────────────────────┐
  ──────────┘                         └──────────
       logic 1                              logic 0

         │◄── tpd ≈ 0.2 ns (sky130_fd_sc_hd__inv_1, TT 25°C 1.8V) ──►│

  IO delay budget (SDC):
    set_input_delay  2.0 ns  (20% of 10 ns period)
    set_output_delay 2.0 ns
    Remaining for logic: 10 - 2 - 2 = 6 ns  »  WNS ≫ 0
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
    │   └── tt_um_inverter.v               TT top-level wrapper
    ├── test/
    │   └── tb_tt_um_inverter.v            256-pattern sweep testbench
    ├── openlane/tt_um_inverter/
    │   ├── config.json                     OpenLane 1.x configuration
    │   ├── pin_order.cfg                   ioplacer pin placement spec
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
# Clone
git clone https://github.com/googleguru/vlsi-implementation
cd vlsi-implementation/tinytapeout

# Step 1 — install SKY130A PDK via volare (one-time, ~1 GB)
export PDK_ROOT=$HOME/.pdks
bash scripts/setup_pdk.sh

# Step 2 — pull the OpenLane container image
make pull

# Step 3 — RTL simulation (requires iverilog on host)
make sim

# Step 4 — full RTL-to-GDSII (~20 min on 4 cores)
make flow

# Step 5 — parse signoff reports
bash scripts/run_checks.sh
```

---

## 6. Simulation and waveforms

### Running the testbench

The testbench sweeps all 256 `ui_in` patterns and verifies three properties
on every cycle: `uo_out[0] == ~ui_in[0]`, `uo_out[7:1] == 0`, and
`uio_oe == uio_out == 8'h00`.

```bash
# On host with iverilog installed
make sim

# Or inside Docker (uses hdlc/sim:iverilog image)
docker compose run --rm sim
```

### Expected console output

```
VCD info: dumpfile tb_tt_um_inverter.vcd opened for output.
Simulation complete: 256 PASS  0 FAIL
ALL TESTS PASSED
```

If any assertion fails, the testbench prints the offending pattern before
the summary line:

```
FAIL ui_in=01  uo_out[0]=1 expected=0    # example of a bug output
```

### Waveform — annotated timing diagram

```
  Time (ns)    0    5   10   15   20   25   30   35   40   45   50
               │    │    │    │    │    │    │    │    │    │    │
  clk          ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐
               │    └────┘    └────┘    └────┘    └────┘    └────
               │
  rst_n        ─────────────────────────────────────────────────── (held 1)
  ena          ─────────────────────────────────────────────────── (held 1)
               │
  ui_in[0]     ────────────────────┐                   ┌──────────
               │                   └───────────────────┘
               │    0000_0000       0000_0001       0000_0000
               │         ▲                ▲
               │         │ sweep step     │ sweep step
               │
  uo_out[0]    ┌──────────────────┐                    ┌──────────
               │                  └────────────────────┘
               │    1 (inverted)        0 (inverted)        1
               │
  uo_out[7:1]  ─────────────────────────────────────────────────── (always 0)
  uio_out      ─────────────────────────────────────────────────── (always 0)
  uio_oe       ─────────────────────────────────────────────────── (always 0)
               │
               │◄──── 2 ns stimulus hold after each step ─────────►│
```

### Reading the VCD file

```bash
# View waveforms in GTKWave
gtkwave tb_tt_um_inverter.vcd &

# Key signals to add in GTKWave signal browser:
#   tb_tt_um_inverter.clk
#   tb_tt_um_inverter.ui_in[7:0]   → set radix Hex
#   tb_tt_um_inverter.uo_out[7:0]  → set radix Hex
#   tb_tt_um_inverter.uio_oe[7:0]
#   tb_tt_um_inverter.uio_out[7:0]
#
# Verify: uo_out[0] toggles opposite to ui_in[0] at every step
#         uo_out[7:1] stays 0x00 throughout
#         uio_oe / uio_out stay 0x00 throughout
```

### VCD structure

```
$timescale 1ns / 1ps $end
$scope module tb_tt_um_inverter $end
  $var wire 8 # ui_in [7:0] $end
  $var wire 8 $ uo_out [7:0] $end
  $var wire 8 % uio_in [7:0] $end
  $var wire 8 & uio_out [7:0] $end
  $var wire 8 ' uio_oe [7:0] $end
  $var wire 1 ( ena $end
  $var wire 1 ) clk $end
  $var wire 1 * rst_n $end
$upscope $end
$enddefinitions $end
#0            ← time = 0 ns
b00000000 #  ← ui_in = 0x00
b11111111 $  ← uo_out[0]=1, [7:1]=0 → uo_out = 0x01 (inv of bit 0)
...
```

### Propagation delay profile (sky130_fd_sc_hd, TT corner 25°C 1.8 V)

| Cell | Rise delay (A→Y) | Fall delay (A→Y) |
|------|-----------------|-----------------|
| `inv_1` | ~0.16 ns | ~0.14 ns |
| `inv_2` | ~0.14 ns | ~0.12 ns |
| `inv_4` | ~0.13 ns | ~0.11 ns |

ABC selects `inv_1` for minimal area. Resizer may upsize to `inv_2` if the
output load (from IO pad capacitance) causes a slew violation.

---

## 7. Stage-by-stage reference

### 7.1 Synthesis — `yosys / abc / OpenSTA`

**Purpose:** Convert RTL to a technology-mapped gate netlist; static timing
analysis without parasitics.

```bash
make synthesis
# Container equivalent:
# flow.tcl -design tt_um_inverter -to synthesis -overwrite
```

#### Internal tool flow

```
  ┌─────────────────────────────────────────────────────────────────┐
  │  yosys                                                          │
  │                                                                 │
  │  read_verilog  ──►  RTLIL IR  ──►  proc  ──►  opt              │
  │                                                    │            │
  │                                                    ▼            │
  │                                              synth_sky130       │
  │                                       (flatten + techmap)       │
  │                                                    │            │
  │                                                    ▼            │
  │                              abc -liberty sky130_fd_sc_hd.lib   │
  │                              (AREA 0: map.script + area opt)    │
  │                                                    │            │
  │                                                    ▼            │
  │                                          write_verilog          │
  │                                          (gate netlist)         │
  └─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │  OpenSTA (pre-place, wire-load model)                           │
  │                                                                 │
  │  read_liberty   sky130_fd_sc_hd__tt_025C_1v80.lib              │
  │  read_verilog   tt_um_inverter.v  (synthesised)                 │
  │  read_sdc       constraints.sdc                                 │
  │                                                                 │
  │  report_checks  -path_delay max  → WNS/TNS setup               │
  │  report_checks  -path_delay min  → WNS/TNS hold                │
  │  report_check_types -max_slew -max_cap                          │
  └─────────────────────────────────────────────────────────────────┘
```

#### yosys pass sequence

| Pass | Action |
|------|--------|
| `read_verilog -sv` | parse `inverter.v` + `tt_um_inverter.v` |
| `hierarchy -check` | verify module references |
| `proc` | convert always blocks to netlists |
| `flatten` | inline all submodules |
| `opt` | constant folding, dead-logic removal |
| `synth_sky130` | technology-specific synthesis pass |
| `dfflibmap -liberty` | map FF primitives to `sky130_fd_sc_hd` |
| `abc -liberty` | Boolean opt + cell mapping (AREA 0 script) |
| `hilomap` | map 0/1 constants to `conb_1` tie cells |
| `splitnets` | split buses for Liberty port matching |
| `clean -purge` | remove unused cells and wires |
| `write_verilog` | emit gate-level netlist |

**Expected synthesised netlist (`assign`-style view):**

```verilog
sky130_fd_sc_hd__inv_1   _0_ (.A(ui_in[0]),    .Y(uo_out[0]));
sky130_fd_sc_hd__conb_1  _1_ (.HI(),           .LO(uo_out[1]));
sky130_fd_sc_hd__conb_1  _2_ (.HI(),           .LO(uo_out[2]));
// ... repeat for uo_out[3:7], uio_out[*], uio_oe[*]
```

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

### 7.2 Floorplan — `init_fp / ioplacer / pdngen / tapcell`

**Purpose:** Define physical die boundaries, place IO pins at tile edges,
generate the power grid, and insert well-tap cells.

```bash
make floorplan
# flow.tcl -design tt_um_inverter -from floorplan -to floorplan -overwrite
```

#### Floorplan geometry

```
  ┌─────────────────── 160 µm die ────────────────────────────┐
  │                                                            │
  │  ◄─10─►◄──────────── 140 µm core ────────────►◄──10──►   │
  │        ┌──────────────────────────────────────┐           │
  │        │ ◄──────────── 29 std-cell rows ──────►│           │
  │        │  row height = 2.72 µm                 │           │
  │        │  site width = 0.46 µm  (sky130hd)     │  80 µm   │
  │        │                                        │  core    │
  │        │  Tracks (from sky130_fd_sc_hd.tlef):  │           │
  │        │  H: offset=0.23  pitch=0.46            │           │
  │        │  V: offset=0.17  pitch=0.34            │           │
  │        └──────────────────────────────────────┘           │
  │                                                            │
  └────────────────────────────────────────────────────────────┘
```

#### PDN strap geometry

```
  Strap    Layer   Width    Pitch     Offset   Direction
  ───────  ──────  ───────  ────────  ───────  ─────────
  rail     met1    0.48 µm  5.44 µm   0 µm     H (followpin)
  strap    met4    1.60 µm  27.14 µm  13.57 µm V
  strap    met5    1.60 µm  27.20 µm  13.60 µm H
  connect  via     met1↔met4, met4↔met5

  In a 140 µm core:
    met4 straps: ⌊140/27.14⌋ = 5 vert straps (2 VDD + 3 VSS alternating)
    met5 straps: ⌊80/27.20⌋  = 2 horiz straps (1 VDD + 1 VSS)
```

**Output files:**

```
runs/<tag>/results/floorplan/
  tt_um_inverter.def   floorplan DEF (die, core, IO, rows, PDN vias)
  tt_um_inverter.odb   OpenDB binary snapshot

runs/<tag>/reports/floorplan/
  core_util.rpt        utilisation breakdown
```

---

### 7.3 Placement — `RePLace / Resizer / OpenDP`

**Purpose:** Optimally place standard cells minimising wirelength and
satisfying timing and routability constraints.

```bash
make placement
# flow.tcl -design tt_um_inverter -from placement -to placement -overwrite
```

#### Placement sub-step detail

```
  ┌──────────────────────────────────────────────────────────────────┐
  │  RePLace — global placement                                      │
  │                                                                  │
  │  Objective: minimise  α·HPWL + β·overflow_penalty               │
  │  PL_TARGET_DENSITY    = 0.50                                     │
  │  PL_ROUTABILITY_DRIVEN = 1  (congestion maps fed from FastRoute) │
  │                                                                  │
  │  For the inverter (1 cell):                                      │
  │    Cell placed near centre of core; fill cells distributed       │
  │    around it to reach density target.                            │
  └──────────────────────────────────────────────────────────────────┘
                        │
                        ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  OpenROAD Resizer — timing / design optimisation                 │
  │                                                                  │
  │  PL_RESIZER_DESIGN_OPTIMIZATIONS = 1                             │
  │    → remove_buffers: strip synthesis buffers                     │
  │    → repair_design:  fix max_cap / max_slew DRC                  │
  │                                                                  │
  │  PL_RESIZER_TIMING_OPTIMIZATIONS = 1                             │
  │    → repair_timing -setup: buffer insertion for WNS              │
  │    → repair_timing -hold:  buffer insertion for WHS              │
  │  PL_RESIZER_MAX_WIRE_LENGTH = 500 µm                             │
  └──────────────────────────────────────────────────────────────────┘
                        │
                        ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  OpenDP — detail placement legalisation                          │
  │                                                                  │
  │  Cell padding: 4 sites global → 2 sites detail                  │
  │  Legalises each cell to nearest row/site slot.                   │
  │  Resolves overlaps via Abacus / Tetris legaliser.                │
  │  Outputs: legal DEF guaranteed to match site grid.               │
  └──────────────────────────────────────────────────────────────────┘
```

**Output files:**

```
runs/<tag>/results/placement/
  tt_um_inverter.def   legally placed DEF

runs/<tag>/reports/placement/
  replace.log          wirelength / overflow metrics
  resizer.log          buffer/sizing change log
  opendp.log           placement density map
  opensta.timing.rpt   post-placement STA (wire-load, no RC)
```

---

### 7.4 CTS — `TritonCTS`

**Purpose:** Build a balanced clock tree to minimise skew across all
registered endpoints.

```
RUN_CTS = 0  — disabled for this design
```

`tt_um_inverter` is purely combinational. The `clk` port satisfies the
TinyTapeout wrapper interface requirement but drives zero registers.
Running TritonCTS would insert unnecessary clock buffers (clkbuf_1 cells)
that inflate area and add unroutable segments.

The SDC constrains `clk` with `create_clock` so OpenSTA analyses
combinational propagation timing correctly. `rst_n` and `ena` are
`set_false_path`'d to exclude them from timing arcs.

```
  If CTS were enabled (hypothetical):
  ┌───────────────────────────────────────────────┐
  │  TritonCTS topology for a single-register FF: │
  │                                               │
  │  clk ──► clkbuf_1 ──► FF.CLK                 │
  │             │                                 │
  │          (trivial tree; no balancing needed)  │
  └───────────────────────────────────────────────┘
  Skipped because this design has 0 FFs.
```

---

### 7.5 Routing — `FastRoute / TritonRoute`

**Purpose:** Assign physical wire segments to routing layers, resolving all
DRC constraints including spacing, via, and antenna rules.

```bash
make routing
# flow.tcl -design tt_um_inverter -from routing -to routing -overwrite
```

#### Routing layer stack (SKY130HD)

```
  Layer   Min-W    Min-Sp   Preferred  Max current  Used for
  ──────  ───────  ───────  ─────────  ───────────  ────────────────
  met5    1.60 µm  1.60 µm  H          ≥6 mA/µm    PDN strap only
  met4    0.30 µm  0.30 µm  V          ≥6 mA/µm    PDN strap only
  met3    0.30 µm  0.30 µm  H          ~1 mA/µm    intermediate signal
  met2    0.14 µm  0.14 µm  V          ~1 mA/µm    intermediate signal
  met1    0.14 µm  0.14 µm  H          ~1 mA/µm    local signal + rails
  li1     0.17 µm  0.17 µm  any        ~0.5 mA/µm  intra-cell only
```

#### Routing flow

```
  FastRoute  (global routing)
  ├─ Build routing resource graph per layer
  ├─ Net decomposition (Steiner tree per net)
  ├─ GRT_ADJUSTMENT=0.30  → 30% capacity margin for detailed routing
  ├─ GRT_OVERFLOW_ITERS=50 → rip-up-and-reroute budget
  └─ Output: route guides (.guide file)

  TritonRoute  (detailed routing)
  ├─ Read guides → generate initial detailed routes
  ├─ Iterative DRC repair (spacing, width, enclosure, via)
  ├─ Antenna check: DIODE_INSERTION_STRATEGY=3
  │    → global-route phase: estimate antenna ratios
  │    → insert sky130_fd_sc_hd__diode_2 on long nets
  │    → re-route with diodes in place
  │    → post-route re-check: verify ratio ≤ 400× per layer
  └─ Output: routed DEF (all wires DRC-clean)
```

**Output files:**

```
runs/<tag>/results/routing/
  tt_um_inverter.def    fully routed DEF
  tt_um_inverter.guide  FastRoute global guides per net

runs/<tag>/reports/routing/
  tritonRoute.drc       post-route DRC violations (target: 0)
  antenna.rpt           net antenna ratios
```

---

### 7.6 Parasitic extraction — `OpenRCX`

**Purpose:** Extract distributed R/C parasitics from the routed layout for
high-accuracy post-route static timing analysis.

```bash
make extraction
# flow.tcl -design tt_um_inverter -from extraction -to extraction -overwrite
```

#### Extraction model

```
  For each wire segment on layer L:
    R = sheet_resistance[L] × length / width
    C = Carea[L] × (length × width) + Cfringe[L] × (2 × length)

  sky130hd calibrated values (approx, TT corner):
  Layer   ρ (Ω/□)    Carea (aF/µm²)   Cfringe (aF/µm)
  ──────  ─────────  ───────────────  ───────────────
  met1    0.125       36               51
  met2    0.125       37               52
  met3    0.047       30               45
  met4    0.047       28               42
  met5    0.029       22               35

  OpenRCX output (SPEF snippet for uo_out[0] net):
  *NET uo_out[0] 1.23fF
  *RES
  1:uo_out[0]:1 1:u_inv/Y 0.052
  *CAP
  1 1:uo_out[0]:1 0.000823
  *END
```

**Output files:**

```
runs/<tag>/results/routing/
  tt_um_inverter.spef         extracted parasitics (SPEF)

runs/<tag>/reports/routing/
  sta-rcx.min_max.rpt         final WNS / TNS (hold + setup)
  sta-rcx_hold.min.rpt        per-path hold slack
  sta-rcx_setup.max.rpt       per-path setup slack
```

---

### 7.7 GDS stream-out — `Magic / KLayout`

**Purpose:** Convert the routed database to GDSII for wafer fabrication.

```bash
make gds
# flow.tcl -design tt_um_inverter -from magic -to magic -overwrite
```

#### GDS generation flow

```
  ┌──────────────────────────────────────────────────────────────────┐
  │  Magic (primary GDS)                                             │
  │                                                                  │
  │  1. load  tt_um_inverter.def  (reads routed geometry)            │
  │  2. load  sky130_fd_sc_hd GDS library (std-cell geometry)        │
  │  3. def2stream  -format GDS  -tech sky130A.tech                  │
  │     → flattens cells, merges polygons, maps layers               │
  │  4. write tt_um_inverter.gds  ← PRIMARY SUBMISSION FILE          │
  │  5. magic -ext: extract SPICE for LVS  (MAGIC_EXT_USE_GDS=1)    │
  │     → writes tt_um_inverter.spice + tt_um_inverter.lef           │
  └──────────────────────────────────────────────────────────────────┘
                        │
                        ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │  KLayout (secondary GDS + cross-check)                           │
  │                                                                  │
  │  1. Read routed DEF with sky130hd.lyt technology                 │
  │  2. Stream out → tt_um_inverter.gds (KLayout version)            │
  │  3. XOR Magic GDS vs KLayout GDS:                                │
  │       diff area = 0  →  PASS (tools agree on every polygon)      │
  │       diff area > 0  →  WARN (flag for manual inspection)        │
  │  4. KLayout DRC (KLAYOUT_DRC_KLAYOUT_GDS=1):                    │
  │       runs sky130A.lydrc rules on the KLayout GDS                │
  └──────────────────────────────────────────────────────────────────┘
```

#### GDSII layer map (SKY130HD, partial)

| GDS layer | Datatype | Magic layer | Purpose |
|-----------|----------|-------------|---------|
| 64 | 20 | `nwell` | N-well |
| 65 | 20 | `pwell` | P-well (nwell absent) |
| 66 | 20 | `diff` | Active diffusion |
| 66 | 44 | `tap` | Tap/contact diffusion |
| 67 | 20 | `poly` | Polysilicon gate |
| 68 | 16 | `licon1` | Li1 contact |
| 67 | 16 | `npc` | N+ poly contact |
| 71 | 20 | `li1` | Local interconnect |
| 72 | 20 | `mcon` | Li1→met1 via |
| 68 | 20 | `met1` | Metal 1 |
| 69 | 20 | `via` | Met1→met2 via |
| 69 | 44 | `met2` | Metal 2 |

**Output files:**

```
runs/<tag>/results/magic/
  tt_um_inverter.gds    primary GDSII  ← TinyTapeout submission file
  tt_um_inverter.lef    abstract LEF (used by TT wrapper integration)
  tt_um_inverter.spice  extracted SPICE (input to Netgen LVS)

runs/<tag>/results/klayout/
  tt_um_inverter.gds    KLayout secondary GDS (cross-check reference)
```

---

### 7.8 Signoff — `Magic DRC / Netgen LVS / CVC / OpenSTA`

**Purpose:** Verify the final GDS meets all fabrication, connectivity,
and timing requirements before tape-out.

```bash
make signoff
bash scripts/run_checks.sh
```

#### DRC (Magic)

```
  Magic reads tt_um_inverter.gds with sky130A.tech DRC rules.

  Rule categories checked:
  ┌───────────────────────────┬─────────────────────────────────────┐
  │ Rule class                │ Example (met1)                      │
  ├───────────────────────────┼─────────────────────────────────────┤
  │ Minimum width             │ met1.width ≥ 0.14 µm               │
  │ Minimum spacing           │ met1.spacing ≥ 0.14 µm             │
  │ Enclosure                 │ via enclosed by met1 ≥ 0.055 µm    │
  │ Extension                 │ met1 extends beyond via ≥ 0.055 µm │
  │ Well/implant coverage     │ nwell covers all PMOS bodies        │
  │ Antenna per layer         │ met1 ratio ≤ 400×                   │
  └───────────────────────────┴─────────────────────────────────────┘

  Target: 0 violations.
  Report: reports/magic_drc/tt_um_inverter.drc
```

#### LVS (Netgen)

```
  Source: results/synthesis/tt_um_inverter.v   (gate-level netlist)
  Layout: results/magic/tt_um_inverter.spice   (Magic-extracted)

  Netgen comparison:
    1. Flatten both netlists to device level
    2. Match devices by topology (graph isomorphism)
    3. Match net names and port assignments
    4. Compare device parameters (W/L for transistors)

  Pass condition: "Circuits match uniquely."
  Fail condition: "Mismatch:" lines present in log

  Report: reports/lvs/tt_um_inverter.lvs.lef.log
```

#### Antenna check

```
  Antenna ratio = (metal area on gate side of cut) / (gate oxide area)

  For each net, OpenROAD checks the partial ratio at each routing layer:
  met1 ratio ≤ 400×  met2 ≤ 400×  met3 ≤ 400×  met4 ≤ 400×  met5 ≤ 400×

  Violations resolved by DIODE_INSERTION_STRATEGY=3:
    1. FastRoute estimates antenna ratios per net
    2. Inserts sky130_fd_sc_hd__diode_2 on violating nets
       (diode provides a discharge path; ratio resets at each diode)
    3. TritonRoute re-routes with diodes in final position
    4. Post-route CVC re-checks all ratios

  Report: reports/antenna/tt_um_inverter_antenna.rpt
```

#### Post-route STA (OpenSTA + SPEF)

```
  Timing check equations:

  Setup: data_arrival_time ≤ capture_edge − setup_margin
         where data_arrival_time = launch_edge + tclk→Q + combo_delay + tRC

  Hold:  data_arrival_time ≥ capture_edge + hold_margin
         where data_arrival_time = launch_edge + min(tclk→Q + combo_delay)

  For the inverter (no registers):
    Combinational path: ui_in → inv_1 → uo_out
    tpd ≈ 0.2 ns  (inv_1, TT corner, with ~1 fF output load)
    IO budget: 2 ns input + 2 ns output = 4 ns total
    Remaining slack = 10 ns − 4 ns − 0.2 ns = 5.8 ns  (WNS >> 0)

  Reports:
    reports/routing/sta-rcx_setup.max.rpt   (max-delay paths, setup)
    reports/routing/sta-rcx_hold.min.rpt    (min-delay paths, hold)
    reports/routing/sta-rcx.min_max.rpt     (WNS + TNS summary)
```

---

## 8. Docker reference

### Container image

```
efabless/openlane:2023.07.19-1
  ├── OpenLane 1.x      flow.tcl — main flow controller
  ├── yosys 0.26+       RTL synthesis
  ├── OpenROAD 2023.07  OpenDP, TritonCTS, FastRoute, TritonRoute,
  │                     OpenRCX, OpenSTA, Resizer, pdngen
  ├── Magic 8.3.x       GDS stream-out, DRC, LVS extraction
  ├── KLayout 0.28.x    secondary GDS, DRC
  ├── Netgen 1.5.x      LVS comparison
  └── PDK               NOT included — mount from host via $PDK_ROOT
```

### Volume mounts

```
Host path          Container path    Purpose
─────────────────  ────────────────  ──────────────────────────────
$(pwd)             /project          project source + run outputs
$PDK_ROOT          /pdks             SKY130A PDK (volare-managed)
```

### Environment variables

```bash
PDK_ROOT=/pdks
PDK=sky130A
STD_CELL_LIBRARY=sky130_fd_sc_hd
DESIGN_NAME=tt_um_inverter
PROJECT_ROOT=/project
OPENLANE_ROOT=/openlane
```

### Manual stage commands (inside container shell)

```bash
# Enter interactive container
make mount

# Inside container — link design into OpenLane's search path
ln -sf /project/openlane/tt_um_inverter /openlane/designs/tt_um_inverter
cd /openlane

# Run individual stages
flow.tcl -design tt_um_inverter -tag dbg -from synthesis  -to synthesis  -overwrite
flow.tcl -design tt_um_inverter -tag dbg -from floorplan  -to floorplan  -overwrite
flow.tcl -design tt_um_inverter -tag dbg -from placement  -to placement  -overwrite
flow.tcl -design tt_um_inverter -tag dbg -from cts        -to cts        -overwrite
flow.tcl -design tt_um_inverter -tag dbg -from routing    -to routing    -overwrite
flow.tcl -design tt_um_inverter -tag dbg -from extraction -to extraction -overwrite
flow.tcl -design tt_um_inverter -tag dbg -from magic      -to magic      -overwrite
flow.tcl -design tt_um_inverter -tag dbg -from magic_drc  -to lvs        -overwrite

# Inspect placement in OpenROAD GUI
openroad -gui /project/openlane/tt_um_inverter/runs/dbg/results/placement/tt_um_inverter.odb

# Inspect GDS in Magic
magic -T /pdks/sky130A/libs.tech/magic/sky130A.tech \
      /project/openlane/tt_um_inverter/runs/dbg/results/magic/tt_um_inverter.gds

# Run Netgen LVS manually
netgen -batch lvs \
  "results/magic/tt_um_inverter.spice tt_um_inverter" \
  "results/synthesis/tt_um_inverter.v tt_um_inverter" \
  /pdks/sky130A/libs.tech/netgen/sky130A_setup.tcl \
  reports/lvs/tt_um_inverter.lvs.lef.log

# Clean + rebuild
make clean && make flow
```

### docker compose shortcuts

```bash
docker compose run --rm flow    # full RTL-to-GDSII
docker compose run --rm shell   # interactive bash shell
docker compose run --rm sim     # iverilog simulation (hdlc/sim image)
```

---

## 9. ORFS-native flow

The design is integrated into the OpenROAD-flow-scripts Makefile at
`flow/designs/sky130hd/tt_inverter/config.mk`.

```bash
# From repo root — requires OpenROAD on PATH
cd flow

# tt_inverter is the active DESIGN_CONFIG in flow/Makefile
make                  # full flow: synth → route → finish
make synth            # synthesis only
make floorplan        # floorplan only
make place            # placement only
make cts              # CTS only
make route            # routing only
make finish           # GDS + DRC + LVS + reports

# Override design at command line
make DESIGN_CONFIG=./designs/sky130hd/tt_inverter/config.mk route
```

ORFS stage outputs:

```
flow/logs/sky130hd/tt_inverter/
  1_synth.log   2_floorplan.log   3_place.log
  4_cts.log     5_route.log       6_finish.log

flow/results/sky130hd/tt_inverter/
  1_synth/        2_floorplan/    3_place/
  4_cts/          5_route/        6_finish/

flow/reports/sky130hd/tt_inverter/
  synth_stat.rpt   timing.rpt   drc.rpt   lvs.rpt
```

---

## 10. Expected outputs

| Stage | Key output file | Notes |
|-------|----------------|-------|
| Synthesis | `results/synthesis/tt_um_inverter.v` | 1× inv_1, ~3× conb_1 |
| Pre-place STA | `reports/synthesis/opensta.min_max.rpt` | wire-load, no RC |
| Floorplan | `results/floorplan/tt_um_inverter.def` | die/core/IO/PDN |
| Placement | `results/placement/tt_um_inverter.def` | legal cell positions |
| CTS | (same as placement DEF) | RUN_CTS=0, skipped |
| Routing | `results/routing/tt_um_inverter.def` | all nets DRC-routed |
| Route guides | `results/routing/tt_um_inverter.guide` | FastRoute guides |
| SPEF | `results/routing/tt_um_inverter.spef` | R/C parasitics |
| Post-route STA | `reports/routing/sta-rcx.min_max.rpt` | with SPEF |
| GDS (Magic) | `results/magic/tt_um_inverter.gds` | submission file |
| GDS (KLayout) | `results/klayout/tt_um_inverter.gds` | cross-check |
| Abstract LEF | `results/magic/tt_um_inverter.lef` | for wrapper |
| DRC report | `reports/magic_drc/tt_um_inverter.drc` | target: 0 violations |
| LVS report | `reports/lvs/tt_um_inverter.lvs.lef.log` | "match uniquely" |
| Antenna report | `reports/antenna/tt_um_inverter_antenna.rpt` | target: 0 |

---

## 11. TinyTapeout signoff checklist

Run `bash scripts/run_checks.sh` after `make flow` for an automated
pass/fail summary. All checks must pass before submission.

```
┌─────────────────────────────────────────────────────────┬────────────┐
│ Check                                                   │ Target     │
├─────────────────────────────────────────────────────────┼────────────┤
│ Synthesized netlist present                             │  PASS      │
│ Floorplan DEF present                                   │  PASS      │
│ Placed DEF present                                      │  PASS      │
│ Routed DEF present                                      │  PASS      │
│ SPEF parasitics present                                 │  PASS      │
│ GDSII (Magic) present                                   │  PASS      │
│ GDSII (KLayout) present                                 │  PASS      │
│ Abstract LEF present                                    │  PASS      │
├─────────────────────────────────────────────────────────┼────────────┤
│ Magic DRC — violation count                             │  = 0       │
│ Netgen LVS — "Circuits match uniquely"                  │  true      │
│ Antenna violations after diode insertion                │  = 0       │
│ Post-route WNS (setup slack, 100 MHz)                   │  ≥ 0 ns    │
│ Post-route WHS (hold slack)                             │  ≥ 0 ns    │
│ Chip area ≤ 16 000 µm² (160×100 µm tile)               │  true      │
│ RTL simulation — all 256 patterns PASS                  │  256/256   │
└─────────────────────────────────────────────────────────┴────────────┘
```

When all checks pass, submit:
- `results/magic/tt_um_inverter.gds` → TinyTapeout upload portal
- `info.yaml` → project description and author metadata

---

## 12. Technical constraints

| Constraint | Value |
|------------|-------|
| PDK | SkyWater SKY130A (`sky130A`) |
| Standard-cell library | `sky130_fd_sc_hd` (1.8 V, high-density) |
| Technology node | 130 nm |
| Die area | 160 µm × 100 µm |
| Core area | 140 µm × 80 µm |
| Core utilisation | 35 % |
| Row height (std-cell) | 2.72 µm |
| Site width | 0.46 µm |
| Metal layers (signal) | li1, met1, met2, met3 |
| Metal layers (PDN) | met4 (V strap), met5 (H strap) |
| Min metal width | li1: 0.17 µm · met1: 0.14 µm · met2: 0.14 µm |
| VDD / VSS | 1.8 V nominal |
| Timing corner | TT 25°C 1.8 V (`sky130_fd_sc_hd__tt_025C_1v80.lib`) |
| Clock period | 10 ns (100 MHz) |
| IO delay budget | 2 ns in + 2 ns out (20% of period each) |
| Tapcell cell | `sky130_fd_sc_hd__tapvpwrvgnd_1` |
| Tapcell spacing | 14 µm |
| Fill cells | `sky130_fd_sc_hd__fill_{1,2,4,8}` |
| Antenna strategy | Global-route diode insertion (strategy 3) |
| Antenna diode | `sky130_fd_sc_hd__diode_2` |
| Antenna limit | 400× per metal layer |
| OpenLane image | `efabless/openlane:2023.07.19-1` |
| SKY130A PDK commit | `0fe599b2afb6708d281543108caf8310912f54af` (volare) |
