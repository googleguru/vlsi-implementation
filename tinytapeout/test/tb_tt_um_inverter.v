// Testbench for tt_um_inverter (CMOS inverter + CA Rule-235, dual-mode).
// Compile:
//   iverilog -g2012 -o /tmp/sim \
//     tb_tt_um_inverter.v ../src/inverter.v \
//     ../src/ca235_cell.v ../src/ca235_row.v ../src/tt_um_inverter.v
//   vvp /tmp/sim
`timescale 1ns / 1ps
`default_nettype none

module tb_tt_um_inverter;

    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        ena, clk, rst_n;

    tt_um_inverter dut (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // CA-235 reference model: next[i] = state[(i+1)%8] | ~(state[(i-1+8)%8] ^ state[i])
    function [7:0] ca235_ref;
        input [7:0] s;
        integer     j;
        reg         l, c, r;
        begin
            ca235_ref = 8'b0;
            for (j = 0; j < 8; j = j + 1) begin
                l = (j == 0) ? s[7] : s[j-1];
                c = s[j];
                r = (j == 7) ? s[0] : s[j+1];
                ca235_ref[j] = r | ~(l ^ c);
            end
        end
    endfunction

    integer i, pass, fail;

    initial begin
        $dumpfile("tb_tt_um_inverter.vcd");
        $dumpvars(0, tb_tt_um_inverter);

        ena = 1; rst_n = 0; ui_in = 8'h00; uio_in = 8'h00;
        @(posedge clk); #1;
        rst_n = 1;
        pass = 0; fail = 0;

        // ── INVERTER MODE (ui_in[7]=0): sweep bits[6:0] ──────────
        for (i = 0; i < 128; i = i + 1) begin
            ui_in = i[7:0];   // bit7 = 0
            #2;
            if (uo_out !== {7'b0, ~ui_in[0]}) begin
                $display("FAIL INV  ui_in=%02h  uo_out=%02h  exp=%02h",
                         ui_in, uo_out, {7'b0, ~ui_in[0]});
                fail = fail + 1;
            end else
                pass = pass + 1;
            if (uio_oe !== 8'h00 || uio_out !== 8'h00) begin
                $display("FAIL uio  oe=%02h  out=%02h (both must be 0)", uio_oe, uio_out);
                fail = fail + 1;
            end
        end

        // ── CA-235 MODE (ui_in[7]=1): sweep bits[6:0] ────────────
        for (i = 0; i < 128; i = i + 1) begin
            ui_in = {1'b1, i[6:0]};
            #2;
            if (uo_out !== ca235_ref(ui_in)) begin
                $display("FAIL CA235 ui_in=%08b  uo_out=%08b  exp=%08b",
                         ui_in, uo_out, ca235_ref(ui_in));
                fail = fail + 1;
            end else
                pass = pass + 1;
        end

        $display("Inverter+CA-235 tests: %0d PASS  %0d FAIL", pass, fail);
        if (fail == 0) $display("ALL TESTS PASSED");
        else           $display("TESTS FAILED");
        $finish;
    end

endmodule
`default_nettype wire
