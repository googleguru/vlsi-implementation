// TinyTapeout top-level module — CMOS inverter
// Complies with TinyTapeout v5 / v6 standard port interface.
// Die area: 160 µm × 100 µm (single TT tile, sky130_fd_sc_hd)
//
// Pin mapping:
//   ui_in[0]  → inverter input
//   uo_out[0] ← inverted output
//   ui_in[7:1], uio_* — unused, tied off
`default_nettype none
`timescale 1ns / 1ps

module tt_um_inverter (
    input  wire [7:0] ui_in,    // dedicated inputs (TT mux → user)
    output wire [7:0] uo_out,   // dedicated outputs (user → TT mux)
    input  wire [7:0] uio_in,   // bidir IO input path
    output wire [7:0] uio_out,  // bidir IO output path
    output wire [7:0] uio_oe,   // bidir IO output enable (1 = drive)
    input  wire       ena,      // 1 when tile is powered; ignore unless power-gating
    input  wire       clk,      // TT system clock
    input  wire       rst_n     // TT active-low reset
);

    wire inv_out;

    inverter u_inv (
        .in  (ui_in[0]),
        .out (inv_out)
    );

    assign uo_out  = {7'b0, inv_out};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Tie off unused signals to avoid inferred logic or DC warnings
    wire _unused_ok = &{ena, clk, rst_n, ui_in[7:1], uio_in};

endmodule
`default_nettype wire
