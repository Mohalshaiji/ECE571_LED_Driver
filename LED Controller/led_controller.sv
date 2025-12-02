import led_driver_pkg::*;

// LED Controller Module
module led_controller(
    output logic [3:0] leds,
    output logic sleep,
    input clk_400K,
    bus_if.led_ctrl bus,
    global_if glb
);

logic [(1 << ADDR_BITS)-1:0][DATA_BITS-1:0] register_file; // Define array for registers
logic [DATA_BITS-1:0] read_data; // Internal read data signal


// Write / Reset
always_ff @(posedge bus.clk, posedge glb.reset) begin
    if (glb.reset) begin // Reset case
        integer i;
        for (i = 0; i < (1<<ADDR_BITS); i++)
            register_file[i] <= 0;
    end else if (bus.w_en) // Write case
        register_file[bus.addr] <= bus.data; // Latch incoming write data
end

// Read
always_comb begin
    if (bus.r_en)
        read_data = register_file[bus.addr];
    else
        read_data = 'z;   // not driving
end

// Drive bus during read
assign bus.data = bus.r_en ? read_data : 'z;


//-- Instantiate PWM control modules:

// Declare intermediate variables
logic clk_6p25K, led_clk_400K;
logic grp_pwm_signal;
logic [3:0] indiv_pwm_signal;
reg_mode_t reg_mode;
reg_led_out_t reg_led_out;
assign reg_mode = reg_mode_t'(register_file[REG_MODE]);
assign reg_led_out = reg_led_out_t'(register_file[REG_LEDOUT]);

// Assign sleep output signal from the mode register
assign sleep = reg_mode.sleep;

// Turn clock off if asleep
assign led_clk_400K = glb.sleep ? 0 : clk_400K;

// Instantiate clock divider to create 6.25KHz signal
clock_divider #(6) clk_6p25K_m(.clk_in(led_clk_400K), .glb, .clk_out(clk_6p25K)); // Divide by 64 for 6.25KHz

// Instantiate Group PWM Block (outputs PWM signal to use when an LED is in group mode)
group_pwm group_pwm_m(
    .grp_pwm_signal, 
    .clk_400K(led_clk_400K), 
    .clk_6p25K, 
    .dim_blink(reg_mode.dim_blink), 
    .grp_pwm_reg(register_file[REG_GRPPWM]),
    .grp_freq_reg(register_file[REG_GRPFREQ]),
    .glb
);

// Instantiate Individual PWM Block (outputs PWM signals to use when an LED is in individual mode)
individual_pwm_block indiv_pwm_m(
    .clk_pwm(led_clk_400K),
    .rst_n(~glb.reset),
    .sleep(glb.sleep),
    .pwm0_reg(register_file[REG_PWM0]),
    .pwm1_reg(register_file[REG_PWM1]),
    .pwm2_reg(register_file[REG_PWM2]),
    .pwm3_reg(register_file[REG_PWM3]),
    .pwm_individual(indiv_pwm_signal)
);

// Select correct LED mode signal to pass to the output (Mux)
led_mode_select led_mode_select_m(
    .ledout_reg(register_file[REG_LEDOUT]),        
    .pwm_individual(indiv_pwm_signal),    
    .group_out(grp_pwm_signal),         
    .invrt(reg_mode.invert),            
    .led(leds)        
);

endmodule