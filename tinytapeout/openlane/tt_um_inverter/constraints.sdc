# ============================================================
# OpenLane SDC — tt_um_inverter / SKY130HD / TinyTapeout
# 10 ns (100 MHz) — standard TT clock budget
# ============================================================

current_design tt_um_inverter

# ── Primary clock ────────────────────────────────────────────
create_clock -name clk -period 10.0 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]

# ── IO delay (20 % of period on all non-clock ports) ─────────
set_input_delay  2.0 -clock clk \
    [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 2.0 -clock clk [all_outputs]

# ── Async quasi-static signals ───────────────────────────────
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports ena]

# ── Unused bidir ports ───────────────────────────────────────
set_false_path -from [get_ports {uio_in[*]}]
set_false_path -to   [get_ports {uio_out[*]}]
set_false_path -to   [get_ports {uio_oe[*]}]

# ── Drive / load models ──────────────────────────────────────
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 -pin X \
    [remove_from_collection [all_inputs] [get_ports clk]]
set_load 0.01 [all_outputs]
