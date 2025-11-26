`timescale 1ns/1ps
import i2c_pkg::*;

module tb_i2c_controller;

  logic       clk;               // System clock
  logic       reset_n;           // Active low reset
  logic       sleep;             // Sleep control
  logic       start;             // Start pulse
  logic       stop;              // Stop pulse
  logic       rx_valid;          // Byte valid pulse
  logic [7:0] rx_data;           // Byte from I2C interface

  reg_bus_t   reg_bus;           // Register bus from DUT
  logic       transaction_done;  // Transaction done pulse

  int         error_count = 0;   // Error counter
  reg_bus_t   last_write;        // Last write captured
  logic       prev_write_en;     // For edge detection of write_en

  localparam logic [6:0] DEV_ADDR = 7'h40; // Device address used in tests
  localparam real CLK_PERIOD_NS   = 10.0;  // 100 MHz clock

  i2c_controller #(
    .DEVICE_ADDR(DEV_ADDR)
  ) dut (
    .clk              (clk),
    .reset_n          (reset_n),
    .sleep            (sleep),
    .start            (start),
    .stop             (stop),
    .rx_valid         (rx_valid),
    .rx_data          (rx_data),
    .reg_bus          (reg_bus),
    .transaction_done (transaction_done)
  );

  initial clk = 1'b0;
  always #(CLK_PERIOD_NS/2.0) clk = ~clk;

  // Pack 7-bit address and R/W bit into a byte
  function automatic logic [7:0] pack_addr_rw(input logic [6:0] addr, input logic rw);
    pack_addr_rw = {addr, rw};
  endfunction

  // Build expected reg_bus_t value
  function automatic reg_bus_t make_expected(input logic [7:0] addr, input logic [7:0] data);
    reg_bus_t tmp;
    tmp.addr     = addr;
    tmp.data     = data;
    tmp.write_en = 1'b1;
    tmp.read_en  = 1'b0;
    return tmp;
  endfunction

  // Send one byte to the controller
  task automatic send_byte(input logic [7:0] data);
    @(posedge clk);
    rx_data  <= data;
    rx_valid <= 1'b1;
    @(posedge clk);
    rx_valid <= 1'b0;
  endtask

  // One complete write transaction: START, [addr+W], reg_addr, data, STOP
  task automatic i2c_write_transaction(input logic [6:0] dev_addr, input logic [7:0] reg_addr, input logic [7:0] data);
    logic [7:0] addr_rw;
    addr_rw = pack_addr_rw(dev_addr, 1'b0);
    @(posedge clk);
    start <= 1'b1;
    @(posedge clk);
    start <= 1'b0;
    send_byte(addr_rw);
    send_byte(reg_addr);
    send_byte(data);
    @(posedge clk);
    stop <= 1'b1;
    @(posedge clk);
    stop <= 1'b0;
    wait (transaction_done === 1'b1);
    @(posedge clk);
  endtask

  // Self-check against expected write
  task automatic check_last_write(input reg_bus_t expected, input string tag);
    if (last_write.write_en !== expected.write_en ||
        last_write.addr    !== expected.addr    ||
        last_write.data    !== expected.data) begin
      $error("FAIL %s: expected we=%0b addr=0x%02h data=0x%02h, got we=%0b addr=0x%02h data=0x%02h",
             tag,
             expected.write_en, expected.addr, expected.data,
             last_write.write_en, last_write.addr, last_write.data);
      error_count++;
    end else begin
      $display("PASS %s: addr=0x%02h data=0x%02h", tag, last_write.addr, last_write.data);
    end
  endtask

  // Capture writes on rising edge of write_en
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      last_write   <= '0;
      prev_write_en <= 1'b0;
    end else begin
      prev_write_en <= reg_bus.write_en;
      if (reg_bus.write_en && !prev_write_en) begin
        last_write <= reg_bus;
        $display("TB: DUT write addr=0x%02h data=0x%02h", reg_bus.addr, reg_bus.data);
      end
    end
  end

  initial begin : main_test
    reg_bus_t expected;

    reset_n     = 1'b0;
    sleep       = 1'b0;
    start       = 1'b0;
    stop        = 1'b0;
    rx_valid    = 1'b0;
    rx_data     = 8'h00;
    error_count = 0;

    repeat (5) @(posedge clk);
    reset_n = 1'b1;
    @(posedge clk);

    // Test 1: Write PWM0 (0x01) = 0xAA
    expected = make_expected(8'h01, 8'hAA);
    i2c_write_transaction(DEV_ADDR, expected.addr, expected.data);
    check_last_write(expected, "Write PWM0 (0x01)");

    // Test 2: Write LEDOUT (0x07) = 0x55
    expected = make_expected(8'h07, 8'h55);
    i2c_write_transaction(DEV_ADDR, expected.addr, expected.data);
    check_last_write(expected, "Write LEDOUT (0x07)");

    if (error_count == 0) begin
      $display("ALL TESTS PASSED");
    end else begin
      $display("TEST FAILED: %0d error(s)", error_count);
    end

    $finish;
  end

endmodule
