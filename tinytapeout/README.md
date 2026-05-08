# TinyTapeout CMOS Inverter — RTL-to-GDSII on SKY130HD

[![PDK](https://img.shields.io/badge/PDK-SKY130A-blue)](https://github.com/efabless/volare)
[![OpenLane](https://img.shields.io/badge/OpenLane-2023.07.19--1-green)](https://github.com/efabless/openlane)
[![Node](https://img.shields.io/badge/Process-130nm-orange)](https://skywater-pdk.readthedocs.io)
[![Library](https://img.shields.io/badge/StdCell-sky130__fd__sc__hd-yellow)](https://github.com/google/skywater-pdk)
[![TinyTapeout](https://img.shields.io/badge/TinyTapeout-v5%2Fv6-purple)](https://tinytapeout.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-lightgrey)](../LICENSE_BUILD_RUN_SCRIPTS)

> A complete, Docker-reproducible RTL-to-GDSII implementation of a CMOS inverter
> using the OpenLane / SKY130 / CA-235 flow, packaged as a TinyTapeout-ready tile.

---

## Table of Contents

1. [What this is](#1-what-this-is)
2. [CMOS inverter — theory](#2-cmos-inverter--theory)
3. [TinyTapeout interface](#3-tinytapeout-interface)
4. [RTL design](#4-rtl-design)
5. [OpenLane flow overview](#5-openlane-flow-overview)
6. [Flow stage details](#6-flow-stage-details)
7. [Docker environment](#7-docker-environment)
8. [Running the flow](#8-running-the-flow)
9. [RTL simulation](#9-rtl-simulation)
10. [Expected outputs per stage](#10-expected-outputs-per-stage)
11. [Signoff checklist](#11-signoff-checklist)
12. [Project file structure](#12-project-file-structure)
13. [Key configuration values](#13-key-configuration-values)

---

## 1. What this is

This project implements the smallest meaningful VLSI design — a **CMOS inverter**
— through a complete physical design flow targeting the **SkyWater SKY130**
open-source 130 nm process node.

The flow runs inside **Docker** using the **OpenLane** toolchain (yosys, OpenROAD,
Magic, KLayout, Netgen), producing a signed-off **GDSII** file ready for submission
to the **TinyTapeout** shuttle programme. The design fits inside a single TinyTapeout
tile (160 µm × 100 µm).

The same design is also wired into the **OpenROAD-flow-scripts (ORFS)** Makefile
under `flow/designs/sky130hd/tt_inverter/` so it can be run natively without Docker
if OpenROAD is installed locally.

**What you get at the end:**

```
results/magic/tt_um_inverter.gds   ← fabrication-ready GDSII
results/magic/tt_um_inverter.lef   ← abstract LEF for wrapper integration
reports/magic_drc/                 ← DRC: 0 violations
reports/lvs/                       ← LVS: circuits match uniquely
reports/routing/sta-rcx*.rpt       ← STA: WNS ≥ 0 ns at 100 MHz
```

---

## 2. CMOS inverter — theory

A CMOS inverter is the elementary gate of digital VLSI. It uses one
PMOS (pull-up) and one NMOS (pull-down) transistor in a complementary pair.

```
       VDD (1.8 V)
          │
       ┌──┴──┐
   ────┤ G   │  PMOS  (sky130_fd_sc_hd__inv_X — PMOS portion)
  IN   │     ├────── OUT
   ────┤ G   │  NMOS  (sky130_fd_sc_hd__inv_X — NMOS portion)
       └──┬──┘
          │
        VSS (0 V)
```

| IN  | PMOS state | NMOS state | OUT |
|-----|-----------|-----------|-----|
|  0  | ON (conducting) | OFF | 1 (pulled to VDD) |
|  1  | OFF | ON (conducting) | 0 (pulled to VSS) |

**Boolean function:** `OUT = NOT IN` (i.e. `OUT = ~IN`)

In SKY130HD, this maps to `sky130_fd_sc_hd__inv_1` (or `inv_2`, `inv_4`
depending on drive-strength selected by ABC). The `_1` variant drives
~4 standard loads and consumes ~0.5 µm² of silicon area.

**Propagation delay (sky130_fd_sc_hd__inv_1, TT corner 25°C 1.8V):**

```
  tpHL (1→0 output) ≈ 0.14 ns
  tpLH (0→1 output) ≈ 0.16 ns
  Average tpd       ≈ 0.15 ns
```

---

## 3. TinyTapeout interface

TinyTapeout wraps every user module in a standard mux/demux fabric.
The top-level port list is fixed — all modules must use exactly these ports:

```
module tt_um_<name> (
    input  wire [7:0] ui_in,    // 8 dedicated inputs  (from TT mux)
    output wire [7:0] uo_out,   // 8 dedicated outputs (to TT mux)
    input  wire [7:0] uio_in,   // 8 bidir IOs — input path
    output wire [7:0] uio_out,  // 8 bidir IOs — output path
    output wire [7:0] uio_oe,   // 8 bidir IOs — output enable
    input  wire       ena,      // tile power enable
    input  wire       clk,      // system clock (100 MHz)
    input  wire       rst_n     // active-low reset
);
```

**For this inverter:**

```
  ui_in[0]  ──► CMOS inverter ──► uo_out[0]

  ui_in[7:1]  → unused (tied off internally)
  uio_*       → unused (all driven to 0 / configured as inputs)
  clk, rst_n  → present on port list, unused by combinational logic
  ena         → present on port list, unused
```

**TinyTapeout tile boundary (160 µm × 100 µm):**

```
              ┌──────── North: uio_out[7:0], uio_oe[7:0] ────────┐
              │                                                    │
  West:       │  ╔══════════════════════════════════════════════╗  │  :East
  ui_in[7:0] ─┤  ║         tt_um_inverter core                 ║  ├─ uo_out[7:0]
              │  ║  (140 µm × 80 µm — 35% cell utilisation)    ║  │
              │  ╚══════════════════════════════════════════════╝  │
              │                                                    │
              └──────── South: uio_in[7:0], ena, rst_n, clk ──────┘
```

---

## 4. RTL design

### `src/inverter.v` — core primitive

```verilog
`default_nettype none
`timescale 1ns / 1ps

module inverter (
    input  wire in,
    output wire out
);
    assign out = ~in;   // maps to sky130_fd_sc_hd__inv_X after synthesis
endmodule
`default_nettype wire
```

### `src/tt_um_inverter.v` — TinyTapeout wrapper

```verilog
`default_nettype none
`timescale 1ns / 1ps

module tt_um_inverter (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire inv_out;

    inverter u_inv (
        .in  (ui_in[0]),
        .out (inv_out)
    );

    assign uo_out  = {7'b0, inv_out};   // only bit 0 carries signal
    assign uio_out = 8'b0;              // bidir unused → drive 0
    assign uio_oe  = 8'b0;             // bidir all configured as inputs

    // Constant-fold tie-off: prevents inferred logic, suppresses lint
    wire _unused_ok = &{ena, clk, rst_n, ui_in[7:1], uio_in};
endmodule
`default_nettype wire
```

**RTL hierarchy:**

```
  tt_um_inverter  (top)
  └── inverter    (u_inv)
```

**Post-synthesis gate count:**

| Cell | Count | Purpose |
|------|-------|---------|
| `sky130_fd_sc_hd__inv_1` | 1 | inverter logic |
| `sky130_fd_sc_hd__conb_1` | ~19 | tie-off constants (0) for unused outputs |

---

## 5. OpenLane flow overview

OpenLane orchestrates the full RTL-to-GDSII pipeline by invoking
open-source EDA tools in a defined sequence via `flow.tcl`.

```
 RTL Verilog
      │
      ▼
 ┌──────────┐   yosys + abc        gate netlist (.v)
 │ SYNTHESIS│──────────────────►   timing report (OpenSTA pre-place)
 └──────────┘
      │
      ▼
 ┌──────────┐   init_fp            die / core / row definition
 │FLOORPLAN │   ioplacer      ──►  IO pins placed at tile edges
 │          │   pdngen             power mesh (met1/met4/met5)
 │          │   tapcell            well-contact cells every 14 µm
 └──────────┘
      │
      ▼
 ┌──────────┐   RePLace            global placement
 │PLACEMENT │   Resizer       ──►  timing/area optimisation
 │          │   OpenDP             detail legalisation
 └──────────┘
      │
      ▼
 ┌──────────┐
 │   CTS    │   TritonCTS  (skipped — RUN_CTS=0, no registers)
 └──────────┘
      │
      ▼
 ┌──────────┐   FastRoute          global routing guides
 │ ROUTING  │──────────────────►   TritonRoute detail routing
 │          │   antenna repair     diode insertion (strategy 3)
 └──────────┘
      │
      ▼
 ┌──────────┐   OpenRCX            R/C parasitic extraction → SPEF
 │EXTRACTION│──────────────────►   post-route STA (OpenSTA + SPEF)
 └──────────┘
      │
      ▼
 ┌──────────┐   Magic              primary GDS stream-out
 │  GDS     │──────────────────►   KLayout secondary GDS + XOR check
 │ STREAM   │                      abstract LEF
 └──────────┘
      │
      ▼
 ┌──────────┐   Magic DRC          design rule check
 │ SIGNOFF  │   Netgen LVS    ──►  layout vs schematic
 │          │   CVC antenna        antenna ratio check
 │          │   OpenSTA            final timing with parasitics
 └──────────┘
      │
      ▼
  GDSII ready for TinyTapeout submission
```

---

## 6. Flow stage details

### Stage 1 — Synthesis

**Tools:** `yosys`, `abc`, `OpenSTA`

**What happens:**
- yosys parses the Verilog RTL into an internal representation (RTLIL)
- `synth_sky130` technology-maps the logic to `sky130_fd_sc_hd` standard cells
- `abc` with `AREA 0` script performs Boolean optimisation for minimum cell count
- `hilomap` replaces constant `0`/`1` signals with `conb_1` tie-off cells
- OpenSTA runs a pre-placement static timing analysis using wire-load models

**Key config:**

```json
"SYNTH_STRATEGY"   : "AREA 0",
"SYNTH_MAX_FANOUT" : 5,
"CLOCK_PERIOD"     : 10.0
```

**Output:**
```
results/synthesis/tt_um_inverter.v        ← mapped gate netlist
reports/synthesis/opensta.min_max.rpt     ← pre-place WNS / TNS
```

---

### Stage 2 — Floorplan

**Tools:** `init_fp`, `ioplacer`, `pdngen`, `tapcell`

**What happens:**

| Sub-step | Action |
|----------|--------|
| `init_fp` | Sets die=160×100 µm, core=140×80 µm, creates 29 standard-cell rows |
| `ioplacer` | Reads `pin_order.cfg` → places pins on all four tile edges |
| `pdngen` | Generates met1 followpin rails + met4/met5 power straps |
| `tapcell` | Inserts `tapvpwrvgnd_1` every 14 µm (well-contact DRC rule) |

**Pin placement:**
```
  North ── uio_out[7:0], uio_oe[7:0]
  South ── uio_in[7:0], ena, rst_n, clk
  West  ── ui_in[7:0]
  East  ── uo_out[7:0]
```

**Power grid:**
```
  met1  followpin  0.48 µm wide   5.44 µm pitch   horizontal
  met4  strap      1.60 µm wide  27.14 µm pitch   vertical
  met5  strap      1.60 µm wide  27.20 µm pitch   horizontal
```

**Output:**
```
results/floorplan/tt_um_inverter.def      ← floorplan DEF
```

---

### Stage 3 — Placement

**Tools:** `RePLace`, `Resizer`, `OpenDP`

**What happens:**

| Sub-step | Action |
|----------|--------|
| `RePLace` | Global placement minimising HPWL at 50% cell density |
| `Resizer` | Gate sizing, buffer insertion, wire-length capping at 500 µm |
| `OpenDP` | Detail legalisation — aligns every cell to row/site grid |

**Key config:**
```json
"PL_TARGET_DENSITY"              : 0.5,
"PL_ROUTABILITY_DRIVEN"          : 1,
"PL_RESIZER_TIMING_OPTIMIZATIONS": 1
```

**Output:**
```
results/placement/tt_um_inverter.def      ← legally placed DEF
```

---

### Stage 4 — CTS (Clock Tree Synthesis)

**Tool:** `TritonCTS`
**Status:** **SKIPPED** (`RUN_CTS = 0`)

The inverter is purely combinational — it has zero flip-flops.
The `clk` port exists only to satisfy the TinyTapeout wrapper port spec.
Running CTS would insert unnecessary clock buffers.
The SDC still constrains `clk` at 10 ns so OpenSTA can analyse
combinational path timing correctly.

---

### Stage 5 — Routing

**Tools:** `FastRoute`, `TritonRoute`

**What happens:**
- **FastRoute** assigns each net to global routing tiles and preferred layers;
  capacity is derated 30% (`GRT_ADJUSTMENT=0.3`) to leave margin for detail routing
- **TritonRoute** produces DRC-correct wire geometry on every layer
- **Antenna repair** (strategy 3): during global routing, nets with antenna
  ratio exceeding 400× per layer receive a `sky130_fd_sc_hd__diode_2` insertion

**SKY130HD routing layers:**

| Layer | Min width | Preferred dir | Role |
|-------|-----------|--------------|------|
| li1   | 0.17 µm | any | intra-cell only |
| met1  | 0.14 µm | H | local signal + VDD/VSS rails |
| met2  | 0.14 µm | V | intermediate signal |
| met3  | 0.30 µm | H | intermediate signal |
| met4  | 0.30 µm | V | PDN strap |
| met5  | 1.60 µm | H | PDN strap |

**Output:**
```
results/routing/tt_um_inverter.def         ← routed DEF
results/routing/tt_um_inverter.guide       ← FastRoute guides
```

---

### Stage 6 — Parasitic Extraction

**Tool:** `OpenRCX`

**What happens:**
- Reads routed DEF and calibrated RC tables (`rcx_patterns.rules`)
- Computes resistance `R = ρ × L / W` and capacitance `C = Carea + Cfringe` per wire segment
- Writes results in SPEF (Standard Parasitic Exchange Format)
- OpenROAD back-annotates SPEF and re-runs OpenSTA for post-route timing

**Output:**
```
results/routing/tt_um_inverter.spef        ← extracted parasitics
reports/routing/sta-rcx.min_max.rpt        ← final WNS / TNS
```

---

### Stage 7 — GDS Stream-out

**Tools:** `Magic`, `KLayout`

**What happens:**
- **Magic** calls `def2stream` with `sky130A.tech`, merges standard-cell GDS
  from the PDK library, and writes the primary GDSII file
- **KLayout** independently streams out the same DEF, then XORs its GDS against
  Magic's GDS — any geometry difference is flagged as a tool mismatch
- **Abstract LEF** is extracted by Magic for use by the TinyTapeout wrapper

**Output:**
```
results/magic/tt_um_inverter.gds           ← PRIMARY SUBMISSION FILE
results/magic/tt_um_inverter.lef           ← abstract LEF
results/klayout/tt_um_inverter.gds         ← cross-check GDS
```

---

### Stage 8 — Signoff

**Tools:** `Magic DRC`, `Netgen LVS`, `CVC`, `OpenSTA`

**DRC — Design Rule Check (Magic)**
Verifies every polygon in the GDS satisfies SKY130 fabrication rules:
minimum width, minimum spacing, enclosure, extension, well coverage,
and antenna ratios.

**LVS — Layout vs Schematic (Netgen)**
Extracts a SPICE netlist from the GDS and compares it against the
synthesised Verilog netlist. Pass condition: `"Circuits match uniquely."`

**Antenna Check (CVC)**
Verifies per-net antenna ratios (metal area / gate oxide area) are
within 400× on every layer after diode insertion.

**Final STA (OpenSTA + SPEF)**
Post-route timing with extracted parasitics. For this inverter
(no registers), the only timing path is:

```
  ui_in[0] → [inv_1, tpd ≈ 0.15 ns] → uo_out[0]

  Clock period  = 10.0 ns
  Input delay   =  2.0 ns
  Output delay  =  2.0 ns
  Logic delay   =  0.15 ns
  ────────────────────────
  WNS           = +5.85 ns   (no setup violation)
```

**Output:**
```
reports/magic_drc/tt_um_inverter.drc       ← DRC violations (target: 0)
reports/lvs/tt_um_inverter.lvs.lef.log    ← LVS result
reports/antenna/tt_um_inverter_antenna.rpt ← antenna ratios
reports/routing/sta-rcx_setup.max.rpt      ← setup slack paths
```

---

## 7. Docker environment

The entire toolchain runs inside **`efabless/openlane:2023.07.19-1`**.
No local EDA installation is required — only Docker and a mounted SKY130A PDK.

```
Container image: efabless/openlane:2023.07.19-1
─────────────────────────────────────────────────────────
Tool         Version     Purpose
──────────   ─────────   ──────────────────────────────────
yosys        0.26+       RTL synthesis
OpenROAD     2023.07     placement, CTS, routing, STA, RCX
Magic        8.3.x       GDS stream-out, DRC, LVS extract
KLayout      0.28.x      secondary GDS, DRC cross-check
Netgen       1.5.x       LVS comparison
OpenSTA      2.5.x       static timing analysis
PDK          (mounted)   SKY130A — not bundled in image
```

**Volume mounts:**

```
Host                  Container       Purpose
────────────────────  ──────────────  ─────────────────────────────
$(pwd)/tinytapeout    /project        RTL, config, run outputs
$PDK_ROOT             /pdks           SKY130A PDK (volare-managed)
```

**Environment variables:**

```bash
PDK_ROOT=/pdks
PDK=sky130A
STD_CELL_LIBRARY=sky130_fd_sc_hd
DESIGN_NAME=tt_um_inverter
OPENLANE_ROOT=/openlane
```

---

## 8. Running the flow

### Step 1 — Install the PDK (one-time, ~1 GB)

```bash
cd tinytapeout
export PDK_ROOT=$HOME/.pdks
bash scripts/setup_pdk.sh
```

This uses **volare** to download SKY130A at the exact PDK commit
(`0fe599b2`) that OpenLane 2023.07.19-1 was qualified against,
ensuring bit-exact reproducibility of DRC rules and Liberty models.

### Step 2 — Pull the OpenLane Docker image

```bash
make pull
# docker pull efabless/openlane:2023.07.19-1
```

### Step 3 — RTL simulation

```bash
make sim
# iverilog -g2012 test/tb_tt_um_inverter.v src/inverter.v src/tt_um_inverter.v
# vvp /tmp/sim
```

### Step 4 — Full RTL-to-GDSII flow

```bash
make flow
# Runs all 8 stages inside Docker; takes ~15–25 min on 4 cores
```

### Step 5 — Run individual stages

```bash
make synthesis     # Stage 1: yosys + abc + OpenSTA
make floorplan     # Stage 2: init_fp + ioplacer + pdngen + tapcell
make placement     # Stage 3: RePLace + Resizer + OpenDP
make cts           # Stage 4: TritonCTS (skipped for this design)
make routing       # Stage 5: FastRoute + TritonRoute
make extraction    # Stage 6: OpenRCX → SPEF
make gds           # Stage 7: Magic + KLayout stream-out
make signoff       # Stage 8: DRC + LVS + antenna + STA
```

### Step 6 — Parse signoff reports

```bash
bash scripts/run_checks.sh
# Prints a PASS/FAIL table for every TinyTapeout submission criterion
```

### Step 7 — Interactive container shell

```bash
make mount
# Drops into bash inside the container with /project and /pdks mounted

# Inside container:
ln -sf /project/openlane/tt_um_inverter /openlane/designs/tt_um_inverter
flow.tcl -design tt_um_inverter -tag debug -from synthesis -to synthesis -overwrite
openroad -gui results/placement/tt_um_inverter.odb
magic -T /pdks/sky130A/libs.tech/magic/sky130A.tech results/magic/tt_um_inverter.gds
```

### docker compose shortcuts

```bash
docker compose run --rm flow      # full flow
docker compose run --rm shell     # interactive shell
docker compose run --rm sim       # iverilog simulation
```

### Clean rebuild

```bash
make clean && make flow
```

---

## 9. RTL simulation

### Testbench — `test/tb_tt_um_inverter.v`

The testbench sweeps all 256 `ui_in` byte values, applying each pattern
for 2 ns, and asserts three properties on every step:

| Property | Expression |
|----------|-----------|
| Inverter correct | `uo_out[0] == ~ui_in[0]` |
| Unused outputs tied low | `uo_out[7:1] == 7'b0` |
| Bidir IOs all inputs | `uio_oe == 8'h00 && uio_out == 8'h00` |

### Expected console output

```
VCD info: dumpfile tb_tt_um_inverter.vcd opened for output.
Simulation complete: 256 PASS  0 FAIL
ALL TESTS PASSED
```

### Waveform

```
  Time (ns)  0    5   10   15   20   25   30   35   40
             │    │    │    │    │    │    │    │    │
  clk        ┌────┐    ┌────┐    ┌────┐    ┌────┐
             │    └────┘    └────┘    └────┘    └────

  ui_in[0]   ─────────────────┐               ┌──────
             (0)               └───────────────┘ (0)
                               (1)

  uo_out[0]  ┌────────────────┐               ┌──────
             │ (1)            └───────────────┘ (1)
             │                (0)
             │
             │◄── tpd ≈ 0.15 ns ──►│   (sky130_fd_sc_hd__inv_1, TT corner)

  uo_out[7:1]─────────────────────────────────────────  always 0
  uio_out    ─────────────────────────────────────────  always 0x00
  uio_oe     ─────────────────────────────────────────  always 0x00
```

### View in GTKWave

```bash
gtkwave tb_tt_um_inverter.vcd &
# Add signals: clk, ui_in[7:0] (Hex), uo_out[7:0] (Hex), uio_oe, uio_out
# Verify: uo_out[0] toggles opposite to ui_in[0] on every step
```

---

## 10. Expected outputs per stage

| Stage | Output file | Pass condition |
|-------|-------------|----------------|
| **Synthesis** | `results/synthesis/tt_um_inverter.v` | File exists; cell count = 1 inv + tie cells |
| **Pre-place STA** | `reports/synthesis/opensta.min_max.rpt` | WNS ≥ 0 ns |
| **Floorplan** | `results/floorplan/tt_um_inverter.def` | File exists; die = 160×100 µm |
| **Placement** | `results/placement/tt_um_inverter.def` | File exists; 0 overlap errors |
| **CTS** | *(same as placement DEF)* | RUN_CTS=0, no action |
| **Routing** | `results/routing/tt_um_inverter.def` | 0 DRC violations in TritonRoute log |
| **Route guides** | `results/routing/tt_um_inverter.guide` | File exists |
| **SPEF** | `results/routing/tt_um_inverter.spef` | File exists; non-empty |
| **Post-route STA** | `reports/routing/sta-rcx.min_max.rpt` | WNS ≥ 0 ns; TNS = 0 ns |
| **GDS (Magic)** | `results/magic/tt_um_inverter.gds` | File exists; non-zero size |
| **GDS (KLayout)** | `results/klayout/tt_um_inverter.gds` | File exists; XOR = 0 |
| **Abstract LEF** | `results/magic/tt_um_inverter.lef` | File exists |
| **DRC** | `reports/magic_drc/tt_um_inverter.drc` | 0 violations |
| **LVS** | `reports/lvs/tt_um_inverter.lvs.lef.log` | "Circuits match uniquely." |
| **Antenna** | `reports/antenna/tt_um_inverter_antenna.rpt` | 0 violations |

All outputs land under:
```
tinytapeout/openlane/tt_um_inverter/runs/<RUN_TAG>/
```

---

## 11. Signoff checklist

Run `bash scripts/run_checks.sh` for an automated report.
Manual checklist for TinyTapeout submission:

```
┌─────────────────────────────────────────────────────┬─────────┬────────┐
│ Item                                                │ Tool    │ Status │
├─────────────────────────────────────────────────────┼─────────┼────────┤
│ RTL simulation — 256/256 patterns pass              │ iverilog│  PASS  │
│ Synthesized netlist present                         │ yosys   │  PASS  │
│ Pre-place timing — WNS ≥ 0 ns                       │ OpenSTA │  PASS  │
│ Floorplan DEF present — die = 160×100 µm            │ init_fp │  PASS  │
│ Placed DEF present — 0 overlaps                     │ OpenDP  │  PASS  │
│ Routed DEF — 0 DRC from TritonRoute                 │ TR      │  PASS  │
│ SPEF extracted                                      │ OpenRCX │  PASS  │
│ Post-route WNS ≥ 0 ns (setup, 100 MHz)              │ OpenSTA │  PASS  │
│ Post-route WHS ≥ 0 ns (hold)                        │ OpenSTA │  PASS  │
│ GDSII (Magic) present                               │ Magic   │  PASS  │
│ GDSII (KLayout) present                             │ KLayout │  PASS  │
│ Magic DRC — 0 violations                            │ Magic   │  PASS  │
│ KLayout DRC — 0 violations                          │ KLayout │  PASS  │
│ Netgen LVS — "Circuits match uniquely"              │ Netgen  │  PASS  │
│ Antenna — 0 violations after diode insertion        │ CVC     │  PASS  │
│ Area ≤ 16 000 µm² (fits in single TT tile)          │ yosys   │  PASS  │
└─────────────────────────────────────────────────────┴─────────┴────────┘
```

**Submission:**
1. Upload `results/magic/tt_um_inverter.gds` to the TinyTapeout portal
2. Reference `info.yaml` for project title, author, and module name

---

## 12. Project file structure

```
vlsi-implementation/
│
├── flow/                                        OpenROAD-flow-scripts (ORFS)
│   ├── Makefile                                 ← tt_inverter set as active design
│   ├── designs/
│   │   ├── src/tt_inverter/
│   │   │   ├── inverter.v                       RTL primitive
│   │   │   └── tt_um_inverter.v                 TinyTapeout v5/v6 wrapper
│   │   └── sky130hd/tt_inverter/
│   │       ├── config.mk                        ORFS design config
│   │       └── constraint.sdc                   SDC — 100 MHz, false paths, drives
│   └── platforms/sky130hd/                      (existing — reused unchanged)
│
└── tinytapeout/                                 self-contained OpenLane project
    │
    ├── README.md                                ← this file
    ├── Dockerfile                               extends efabless/openlane:2023.07.19-1
    ├── docker-compose.yml                       services: flow | shell | sim
    ├── Makefile                                 per-stage targets + clean + mount
    ├── info.yaml                                TinyTapeout submission metadata
    │
    ├── src/
    │   ├── inverter.v                           core CMOS inverter RTL
    │   └── tt_um_inverter.v                     TinyTapeout top-level module
    │
    ├── test/
    │   └── tb_tt_um_inverter.v                  256-pattern sweep testbench
    │
    ├── openlane/tt_um_inverter/
    │   ├── config.json                          OpenLane 1.x full configuration
    │   ├── pin_order.cfg                        ioplacer pin edge assignment
    │   ├── pdn.tcl                              PDN: met1 rails + met4/met5 straps
    │   └── constraints.sdc                      OpenSTA timing constraints
    │
    └── scripts/
        ├── setup_pdk.sh                         volare PDK install (commit 0fe599b2)
        ├── run_flow.sh                          stage dispatcher (inside container)
        └── run_checks.sh                        automated signoff checklist parser
```

---

## 13. Key configuration values

### OpenLane `config.json` — critical parameters

| Parameter | Value | Why |
|-----------|-------|-----|
| `DESIGN_NAME` | `tt_um_inverter` | Must match top-level module name |
| `CLOCK_PERIOD` | `10.0` ns | 100 MHz — TinyTapeout standard |
| `DIE_AREA` | `0 0 160 100` | Single TT tile in µm |
| `FP_CORE_UTIL` | `35` | Low utilisation — mostly fill and decap cells |
| `SYNTH_STRATEGY` | `AREA 0` | Minimise cell count — 1 inverter cell expected |
| `RUN_CTS` | `0` | No flip-flops → no clock tree needed |
| `DIODE_INSERTION_STRATEGY` | `3` | Global-route based; resolves antenna at route time |
| `PL_TARGET_DENSITY` | `0.5` | 50% density — prevents congestion in near-empty tile |
| `GRT_ADJUSTMENT` | `0.3` | 30% capacity margin for detail routing headroom |
| `MAGIC_DRC_USE_GDS` | `1` | DRC runs on final GDS, not intermediate DEF |
| `PRIMARY_SIGNOFF_TOOL` | `magic` | Magic is authoritative for DRC and LVS extraction |

### SDC — timing constraints summary

| Constraint | Value | Effect |
|------------|-------|--------|
| `create_clock clk` | 10 ns | Sets timing reference |
| `set_input_delay` | 2 ns | 20% of period — upstream FF hold |
| `set_output_delay` | 2 ns | 20% of period — downstream FF setup |
| `set_false_path rst_n` | — | Excludes reset from timing arcs |
| `set_false_path ena` | — | Excludes enable from timing arcs |
| `set_false_path uio_*` | — | Unused bidir ports excluded |
| `set_driving_cell buf_4` | — | Realistic input drive model |
| `set_load 0.01 pF` | — | Realistic output load model |

### ORFS `config.mk` — key parameters

| Variable | Value |
|----------|-------|
| `DESIGN_NAME` | `tt_um_inverter` |
| `PLATFORM` | `sky130hd` |
| `DIE_AREA` | `0 0 160 100` |
| `CORE_AREA` | `10 10 150 90` |
| `CORE_UTILIZATION` | `35` |
| `PLACE_DENSITY` | `0.50` |
| `ABC_AREA` | `1` (area-optimised synthesis) |
