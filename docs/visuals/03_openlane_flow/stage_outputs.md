# OpenLane Stage-wise Output Artifacts

All outputs land under:
```
tinytapeout/openlane/tt_um_inverter/runs/<RUN_TAG>/
```

## Stage 1 — Synthesis

```
results/synthesis/
  tt_um_inverter.v            ← gate-level netlist (sky130_fd_sc_hd cells)
  tt_um_inverter.stat         ← cell statistics summary

reports/synthesis/
  1-synthesis.AREA_0.stat.rpt ← yosys synthesis report
  opensta.min_max.rpt         ← pre-place STA (wire-load model)
  opensta.slack.min.rpt       ← hold slack report
  opensta.slack.max.rpt       ← setup slack report
```

Expected netlist snippet:
```verilog
// 1x inv_1, 8x xor2_1, 8x inv_X, 8x or2_1, 8x mux2_1, ~19x conb_1
sky130_fd_sc_hd__inv_1  _u_inv_ (.A(ui_in[0]), .Y(_out_));
sky130_fd_sc_hd__xor2_1 _xor0_  (.A(ui_in[7]), .B(ui_in[0]), .X(_xor0_));
...
```

## Stage 2 — Floorplan

```
results/floorplan/
  tt_um_inverter.def          ← floorplan DEF (die+core defined, cells placed)
  tt_um_inverter.odb          ← OpenDB binary snapshot

reports/floorplan/
  2-floorplan.log             ← init_fp + ioplacer log
  3-io_place.log              ← IO pin placement log
  4-pdn.log                   ← PDN generation log
```

Floorplan statistics:
```
Die area:   160.00 × 100.00 µm  (16 000 µm²)
Core area:  140.00 ×  80.00 µm  (11 200 µm²)
Core util:  35 %  →  3 920 µm² used
Row count:  29 rows  (sky130_fd_sc_hd row height = 2.72 µm)
IO pins:    28 total (W: ui_in[7:0], E: uo_out[7:0], N+S: uio/ctrl)
```

## Stage 3 — Placement

```
results/placement/
  tt_um_inverter.def          ← placed DEF (all cells legalised)
  tt_um_inverter.odb

reports/placement/
  6-place.log                 ← RePLace global placement log
  7-resizer.log               ← buffer/gate sizing log
  8-dp.log                    ← OpenDP detail placement log
  timing/                     ← post-placement timing snapshots
```

## Stage 4 — CTS (SKIPPED)

```
RUN_CTS = 0 — no flip-flops; placement DEF used unchanged.
```

## Stage 5 — Routing

```
results/routing/
  tt_um_inverter.def          ← routed DEF (all nets connected)
  tt_um_inverter.guide        ← FastRoute global route guides

reports/routing/
  9-global_route.log          ← FastRoute congestion log
  10-detail_route.log         ← TritonRoute DRC log (target: 0)
  10-antenna.rpt              ← antenna violation list
```

## Stage 6 — Parasitic Extraction

```
results/routing/
  tt_um_inverter.spef         ← Standard Parasitic Exchange Format

reports/routing/
  11-rcx.log                  ← OpenRCX extraction log
  12-sta-rcx.min_max.rpt      ← post-route STA with RC parasitics
```

SPEF snippet:
```
*SPEF "IEEE 1481-1998"
*DESIGN "tt_um_inverter"
*R_UNIT 1 OHM
*C_UNIT 1 FF
*NET _net_ui_in_0_ 0.003
...
```

## Stage 7 — GDS Stream-out

```
results/magic/
  tt_um_inverter.gds          ← PRIMARY GDSII (SUBMISSION FILE)
  tt_um_inverter.lef          ← abstract LEF (black-box for integration)
  tt_um_inverter.mag          ← Magic layout database

results/klayout/
  tt_um_inverter.gds          ← secondary GDSII (XOR must = 0 polygons)

reports/magic/
  magic_drc_violations.rpt    ← violations list (target: 0)
```

## Stage 8 — Signoff

```
reports/magic_drc/
  tt_um_inverter.drc          ← Magic DRC log (target: 0 lines)

reports/lvs/
  tt_um_inverter.lvs.lef.log  ← Netgen LVS log
                              ← pass string: "Circuits match uniquely."

reports/antenna/
  tt_um_inverter_antenna.rpt  ← CVC antenna ratio report (target: < 400×)

reports/routing/
  13-sta-signoff.min_max.rpt  ← final OpenSTA timing (WNS ≥ 0 ns)
```
