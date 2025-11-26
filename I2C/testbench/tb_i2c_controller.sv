`timescale 1ns/1ps
import led_driver_pkg::*;

module tb_i2c_controller;

    logic clk;                      // System clock
    logic reset;                    // Active high reset
    logic sleep;                    // Global sleep signal

    logic start;                    // Start pulse into controller
    logic stop;                     // Stop pulse into controller
    logic rx_valid;                 // Byte valid into controller
    logic [7:0] rx_data;            // Byte into controller

    logic transaction_done;         // Done flag from controller

    int   error_count = 0;          // Error counter

    reg [ADDR_BITS-1:0] last_addr;  // Last address written
    reg [DATA_BITS-1:0] last_data;  // Last data written
    logic               prev_w_en;  // Previous value of bus.w_en

    localparam logic [I2C_ADDR_BITS-1:0] DEV_ADDR = 7'h40; // Same as controller parameter
    localparam real CLK_PERIOD_NS = 10.0;                  // 100 MHz

    // Instantiate global and bus interfaces
    global_if g_if(.reset(reset), .sleep(sleep));
    bus_if    bus(clk);

    // DUT instantiation
    i2c_controller #(
        .DEVICE_ADDR(DEV_ADDR)
    ) dut (
        .clk              (clk),
        .g_if             (g_if),
        .bus              (bus),
        .start            (start),
        .stop             (stop),
        .rx_valid         (rx_valid),
        .rx_data          (rx_data),
        .transaction_done (transaction_done)
    );

    // Clock generation
    initial clk = 1'b0;
    always #(CLK_PERIOD_NS/2.0) clk = ~clk;

    // Function to pack address and R/W bit
    function automatic logic [7:0] pack_addr_rw(input logic [I2C_ADDR_BITS-1:0] addr, input logic rw);
        pack_addr_rw = {addr, rw};
    endfunction

    // Helper to check expected write
    task automatic check_last_write(input logic [ADDR_BITS-1:0] exp_addr,
                                    input logic [DATA_BITS-1:0] exp_data,
                                    input string                tag);
        if (last_addr !== exp_addr || last_data !== exp_data) begin
            $error("FAIL %s: expected addr=0x%0h data=0x%0h, got addr=0x%0h data=0x%0h",
                   tag, exp_addr, exp_data, last_addr, last_data);
            error_count++;
        end else begin
            $display("PASS %s: addr=0x%0h data=0x%0h", tag, last_addr, last_data);
        end
    endtask

    // Capture writes on rising edge of bus.w_en
    always_ff @(posedge clk) begin
        if (reset) begin
            last_addr   <= '0;
            last_data   <= '0;
            prev_w_en   <= 1'b0;
        end else begin
            prev_w_en <= bus.w_en;
            if (bus.w_en && !prev_w_en) begin
                last_addr <= bus.addr;
                last_data <= bus.data;
                $display("TB: DUT write addr=0x%0h data=0x%0h", bus.addr, bus.data);
            end
        end
    end

    // Send one byte into the controller
    task automatic send_byte(input logic [7:0] data);
        @(posedge clk);
        rx_data  <= data;
        rx_valid <= 1'b1;
        @(posedge clk);
        rx_valid <= 1'b0;
    endtask

    // One complete write transaction: START, [addr+W], reg_addr, data, STOP
    task automatic i2c_write_transaction(input logic [I2C_ADDR_BITS-1:0] dev_addr,
                                         input logic [ADDR_BITS-1:0]     reg_addr,
                                         input logic [DATA_BITS-1:0]     data);
        logic [7:0] addr_rw;
        addr_rw = pack_addr_rw(dev_addr, 1'b0);
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        send_byte(addr_rw);
        send_byte({{(8-ADDR_BITS){1'b0}}, reg_addr});
        send_byte(data);
        @(posedge clk);
        stop <= 1'b1;
        @(posedge clk);
        stop <= 1'b0;
        wait (transaction_done === 1'b1);
        @(posedge clk);
    endtask

    // Main test sequence
    initial begin : main_test
        reset       = 1'b1;
        sleep       = 1'b0;
        start       = 1'b0;
        stop        = 1'b0;
        rx_valid    = 1'b0;
        rx_data     = 8'h00;
        error_count = 0;

        repeat (5) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);

        // Test 1: Write PWM0 (REG_PWM0 -> address 1) with 0xAA
        i2c_write_transaction(DEV_ADDR, REG_PWM0, 8'hAA);
        check_last_write(REG_PWM0, 8'hAA, "Write PWM0 (0x01)");

        // Test 2: Write LEDOUT (REG_LEDOUT -> address 7) with 0x55
        i2c_write_transaction(DEV_ADDR, REG_LEDOUT, 8'h55);
        check_last_write(REG_LEDOUT, 8'h55, "Write LEDOUT (0x07)");

        if (error_count == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("TEST FAILED: %0d error(s)", error_count);
        end

        $finish;
    end

endmodule
