`timescale 1ns/1ps
import i2c_pkg::*;

module i2c_controller #(
  parameter logic [I2C_ADDR_WIDTH-1:0] DEVICE_ADDR = 7'h40 // Target I2C address
)(
  input  logic                     clk,              // System clock
  input  logic                     reset_n,          // Active low reset
  input  logic                     sleep,            // Sleep mode input
  input  logic                     start,            // Start of I2C transaction
  input  logic                     stop,             // End of I2C transaction
  input  logic                     rx_valid,         // New byte available
  input  logic [I2C_DATA_WIDTH-1:0] rx_data,         // Received byte from I2C interface
  output reg_bus_t                 reg_bus,          // Register bus write/read strobes
  output logic                     transaction_done  // Stays high until next start
);

  ctrl_state_t                     state;            // Controller state
  logic [I2C_ADDR_WIDTH-1:0]       dev_addr_latched; // Latched device address
  logic                            rw_bit;           // Latched R/W bit
  logic [REG_ADDR_WIDTH-1:0]       reg_addr_ptr;     // Current register pointer
  logic                            addr_match;       // Address match flag

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      state             <= CTRL_IDLE;
      dev_addr_latched  <= '0;
      rw_bit            <= 1'b0;
      reg_addr_ptr      <= '0;
      addr_match        <= 1'b0;
      reg_bus           <= '0;
      transaction_done  <= 1'b0;
    end else begin
      reg_bus.write_en  <= 1'b0;
      reg_bus.read_en   <= 1'b0;

      if (start) begin
        transaction_done <= 1'b0;
      end

      unique case (state)
        CTRL_IDLE: begin
          if (start) begin
            state      <= CTRL_ADDR;
            addr_match <= 1'b0;
          end
        end

        CTRL_ADDR: begin
          if (rx_valid) begin
            dev_addr_latched <= rx_data[7:1];
            rw_bit           <= rx_data[0];
            addr_match       <= (rx_data[7:1] == DEVICE_ADDR);
            state            <= CTRL_REG;
          end
        end

        CTRL_REG: begin
          if (rx_valid) begin
            reg_addr_ptr <= rx_data;
            state        <= CTRL_DATA;
          end
          if (stop) begin
            state <= CTRL_IDLE;
          end
        end

        CTRL_DATA: begin
          if (rx_valid) begin
            if (addr_match && (rw_bit == 1'b0) && !sleep) begin
              reg_bus.addr     <= reg_addr_ptr;
              reg_bus.data     <= rx_data;
              reg_bus.write_en <= 1'b1;
              transaction_done <= 1'b1;  // Latch done until next start
            end
            state <= CTRL_IDLE;
          end
          if (stop) begin
            state <= CTRL_IDLE;
          end
        end

        default: begin
          state <= CTRL_IDLE;
        end
      endcase
    end
  end

endmodule
