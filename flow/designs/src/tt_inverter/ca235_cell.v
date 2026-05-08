// CA Rule-235 single-cell combinational next-state logic.
// Rule 235 (0xEB = 0b11101011): neighborhood {L,C,R} → next
//
// Truth table:
//   L C R | next     minimised: next = R | ~(L ^ C)
//   0 0 0 |  1
//   0 0 1 |  1
//   0 1 0 |  0
//   0 1 1 |  1
//   1 0 0 |  0
//   1 0 1 |  1
//   1 1 0 |  1
//   1 1 1 |  1
`default_nettype none
`timescale 1ns / 1ps

module ca235_cell (
    input  wire L,
    input  wire C,
    input  wire R,
    output wire next
);
    assign next = R | ~(L ^ C);
endmodule
`default_nettype wire
