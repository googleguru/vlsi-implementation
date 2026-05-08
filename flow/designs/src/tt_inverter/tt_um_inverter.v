// TinyTapeout top-level wrapper — SKY130 / OpenLane compatible
// Interface: TinyTapeout v5+ standard (8-bit user IO bus)
//   ui_in[7:0]  dedicated inputs from the TT mux
//   uo_out[7:0] dedicated outputs to the TT mux
//   uio_in[7:0] bidirectional IOs — input path
//   uio_out[7:0] bidirectional IOs — output path
//   uio_oe[7:0]  bidirectional IOs — output enable (1 = output)
//   ena          power-on enable; ignore when not using power gating
//   clk          system clock supplied by TT wrapper
//   rst_n        active-low synchronous reset from TT wrapper
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

    // Only bit 0 carries the inverted signal; upper bits are tied low
    assign uo_out  = {7'b000_0000, inv_out};

    // Bidir port unused — all driven to 0, all set as inputs
    assign uio_out = 8'b0000_0000;
    assign uio_oe  = 8'b0000_0000;

    // Suppress "unused signal" lint warnings; tools will constant-fold this away
    wire _unused_ok = &{ena, clk, rst_n, ui_in[7:1], uio_in};

endmodule
`default_nettype wire
