// Testbench for clock divider
module clock_divider_tb;

// Set timescale
timeunit 1us;
timeprecision 1ns;

// Declare port nets/vars
logic reset, sleep;
logic clk;
logic clk_200K, clk_6p25K, clk_3p13K, clk_1p56K;
global_if glb(.reset, .sleep);

// Instantiate DUTs
clock_divider #(1) DUT0(.clk_in(clk), .glb, .clk_out(clk_200K)); // Divide by 2 for 200KHz
clock_divider #(6) DUT1(.clk_in(clk), .glb, .clk_out(clk_6p25K)); // Divide by 64 for 6.25KHz
clock_divider #(7) DUT2(.clk_in(clk), .glb, .clk_out(clk_3p13K)); // Divide by 128 for ~3.13KHz
clock_divider #(8) DUT3(.clk_in(clk), .glb, .clk_out(clk_1p56K)); // Divide by 256 for ~1.56KHz

initial begin
    clk = 0;
    #3 reset = 1; #3 reset = 0; // Reset the DUTs
    fork
        forever #2.5 clk = ~clk;
        #10000 $finish();
    join
end

endmodule