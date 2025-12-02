import led_driver_pkg::*;


// Testbench for LED Driver (Main Module)
module led_driver_tb;

// Set timescale
timeunit 1ms;
timeprecision 10ns;


// Declare port connections & interfaces
logic [3:0] LEDS;
logic RESET;
logic SCL;
wire  SDA;
logic sda_out;   // SDA value driven by TB
logic sda_oe;    // SDA output enable: 1 = drive, 0 = release

assign SDA = sda_oe ? sda_out : 1'bz;


// Instantiate DUT
led_driver DUT(
    .leds(LEDS),
    .reset(RESET),
    .scl(SCL),
    .sda(SDA)
);
// keep track of writes for self-checking
logic [ADDR_BITS-1:0] last_addr;
logic [DATA_BITS-1:0] last_data;
logic                 last_we;

always @(posedge DUT.bus.w_en) begin
    last_addr <= DUT.bus.addr;
    last_data <= DUT.bus.data;
    last_we   <= 1'b1;
end


logic __end; // Special var for flagging end of sim
int error_count = 0; // for testbench self-checking
// Task for flagging the end of simulation
task end_sim();
    __end = 0; #1;
    __end = 1; #1;
    $dumpflush;
endtask


// Task for reseting the DUT
task reset_dut();
    #0.0025 RESET = 1; 
    #0.0025 RESET = 0;
    $display("[Reset]");
endtask


localparam logic [6:0] I2C_ADDR = 7'h40;  // Must match DEVICE_ADDR in i2c_controller
localparam real        T_I2C    = 0.01; // Half I2C bit time with timeunit 1ms

task automatic i2c_start();
    sda_oe  = 1'b1;
    sda_out = 1'b1;
    SCL     = 1'b1;
    #T_I2C;
    sda_out = 1'b0; // SDA 1->0 while SCL=1
    #T_I2C;
endtask

task automatic i2c_stop();
    sda_oe  = 1'b1;
    sda_out = 1'b0;
    SCL     = 1'b1;
    #T_I2C;
    sda_out = 1'b1; // SDA 0->1 while SCL=1
    #T_I2C;
endtask

task automatic i2c_write_byte(input logic [7:0] data);
    int i;
    for (i = 7; i >= 0; i--) begin
        SCL     = 1'b0;
        sda_oe  = 1'b1;
        sda_out = data[i];
        #T_I2C;
        SCL     = 1'b1;
        #T_I2C;
    end
    // No ACK Cycle
endtask

task automatic i2c_read_byte(output logic [7:0] data);
    int  i;
    logic bit_val;
    data = '0;
    for (i = 7; i >= 0; i--) begin
        SCL    = 1'b0;
        sda_oe = 1'b0; // release SDA so slave can drive
        #T_I2C;
        SCL    = 1'b1;
        #T_I2C;
        bit_val = SDA;
        data[i] = bit_val;
    end
    // No ACK/NACK cycle
endtask

task automatic i2c_write_reg_raw(input reg_enum_t a, input logic [DATA_BITS-1:0] d);
    logic [7:0] addr_byte;
    logic [7:0] reg_byte;
    addr_byte = {I2C_ADDR, 1'b0};                    // 7-bit addr + W
    reg_byte  = {{(8-ADDR_BITS){1'b0}}, a};          // zero-extend reg index

    i2c_start();
    i2c_write_byte(addr_byte);
    i2c_write_byte(reg_byte);
    i2c_write_byte(d);
    i2c_stop();
endtask

task automatic i2c_read_reg_raw(input reg_enum_t a, output logic [DATA_BITS-1:0] d);
    logic [7:0] addr_byte;
    logic [7:0] reg_byte;
    logic [7:0] tmp;
    addr_byte = {I2C_ADDR, 1'b1};                    // 7-bit addr + R
    reg_byte  = {{(8-ADDR_BITS){1'b0}}, a};

    i2c_start();
    i2c_write_byte(addr_byte);
    i2c_write_byte(reg_byte);
    i2c_read_byte(tmp);
    i2c_stop();

    d = tmp;
endtask

// Task for writing to a register in the LED controller
task write_reg(input reg_enum_t a, input logic [DATA_BITS-1:0] d);
    logic [ADDR_BITS-1:0] exp_addr;

    exp_addr = a;

    i2c_write_reg_raw(a, d);

    // small delay to let controller update bus
    #0.001;

    if (!last_we) begin
        $error("[Write-Check FAIL] %s no write observed on bus_if", a.name());
        error_count++;
    end
    else if (last_addr !== exp_addr || last_data !== d) begin
        $error("[Write-Check FAIL] %s expected addr=%0d data=%b got addr=%0d data=%b",
               a.name(), exp_addr, d, last_addr, last_data);
        error_count++;
    end
    else begin
        $display("[Write-Check PASS]\t%s\taddr=%0d data=%b", a.name(), last_addr, last_data);
    end

    last_we = 1'b0;
endtask

// Task for reading a register in the LED controller
task read_reg(input reg_enum_t a);
    logic [DATA_BITS-1:0] d;
    i2c_read_reg_raw(a, d);
    $display("[Read]\t%s\t\tDATA=%b", a.name(), d);
endtask

// Test LED ON output
task test_on();
    $display("\n-- LEDs On (No PWM) --");
    #1s;
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
    write_reg(REG_MODE, 8'h00);         // Clear SLEEP bit
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
    read_reg(REG_PWM0); #1;
    read_reg(REG_PWM1); #1;
    read_reg(REG_PWM2); #1;
    read_reg(REG_PWM3); #1;
    reset_dut(); 
    #1s;
    read_reg(REG_PWM0); #1;
    read_reg(REG_PWM1); #1;
    read_reg(REG_PWM2); #1;
    read_reg(REG_PWM3); #1;
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
    
    if (error_count == 0) begin
        $display("\n=== ALL TESTS PASSED ===");
    end else begin
        $display("\n=== TEST FAILED: %0d error(s) ===", error_count);
    end

    end_sim(); // Flag the end of sim
    $finish();
endtask

// Main intial block
initial begin
    // Zero everything out
    RESET   = 0;
    SCL     = 0;
    sda_oe  = 1'b1;
    sda_out = 1'b1;   // I2C idle: SDA high

    reset_dut();      // Reset before starting
    test();           // Run all tests
end

// Save the output file
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, led_driver_tb.__end);
    $dumpvars(0, led_driver_tb.LEDS);
end

endmodule
