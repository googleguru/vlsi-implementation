// CA Rule-235 N-cell 1-D row update with periodic (wrap-around) boundary.
// next_state[i] = ca235_cell( state[(i-1) mod N], state[i], state[(i+1) mod N] )
`default_nettype none
`timescale 1ns / 1ps

module ca235_row #(
    parameter N = 8
) (
    input  wire [N-1:0] state,
    output wire [N-1:0] next_state
);
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : g_cell
            ca235_cell u_cell (
                .L   ((i == 0)     ? state[N-1] : state[i-1]),
                .C   (state[i]),
                .R   ((i == N-1)   ? state[0]   : state[i+1]),
                .next(next_state[i])
            );
        end
    endgenerate
endmodule
`default_nettype wire
