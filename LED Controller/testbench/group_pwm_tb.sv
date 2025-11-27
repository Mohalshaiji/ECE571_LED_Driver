import led_driver_pkg::*;

// Testbench for clock divider
module group_pwm_tb;

// Set timescale
timeunit 1ms;
timeprecision 10ns;

// Declare port nets/vars
logic reset, sleep;
global_if glb(.reset, .sleep);
logic clk_400K, clk_6p25K;
logic grp_pwm_signal;
reg [7:0] grp_pwm_reg, grp_freq_reg;
logic dim_blink;

// Instantiate DUT
group_pwm DUT(.clk_400K, .clk_6p25K, .dim_blink, .grp_pwm_reg, .grp_freq_reg, .grp_pwm_signal, .glb);

task test_dim();
    dim_blink = 0;      // Set dim mode

    // Test different duty cycle cases
    #100 grp_pwm_reg = 8'h01;
    #100 grp_pwm_reg = 8'h02;
    #100 grp_pwm_reg = 8'h03;
    #100 grp_pwm_reg = 8'h40;
    #100 grp_pwm_reg = 8'h80;
    #100 grp_pwm_reg = 8'hC0;
    #100 grp_pwm_reg = 8'hFF;
    #100 grp_freq_reg = 8'hAA; // Confirm that setting the group freq while in dimming mode does not affect the output
endtask

task test_blink();
    dim_blink = 1;      // Set blink mode

    // Test different duty cycle / frequency combinations
    grp_pwm_reg = 8'h40; grp_freq_reg = 8'h00; #1000; // ~41ms blink (zero default)
    grp_pwm_reg = 8'h80; #1000;
    grp_pwm_reg = 8'hC0; #1000;
    grp_pwm_reg = 8'h40; grp_freq_reg = 8'h01; #1000; // ~82ms blink
    grp_pwm_reg = 8'h80; #1000; 
    grp_pwm_reg = 8'hC0; #1000; 
    grp_pwm_reg = 8'h40; grp_freq_reg = 8'h10; #5000; // ~700ms blink
    grp_pwm_reg = 8'h80; #5000;
    grp_pwm_reg = 8'hC0; #5000;
    grp_pwm_reg = 8'h40; grp_freq_reg = 8'hFF; #50000; // ~10.5s blink
    grp_pwm_reg = 8'h80; #50000;
    grp_pwm_reg = 8'hC0; #50000;
endtask

// Group all test tasks here
task test();
    test_dim();
    test_blink();
    $finish();
endtask

initial begin
    clk_400K = 0;
    clk_6p25K = 0;
    grp_pwm_reg = 0;    // Start at zero duty cycle
    grp_freq_reg = 0;   // No group freq
    #3 reset = 1; #3 reset = 0; // Reset the DUTs
    fork
        forever #0.00125 clk_400K = ~clk_400K;   // Generate 400KHz clock
        forever #0.08 clk_6p25K = ~clk_6p25K;   // Generate 6.25KHz clock
        test();                                 // Call the test task                             
    join
end

endmodule