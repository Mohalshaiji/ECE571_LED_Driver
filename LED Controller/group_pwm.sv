import led_driver_pkg::*;

// Module to create the group mode PWM output
module group_pwm(
    output logic grp_pwm_signal, 
    global_if glb, 
    input logic [DATA_BITS-1:0] grp_pwm_reg, grp_freq_reg,
    input logic dim_blink,
    input logic clk_400K,
    input logic clk_6p25K
);

// Create intermediate signals
logic grp_blink_clk, grp_dim_clk, grp_clk;

// Generate Dimming Clock - Divide 400KHz clock by 8 to generate ~50KHz (50K / 256 = ~195Hz for final PWM freq)
clock_divider #(3) dim_clk_m(.clk_in(clk_400K), .clk_out(grp_dim_clk), .glb);

// Generate Blinking Clock - Divide 6.25KHz clock by variable amount (based on REG_GRPFREQ)
// -> (6.25K to 24 Hz) / 256 = (24 to 0.9 Hz) for final PWM freq
variable_clock_divider #(DATA_BITS) blink_clk_m(.clk_in(clk_6p25K), .clk_out(grp_blink_clk), .divisor(grp_freq_reg), .glb);

// Select which clock to use
assign grp_clk = dim_blink ? grp_blink_clk : grp_dim_clk;

// Feed the group clock into a pwm block along with the duty cycle from REG_GRPPWM
pwm #(DATA_BITS) grp_pwm_m(.pwm_out(grp_pwm_signal), .clk(grp_clk), .duty(grp_pwm_reg), .glb);

endmodule