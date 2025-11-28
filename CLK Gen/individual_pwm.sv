// ------------------------------------------------------------
// individual_pwm.sv
// Generic N-bit PWM engine (default 8-bit)
// Duty cycle = duty / 2^WIDTH
// ------------------------------------------------------------
`timescale 1ns/1ps

module individual_pwm #(
    parameter int WIDTH = 8
) (
    input  logic             clk_pwm,   // PWM tick clock
    input  logic             rst_n,     // active-low reset
    input  logic             enable,    // 1 = PWM active, 0 = force low
    input  logic [WIDTH-1:0] duty,      // duty setting (e.g. PWMx register)
    output logic             pwm_out
);

    logic [WIDTH-1:0] ctr;

    // Free-running counter
    always_ff @(posedge clk_pwm or negedge rst_n) begin
        if (!rst_n)
            ctr <= '0;
        else
            ctr <= ctr + {{(WIDTH-1){1'b0}}, 1'b1};
    end

    // Compare to set duty cycle
    always_comb begin
        if (!enable)
            pwm_out = 1'b0;
        else
            pwm_out = (ctr < duty);
    end

endmodule
