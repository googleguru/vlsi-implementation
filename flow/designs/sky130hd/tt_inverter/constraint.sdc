# ============================================================
# SDC — tt_um_inverter on SKY130HD
# Clock: 100 MHz (10 ns period) — TinyTapeout default
# ============================================================

current_design tt_um_inverter

# ── Clock definition ─────────────────────────────────────────
# clk is the TT-wrapper-supplied clock; the inverter is
# combinational but the port must still be constrained so
# OpenSTA can compute setup/hold slack on the wrapper regs.
set clk_period 10.0
set clk_io_pct  0.20

create_clock -name clk -period $clk_period [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]

# ── IO timing ────────────────────────────────────────────────
# 20 % of period for input/output delays — typical TT margin
set_input_delay  [expr $clk_period * $clk_io_pct] \
    -clock clk [remove_from_collection [all_inputs] [get_ports clk]]

set_output_delay [expr $clk_period * $clk_io_pct] \
    -clock clk [all_outputs]

# ── False paths for async resets / enables ───────────────────
# rst_n and ena are quasi-static; no timing arc needed
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports ena]

# ── Disable timing through unused bidir ports ────────────────
set_false_path -from [get_ports {uio_in[*]}]
set_false_path -to   [get_ports {uio_out[*]}]
set_false_path -to   [get_ports {uio_oe[*]}]

# ── Drive/load models ────────────────────────────────────────
# Represent upstream driver as 4× buffer; downstream load = 10 fF
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 \
    -pin X [remove_from_collection [all_inputs] [get_ports clk]]
set_load 0.01 [all_outputs]
