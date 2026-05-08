// TinyTapeout top-level — CMOS inverter + CA Rule-235 (dual-mode).
// Die area: 160 µm × 100 µm (single TT tile, sky130_fd_sc_hd).
//
// Pin mapping:
//   ui_in[7]=0  INVERTER MODE  uo_out[0] = ~ui_in[0]  uo_out[7:1] = 0
//   ui_in[7]=1  CA-235  MODE   uo_out[7:0] = CA-235 next-state(ui_in[7:0])
//                              (wrap-around 8-cell, ui_in[7] participates)
//   uio_*       never driven   uio_oe = 0 always
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
    wire        inv_out;
    wire [7:0]  ca_next;

    inverter u_inv (
        .in  (ui_in[0]),
        .out (inv_out)
    );

    ca235_row #(.N(8)) u_ca (
        .state     (ui_in),
        .next_state(ca_next)
    );

    // ui_in[7]=0 → inverter mode; ui_in[7]=1 → CA-235 mode
    assign uo_out  = ui_in[7] ? ca_next : {7'b0, inv_out};
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire _unused_ok = &{ena, clk, rst_n, uio_in};

endmodule
`default_nettype wire
