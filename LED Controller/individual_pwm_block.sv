// ------------------------------------------------------------
// individual_pwm_block.sv
// Wrapper for 4 independent PWM channels (LED0..LED3)
// Each channel uses individual_pwm with 8-bit duty
// ------------------------------------------------------------
`timescale 1ns/1ps

module individual_pwm_block (
    input  logic       clk_pwm,
    input  logic       rst_n,
    input  logic       sleep,        // 1 = low-power, disable PWM
    input  logic [7:0] pwm0_reg,     // register for LED0
    input  logic [7:0] pwm1_reg,     // register for LED1
    input  logic [7:0] pwm2_reg,     // register for LED2
    input  logic [7:0] pwm3_reg,     // register for LED3
    output logic [3:0] pwm_individual
);

    logic enable;
    assign enable = ~sleep;

    // LED0
    individual_pwm #(.WIDTH(8)) u_pwm0 (
        .clk_pwm (clk_pwm),
        .rst_n   (rst_n),
        .enable  (enable),
        .duty    (pwm0_reg),
        .pwm_out (pwm_individual[0])
    );

    // LED1
    individual_pwm #(.WIDTH(8)) u_pwm1 (
        .clk_pwm (clk_pwm),
        .rst_n   (rst_n),
        .enable  (enable),
        .duty    (pwm1_reg),
        .pwm_out (pwm_individual[1])
    );

    // LED2
    individual_pwm #(.WIDTH(8)) u_pwm2 (
        .clk_pwm (clk_pwm),
        .rst_n   (rst_n),
        .enable  (enable),
        .duty    (pwm2_reg),
        .pwm_out (pwm_individual[2])
    );

    // LED3
    individual_pwm #(.WIDTH(8)) u_pwm3 (
        .clk_pwm (clk_pwm),
        .rst_n   (rst_n),
        .enable  (enable),
        .duty    (pwm3_reg),
        .pwm_out (pwm_individual[3])
    );

endmodule
