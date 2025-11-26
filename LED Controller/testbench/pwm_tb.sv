// Testbench for basic PWM module
module pwm_tb;

// Set timescale
timeunit 1us;
timeprecision 1ns;

// Declare port nets/vars
logic reset, sleep;
logic pwm_out;
logic clk;
logic [7:0] duty;
global_if glb(.reset, .sleep);

// Instantiate DUT
pwm #(8) DUT(.pwm_out, .glb, .clk, .duty);

initial begin
    clk = 0; 
    forever #2.5 clk = ~clk;
end

initial begin
    sleep = 0; duty = 8'h00; reset = 0;
    #3 reset = 1; #3 reset = 0; // Reset the DUT
    #10000; duty = 8'h40; // Duty cycle = ~25%
    #10000; duty = 8'h80; // Duty cycle = ~50%
    #10000; duty = 8'hC0; // Duty cycle = ~75%
    #10000; duty = 8'hFF; // Duty cycle = ~99%
    #10000;
    $finish();
end
endmodule