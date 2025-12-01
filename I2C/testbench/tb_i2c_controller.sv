`timescale 1ns/1ps
import led_driver_pkg::*;

// Simple LED register stub that sits on the bus_if.led_ctrl side
module led_reg_stub (
    input  logic      clk,
    global_if         g_if,
    bus_if.led_ctrl   bus
);
    logic [DATA_BITS-1:0] regs [0:(1<<ADDR_BITS)-1];
    integer i;

    always_ff @(posedge clk) begin
        if (g_if.reset) begin
            for (i = 0; i < (1<<ADDR_BITS); i++) begin
                regs[i] <= '0;
            end
        end else begin
            if (bus.w_en) begin
                regs[bus.addr] <= bus.data;
            end
        end
    end

    assign bus.data = (bus.r_en) ? regs[bus.addr] : 'hz;

endmodule

module tb_i2c_controller;

    logic clk;                         // System clock
    logic reset;                       // Global reset
    logic sleep;                       // Global sleep

    logic start;                       // Start from bit-level interface
    logic stop;                        // Stop from bit-level interface
    logic rx_valid;                    // Byte valid from bit-level interface
    logic [7:0] rx_data;               // Byte from bit-level interface

    logic [7:0] tx_data;               // Byte to Liukee for reads
    logic       tx_req;                // TX request pulse
    logic       tx_ready;              // TX ready from Liukee

    logic transaction_done;            // Done flag from controller

    logic [ADDR_BITS-1:0] last_wr_addr;
    logic [DATA_BITS-1:0] last_wr_data;
    logic                  prev_w_en;

    logic [ADDR_BITS-1:0] last_rd_addr;
    logic [DATA_BITS-1:0] last_rd_data;
    logic                  prev_tx_req;

    int   error_count;

    global_if g_if(.reset(reset), .sleep(sleep));
    bus_if    bus(clk);

    i2c_controller #(
        .DEVICE_ADDR(7'h40)
    ) dut (
        .clk              (clk),
        .g_if             (g_if),
        .bus              (bus),
        .start            (start),
        .stop             (stop),
        .rx_valid         (rx_valid),
        .rx_data          (rx_data),
        .tx_data          (tx_data),
        .tx_req           (tx_req),
        .tx_ready         (tx_ready),
        .transaction_done (transaction_done)
    );

    led_reg_stub led_regs (
        .clk  (clk),
        .g_if (g_if),
        .bus  (bus)
    );

    localparam real CLK_PERIOD_NS = 10.0;

    initial clk = 1'b0;
    always #(CLK_PERIOD_NS/2.0) clk = ~clk;

    function automatic logic [7:0] pack_addr_rw(input logic [I2C_ADDR_BITS-1:0] addr, input logic rw);
        pack_addr_rw = {addr, rw};
    endfunction

    task automatic send_byte(input logic [7:0] data);
        @(posedge clk);
        rx_data  <= data;
        rx_valid <= 1'b1;
        @(posedge clk);
        rx_valid <= 1'b0;
    endtask

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
        wait (transaction_done === 1'b1);
        @(posedge clk);
        @(posedge clk);
    endtask

    task automatic i2c_read_transaction(input logic [I2C_ADDR_BITS-1:0] dev_addr,
                                        input logic [ADDR_BITS-1:0]     reg_addr);
        logic [7:0] addr_rw;
        addr_rw = pack_addr_rw(dev_addr, 1'b1);
        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;
        send_byte(addr_rw);
        send_byte({{(8-ADDR_BITS){1'b0}}, reg_addr});
        wait (transaction_done === 1'b1);
        @(posedge clk);
        @(posedge clk);
    endtask

    task automatic check_write(input logic [ADDR_BITS-1:0] exp_addr,
                               input logic [DATA_BITS-1:0] exp_data,
                               input string                tag);
        if (last_wr_addr !== exp_addr || last_wr_data !== exp_data) begin
            $error("FAIL %s: expected addr=0x%0h data=0x%0h, got addr=0x%0h data=0x%0h",
                   tag, exp_addr, exp_data, last_wr_addr, last_wr_data);
            error_count++;
        end else begin
            $display("PASS %s: addr=0x%0h data=0x%0h", tag, last_wr_addr, last_wr_data);
        end
    endtask

    task automatic check_read(input logic [ADDR_BITS-1:0] exp_addr,
                              input logic [DATA_BITS-1:0] exp_data,
                              input string                tag);
        if (last_rd_addr !== exp_addr || last_rd_data !== exp_data) begin
            $error("FAIL %s: expected addr=0x%0h data=0x%0h, got addr=0x%0h data=0x%0h",
                   tag, exp_addr, exp_data, last_rd_addr, last_rd_data);
            error_count++;
        end else begin
            $display("PASS %s: addr=0x%0h data=0x%0h", tag, last_rd_addr, last_rd_data);
        end
    endtask

    always_ff @(posedge clk) begin
        if (reset) begin
            last_wr_addr <= '0;
            last_wr_data <= '0;
            prev_w_en    <= 1'b0;
        end else begin
            prev_w_en <= bus.w_en;
            if (bus.w_en && !prev_w_en) begin
                last_wr_addr <= bus.addr;
                last_wr_data <= bus.data;
                $display("TB: WRITE addr=0x%0h data=0x%0h", bus.addr, bus.data);
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            last_rd_addr <= '0;
            last_rd_data <= '0;
            prev_tx_req  <= 1'b0;
        end else begin
            prev_tx_req <= tx_req;
            if (tx_req && !prev_tx_req) begin
                last_rd_addr <= bus.addr;
                last_rd_data <= tx_data;
                $display("TB: READ  addr=0x%0h data=0x%0h", bus.addr, tx_data);
            end
        end
    end

    initial begin : main_test
        reset       = 1'b1;
        sleep       = 1'b0;
        start       = 1'b0;
        stop        = 1'b0;
        rx_valid    = 1'b0;
        rx_data     = 8'h00;
        tx_ready    = 1'b1;
        error_count = 0;

        repeat (5) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);

        i2c_write_transaction(7'h40, REG_PWM0, 8'hAA);
        check_write(REG_PWM0, 8'hAA, "Write PWM0 (0x01)");

        i2c_read_transaction(7'h40, REG_PWM0);
        check_read(REG_PWM0, 8'hAA, "Read PWM0 (0x01)");

        if (error_count == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("TEST FAILED: %0d error(s)", error_count);
        end

        $finish;
    end

endmodule
