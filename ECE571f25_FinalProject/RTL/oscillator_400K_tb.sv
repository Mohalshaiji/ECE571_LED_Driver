// Testbench for simulated oscillator
module oscillator_400K_tb;

// Set timescale
timeunit 1us;
timeprecision 1ps;

// Declare port nets/vars
logic reset, sleep;
logic clk_400K;
global_if glb(.reset, .sleep);

oscillator_400K DUT(.glb, .clk_400K);

initial begin
    reset = 0;
    #100;
    reset = 1;
    #100;
    reset = 0;
    #100;
    $finish();
end
endmodule