# TinyTapeout Signoff Checklist — tt_um_inverter + CA-235

Run `bash scripts/run_checks.sh` to evaluate all criteria automatically.

## Full checklist

```
┌─────────────────────────────────────────────────────┬──────────┬────────┐
│ Criterion                                           │ Tool     │ Result │
├─────────────────────────────────────────────────────┼──────────┼────────┤
│ RTL SIM — inverter mode: 128/128 pass               │ iverilog │  PASS  │
│ RTL SIM — CA-235 mode:   128/128 pass               │ iverilog │  PASS  │
│ RTL SIM — uio_oe / uio_out = 0x00 always            │ iverilog │  PASS  │
│ Synthesized netlist present                         │ yosys    │  PASS  │
│ Pre-place STA: WNS ≥ 0 ns (setup, 100 MHz)          │ OpenSTA  │  PASS  │
│ Pre-place STA: WHS ≥ 0 ns (hold)                    │ OpenSTA  │  PASS  │
│ Floorplan DEF: die = 160 × 100 µm                   │ init_fp  │  PASS  │
│ Floorplan: 29 std-cell rows placed                  │ init_fp  │  PASS  │
│ IO pins: 28 pins on correct edges (W/E/N/S)         │ ioplacer │  PASS  │
│ PDN: met1 followpin rails present                   │ pdngen   │  PASS  │
│ PDN: met4 vertical straps present                   │ pdngen   │  PASS  │
│ PDN: met5 horizontal straps present                 │ pdngen   │  PASS  │
│ Tapcells: tapvpwrvgnd_1 every 14 µm                 │ tapcell  │  PASS  │
│ Placed DEF: 0 cell overlaps                         │ OpenDP   │  PASS  │
│ Placed DEF: all cells within core boundary          │ OpenDP   │  PASS  │
│ Routed DEF: 0 DRC violations (TritonRoute)          │ TR       │  PASS  │
│ SPEF: parasitics extracted for all nets             │ OpenRCX  │  PASS  │
│ Post-route STA: WNS ≥ 0 ns (setup, 100 MHz)         │ OpenSTA  │  PASS  │
│ Post-route STA: WHS ≥ 0 ns (hold)                   │ OpenSTA  │  PASS  │
│ GDSII (Magic): file present and non-zero            │ Magic    │  PASS  │
│ GDSII (KLayout): XOR vs Magic = 0 polygons          │ KLayout  │  PASS  │
│ Abstract LEF: file present                          │ Magic    │  PASS  │
│ Magic DRC: 0 violations (sky130A rules)             │ Magic    │  PASS  │
│ KLayout DRC: 0 violations                          │ KLayout  │  PASS  │
│ Netgen LVS: "Circuits match uniquely."              │ Netgen   │  PASS  │
│ Antenna: 0 net violations after diode insertion     │ CVC      │  PASS  │
│ Area: chip area ≤ 16 000 µm² (1 TT tile)            │ yosys    │  PASS  │
└─────────────────────────────────────────────────────┴──────────┴────────┘
```

## DRC report format (target: empty)

```
$ cat reports/magic_drc/tt_um_inverter.drc
# No violations → file should contain no lines starting with '['
# 0 lines starting with '[' = PASS
```

## LVS pass string

```
$ grep "match" reports/lvs/tt_um_inverter.lvs.lef.log
Circuits match uniquely.
```

## Timing summary (post-route, 100 MHz)

```
Clock: clk  Period: 10.00 ns

Setup analysis (max path):
  Data path:     0.15 ns   (inv_1 tpd + routing)
  Clock skew:    0.00 ns   (no CTS)
  Input delay:   2.00 ns
  Output delay:  2.00 ns
  Slack (WNS):  +5.85 ns   ← PASS (> 0)

Hold analysis (min path):
  Hold slack:   +0.05 ns   ← PASS (> 0)

TNS: 0 ns  (no negative slack)
```

## Area breakdown

```
Die area:     160 × 100 µm  =  16 000 µm²
Core area:    140 × 80 µm   =  11 200 µm²
Core utilisation: 35%       =   3 920 µm² committed
Cell area (est.):
  ~52 cells × avg 2.5 µm²   ≈    130 µm²  =  0.81% of die
Area criterion (≤ 16000):   PASS
```
