// Module for the simulated oscillator
module oscillator_400K(
    global_if glb, 
    output logic clk_400K
);

// Set timescale
timeunit 1ns;
timeprecision 1ps;

parameter real PERIOD = 2500.0; // In nanoseconds

initial clk_400K = 0;

always begin
    if (!glb.sleep)
        #(PERIOD/2) clk_400K = ~clk_400K;
    else begin
        clk_400K = 0;
        @(negedge glb.sleep);
    end
end

endmodule