// ------------------------------------------------------------
// led_mode_select.sv
// Selects source for each LED output based on LEDOUT register
//
// For each LEDn (n=0..3), LEDOUT uses 2 bits:
//   00: LED permanently OFF
//   01: LED permanently ON
//   10: LED uses individual PWMn
//   11: LED uses group_out (group dim/blink)
// INVRT bit globally inverts all LED outputs
// ------------------------------------------------------------
`timescale 1ns/1ps

module led_mode_select (
    input  logic [7:0] ledout_reg,        // LEDOUT register (2 bits per LED)
    input  logic [3:0] pwm_individual,    // from individual_pwm_block
    input  logic       group_out,         // group-control waveform
    input  logic       invrt,             // 1 = invert all outputs
    output logic [3:0] led                // final LED pins
);

    // Decode 2-bit mode per LED
    logic [1:0] mode_led0;
    logic [1:0] mode_led1;
    logic [1:0] mode_led2;
    logic [1:0] mode_led3;

    assign mode_led0 = ledout_reg[1:0];
    assign mode_led1 = ledout_reg[3:2];
    assign mode_led2 = ledout_reg[5:4];
    assign mode_led3 = ledout_reg[7:6];

    logic [3:0] led_raw;

    // Helper function: one LED mode select
    function automatic logic select_mode (
        input logic [1:0] mode,
        input logic       pwm_indiv,
        input logic       grp
    );
        unique case (mode)
            2'b00: select_mode = 1'b0;         // OFF
            2'b01: select_mode = 1'b1;         // ON
            2'b10: select_mode = pwm_indiv;    // individual PWM
            2'b11: select_mode = grp & pwm_indiv; // group output overlayed with individual brightness
            default: select_mode = 1'b0;
        endcase
    endfunction

    always_comb begin
        led_raw[0] = select_mode(mode_led0, pwm_individual[0], group_out);
        led_raw[1] = select_mode(mode_led1, pwm_individual[1], group_out);
        led_raw[2] = select_mode(mode_led2, pwm_individual[2], group_out);
        led_raw[3] = select_mode(mode_led3, pwm_individual[3], group_out);

        // Apply global invert from MODE[2]
        led = invrt ? ~led_raw : led_raw;
    end

endmodule
