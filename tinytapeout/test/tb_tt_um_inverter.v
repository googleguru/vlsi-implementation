// Simulation testbench for tt_um_inverter
// Drives all 256 ui_in combinations; checks uo_out[0] == ~ui_in[0]
// Run: iverilog -o sim tb_tt_um_inverter.v ../src/inverter.v ../src/tt_um_inverter.v && vvp sim
`timescale 1ns / 1ps
`default_nettype none

module tb_tt_um_inverter;

    // ── DUT ports ────────────────────────────────────────────
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

    // ── 100 MHz clock ────────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Stimulus & checking ──────────────────────────────────
    integer i, pass, fail;
    initial begin
        $dumpfile("tb_tt_um_inverter.vcd");
        $dumpvars(0, tb_tt_um_inverter);

        ena   = 1;
        rst_n = 0;
        ui_in = 8'h00;
        uio_in = 8'h00;
        @(posedge clk); #1;
        rst_n = 1;

        pass = 0; fail = 0;

        // Sweep all 8-bit input patterns
        for (i = 0; i < 256; i = i + 1) begin
            ui_in = i[7:0];
            #2; // combinational propagation

            // Core correctness: uo_out[0] must equal ~ui_in[0]
            if (uo_out[0] !== ~ui_in[0]) begin
                $display("FAIL ui_in=%02h  uo_out[0]=%b expected=%b",
                         ui_in, uo_out[0], ~ui_in[0]);
                fail = fail + 1;
            end else begin
                pass = pass + 1;
            end

            // Upper output bits must always be 0
            if (uo_out[7:1] !== 7'b0) begin
                $display("FAIL uo_out[7:1] = %07b (expected 0)", uo_out[7:1]);
                fail = fail + 1;
            end

            // Bidir pins must be configured as inputs (oe=0, out=0)
            if (uio_oe !== 8'h00 || uio_out !== 8'h00) begin
                $display("FAIL uio: oe=%02h out=%02h (expected 0)", uio_oe, uio_out);
                fail = fail + 1;
            end
        end

        $display("Simulation complete: %0d PASS  %0d FAIL", pass, fail);
        if (fail == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED — check output above");

        $finish;
    end

endmodule
`default_nettype wire
