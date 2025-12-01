import led_driver_pkg::*;

// Testbench for clock divider
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

// Group all test tasks here
task test();
    write_reg(REG_PWM0, 8'h40);         // Set PWM0 channel to 25%
    write_reg(REG_PWM1, 8'h80);         // Set PWM0 channel to 50%
    write_reg(REG_PWM2, 8'hC0);         // Set PWM0 channel to 75%
    write_reg(REG_PWM3, 8'hFF);         // Set PWM0 channel to 99%
    write_reg(REG_GRPPWM, 8'hC0);       // Set group PWM to 75%
    #1000 write_reg(REG_LEDOUT, 8'h55);  // Turn LEDs to fully on (no PWM)
    #1000 write_reg(REG_LEDOUT, 8'hAA);  // Turn LEDs to individual mode
    #1000 write_reg(REG_LEDOUT, 8'hFF);  // Turn LEDs to group mode
    #1000 write_reg(REG_GRPPWM, 8'h20);  // Set group PWM to 12.5%

    //TODO: test more cases?
    
    // Read registers before & after reset
    read_reg(REG_PWM0);
    read_reg(REG_PWM1);
    read_reg(REG_PWM2);
    read_reg(REG_PWM3);

    #1000 reset_dut();

    read_reg(REG_PWM0);
    read_reg(REG_PWM1);
    read_reg(REG_PWM2);
    read_reg(REG_PWM3);

    #1000
    end_sim(); // Flag the end of sim
    $finish();
endtask

initial begin
    CLK_400K = 0;
    sleep = 0; reset = 0;
    BUS.addr = 0; data_out = 0; BUS.w_en = 0; BUS.r_en = 0;

    reset_dut();
    fork
        forever #0.00125 CLK_400K = ~CLK_400K;   // Generate 400KHz clock
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