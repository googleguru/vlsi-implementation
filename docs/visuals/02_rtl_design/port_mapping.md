# TinyTapeout Port Mapping — tt_um_inverter (Dual-Mode)

## TinyTapeout v5/v6 standard interface

```
                    ┌──────────────────────────────────────────┐
                    │             tt_um_inverter                │
  ui_in[7]  ───────►│ MODE SELECT (0=inverter, 1=CA-235)        │
  ui_in[6:1]───────►│ CA-235 state bits [6:1] (CA mode only)   │
  ui_in[0]  ───────►│ Inverter input (inverter mode)           │
                    │                                          │
  uo_out[0] ◄───────│ ~ui_in[0]        (inverter mode)        │
  uo_out[7:0]◄──────│ CA-235 next-state (CA-235 mode)         │
  uo_out[7:1]◄──────│ 0x00              (inverter mode)        │
                    │                                          │
  uio_out[7:0]◄─────│ 0x00  (never driven)                    │
  uio_oe[7:0] ◄─────│ 0x00  (always input)                    │
  uio_in[7:0] ───►  │ ignored                                 │
                    │                                          │
  clk  ────────────►│ unused (combinational design)            │
  rst_n────────────►│ unused (combinational design)            │
  ena  ────────────►│ unused (combinational design)            │
                    └──────────────────────────────────────────┘
```

## Pin-to-edge assignment (pin_order.cfg)

```
Edge    Pins
──────  ──────────────────────────────────────
West    ui_in[7]  ui_in[6]  ui_in[5]  ui_in[4]
        ui_in[3]  ui_in[2]  ui_in[1]  ui_in[0]
East    uo_out[7] uo_out[6] uo_out[5] uo_out[4]
        uo_out[3] uo_out[2] uo_out[1] uo_out[0]
North   uio_out[7:0]  uio_oe[7:0]
South   uio_in[7:0]   ena  rst_n  clk
```

## Dual-mode truth table (ui_in[7] as mode select)

```
ui_in[7]  ui_in[6:0]  Mode      uo_out[7:0]
────────  ──────────  ────────  ────────────────────────────────
    0      XXXXXXX    INVERTER  {7'b0, ~ui_in[0]}
    1      CCCCCCC    CA-235    CA-235 next-state of ui_in[7:0]
                                (ui_in[7]=1 participates in CA)
```

## CA-235 cell neighborhood in CA mode (ui_in[7]=1)

```
Cell  L (left)     C (center)   R (right)
────  ───────────  ───────────  ───────────
 0    ui_in[7]=1   ui_in[0]     ui_in[1]
 1    ui_in[0]     ui_in[1]     ui_in[2]
 2    ui_in[1]     ui_in[2]     ui_in[3]
 3    ui_in[2]     ui_in[3]     ui_in[4]
 4    ui_in[3]     ui_in[4]     ui_in[5]
 5    ui_in[4]     ui_in[5]     ui_in[6]
 6    ui_in[5]     ui_in[6]     ui_in[7]=1
 7    ui_in[6]     ui_in[7]=1   ui_in[0]
```

## Synthesis cell count (post-yosys, AREA 0)

| Cell                          | Count | Function            |
|-------------------------------|-------|---------------------|
| sky130_fd_sc_hd__inv_1        | 1     | CMOS inverter       |
| sky130_fd_sc_hd__xor2_1       | 8     | CA L^C              |
| sky130_fd_sc_hd__inv_X        | 8     | CA ~(L^C)           |
| sky130_fd_sc_hd__or2_1        | 8     | CA R or ~(L^C)      |
| sky130_fd_sc_hd__mux2_1       | 8     | Mode mux            |
| sky130_fd_sc_hd__conb_1       | ~19   | Tie-off cells       |
| **Total**                     | **~52** | **≈ 110 µm²**     |
