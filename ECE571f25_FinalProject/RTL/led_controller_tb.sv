import led_driver_pkg::*;

// Testbench for LED Controller
module led_controller_tb;

// Set timescale
timeunit 1ms;
timeprecision 10ns;

// Special var for flagging end of sim
logic __end;

// Declare port connections & interfaces
logic CLK_400K;
logic [3:0] LEDS;

logic reset, sleep;
global_if GLB(.reset, .sleep);

bus_if BUS(.clk(CLK_400K));

logic [DATA_BITS-1:0] data_out;
assign BUS.data = (BUS.w_en) ? data_out : 'z;


// Instantiate DUT
led_controller DUT(
    .leds(LEDS),
    .sleep(sleep),
    .clk_400K(CLK_400K),
    .bus(BUS.led_ctrl),
    .glb(GLB)
);

// Task for flagging the end of simulation
task end_sim();
    __end = 0; #1;
    __end = 1; #1;
    $dumpflush;
endtask

// Task for reseting the DUT
task reset_dut();
    #0.0025 reset = 1; 
    #0.0025 reset = 0;
    $display("[Reset]");
endtask

// Task for writing to a register in the LED controller
task write_reg(input reg_enum_t a, input logic [DATA_BITS-1:0] d);
    data_out = d;
    BUS.addr = a;
    BUS.r_en = 0;
    #0.0025 // Wait one clock cycle to ensure data & address are latched
    BUS.w_en = 1;
    #0.0025 BUS.w_en = 0; // Hold write enable high for one clock cycle
    $display("[Write]\t%s\t\tDATA=%b", a.name(), data_out);
endtask

// Task for reading a register in the LED controller
task read_reg(input reg_enum_t a);
    BUS.addr = a;
    BUS.w_en = 0;
    #0.0025 // Wait one clock cycle to ensure address is latched
    BUS.r_en = 1;
    #0.0025; // Hold read enable high for one clock cycle
    $display("[Read]\t%s\t\tDATA=%b", a.name(), BUS.data); // display result
    BUS.r_en = 0;
endtask

// Test LED ON output
task test_on();
    $display("\n-- LEDs On (No PWM) --");
    write_reg(REG_LEDOUT, 8'h55);       // Turn LEDs to fully on (no PWM)
    #1s;
endtask

// Test individual PWM output
task test_indiv();
    $display("\n-- Individual PWM --");
    write_reg(REG_LEDOUT, 8'hAA);       // Turn LEDs to individual mode
    #1s;
    write_reg(REG_PWM0, 8'h40);         // Set PWM0 channel to 25%
    write_reg(REG_PWM1, 8'h80);         // Set PWM1 channel to 50%
    write_reg(REG_PWM2, 8'hC0);         // Set PWM2 channel to 75%
    write_reg(REG_PWM3, 8'hFF);         // Set PWM3 channel to 99%
    #1s;
    write_reg(REG_PWM0, 8'hb2);         // Set PWM0 channel to 69.5%
    #1s;
    write_reg(REG_PWM1, 8'h01);         // Set PWM1 channel to 0.4%
    #1s;
    write_reg(REG_PWM2, 8'hE7);         // Set PWM2 channel to 90.2%
    #1s;
    write_reg(REG_PWM3, 8'h33);         // Set PWM3 channel to 20%
    #1s;
endtask

// Test group dimming mode
task test_grp_dim();
    $display("\n-- Group Dimming --");
    write_reg(REG_LEDOUT, 8'hFF);       // Turn LEDs to group mode
    write_reg(REG_GRPPWM, 8'hC0);       // Set group PWM to 75%
    #1s;
    write_reg(REG_PWM3, 8'h40);         // Set PWM3 channel to 25%
    write_reg(REG_PWM2, 8'h80);         // Set PWM2 channel to 50%
    write_reg(REG_PWM1, 8'hC0);         // Set PWM1 channel to 75%
    write_reg(REG_PWM0, 8'hFF);         // Set PWM0 channel to 99%
    #1s;
    write_reg(REG_GRPPWM, 8'h00);       // Set group PWM to 0%
    #1s;
    write_reg(REG_GRPPWM, 8'h80);       // Set group PWM to 50%
    #1s;
    write_reg(REG_GRPPWM, 8'h30);       // Set group PWM to 18.75%
    #1s;
endtask

// Test group blinking mode
task test_grp_blink();
    $display("\n-- Group Blinking --");
    write_reg(REG_LEDOUT, 8'hFF);       // Turn LEDs to group mode
    write_reg(REG_MODE, 8'h08);         // Set DMBLNK bit (GRPFREQ is zero by default so blink @24Hz)
    #1s;
    write_reg(REG_GRPPWM, 8'h80);       // Set group PWM to 50%
    #1s;
    write_reg(REG_GRPFREQ, 8'h10);      // Set group period to 656ms (1.524Hz) 
    #5s;
    write_reg(REG_GRPFREQ, 8'hFF);      // Set group period to max (10.5s - 0.09Hz) 
    #25s;
    write_reg(REG_MODE, 8'h00);         // Clear DMBLNK bit
    #1s;
endtask

// Test sleep
task test_sleep();
    $display("\n-- Sleep --");
    write_reg(REG_LEDOUT, 8'hAA);       // Turn LEDs to individual mode
    write_reg(REG_MODE, 8'h10);         // Set SLEEP bit
    #1s;
    write_reg(REG_MODE, 8'h10);         // Clear SLEEP bit
    #1s;
endtask

// Test inverting the output
task test_invert();
    $display("\n-- Invert Output --");
    write_reg(REG_LEDOUT, 8'hAA);       // Turn LEDs to individual mode
    write_reg(REG_MODE, 8'h04);         // Set INVRT bit
    #1s;
    write_reg(REG_MODE, 8'h00);         // Clear INVRT bit
    #1s;
endtask

// Test reading register values
task test_readback();
    $display("\n-- Register Read --");
    // Read PWM registers before & after reset
    read_reg(REG_PWM0);
    read_reg(REG_PWM1);
    read_reg(REG_PWM2);
    read_reg(REG_PWM3);
    reset_dut(); 
    #1s;
    read_reg(REG_PWM0);
    read_reg(REG_PWM1);
    read_reg(REG_PWM2);
    read_reg(REG_PWM3);
    #1s;
endtask

// Group all test tasks here
task test();
    $display("\n=== Starting Testcases ===\n");

    test_on();
    test_indiv();
    test_grp_dim();
    test_grp_blink();
    test_sleep();
    test_invert();
    test_readback();
    
    end_sim(); // Flag the end of sim
    $finish();
endtask

// Main intial block
initial begin
    // Zero everything out
    CLK_400K = 0;
    reset = 0;
    BUS.addr = 0; data_out = 0; BUS.w_en = 0; BUS.r_en = 0;

    reset_dut(); // Reset before starting
    fork
        forever #0.00125 CLK_400K = ~CLK_400K;  // Generate 400KHz clock
        test();                                 // Call the test task                             
    join
end

// Save the output file
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, led_controller_tb.__end);
    $dumpvars(0, led_controller_tb.LEDS);
    
end

endmodule