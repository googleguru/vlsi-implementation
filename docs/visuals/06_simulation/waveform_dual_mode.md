# RTL Simulation Waveforms — Dual-Mode (Inverter + CA-235)

## Inverter mode (ui_in[7]=0)

```
Time(ns)   0    5   10   15   20   25   30   35   40

clk        ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌───
           └────┘    └────┘    └────┘    └────┘    └───
           (100 MHz — 10 ns period)

rst_n      ──────┐
           (0)   └──────────────────────────────────────  (1)

ui_in[7]   ──────────────────────────────────────────────  0 (inverter mode)

ui_in[0]   ──────────────────┐              ┌───────────
                              └──────────────┘
           (0)                (1)             (0)

uo_out[0]  ┌────────────────┐              ┌───────────
           (1)               └──────────────┘  (1)
                             (0)
           │◄── tpd ≈ 0.15 ns ──►│   (sky130_fd_sc_hd__inv_1)

uo_out[7:1]────────────────────────────────────────────  0x00 always
uio_out    ────────────────────────────────────────────  0x00 always
uio_oe     ────────────────────────────────────────────  0x00 always
```

## CA-235 mode (ui_in[7]=1, example pattern 0xA5 → next)

Pattern 0xA5 = `1010 0101`:
- `next = R | ~(L ^ C)` for each cell (wrap-around)

```
Time(ns)   0    2    4    6    8

clk        ┌────┐    ┌────┐    ┌────┐
           └────┘    └────┘    └────┘

ui_in[7:0] ─┬──────────┬──────────┬────
            │  0xA5    │  0xCA    │  0x7F
            │10100101  │11001010  │01111111
            └──────────┴──────────┴────
              (1→CA)     (1→CA)

uo_out[7:0]──┬──────────┬──────────┬────
             │  ?→      │  0xEB    │  0xFF
             │computed  │11101011  │(fixed pt)
             └──────────┴──────────┴────
```

Step-by-step for 0xA5 = `10100101`:

```
Cell  s[i]  L       C       R       L^C  ~(L^C)  R|~(L^C)=ns
 0    1      1(s7)   1(s0)   0(s1)   0     1       1
 1    0      1(s0)   0(s1)   1(s2)   1     0       1
 2    1      0(s1)   1(s2)   0(s3)   1     0       0
 3    0      1(s2)   0(s3)   0(s4)   1     0       0
 4    0      0(s3)   0(s4)   1(s5)   0     1       1
 5    1      0(s4)   1(s5)   0(s6)   1     0       0
 6    0      1(s5)   0(s6)   1(s7)   1     0       1
 7    1      0(s6)   1(s7)   1(s0)   1     0       1

next_state = {ns7,ns6,...,ns0} = 11001001 = 0xC9
```

## Testbench test coverage

```
Mode       Patterns    Checks per pattern          Total checks
─────────  ──────────  ──────────────────────────  ─────────────
Inverter   128         uo_out=={7'b0,~in} + uio    256
CA-235     128         uo_out==ca235_ref(ui_in)     128
─────────────────────────────────────────────────────────────
Total      256         —                            384 assertions
```

## VCD viewing with GTKWave

```bash
cd tinytapeout
make sim                          # generates tb_tt_um_inverter.vcd
gtkwave tb_tt_um_inverter.vcd &

# Recommended signal groups:
# Group 1 — Control:  clk  rst_n  ena
# Group 2 — Inputs:   ui_in[7:0] (Hex)
# Group 3 — Outputs:  uo_out[7:0] (Hex)  uo_out[0] (Binary)
# Group 4 — Bidir:    uio_in[7:0]  uio_out[7:0]  uio_oe[7:0]
```
