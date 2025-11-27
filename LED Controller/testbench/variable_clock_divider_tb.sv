// Testbench for clock divider
module variable_clock_divider_tb;

// Set timescale
timeunit 1us;
timeprecision 1ns;

// Declare port nets/vars
logic reset, sleep;
logic clk_in, clk_out;
logic [7:0] divisor;
global_if glb(.reset, .sleep);

// Instantiate DUTs
variable_clock_divider #(8) DUT(.clk_in, .glb, .clk_out, .divisor);

task test();
    divisor = 8'h00;
    #1000 divisor = 8'h01;
    #1000 divisor = 8'h02;
    #1000 divisor = 8'h03;
    #1000 divisor = 8'h04;
    #1000 divisor = 8'h05;
    #1000 divisor = 8'h10;
    #1000 divisor = 8'h80;
    #1000 divisor = 8'hC5;
    #1000 divisor = 8'hFF;
endtask

initial begin
    clk_in = 0;
    #3 reset = 1; #3 reset = 0; // Reset the DUTs
    fork
        forever #2.5 clk_in = ~clk_in;
        test();
        #10000 $finish();
    join
end

endmodule