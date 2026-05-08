// Structural CMOS inverter primitive
// Synthesises to sky130_fd_sc_hd__inv_X (size chosen by ABC)
`default_nettype none
`timescale 1ns / 1ps

module inverter (
    input  wire in,
    output wire out
);
    assign out = ~in;
endmodule
`default_nettype wire
