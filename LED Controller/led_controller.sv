import led_driver_pkg::*;

// LED Controller Module
module led_controller(
    output logic leds[3:0],
    input clk_400K,
    bus_if bus, 
    global_if glb
);

logic [ADDR_BITS-1:0][DATA_BITS-1:0] register_file; // Define array for registers
logic [DATA_BITS-1:0] read_data; // Internal read data signal

// Handle reset
always_ff @(posedge glb.reset) begin
    integer i;
    for (i = 0; i < (1<<ADDR_BITS); i++)
        register_file[i] <= 0;
end

// Write
always_ff @(posedge bus.clk) begin
    if (bus.w_en)
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

//TODO: Make sleep signal an output? How do we pass it into the I2C modules?

//-- Instantiate PWM control modules:

// Declare intermediate variables
logic clk_6p25K;
logic grp_pwm_signal, indiv_pwm_signal;
reg_mode_t reg_mode;
reg_led_out_t reg_led_out;
assign reg_mode = reg_mode_t'(register_file[REG_MODE]);
assign reg_led_out = reg_led_out_t'(register_file[REG_LEDOUT]);

// Instantiate clock dividers to create 6.25KHz & 1.5625KHz signals
clock_divider #(6) clk_6p25K_m(.clk_in(clk_400K), .glb, .clk_out(clk_6p25K)); // Divide by 64 for 6.25KHz

// Instantiate Group PWM Block (outputs PWM signal to use when an LED is in group mode)
group_pwm group_pwm(
    .grp_pwm_signal, 
    .clk_400K, 
    .clk_6p25K, 
    .dim_blink(reg_mode.dim_blink), 
    .grp_pwm_reg(register_file[REG_GRPPWM]),
    .grp_freq_reg(register_file[REG_GRPFREQ]),
    .glb
);

//TODO: Instantiate Individual PWM Block (outputs PWM signals to use when an LED is in individual mode)
// Something like: indiv_pwm indiv_pwm(.indiv_pwm_signal, .clk_400K, ...)

//TODO: Select correct LED mode signal to pass to the output (Mux)

//TODO: Invert signals if needed

endmodule