`timescale 1ns/1ps
import led_driver_pkg::*;

module i2c_controller #(
    parameter logic [I2C_ADDR_BITS-1:0] DEVICE_ADDR = 7'h40 // Target I2C address
)(
    input  logic          clk,               // System clock
    global_if             g_if,              // Global reset and sleep interface
    bus_if.i2c_ctrl       bus,               // Shared register bus (controller modport)

    // From Liukee's bit-level interface
    input  logic          start,             // Start condition detected
    input  logic          stop,              // Stop condition detected
    input  logic          rx_valid,          // New byte available from bit-level interface
    input  logic [7:0]    rx_data,           // Received byte (addr/reg or write data)

    // To Liukee's bit-level interface (for reads)
    output logic [7:0]    tx_data,           // Byte to send to I2C master
    output logic          tx_req,            // Pulse: request to send tx_data
    input  logic          tx_ready,          // High when bit-level TX is idle

    output logic          transaction_done   // High after a completed write or read
);

    ctrl_state_t                    state;            // Controller state
    logic [I2C_ADDR_BITS-1:0]       dev_addr_latched; // Latched device address
    logic                           rw_bit;           // Latched R/W bit
    logic [ADDR_BITS-1:0]           reg_addr_ptr;     // Latched register address
    logic                           addr_match;       // Address match flag
    logic [DATA_BITS-1:0]           data_drive;       // Local driver for bus.data
    logic                           read_phase;       // Two-phase read control

    logic 			    sleep_block;

    assign sleep_block = g_if.sleep && (reg_addr_ptr != REG_MODE);

    assign bus.data = (bus.w_en) ? data_drive : 'hz; // Drive bus only during writes


    always_ff @(posedge clk or posedge g_if.reset) begin
        if (g_if.reset) begin
            state             <= CTRL_IDLE;
            dev_addr_latched  <= '0;
            rw_bit            <= 1'b0;
            reg_addr_ptr      <= '0;
            addr_match        <= 1'b0;
            bus.addr          <= '0;
            bus.w_en          <= 1'b0;
            bus.r_en          <= 1'b0;
            data_drive        <= '0;
            tx_data           <= 8'h00;
            tx_req            <= 1'b0;
            transaction_done  <= 1'b0;
            read_phase        <= 1'b0;
        end else begin
            bus.w_en         <= 1'b0;
            bus.r_en         <= 1'b0;
            tx_req           <= 1'b0;

            if (start) begin
                transaction_done <= 1'b0;
                read_phase       <= 1'b0;
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
                        read_phase       <= 1'b0;
                    end
                    if (stop) begin
                        state      <= CTRL_IDLE;
                        read_phase <= 1'b0;
                    end
                end

                CTRL_REG: begin
                    if (rx_valid) begin
                        reg_addr_ptr <= rx_data[ADDR_BITS-1:0];
                        state        <= CTRL_DATA;
                        read_phase   <= 1'b0;
                    end
                    if (stop) begin
                        state      <= CTRL_IDLE;
                        read_phase <= 1'b0;
                    end
                end

                CTRL_DATA: begin
                    if (rw_bit == 1'b0) begin
                        // Write transaction
                        if (rx_valid) begin
                            if (addr_match && !sleep_block) begin
                                bus.addr          <= reg_addr_ptr;
                                data_drive        <= rx_data;
                                bus.w_en          <= 1'b1;
                                transaction_done  <= 1'b1;
                            end
                            state      <= CTRL_IDLE;
                            read_phase <= 1'b0;
                        end
                    end else begin
                        // Read transaction (two-phase to allow bus.data to settle)
                        if (addr_match && !sleep_block) begin
                            bus.addr <= reg_addr_ptr;
                            bus.r_en <= 1'b1;
                            if (!read_phase) begin
                                read_phase <= 1'b1;
                            end else begin
                                if (tx_ready) begin
                                    tx_data          <= bus.data;
                                    tx_req           <= 1'b1;
                                    transaction_done <= 1'b1;
                                    state            <= CTRL_IDLE;
                                    read_phase       <= 1'b0;
                                end
                            end
                        end else begin
                            state      <= CTRL_IDLE;
                            read_phase <= 1'b0;
                        end
                    end
                    if (stop) begin
                        state      <= CTRL_IDLE;
                        read_phase <= 1'b0;
                    end
                end

                default: begin
                    state      <= CTRL_IDLE;
                    read_phase <= 1'b0;
                end
            endcase
        end
    end

endmodule
