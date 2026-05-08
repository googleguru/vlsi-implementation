// CMOS inverter primitive — single sky130_fd_sc_hd__inv_X cell after synthesis
`default_nettype none
`timescale 1ns / 1ps

module inverter (
    input  wire in,
    output wire out
);
    assign out = ~in;
endmodule
`default_nettype wire
